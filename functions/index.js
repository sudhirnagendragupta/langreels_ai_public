// Firebase Cloud Functions for LangReels AI Processing Pipeline
// Date: August 14, 2025 (AWS Transcribe - Event-Driven with EventBridge)

// Corrected imports for Firebase Functions v2
const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onCall, onRequest } = require('firebase-functions/v2/https');
const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions').logger;
const functions = require('firebase-functions');

const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const { TranslationServiceClient } = require('@google-cloud/translate');
const videoIntelligence = require('@google-cloud/video-intelligence');

// AWS SDK v3 imports
const { TranscribeClient, StartTranscriptionJobCommand, GetTranscriptionJobCommand, DeleteTranscriptionJobCommand } = require('@aws-sdk/client-transcribe');
const { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google Cloud clients
const storageClient = new Storage();
const translateClient = new TranslationServiceClient();
const videoClient = new videoIntelligence.VideoIntelligenceServiceClient();

// Initialize AWS services
const transcribeClient = new TranscribeClient({
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
    region: process.env.AWS_REGION || 'us-east-1'
});

const s3Client = new S3Client({
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
    region: process.env.AWS_REGION || 'us-east-1'
});

// Configuration
const SUPPORTED_LANGUAGES = {
    'en': 'English', 'es': 'Spanish', 'fr': 'French',
    'de': 'German', 'it': 'Italian', 'pt': 'Portuguese',
    'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean',
    'zh': 'Chinese', 'ar': 'Arabic', 'hi': 'Hindi',
    'kn': 'Kannada', 'mr': 'Marathi', 'ta': 'Tamil'
};

const MAX_VIDEO_DURATION = 120; // 2 minutes in seconds
const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB

// --- NEW: Event-Driven AWS Transcribe Function ---

async function startTranscriptionJobEventDriven(videoFilePath, reelId) {
    try {
        logger.log(`🚀 Starting EVENT-DRIVEN transcription for reel ${reelId}`);

        const bucketName = process.env.AWS_S3_BUCKET || 'langreels-transcribe-temp';
        const videoFileName = `temp-video-${reelId}-${Date.now()}.mp4`;
        const jobName = `transcribe-job-${reelId}-${Date.now()}`;

        // Upload video to S3
        const videoBuffer = fs.readFileSync(videoFilePath);
        const uploadCommand = new PutObjectCommand({
            Bucket: bucketName,
            Key: videoFileName,
            Body: videoBuffer,
            ContentType: 'video/mp4',
            Metadata: {
                'reelId': reelId,
                'firebaseProject': process.env.GCLOUD_PROJECT
            }
        });
        await s3Client.send(uploadCommand);

        // Start transcription job (NO POLLING - just start and return)
        const transcribeCommand = new StartTranscriptionJobCommand({
            TranscriptionJobName: jobName,
            IdentifyLanguage: true,
            LanguageOptions: ['en-US', 'es-ES', 'fr-FR', 'de-DE', 'it-IT', 'pt-BR',
                'hi-IN', 'kn-IN', 'ta-IN', 'mr-IN', 'ja-JP', 'ko-KR',
                'zh-CN', 'ar-AE', 'ru-RU'],
            MediaFormat: 'mp4',
            Media: {
                MediaFileUri: `s3://${bucketName}/${videoFileName}`
            },
            OutputBucketName: bucketName,
            Subtitles: {
                Formats: ['srt'],
                OutputStartIndex: 1
            }
        });

        await transcribeClient.send(transcribeCommand);

        // Store job metadata in Firestore for webhook to retrieve later
        await admin.firestore().collection('transcribe_jobs').doc(jobName).set({
            reelId: reelId,
            jobName: jobName,
            videoFileName: videoFileName,
            bucketName: bucketName,
            status: 'IN_PROGRESS',
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
            firebaseProject: process.env.GCLOUD_PROJECT
        });

        logger.log(`✅ Transcription job ${jobName} started successfully - awaiting EventBridge notification`);

        // Update reel status to show transcription in progress
        await updateProcessingStatus(reelId, 'transcribing', {
            transcribeJobName: jobName,
            transcribeMethod: 'event-driven'
        });

        return {
            success: true,
            jobName: jobName,
            message: 'Transcription started, will process via EventBridge'
        };

    } catch (error) {
        logger.error(`❌ Failed to start event-driven transcription:`, error);
        throw error;
    }
}

// --- NEW: Webhook Handler for AWS EventBridge/SNS ---
// --- NEW: Webhook Handler for AWS EventBridge/SNS ---
exports.handleTranscribeWebhook = onRequest(
    {
        cpu: 2,
        memory: '2GiB',
        timeoutSeconds: 300,
        secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'AWS_S3_BUCKET']
    },
    async (req, res) => {
        try {
            logger.log(`📨 Received transcription webhook: ${req.method}`);

            // Parse body if it's a string
            let body = req.body;
            if (typeof body === 'string') {
                try {
                    body = JSON.parse(body);
                    logger.log(`📦 Parsed string body to JSON`);
                } catch (e) {
                    logger.error(`❌ Failed to parse body as JSON:`, e);
                }
            }

            // Handle test/ping requests
            if (body && body.test === 'ping') {
                logger.log(`🏓 Test ping received`);
                res.status(200).json({ status: 'ok', message: 'Webhook is alive' });
                return;
            }

            // Handle SNS subscription confirmation
            if (body && body.Type === 'SubscriptionConfirmation') {
                logger.log(`🔔 SNS Subscription Confirmation received`);
                logger.log(`📋 Subscribe URL: ${body.SubscribeURL}`);

                const https = require('https');

                https.get(body.SubscribeURL, (response) => {
                    let data = '';
                    response.on('data', (chunk) => {
                        data += chunk;
                    });
                    response.on('end', () => {
                        logger.log(`✅ SNS Subscription confirmed successfully`);
                        res.status(200).send('Subscription confirmed');
                    });
                }).on('error', (err) => {
                    logger.error('❌ SNS Subscription confirmation failed:', err);
                    res.status(500).send('Subscription confirmation failed');
                });
                return;
            }

            // Handle SNS notifications
            if (body && body.Type === 'Notification') {
                logger.log(`📬 SNS Notification received`);

                // Parse the Message field which contains the actual event
                let eventData;
                try {
                    const message = JSON.parse(body.Message);
                    eventData = message.detail || message;
                    logger.log(`📦 Parsed event data:`, JSON.stringify(eventData));
                } catch (parseError) {
                    logger.error('❌ Failed to parse SNS message:', parseError);
                    res.status(400).send('Invalid message format');
                    return;
                }

                const jobName = eventData.TranscriptionJobName;
                const jobStatus = eventData.TranscriptionJobStatus;

                logger.log(`📊 Job ${jobName} status: ${jobStatus}`);

                // Retrieve job metadata from Firestore
                const jobDoc = await admin.firestore().collection('transcribe_jobs').doc(jobName).get();

                if (!jobDoc.exists) {
                    logger.error(`❌ Job metadata not found for ${jobName}`);
                    res.status(404).send('Job not found');
                    return;
                }

                const jobData = jobDoc.data();
                const reelId = jobData.reelId;

                if (jobStatus !== 'COMPLETED') {
                    logger.error(`❌ Transcription job ${jobName} failed with status: ${jobStatus}`);
                    await updateProcessingStatus(reelId, 'failed', {
                        error: `Transcription failed: ${jobStatus}`,
                        step: 'transcription'
                    });

                    // Cleanup
                    await cleanupFailedJob(jobData);
                    await jobDoc.ref.delete();

                    res.status(200).send('Failure processed');
                    return;
                }

                // Job completed successfully - process results
                logger.log(`✅ Processing completed transcription for reel ${reelId}`);

                // Retrieve transcription results
                const transcriptionData = await retrieveTranscriptionResults(jobName, jobData);

                // Continue with translation
                await processTranslations(transcriptionData, reelId);

                // Cleanup S3 files and Firestore job document
                await cleanupCompletedJob(jobData, jobName);
                await jobDoc.ref.delete();

                logger.log(`🎉 Event-driven processing completed for reel ${reelId}`);
                res.status(200).send('Success');
                return;
            }

            // If we reach here, it's an unknown format - but let's log it for debugging
            logger.log(`⚠️ Received unknown webhook format, logging for debugging:`);
            logger.log(JSON.stringify(body));
            res.status(200).send('OK');

        } catch (error) {
            logger.error(`❌ Webhook processing failed:`, error);
            res.status(500).send('Processing failed');
        }
    }
);

