// /functions/sentence-processor.js

/**
 * Checks if a word ends a sentence with more robust patterns.
 * @param {string} word - The word to check.
 * @returns {boolean} True if the word likely ends a sentence.
 */
function isSentenceEnding(word) {
    // Basic punctuation that typically ends a sentence
    const sentenceEndPunctuation = /[.!?]$/;

    // Check for common abbreviations that might end with a period but not end a sentence.
    // This list is not exhaustive and can be expanded.
    const abbreviations = new Set([
        'mr', 'mrs', 'ms', 'dr', 'prof', 'rev', 'sr', 'jr', 'inc', 'corp',
        'ltd', 'etc', 'vs', 'est', 'approx', 'fig', 'vol', 'ch', 'art',
        'e.g', 'i.e', 'etc.', 'st.', 'ave.', 'blvd.', 'rd.', 'ln.', 'ct.',
        // Add other languages' abbreviations if needed
        'sr.', 'jr.' // Spanish/Portuguese
    ]);

    // Normalize the word for abbreviation check (remove trailing punctuation and case)
    const cleanedWord = word.replace(/[.,!?]+$/, '').toLowerCase();

    // If it's a known abbreviation, it doesn't end a sentence.
    if (abbreviations.has(cleanedWord)) {
        return false;
    }

    // Check for standard sentence-ending punctuation, possibly followed by quote or parenthesis.
    // This regex is more forgiving: it looks for punctuation, optionally followed by quotes/parentheses,
    // and then checks if the *actual* end of the word matches sentence-ending punctuation.
    // It's hard to get perfect without a full tokenizer.
    return sentenceEndPunctuation.test(word);
}

/**
 * Calculates average confidence for a sentence.
 * @param {Array} words - Array of word objects with confidence scores.
 * @returns {number} Average confidence score (0-1).
 */
function calculateSentenceConfidence(words) {
    if (!words || words.length === 0) return 0;

    const totalConfidence = words.reduce((sum, word) => {
        // Ensure confidence is a valid number, default to 0 if not.
        const wordConfidence = word.confidence !== undefined && word.confidence !== null ? word.confidence : 0;
        return sum + wordConfidence;
    }, 0);

    return totalConfidence / words.length;
}

/**
 * Extracts sentences with timing information from Speech-to-Text results.
 * @param {Array} speechResults - Google Speech-to-Text response results.
 * @param {Object} options - Processing options.
 * @returns {Object} Object containing sentences, metadata, and potential errors.
 */
function extractSentencesWithTiming(speechResults, options = {}) {
    const {
        maxSentenceDuration = 15, // seconds
        minSentenceLength = 3,    // characters
        splitLongSentences = true,
        sentencePunctuationTolerance = 0.5 // seconds, allows slight gap for punctuation
    } = options;

    const sentences = [];
    let currentSentenceWords = [];
    let currentSentenceStartTime = null;
    let currentSentenceEndTime = null;
    let currentSentenceText = "";

    if (!speechResults || speechResults.length === 0) {
        return { sentences: [], metadata: { totalSentences: 0, totalDuration: 0, averageConfidence: 0 }, error: "No speech results provided." };
    }

    for (const result of speechResults) {
        if (!result.alternatives || !result.alternatives[0] || !result.alternatives[0].words) {
            continue;
        }

        const words = result.alternatives[0].words;

        for (let i = 0; i < words.length; i++) {
            const word = words[i];
            const startTime = parseFloat(word.startTime.seconds || 0) + (parseFloat(word.startTime.nanos || 0) / 1e9);
            const endTime = parseFloat(word.endTime.seconds || 0) + (parseFloat(word.endTime.nanos || 0) / 1e9);

            // Initialize sentence timing if it's the first word of a new sentence
            if (currentSentenceStartTime === null) {
                currentSentenceStartTime = startTime;
            }
            currentSentenceEndTime = endTime; // Always update end time

            // Add word to the current sentence
            currentSentenceWords.push({
                word: word.word,
                startTime: startTime,
                endTime: endTime,
                confidence: word.confidence || 0
            });
            currentSentenceText += (currentSentenceText ? " " : "") + word.word;

            // Check if this word ends a sentence or if it's the last word and we need to finalize.
            const isLastWordOfResult = i === words.length - 1;
            const endsSentence = isSentenceEnding(word.word);

            // --- Sentence Boundary Logic ---
            let finalizeCurrentSentence = false;

            if (endsSentence) {
                // If the word ends a sentence, and the next word is either not available or starts with a capital letter,
                // OR if it's the last word of the entire result, finalize.
                const nextWordStartsCapital = !isLastWordOfResult && words[i + 1] && /^[A-Z]/.test(words[i + 1].word);
                const timeSinceLastWord = !isLastWordOfResult ? (words[i + 1].startTime.seconds + words[i + 1].startTime.nanos / 1e9) - endTime : 0;
                const gapIsSignificant = timeSinceLastWord > sentencePunctuationTolerance;

                if (nextWordStartsCapital || isLastWordOfResult || gapIsSignificant) {
                    finalizeCurrentSentence = true;
                }
            }

            if (finalizeCurrentSentence) {
                // Ensure the sentence meets minimum criteria before adding
                if (currentSentenceText.length >= minSentenceLength && currentSentenceWords.length > 0) {
                    sentences.push({
                        originalText: cleanSentenceText(currentSentenceText), // Use your cleaner
                        startTime: currentSentenceStartTime,
                        endTime: currentSentenceEndTime,
                        words: [...currentSentenceWords], // Copy words array
                        confidence: calculateSentenceConfidence(currentSentenceWords)
                    });
                }

                // Reset for the next sentence
                currentSentenceWords = [];
                currentSentenceText = "";
                currentSentenceStartTime = null;
                currentSentenceEndTime = null;
            }
        }
    }

    // Add any remaining words as the last sentence if they weren't finalized
    if (currentSentenceWords.length > 0 && currentSentenceText.trim().length >= minSentenceLength) {
        sentences.push({
            originalText: cleanSentenceText(currentSentenceText),
            startTime: currentSentenceStartTime,
            endTime: currentSentenceEndTime,
            words: [...currentSentenceWords],
            confidence: calculateSentenceConfidence(currentSentenceWords)
        });
    }

    // --- Post-processing: Split long sentences ---
    let finalSentences = sentences;
    if (splitLongSentences) {
        finalSentences = [];
        for (const sentence of sentences) {
            const duration = sentence.endTime - sentence.startTime;
            if (duration > maxSentenceDuration) {
                // Attempt to split
                const splitSegments = attemptSentenceSplit(sentence, maxSentenceDuration, options);
                finalSentences.push(...splitSegments);
            } else {
                finalSentences.push(sentence);
            }
        }
    }

    // Re-index sentences
    finalSentences = finalSentences.map((s, idx) => ({ ...s, index: idx }));

    // Calculate final metadata
    const metadata = {
        totalSentences: finalSentences.length,
        totalDuration: finalSentences.length > 0 ?
            Math.max(...finalSentences.map(s => s.endTime)) - Math.min(...finalSentences.map(s => s.startTime)) : 0,
        averageConfidence: finalSentences.length > 0 ?
            finalSentences.reduce((sum, s) => sum + s.confidence, 0) / finalSentences.length : 0
    };

    return { sentences: finalSentences, metadata, error: null };
}

/**
 * Attempts to split a long sentence at natural break points.
 * @param {Object} sentence - The sentence object to split.
 * @param {number} maxDuration - Maximum duration for a segment.
 * @param {Object} options - Processing options.
 * @returns {Array} Array of split sentence segments.
 */