// --- Helper: Retrieve Transcription Results ---

async function retrieveTranscriptionResults(jobName, jobData) {
    try {
        logger.log(`📥 Retrieving transcription results for job ${jobName}`);

        // Get job details
        const jobCommand = new GetTranscriptionJobCommand({
            TranscriptionJobName: jobName
        });
        const jobResult = await transcribeClient.send(jobCommand);

        // Extract transcript URI
        const transcriptUri = jobResult.TranscriptionJob.Transcript.TranscriptFileUri;
        const transcriptUrl = new URL(transcriptUri);
        const pathParts = transcriptUrl.pathname.substring(1).split('/');
        const transcriptBucket = pathParts[0];
        const transcriptKey = pathParts.slice(1).join('/');

        // Download transcript
        const getTranscriptCommand = new GetObjectCommand({
            Bucket: transcriptBucket,
            Key: transcriptKey
        });
        const transcriptS3Response = await s3Client.send(getTranscriptCommand);
        const transcriptData = JSON.parse(await transcriptS3Response.Body.transformToString());

        // Get SRT file
        const srtUri = jobResult.TranscriptionJob.Subtitles.SubtitleFileUris.find(uri => uri.endsWith('.srt'));
        const srtUrl = new URL(srtUri);
        const srtPathParts = srtUrl.pathname.substring(1).split('/');
        const srtBucket = srtPathParts[0];
        const srtKey = srtPathParts.slice(1).join('/');

        const getSrtCommand = new GetObjectCommand({
            Bucket: srtBucket,
            Key: srtKey
        });
        const srtS3Response = await s3Client.send(getSrtCommand);
        const srtContent = await srtS3Response.Body.transformToString();

        // Process data
        const fullText = transcriptData.results.transcripts[0].transcript;
        const detectedLanguageCode = jobResult.TranscriptionJob.LanguageCode || 'en-US';
        const detectedLanguage = detectedLanguageCode.split('-')[0];

        // Parse SRT to sentences
        const sentences = parseSRTToSentences(srtContent);
        const words = extractWordsFromTranscript(transcriptData);

        logger.log(`✅ Retrieved transcription: ${sentences.length} sentences, ${words.length} words`);

        return {
            fullText,
            detectedLanguage,
            words,
            sentences,
            metadata: {
                totalSentences: sentences.length,
                totalDuration: sentences.length > 0 ? sentences[sentences.length - 1].endTime : 0,
                averageConfidence: sentences.length > 0 ?
                    sentences.reduce((sum, s) => sum + s.confidence, 0) / sentences.length : 0.95,
                transcriptionProvider: 'aws-transcribe-event-driven',
                wordCount: words.length
            }
        };

    } catch (error) {
        logger.error(`❌ Failed to retrieve transcription results:`, error);
        throw error;
    }
}