function attemptSentenceSplit(sentence, maxDuration, options) {
    const { sentencePunctuationTolerance = 0.5 } = options;
    const words = sentence.words;
    const segments = [];
    let currentSegmentWords = [];
    let currentSegmentStartTime = sentence.startTime;
    let currentSegmentEndTime = sentence.startTime;
    let currentSegmentText = "";

    for (let i = 0; i < words.length; i++) {
        const word = words[i];
        currentSegmentWords.push(word);
        currentSegmentEndTime = word.endTime;
        currentSegmentText += (currentSegmentText ? " " : "") + word.word;

        const segmentDuration = currentSegmentEndTime - currentSegmentStartTime;

        // Determine if we should finalize the current segment
        let finalizeSegment = false;

        // Conditions to finalize:
        // 1. Segment duration exceeds max, AND the current word is a natural break point,
        //    OR it's the last word of the original sentence.
        // 2. OR the segment duration exceeds max significantly (e.g., 1.5x maxDuration) regardless of break point.
        // 3. OR we are at the last word.

        const isLastWordOfSentence = i === words.length - 1;
        const isNaturalBreak = isSentenceEnding(word.word) || isNaturalBreakPoint(word.word.toLowerCase().replace(/[^\w]/g, ''));
        const timeSinceLastWord = !isLastWordOfSentence ? (words[i + 1].startTime.seconds + words[i + 1].startTime.nanos / 1e9) - word.endTime : 0;
        const gapIsSignificant = timeSinceLastWord > sentencePunctuationTolerance;

        if (segmentDuration >= maxDuration) {
            if (isNaturalBreak || isLastWordOfSentence || gapIsSignificant) {
                finalizeSegment = true;
            }
            // Also consider splitting if the duration is much longer than max, even without a clear break
            else if (segmentDuration > maxDuration * 1.5) {
                finalizeSegment = true;
            }
        }

        if (finalizeSegment || isLastWordOfSentence) {
            if (currentSegmentText.trim().length > 0) {
                segments.push({
                    originalText: cleanSentenceText(currentSegmentText),
                    startTime: currentSegmentStartTime,
                    endTime: currentSegmentEndTime,
                    words: [...currentSegmentWords],
                    confidence: calculateSentenceConfidence(currentSegmentWords)
                });
            }

            // Reset for the next segment
            currentSegmentWords = [];
            currentSegmentText = "";
            currentSegmentStartTime = isLastWordOfSentence ? null : word.endTime; // Start next segment from current word's end time if not the very last word
            currentSegmentEndTime = currentSegmentStartTime;
        }
    }

    return segments.length > 1 ? segments : [sentence]; // Return original if no split occurred
}

/**
 * Checks if a word represents a natural break point for sentence splitting (for splitting *within* a long sentence).
 * @param {string} wordNormalized - The normalized word (lowercase, no punctuation).
 * @returns {boolean} True if the word is a natural break point.
 */
function isNaturalBreakPoint(wordNormalized) {
    // More common conjunctions and transition words that might indicate a break
    const breakWords = new Set([
        'and', 'but', 'or', 'so', 'then', 'because', 'while', 'when', 'where', 'if', 'although',
        'however', 'therefore', 'moreover', 'furthermore', 'consequently', 'meanwhile',
        'y', 'pero', 'o', 'entonces', 'porque', 'mientras', 'cuando', 'donde', 'si', 'aunque',
        'sin embargo', 'por lo tanto', 'además', 'consecuentemente', 'mientras tanto',
        'et', 'mais', 'ou', 'donc', 'alors', 'parce', 'pendant', 'quand', 'où', 'si', 'bien que',
        'cependant', 'par conséquent', 'en outre', 'dorénavant', 'pendant ce temps',
        'und', 'aber', 'oder', 'dann', 'weil', 'während', 'wann', 'wo', 'wenn', 'obwohl',
        'jedoch', 'daher', 'außerdem', 'folglich', 'inzwischen'
    ]);

    return breakWords.has(wordNormalized);
}

// Add this function to your sentence-processor.js file

/**
 * Converts OpenAI Whisper words to Google Speech-to-Text format
 * @param {Array} openaiWords - OpenAI word array with {word, start, end}
 * @returns {Array} Google Speech-to-Text format results
 */
function convertOpenAIWordsToGoogleFormat(openaiWords) {
    if (!openaiWords || openaiWords.length === 0) {
        return [];
    }

    // Convert OpenAI format to Google Speech format
    const words = openaiWords.map(word => ({
        word: word.word,
        startTime: {
            seconds: Math.floor(word.start),
            nanos: Math.floor((word.start % 1) * 1e9)
        },
        endTime: {
            seconds: Math.floor(word.end),
            nanos: Math.floor((word.end % 1) * 1e9)
        },
        confidence: 0.95 // OpenAI doesn't provide confidence
    }));

    // Wrap in Google Speech-to-Text result structure
    return [{
        alternatives: [{
            transcript: openaiWords.map(w => w.word).join(' '),
            confidence: 0.95,
            words: words
        }]
    }];
}



/**
 * Processes sentences from OpenAI Whisper by aligning punctuation from full transcript
 * @param {Array} openaiWords - OpenAI word array
 * @param {string} fullTranscript - Complete transcript text with punctuation
 * @param {Object} options - Processing options
 * @returns {Object} Same format as processSentencesFromSpeech with success flag
 */
function processSentencesFromOpenAI(openaiWords, fullTranscript, options = {}) {
    try {
        console.log(`🔧 Processing ${openaiWords.length} OpenAI words with universal punctuation alignment...`);
        console.log(`📝 Full transcript: "${fullTranscript}"`);

        // Step 1: Enhanced punctuation alignment for all languages
        const wordsWithPunctuation = alignPunctuationUniversal(openaiWords, fullTranscript);

        // Step 2: Universal sentence extraction
        const sentences = extractSentencesUniversal(wordsWithPunctuation, options);

        // Step 3: Validate and fix sentence boundaries
        const validatedSentences = validateSentenceBoundaries(sentences, fullTranscript);

        const metadata = {
            totalSentences: validatedSentences.length,
            totalDuration: validatedSentences.length > 0 ?
                Math.max(...validatedSentences.map(s => s.endTime)) - Math.min(...validatedSentences.map(s => s.startTime)) : 0,
            averageConfidence: 0.95
        };

        console.log(`✅ Universal processing complete: ${validatedSentences.length} sentences extracted`);

        return {
            success: true,
            sentences: validatedSentences,
            metadata: metadata,
            error: null
        };
    } catch (error) {
        console.error(`❌ Universal sentence processing failed:`, error);
        return {
            success: false,
            sentences: [],
            metadata: { totalSentences: 0, totalDuration: 0, averageConfidence: 0 },
            error: error.message
        };
    }
}

/**
 * Aligns punctuation from full transcript to individual word objects
 * @param {Array} words - OpenAI word objects without punctuation
 * @param {string} fullTranscript - Complete text with punctuation
 * @returns {Array} Words with punctuation attached
 */
function alignPunctuationUniversal(words, fullTranscript) {
    if (!words || words.length === 0) return [];

    console.log(`🌍 Universal alignment: ${words.length} words with transcript`);

    // Split transcript into tokens (words + punctuation)
    const transcriptTokens = tokenizeUniversal(fullTranscript);
    console.log(`📝 Transcript tokens: ${transcriptTokens.length}`);

    const alignedWords = [];
    let tokenIndex = 0;

    for (let i = 0; i < words.length; i++) {
        const audioWord = words[i];

        // Find best matching token(s) for this audio word
        const matchResult = findBestTokenMatch(audioWord, transcriptTokens, tokenIndex);

        if (matchResult.found) {
            alignedWords.push({
                ...audioWord,
                word: matchResult.token,
                originalWord: audioWord.word
            });
            tokenIndex = matchResult.nextIndex;
        } else {
            // Fallback: use original word
            alignedWords.push({
                ...audioWord,
                originalWord: audioWord.word
            });
            tokenIndex++;
        }
    }

    console.log(`✅ Universal alignment complete: ${alignedWords.length} words processed`);
    return alignedWords;
}

/**
 * Extracts sentences from words that now have punctuation
 * @param {Array} words - Words with punctuation aligned
 * @param {Object} options - Processing options
 * @returns {Array} Array of sentence objects
 */
function extractSentencesUniversal(words, options = {}) {
    const { minSentenceLength = 3 } = options;
    const sentences = [];

    let currentSentence = {
        words: [],
        text: '',
        startTime: null,
        endTime: null
    };

    for (let i = 0; i < words.length; i++) {
        const word = words[i];

        // Initialize sentence timing
        if (currentSentence.startTime === null) {
            currentSentence.startTime = word.start;
        }

        // Add word to current sentence
        currentSentence.words.push({
            word: word.word,
            startTime: word.start,
            endTime: word.end,
            confidence: 0.95
        });

        currentSentence.text += (currentSentence.text ? ' ' : '') + word.word;
        currentSentence.endTime = word.end;

        // Universal sentence ending detection
        const endsSentence = isSentenceEndingUniversal(word.word);
        const isLastWord = i === words.length - 1;

        if (endsSentence || isLastWord) {
            // Only add sentence if it meets minimum criteria
            if (currentSentence.text.trim().length >= minSentenceLength) {
                sentences.push({
                    originalText: cleanSentenceTextUniversal(currentSentence.text),
                    startTime: currentSentence.startTime,
                    endTime: currentSentence.endTime,
                    words: currentSentence.words,
                    confidence: 0.95,
                    index: sentences.length
                });

                console.log(`📝 Sentence ${sentences.length}: "${currentSentence.text.trim()}" (${currentSentence.startTime.toFixed(1)}s - ${currentSentence.endTime.toFixed(1)}s)`);
            }

            // Reset for next sentence
            currentSentence = {
                words: [],
                text: '',
                startTime: null,
                endTime: null
            };
        }
    }

    return sentences;
}