// --- Helper: Process Translations ---

async function processTranslations(transcriptionData, reelId) {
    try {
        await updateProcessingStatus(reelId, 'translating');

        const {
            fullText,
            detectedLanguage,
            words,
            sentences,
            metadata
        } = transcriptionData;

        // Validate language
        let finalDetectedLanguage = detectedLanguage;
        if (!SUPPORTED_LANGUAGES[detectedLanguage]) {
            logger.log(`🔍 AWS detected '${detectedLanguage}', confirming with Google Translate...`);
            try {
                const detectionRequest = {
                    parent: `projects/${process.env.GCLOUD_PROJECT}/locations/global`,
                    content: fullText
                };
                const [detectionResponse] = await translateClient.detectLanguage(detectionRequest);
                finalDetectedLanguage = detectionResponse.languages[0].languageCode;
            } catch (detectError) {
                logger.warn(`⚠️ Google detection failed, using AWS result: ${detectedLanguage}`);
                finalDetectedLanguage = detectedLanguage;
            }
        }

        // Batch translate sentences
        logger.log(`🎯 BATCH translating ${sentences.length} sentences to ${Object.keys(SUPPORTED_LANGUAGES).length} languages...`);
        const sentencesWithTranslations = await batchTranslateSentences(
            sentences,
            finalDetectedLanguage,
            reelId
        );

        // Save to Firestore
        const translationsRef = admin.firestore().collection('translations').doc(reelId);
        await translationsRef.set({
            sourceLanguage: finalDetectedLanguage,
            originalText: fullText,
            transcriptionConfidence: metadata.averageConfidence,
            languageDetectionConfidence: 0.95,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            supportedLanguages: Object.keys(SUPPORTED_LANGUAGES),
            sentences: sentencesWithTranslations,
            words: words,
            hasSentenceData: sentencesWithTranslations.length > 0,
            totalSentences: sentencesWithTranslations.length,
            sentenceMetadata: {
                ...metadata,
                translationMappingWarnings: [],
                processingTimestamp: new Date().toISOString(),
                translationMethod: 'batch'
            },
            processingVersion: '5.0-event-driven-aws'
        });

        // Update main reel document
        await admin.firestore().collection('reels').doc(reelId).update({
            processingStatus: 'completed',
            isProcessed: true,
            sourceLanguage: finalDetectedLanguage,
            originalText: fullText,
            transcriptionConfidence: metadata.averageConfidence,
            languageDetectionConfidence: 0.95,
            translationsDocPath: translationsRef.path,
            languageCount: Object.keys(SUPPORTED_LANGUAGES).length,
            hasSentenceData: sentencesWithTranslations.length > 0,
            totalSentences: sentencesWithTranslations.length,
            sentenceMetadata: {
                ...metadata,
                translationMappingWarnings: [],
                processingTimestamp: new Date().toISOString(),
                translationMethod: 'batch'
            },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.log(`🎉 Translations completed for reel ${reelId}`);

    } catch (error) {
        logger.error(`❌ Translation processing failed:`, error);
        await updateProcessingStatus(reelId, 'failed', {
            error: error.message,
            step: 'translation'
        });
        throw error;
    }
}

// --- Helper: Cleanup Functions ---

async function cleanupCompletedJob(jobData, jobName) {
    try {
        // Delete video from S3
        const deleteVideoCommand = new DeleteObjectCommand({
            Bucket: jobData.bucketName,
            Key: jobData.videoFileName
        });
        await s3Client.send(deleteVideoCommand);

        // Delete transcription job
        const deleteJobCommand = new DeleteTranscriptionJobCommand({
            TranscriptionJobName: jobName
        });
        await transcribeClient.send(deleteJobCommand);

        logger.log(`🧹 Cleanup completed for job ${jobName}`);
    } catch (error) {
        logger.warn(`⚠️ Cleanup warning for job ${jobName}:`, error.message);
    }
}

async function cleanupFailedJob(jobData) {
    try {
        // Delete video from S3
        const deleteVideoCommand = new DeleteObjectCommand({
            Bucket: jobData.bucketName,
            Key: jobData.videoFileName
        });
        await s3Client.send(deleteVideoCommand);
        logger.log(`🧹 Cleaned up failed job files`);
    } catch (error) {
        logger.warn(`⚠️ Failed job cleanup warning:`, error.message);
    }
}

// --- BATCH TRANSLATION FUNCTION - EXACT SAME AS WORKING VERSION ---

async function batchTranslateSentences(extractedSentences, detectedLanguage, reelId) {
    const projectId = process.env.GCLOUD_PROJECT;
    const result = [];

    logger.log(`🎯 BATCH translation starting for ${extractedSentences.length} sentences`);

    // Initialize result with source language
    for (let i = 0; i < extractedSentences.length; i++) {
        result.push({
            ...extractedSentences[i],
            index: i,
            translations: {
                [detectedLanguage]: extractedSentences[i].originalText
            }
        });
    }

    // Extract all sentences as array for batch processing
    const originalSentences = extractedSentences.map(s => s.originalText);

    // Batch translate to each target language
    for (const [langCode, langName] of Object.entries(SUPPORTED_LANGUAGES)) {
        if (langCode === detectedLanguage) {
            logger.log(`✅ ${langName} (${langCode}): Using original (source language)`);
            continue;
        }

        try {
            logger.log(`🔄 Batch translating to ${langName} (${langCode})...`);

            // SINGLE BATCH REQUEST per language
            const translateRequest = {
                parent: `projects/${projectId}/locations/global`,
                contents: originalSentences, // Array of all sentences
                mimeType: 'text/plain',
                sourceLanguageCode: detectedLanguage,
                targetLanguageCode: langCode,
            };

            const [translateResponse] = await translateClient.translateText(translateRequest);
            const translations = translateResponse.translations;

            // Validation
            if (translations.length !== originalSentences.length) {
                throw new Error(`Translation count mismatch for ${langCode}: expected ${originalSentences.length}, got ${translations.length}`);
            }

            // Store translations with perfect 1:1 mapping
            for (let i = 0; i < translations.length; i++) {
                result[i].translations[langCode] = translations[i].translatedText;
            }

            logger.log(`✅ ${langName} (${langCode}): ${translations.length} sentences translated`);

        } catch (error) {
            logger.error(`❌ Batch translation failed for ${langName}: ${error.message}`);

            // Fallback for this language only - continue with others
            for (let i = 0; i < extractedSentences.length; i++) {
                result[i].translations[langCode] = extractedSentences[i].originalText;
            }
            logger.warn(`⚠️ Using fallback for ${langCode}, continuing with other languages`);
        }
    }

    logger.log(`🎉 BATCH translation completed`);
    return result;
}

// --- Helper Functions ---

function parseSRTToSentences(srtContent) {
    const lines = srtContent.split('\n');
    const sentences = [];
    let lineIndex = 0;

    while (lineIndex < lines.length) {
        const line = lines[lineIndex].trim();

        if (!line) {
            lineIndex++;
            continue;
        }

        if (/^\d+$/.test(line)) {
            lineIndex++;

            if (lineIndex < lines.length) {
                const timestampLine = lines[lineIndex].trim();
                const timestampMatch = timestampLine.match(/^(\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2},\d{3})$/);

                if (timestampMatch) {
                    const startTime = srtTimeToSeconds(timestampMatch[1]);
                    const endTime = srtTimeToSeconds(timestampMatch[2]);
                    lineIndex++;

                    const textLines = [];
                    while (lineIndex < lines.length) {
                        const textLine = lines[lineIndex].trim();
                        if (!textLine || /^\d+$/.test(textLine)) {
                            break;
                        }
                        textLines.push(textLine);
                        lineIndex++;
                    }

                    if (textLines.length > 0) {
                        const text = textLines.join(' ').trim();

                        sentences.push({
                            originalText: text,
                            startTime: startTime,
                            endTime: endTime,
                            words: [],
                            confidence: 0.95,
                            index: sentences.length
                        });
                    }
                } else {
                    lineIndex++;
                }
            } else {
                lineIndex++;
            }
        } else {
            lineIndex++;
        }
    }

    return sentences;
}

function srtTimeToSeconds(timeString) {
    const [timePart, millisPart] = timeString.split(',');
    const [hours, minutes, seconds] = timePart.split(':').map(Number);
    const milliseconds = parseInt(millisPart);
    return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
}

function extractWordsFromTranscript(transcriptData) {
    const items = transcriptData.results.items || [];
    const words = [];

    for (const item of items) {
        if (item.type === 'pronunciation') {
            words.push({
                word: item.alternatives[0].content,
                startTime: parseFloat(item.start_time),
                endTime: parseFloat(item.end_time),
                confidence: parseFloat(item.alternatives[0].confidence || 0.95)
            });
        }
    }

    return words;
}

async function updateProcessingStatus(reelId, status, additionalData = {}) {
    try {
        const reelRef = admin.firestore().collection('reels').doc(reelId);

        // Check if document exists first
        const doc = await reelRef.get();
        if (!doc.exists) {
            logger.log(`⏳ Waiting for reel ${reelId} document to be created by Flutter app...`);
            return;
        }

        await reelRef.update({
            processingStatus: status,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            ...additionalData
        });

        logger.log(`✅ Reel ${reelId}: Status updated to '${status}'.`);
    } catch (error) {
        logger.error(`❌ Failed to update status for reel ${reelId} to '${status}':`, error);
    }
}

function getReelIdFromPath(filePath) {
    let match = filePath.match(/\/([^\/]+)\.(mp4|flac)$/);
    if (match) {
        let reelId = match[1];
        // Remove "reel_" prefix if present to match Flutter's document ID
        if (reelId.startsWith('reel_')) {
            reelId = reelId.substring(5);
        }
        return reelId;
    }

    logger.warn(`Could not extract reel ID from path: ${filePath}`);
    return null;
}

async function validateVideo(bucketName, filePath) {
    try {
        const file = storageClient.bucket(bucketName).file(filePath);
        const [metadata] = await file.getMetadata();

        if (metadata.size > MAX_FILE_SIZE) {
            throw new Error(`File size ${metadata.size} bytes exceeds maximum allowed ${MAX_FILE_SIZE} bytes.`);
        }
        logger.log(`✅ Video validation passed for ${filePath} (Size: ${metadata.size} bytes).`);
    } catch (error) {
        logger.error(`❌ Video validation failed for ${filePath}:`, error);
        throw error;
    }
}

// --- Cloud Function: FUNCTION 1: Content Moderation - EXACT SAME AS WORKING VERSION ---
exports.moderateContent = onObjectFinalized(
    {
        cpu: 1,
        memory: '1GiB',
        timeoutSeconds: 300,
        bucket: 'YOUR_FIREBASE_PROJECT_ID.firebasestorage.app'
    },
    async (event) => {
        const { name: filePath, bucket: bucketName } = event.data;

        if (!filePath.startsWith('videos/reels/') || !filePath.endsWith('.mp4')) {
            logger.log(`⏭️ Skipping non-video file or incorrect path for moderation: ${filePath}`);
            return null;
        }

        const reelId = getReelIdFromPath(filePath);
        if (!reelId) {
            logger.error(`❌ Could not extract reel ID from path for moderation: ${filePath}`);
            return null;
        }

        logger.log(`🛡️ Starting content moderation for reel ${reelId} from file: ${filePath}`);

        try {
            await updateProcessingStatus(reelId, 'moderating');

            const videoUri = `gs://${bucketName}/${filePath}`;

            const request = {
                inputUri: videoUri,
                features: ['EXPLICIT_CONTENT_DETECTION', 'LABEL_DETECTION'],
                videoContext: {
                    explicitContentDetectionConfig: {},
                    labelDetectionConfig: {
                        labelDetectionMode: 'SHOT_MODE'
                    }
                },
            };

            logger.log(`🔍 Analyzing video content for reel ${reelId}...`);
            const [operation] = await videoClient.annotateVideo(request);
            const [operationResult] = await operation.promise();

            let passedModeration = true;
            let moderationResults = {
                explicitAnnotations: [],
                inappropriateLabels: [],
                checkedAt: new Date().toISOString()
            };

            const annotationResult = operationResult.annotationResults[0];

            // Process Explicit Content Detection
            if (annotationResult.explicitAnnotation) {
                for (const frame of annotationResult.explicitAnnotation.frames) {
                    if (frame.pornographyLikelihood >= 3) {
                        passedModeration = false;
                        moderationResults.explicitAnnotations.push({
                            timeOffset: frame.timeOffset,
                            pornographyLikelihood: frame.pornographyLikelihood
                        });
                    }
                }
            }

            // Process Label Detection for potentially inappropriate content
            const inappropriateLabelKeywords = ['violence', 'weapon', 'drug', 'hate speech', 'pornography', 'nudity', 'sex', 'gang', 'terrorist'];
            if (annotationResult.segmentLabelAnnotations) {
                for (const labelAnnotation of annotationResult.segmentLabelAnnotations) {
                    const labelDescription = labelAnnotation.entity.description.toLowerCase();
                    const highestConfidenceSegment = labelAnnotation.segments[0];

                    if (inappropriateLabelKeywords.some(keyword => labelDescription.includes(keyword))) {
                        if (highestConfidenceSegment.confidence >= 0.7) {
                            passedModeration = false;
                            moderationResults.inappropriateLabels.push({
                                description: labelAnnotation.entity.description,
                                confidence: highestConfidenceSegment.confidence,
                                segment: highestConfidenceSegment.startTime.seconds + 's' + highestConfidenceSegment.endTime.seconds + 's'
                            });
                        }
                    }
                }
            }

            logger.log(`${passedModeration ? '✅' : '❌'} Moderation check completed for reel ${reelId}. Passed: ${passedModeration}`);

            if (!passedModeration) {
                await updateProcessingStatus(reelId, 'rejected', {
                    reason: 'Content moderation failed',
                    moderationResults: moderationResults
                });
            } else {
                await updateProcessingStatus(reelId, 'moderationCompleted', {
                    passedModeration: true,
                    moderationResults: moderationResults
                });
            }

        } catch (error) {
            logger.error(`❌ Content moderation failed for reel ${reelId}:`, error);
            await updateProcessingStatus(reelId, 'failed', {
                error: error.message,
                step: 'content_moderation'
            });
            throw error;
        }
    });

// --- Cloud Function: FUNCTION 2: Transcribe and Translate - EVENT DRIVEN VERSION ---
exports.transcribeAndTranslate = onObjectFinalized(
    {
        cpu: 1,  // Reduced from 2 since we're not waiting
        memory: '1GiB',  // Reduced from 2GiB
        timeoutSeconds: 120,  // Reduced from 540 seconds!
        bucket: 'YOUR_FIREBASE_PROJECT_ID.firebasestorage.app',
        secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'AWS_S3_BUCKET']
    },
    async (event) => {
        const { name: filePath, bucket: bucketName } = event.data;

        if (!filePath.startsWith('videos/reels/') || !filePath.endsWith('.mp4')) {
            logger.log(`⏭️ Skipping non-video file: ${filePath}`);
            return null;
        }

        const reelId = getReelIdFromPath(filePath);
        if (!reelId) {
            logger.error(`❌ Could not extract reel ID from path: ${filePath}`);
            return null;
        }

        logger.log(`🎙️ Starting EVENT-DRIVEN AWS Transcribe for reel ${reelId}`);

        try {
            await updateProcessingStatus(reelId, 'transcribing');

            // Download video file
            const tempVideoPath = `/tmp/video-${reelId}.mp4`;
            await storageClient.bucket(bucketName).file(filePath).download({
                destination: tempVideoPath
            });

            // Start transcription job (returns immediately, no polling)
            const result = await startTranscriptionJobEventDriven(tempVideoPath, reelId);

            // Cleanup local file immediately
            try {
                if (fs.existsSync(tempVideoPath)) {
                    fs.unlinkSync(tempVideoPath);
                    logger.log('🧹 Cleaned up temporary video file');
                }
            } catch (cleanupError) {
                logger.warn('⚠️ Cleanup warning:', cleanupError.message);
            }

            logger.log(`✅ Transcription job initiated for reel ${reelId} - processing will continue via EventBridge`);
            return result;

        } catch (error) {
            logger.error(`❌ Failed to initiate transcription for reel ${reelId}:`, error);
            await updateProcessingStatus(reelId, 'failed', {
                error: error.message,
                step: 'transcription_initiation'
            });
            throw error;
        }
    }
);