// Clean sentence text function remains the same
function cleanSentenceText(text) {
    return text.trim().replace(/\s+/g, ' ').replace(/\s+([.!?¿¡])/g, '$1');
}

/**
 * Universal tokenizer that preserves punctuation for all languages
 */
function tokenizeUniversal(text) {
    // Match word characters (including unicode for all languages) OR punctuation
    const tokens = text.match(/[\p{L}\p{N}'']+|[\p{P}\p{S}]/gu) || [];
    return tokens.filter(token => token.trim().length > 0);
}

/**
 * Find best matching token for an audio word
 */
function findBestTokenMatch(audioWord, tokens, startIndex) {
    const audioBase = normalizeWordUniversal(audioWord.word);

    // Search in a small window around the current position
    const searchWindow = 5;
    const searchStart = Math.max(0, startIndex - 1);
    const searchEnd = Math.min(tokens.length, startIndex + searchWindow);

    for (let i = searchStart; i < searchEnd; i++) {
        const token = tokens[i];
        const tokenBase = normalizeWordUniversal(token);

        if (audioBase === tokenBase) {
            return { found: true, token: token, nextIndex: i + 1 };
        }

        // Check for contractions and special language patterns
        if (isContractionMatch(audioWord.word, token)) {
            return { found: true, token: token, nextIndex: i + 1 };
        }
    }

    // If no match found, check if we can combine tokens
    if (startIndex < tokens.length - 1) {
        const combinedToken = tokens[startIndex] + (tokens[startIndex + 1] || '');
        if (normalizeWordUniversal(combinedToken) === audioBase) {
            return { found: true, token: combinedToken, nextIndex: startIndex + 2 };
        }
    }

    return { found: false, token: audioWord.word, nextIndex: startIndex + 1 };
}

/**
 * Universal word normalization for all supported languages
 */
function normalizeWordUniversal(word) {
    return word.toLowerCase()
        .replace(/[^\p{L}\p{N}]/gu, '') // Remove all punctuation/symbols, keep letters/numbers
        .normalize('NFD') // Decompose accented characters
        .replace(/[\u0300-\u036f]/g, '') // Remove diacritics
        .replace(/['']/g, ''); // Remove apostrophes
}

/**
 * Check for language-specific contractions
 */
function isContractionMatch(audioWord, transcriptToken) {
    const contractionPatterns = {
        // French contractions
        'c': /c['']est/i,
        'qu': /qu[''][ileo]/i,
        'd': /d[''][aeiou]/i,
        'j': /j[''][aeiou]/i,
        'l': /l[''][aeiou]/i,
        'm': /m[''][aeiou]/i,
        'n': /n[''][aeiou]/i,
        's': /s[''][ileo]/i,
        't': /t[''][aeiou]/i,

        // English contractions
        'don': /don['']t/i,
        'won': /won['']t/i,
        'can': /can['']t/i,
        'i': /i[''][ml]/i,
        'you': /you[''][rved]/i,
        'we': /we[''][rved]/i,
        'they': /they[''][rved]/i,
        'it': /it['']s/i,

        // Spanish contractions
        'del': /del?/i,
        'al': /al?/i,
    };

    const audioBase = audioWord.toLowerCase();
    for (const [base, pattern] of Object.entries(contractionPatterns)) {
        if (audioBase === base && pattern.test(transcriptToken)) {
            return true;
        }
    }

    return false;
}

/**
 * Universal sentence ending detection for all supported languages
 */
function isSentenceEndingUniversal(word) {
    // Universal sentence ending patterns
    const sentenceEndPatterns = [
        /[.!?]$/, // Western punctuation
        /[。！？]$/, // East Asian punctuation
        /[؟!.]$/, // Arabic punctuation
        /[।!?]$/, // Devanagari punctuation (Hindi, Marathi)
        /[.!?]['"\)]*$/, // Punctuation followed by quotes/parentheses
    ];

    // Check if word ends with any sentence-ending pattern
    for (const pattern of sentenceEndPatterns) {
        if (pattern.test(word)) {
            return true;
        }
    }

    return false;
}

/**
 * Universal text cleaning for all languages
 */
function cleanSentenceTextUniversal(text) {
    return text.trim()
        .replace(/\s+/g, ' ') // Normalize whitespace
        .replace(/\s+([.!?¿¡।।！？؟])/g, '$1') // Remove space before punctuation
        .replace(/([.!?¿¡।।！？؟])\s*(['")\]}])/g, '$1$2'); // Fix quote positioning
}

/**
 * Validate and fix sentence boundaries using full transcript
 */
function validateSentenceBoundaries(sentences, fullTranscript) {
    // Count expected sentences by counting sentence-ending punctuation in transcript
    const sentenceEndMatches = fullTranscript.match(/[.!?।।！？؟]/g);
    const expectedSentenceCount = sentenceEndMatches ? sentenceEndMatches.length : 1;

    console.log(`🔍 Validation: Found ${sentences.length} sentences, expected ~${expectedSentenceCount}`);

    // If we have significantly fewer sentences than expected, try to split
    if (sentences.length < expectedSentenceCount * 0.7) {
        console.log(`⚠️ Under-detection detected, attempting to split long sentences...`);
        return splitUnderDetectedSentences(sentences, fullTranscript);
    }

    // If we have too many sentences, try to merge
    if (sentences.length > expectedSentenceCount * 1.3) {
        console.log(`⚠️ Over-detection detected, attempting to merge short sentences...`);
        return mergeOverDetectedSentences(sentences);
    }

    return sentences;
}

/**
 * Split sentences that are too long (under-detection fix)
 */
function splitUnderDetectedSentences(sentences, fullTranscript) {
    console.log(`🔪 Starting aggressive sentence splitting...`);
    const result = [];

    for (let i = 0; i < sentences.length; i++) {
        const sentence = sentences[i];
        console.log(`🔪 Analyzing sentence ${i}: "${sentence.originalText}"`);

        // Count punctuation marks in this sentence
        const endMarks = sentence.originalText.match(/[.!?।।！？؟]/g);
        const punctCount = endMarks ? endMarks.length : 0;

        console.log(`🔪 Found ${punctCount} punctuation marks in sentence ${i}`);

        if (punctCount > 1) {
            // This sentence definitely needs splitting
            console.log(`🔪 Splitting sentence ${i} - contains ${punctCount} punctuation marks`);
            const splitSentences = splitSentenceByPunctuation(sentence);
            result.push(...splitSentences);
        } else if (punctCount === 1) {
            // Single punctuation - check if it's abnormally long (likely merged sentences)
            const words = sentence.originalText.split(' ');
            if (words.length > 15) {
                console.log(`🔪 Sentence ${i} is unusually long (${words.length} words) - attempting to split anyway`);
                const splitSentences = splitSentenceByPunctuation(sentence);
                if (splitSentences.length > 1) {
                    result.push(...splitSentences);
                } else {
                    result.push(sentence);
                }
            } else {
                result.push(sentence);
            }
        } else {
            // No punctuation - check if it should be merged with next or is incomplete
            if (sentence.originalText.trim().length < 5) {
                console.log(`🔪 Sentence ${i} is very short - will be handled by merge logic`);
            }
            result.push(sentence);
        }
    }

    // Re-index all sentences
    const reindexed = result.map((s, idx) => ({ ...s, index: idx }));
    console.log(`🔪 Splitting complete: ${sentences.length} → ${reindexed.length} sentences`);

    return reindexed;
}

/**
 * Split a sentence by internal punctuation marks
 */
function splitSentenceByPunctuation(sentence) {
    const text = sentence.originalText;
    const words = sentence.words;

    console.log(`🔪 Splitting sentence: "${text}"`);
    console.log(`🔪 Word count: ${words.length}`);

    // Find all sentence-ending punctuation in the text
    const punctuationPositions = [];
    const regex = /[.!?।।！？؟]/g;
    let match;

    while ((match = regex.exec(text)) !== null) {
        punctuationPositions.push({
            position: match.index,
            char: match[0],
            textAfterPosition: match.index + 1
        });
    }

    console.log(`🔪 Found ${punctuationPositions.length} punctuation marks:`, punctuationPositions);

    if (punctuationPositions.length <= 1) {
        console.log(`🔪 No splitting needed - only ${punctuationPositions.length} punctuation marks`);
        return [sentence];
    }

    // Map punctuation positions to word boundaries
    const splitPoints = [];
    let currentTextPosition = 0;

    for (let wordIndex = 0; wordIndex < words.length; wordIndex++) {
        const word = words[wordIndex];
        const wordText = word.word;

        // Find where this word appears in the text
        const wordStartInText = text.indexOf(wordText, currentTextPosition);
        const wordEndInText = wordStartInText + wordText.length;

        // Check if any punctuation marks fall within or at the end of this word
        for (const punct of punctuationPositions) {
            if (punct.position >= wordStartInText && punct.position <= wordEndInText) {
                splitPoints.push({
                    wordIndex: wordIndex,
                    punctuation: punct.char,
                    endTime: word.endTime
                });
                console.log(`🔪 Split point found: word ${wordIndex} ("${wordText}") at ${word.endTime}s`);
            }
        }

        currentTextPosition = wordEndInText;
    }

    if (splitPoints.length === 0) {
        console.log(`🔪 No valid split points found`);
        return [sentence];
    }

    // Create split sentences based on word boundaries
    const splitSentences = [];
    let currentWordStart = 0;

    for (let i = 0; i < splitPoints.length; i++) {
        const splitPoint = splitPoints[i];
        const wordEndIndex = splitPoint.wordIndex + 1; // Include the word with punctuation

        // Extract words for this sentence
        const sentenceWords = words.slice(currentWordStart, wordEndIndex);

        if (sentenceWords.length > 0) {
            const sentenceText = sentenceWords.map(w => w.word).join(' ');

            const newSentence = {
                originalText: sentenceText.trim(),
                startTime: sentenceWords[0].startTime,
                endTime: sentenceWords[sentenceWords.length - 1].endTime,
                words: sentenceWords,
                confidence: 0.95,
                index: splitSentences.length
            };

            splitSentences.push(newSentence);
            console.log(`🔪 Created sentence ${splitSentences.length}: "${sentenceText.trim()}" (${newSentence.startTime}s - ${newSentence.endTime}s)`);
        }

        currentWordStart = wordEndIndex;
    }

    // Handle any remaining words after the last punctuation
    if (currentWordStart < words.length) {
        const remainingWords = words.slice(currentWordStart);
        const remainingText = remainingWords.map(w => w.word).join(' ');

        if (remainingWords.length > 0 && remainingText.trim().length > 0) {
            const finalSentence = {
                originalText: remainingText.trim(),
                startTime: remainingWords[0].startTime,
                endTime: remainingWords[remainingWords.length - 1].endTime,
                words: remainingWords,
                confidence: 0.95,
                index: splitSentences.length
            };

            splitSentences.push(finalSentence);
            console.log(`🔪 Created final sentence: "${remainingText.trim()}" (${finalSentence.startTime}s - ${finalSentence.endTime}s)`);
        }
    }

    console.log(`🔪 Split complete: ${splitSentences.length} sentences created`);
    return splitSentences;
}

/**
 * Merge sentences that are too short (over-detection fix)
 */
function mergeOverDetectedSentences(sentences) {
    const result = [];
    let i = 0;

    while (i < sentences.length) {
        const current = sentences[i];

        // If current sentence is very short and there's a next sentence
        if (current.originalText.length < 10 && i < sentences.length - 1) {
            const next = sentences[i + 1];

            // Merge with next sentence
            const merged = {
                originalText: current.originalText + ' ' + next.originalText,
                startTime: current.startTime,
                endTime: next.endTime,
                words: [...current.words, ...next.words],
                confidence: 0.95,
                index: result.length
            };

            result.push(merged);
            i += 2; // Skip next sentence since we merged it
        } else {
            result.push({ ...current, index: result.length });
            i++;
        }
    }

    return result;
}

// Export the main function and helpers
module.exports = {
    processSentencesFromSpeech: (speechResults, options) => extractSentencesWithTiming(speechResults, options),
    processSentencesFromOpenAI,
    convertOpenAIWordsToGoogleFormat,
    isSentenceEnding,
    calculateSentenceConfidence,
    cleanSentenceText,
    attemptSentenceSplit,
    isNaturalBreakPoint,
    // Add new exports
    alignPunctuationUniversal,
    extractSentencesUniversal,
    isSentenceEndingUniversal,
    cleanSentenceTextUniversal,
    validateSentenceBoundaries,
    normalizeWordUniversal,
    tokenizeUniversal
};