// --- Cloud Function: FUNCTION 3: Manual Reprocessing ---
exports.reprocessReel = onCall(async (request) => {
    const { reelId } = request.data;

    if (!reelId) {
        throw new HttpsError('invalid-argument', 'The function must be called with a reelId.');
    }

    logger.log(`🔄 Manual reprocessing requested for reel ${reelId}`);

    try {
        await updateProcessingStatus(reelId, 'pending', {
            originalText: null,
            sourceLanguage: null,
            transcriptionConfidence: null,
            languageDetectionConfidence: null,
            hasSentenceData: null,
            totalSentences: null,
            sentenceMetadata: null,
            translationsDocPath: null,
            languageCount: null,
            processingStatus: 'pending'
        });

        // Delete existing translations document
        const translationsDoc = admin.firestore().collection('translations').doc(reelId);
        try {
            const docSnap = await translationsDoc.get();
            if (docSnap.exists) {
                await translationsDoc.delete();
                logger.log(`🗑️ Deleted existing translations document for reel ${reelId}`);
            }
        } catch (deleteError) {
            logger.warn(`⚠️ Could not delete existing translations document for ${reelId}: ${deleteError.message}`);
        }

        // Delete any existing transcribe jobs for this reel
        const jobsQuery = admin.firestore().collection('transcribe_jobs')
            .where('reelId', '==', reelId);
        const jobSnapshots = await jobsQuery.get();

        for (const jobDoc of jobSnapshots.docs) {
            await jobDoc.ref.delete();
            logger.log(`🗑️ Deleted old transcribe job: ${jobDoc.id}`);
        }

        return { success: true, message: `Reprocessing started for reel: ${reelId}` };

    } catch (error) {
        logger.error(`❌ Manual reprocessing failed for reel ${reelId}:`, error);
        throw new HttpsError('internal', `Failed to initiate reprocessing for reel ${reelId}: ${error.message}`);
    }
});

// --- Cloud Function: FUNCTION 4: Health Check ---
exports.healthCheck = onCall(
    {
        cpu: 1,
        memory: '512MiB',
        timeoutSeconds: 30,
        secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'AWS_S3_BUCKET']
    },
    async (request) => {
        logger.log(`💓 Health check requested`);

        try {
            const healthStatus = {
                status: 'healthy',
                timestamp: new Date().toISOString(),
                version: '5.0-event-driven-aws',
                supportedLanguages: Object.keys(SUPPORTED_LANGUAGES),
                features: {
                    awsTranscribe: true,
                    eventDriven: true,
                    batchTranslation: true,
                    sentenceBasedLearning: true,
                    wordLevelSubtitles: true,
                    contentModeration: true,
                    directVideoProcessing: true,
                    webhookEnabled: true
                },
                configuration: {
                    maxVideoSize: `${MAX_FILE_SIZE / (1024 * 1024)}MB`,
                    maxDuration: `${MAX_VIDEO_DURATION}s`,
                    languageCount: Object.keys(SUPPORTED_LANGUAGES).length,
                    processingMode: 'event-driven-no-polling'
                },
                services: {
                    firestore: 'unknown',
                    storage: 'unknown',
                    translate: 'unknown',
                    transcribe: 'unknown'
                }
            };

            // Test Firestore
            try {
                await admin.firestore().collection('reels').doc('health_check').set({
                    lastHealthCheck: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true });
                healthStatus.services.firestore = 'healthy';
            } catch (error) {
                healthStatus.services.firestore = 'error';
            }

            // Test Storage
            try {
                const bucket = storageClient.bucket('YOUR_FIREBASE_PROJECT_ID.firebasestorage.app');
                await bucket.exists();
                healthStatus.services.storage = 'healthy';
            } catch (error) {
                healthStatus.services.storage = 'error';
            }

            // Test Google Translate
            try {
                const request = {
                    parent: `projects/${process.env.GCLOUD_PROJECT}/locations/global`,
                    contents: ['Hello'],
                    mimeType: 'text/plain',
                    sourceLanguageCode: 'en',
                    targetLanguageCode: 'es'
                };
                await translateClient.translateText(request);
                healthStatus.services.translate = 'healthy';
            } catch (error) {
                healthStatus.services.translate = 'error';
            }

            // Test AWS Transcribe
            try {
                const { ListTranscriptionJobsCommand } = require('@aws-sdk/client-transcribe');
                const listCommand = new ListTranscriptionJobsCommand({ MaxResults: 1 });
                await transcribeClient.send(listCommand);
                healthStatus.services.transcribe = 'healthy';
            } catch (error) {
                healthStatus.services.transcribe = 'error';
            }

            // Check for pending transcribe jobs
            try {
                const jobsSnapshot = await admin.firestore().collection('transcribe_jobs')
                    .where('status', '==', 'IN_PROGRESS')
                    .get();
                healthStatus.pendingJobs = jobsSnapshot.size;
            } catch (error) {
                healthStatus.pendingJobs = 'error';
            }

            logger.log(`💓 Health check completed:`, healthStatus);
            return healthStatus;

        } catch (error) {
            logger.error(`❌ Health check failed:`, error);
            throw new HttpsError('internal', `Health check failed: ${error.message}`);
        }
    });

// === BUG REPORTING & FEEDBACK SYSTEM ===

exports.onBugReport = functions.firestore
    .document('bug_reports/{reportId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const reportId = context.params.reportId;

        try {
            await admin.firestore().collection('mail').add({
                to: 'YOUR_EMAIL_ADDRESS', // REPLACE with your actual email
                message: {
                    subject: `🐛 Langreels Bug Report: ${data.title}`,
                    html: `
            <h2>New Bug Report</h2>
            <p><strong>From:</strong> ${data.userName} (${data.userEmail})</p>
            <p><strong>Platform:</strong> ${data.platform}</p>
            <p><strong>App Version:</strong> ${data.appVersion}</p>
            <p><strong>Title:</strong> ${data.title}</p>
            <p><strong>Description:</strong></p>
            <p>${data.description}</p>
            <hr>
            <p><a href="https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/bug_reports/${reportId}">
              View in Firebase Console
            </a></p>
          `,
                }
            });

            logger.log(`✅ Bug report email sent for ${reportId}`);
        } catch (error) {
            logger.error(`❌ Failed to send bug report email:`, error);
        }
    });

exports.onFeedback = functions.firestore
    .document('feedback/{feedbackId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const feedbackId = context.params.feedbackId;

        try {
            await admin.firestore().collection('mail').add({
                to: 'YOUR_EMAIL_ADDRESS', // REPLACE with your actual email
                message: {
                    subject: `💬 Langreels Feedback [${data.category}]`,
                    html: `
            <h2>User Feedback</h2>
            <p><strong>Category:</strong> ${data.category}</p>
            <p><strong>From:</strong> ${data.userName} (${data.userEmail})</p>
            <p><strong>Message:</strong></p>
            <p>${data.message}</p>
            <hr>
            <p><a href="https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/feedback/${feedbackId}">
              View in Firebase Console
            </a></p>
          `,
                }
            });

            logger.log(`✅ Feedback email sent for ${feedbackId}`);
        } catch (error) {
            logger.error(`❌ Failed to send feedback email:`, error);
        }
    });