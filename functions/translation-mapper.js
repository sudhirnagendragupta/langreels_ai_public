// /functions/translation-mapper.js
// Generic approach that works for both single and multi-sentence content

/**
 * Maps full translations to individual sentences using multiple strategies.
 * @param {Array} extractedSentences - Sentences from speech processing.
 * @param {Object} fullTranslations - Full translations by language code.
 * @param {string} detectedLanguage - Original detected language code.
 * @param {Array} mappingWarnings - Array to collect warnings.
 * @returns {Array} Sentences with mapped translations.
 */
function mapTranslationsToSentences(extractedSentences, fullTranslations, detectedLanguage, mappingWarnings = []) {
    const result = [];

    try {
        console.log(`🔗 Starting translation mapping for ${extractedSentences.length} sentences`);
        console.log(`📝 Available translations: ${Object.keys(fullTranslations).join(', ')}`);
        console.log(`🌐 Detected language: ${detectedLanguage}`);

        // Pre-segment all translations once
        const segmentedTranslations = {};
        for (const [langCode, fullTranslation] of Object.entries(fullTranslations)) {
            if (langCode === detectedLanguage) continue;

            segmentedTranslations[langCode] = segmentTranslation(
                fullTranslation,
                langCode,
                extractedSentences.length
            );
        }

        // Map each sentence to its translations
        for (const [index, sentence] of extractedSentences.entries()) {
            const sentenceTranslations = {};

            // Always add the original language first
            sentenceTranslations[detectedLanguage] = sentence.originalText;

            // Map translations for each target language
            for (const [langCode, fullTranslation] of Object.entries(fullTranslations)) {
                if (langCode === detectedLanguage) continue;

                const segments = segmentedTranslations[langCode];
                const mappedTranslation = selectBestTranslationSegment(
                    sentence,
                    segments,
                    index,
                    extractedSentences,
                    fullTranslation,
                    langCode,
                    mappingWarnings
                );

                sentenceTranslations[langCode] = mappedTranslation;
            }

            result.push({
                ...sentence, // Keep original sentence properties
                index: index,
                translations: sentenceTranslations
            });

            console.log(`✅ Sentence ${index}: "${sentence.originalText.substring(0, 50)}..." mapped to ${Object.keys(sentenceTranslations).length} languages`);
        }

        console.log(`🎉 Translation mapping completed. ${result.length} sentences with translations.`);
        return result;

    } catch (error) {
        console.error('❌ Error mapping translations to sentences:', error);
        mappingWarnings.push(`Translation mapping failed: ${error.message}`);

        // Fallback: return sentences with only original language
        return extractedSentences.map((sentence, index) => ({
            ...sentence,
            index: index,
            translations: { [detectedLanguage]: sentence.originalText }
        }));
    }
}

/**
 * Segments a full translation into parts that correspond to original sentences.
 * Uses multiple strategies to handle different content types and languages.
 * @param {string} fullTranslation - Complete translation text.
 * @param {string} languageCode - Target language code.
 * @param {number} expectedSegments - Number of segments we expect to create.
 * @returns {Array} Array of translation segments.
 */
function segmentTranslation(fullTranslation, languageCode, expectedSegments) {
    if (!fullTranslation || typeof fullTranslation !== 'string') {
        return [];
    }

    const text = fullTranslation.trim();
    if (text.length === 0) {
        return [];
    }

    // If we expect only one segment, return the whole text
    if (expectedSegments === 1) {
        return [text];
    }

    // Try multiple segmentation strategies
    let segments = [];

    // Strategy 1: Language-specific sentence patterns
    segments = segmentByLanguagePatterns(text, languageCode);

    // Strategy 2: If pattern-based segmentation doesn't give us the right number,
    // try punctuation-based segmentation
    if (segments.length !== expectedSegments) {
        segments = segmentByPunctuation(text);
    }

    // Strategy 3: If still not right, try length-based segmentation
    if (segments.length !== expectedSegments) {
        segments = segmentByLength(text, expectedSegments);
    }

    // Strategy 4: If we have too few segments, split the longest ones
    if (segments.length < expectedSegments) {
        segments = expandSegments(segments, expectedSegments);
    }

    // Strategy 5: If we have too many segments, merge the shortest ones
    if (segments.length > expectedSegments) {
        segments = mergeSegments(segments, expectedSegments);
    }

    console.log(`📐 Segmented ${languageCode}: ${segments.length} segments (expected ${expectedSegments})`);
    return segments.filter(s => s.trim().length > 0);
}

/**
 * Segment text using language-specific sentence patterns.
 */
function segmentByLanguagePatterns(text, languageCode) {
    const languagePatterns = {
        'en': /(?<=[.!?])\s+(?=[A-Z])/g,
        'es': /(?<=[.!?¡¿])\s+(?=[A-ZÁÉÍÓÚÑ])/g,
        'fr': /(?<=[.!?])\s+(?=[A-ZÀÂÇÉÈÊËÎÏÔÖÙÛÜŸ])/g,
        'de': /(?<=[.!?])\s+(?=[A-ZÄÖÜß])/g,
        'pt': /(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÃÕÇ])/g,
        'ru': /(?<=[.!?])\s+(?=[А-Я])/g,
        'ja': /(?<=[。！？])/g,
        'ko': /(?<=[.!?。！？])/g,
        'zh': /(?<=[。！？])/g,
        'ar': /(?<=[.!?؟])\s+(?=[A-Zأ-ي])/g,
        'hi': /(?<=[।!?])\s+(?=[A-Zअ-ज्ञ])/g,
    };

    const pattern = languagePatterns[languageCode] || languagePatterns['en'];
    const segments = text.split(pattern);

    return segments.map(s => s.trim()).filter(s => s.length > 0);
}

/**
 * Segment text by common punctuation marks.
 */
function segmentByPunctuation(text) {
    // Split on sentence-ending punctuation followed by space or end of string
    const segments = text.split(/([.!?¡¿。！？؟।]+\s*)/);

    // Recombine punctuation with preceding text
    const result = [];
    for (let i = 0; i < segments.length; i += 2) {
        if (segments[i] && segments[i].trim()) {
            const segment = segments[i] + (segments[i + 1] || '');
            result.push(segment.trim());
        }
    }

    return result.filter(s => s.length > 0);
}

/**
 * Segment text by approximate equal lengths.
 */
function segmentByLength(text, expectedSegments) {
    if (expectedSegments <= 1) return [text];

    const words = text.split(/\s+/);
    const wordsPerSegment = Math.ceil(words.length / expectedSegments);
    const segments = [];

    for (let i = 0; i < words.length; i += wordsPerSegment) {
        const segmentWords = words.slice(i, i + wordsPerSegment);
        segments.push(segmentWords.join(' '));
    }

    return segments.filter(s => s.length > 0);
}

/**
 * Expand segments by splitting the longest ones.
 */
function expandSegments(segments, targetCount) {
    const result = [...segments];

    while (result.length < targetCount) {
        // Find the longest segment
        let longestIndex = 0;
        let longestLength = 0;

        for (let i = 0; i < result.length; i++) {
            if (result[i].length > longestLength) {
                longestLength = result[i].length;
                longestIndex = i;
            }
        }

        // Split the longest segment in half
        const longestSegment = result[longestIndex];
        const words = longestSegment.split(/\s+/);
        const midPoint = Math.ceil(words.length / 2);

        const firstHalf = words.slice(0, midPoint).join(' ');
        const secondHalf = words.slice(midPoint).join(' ');

        result.splice(longestIndex, 1, firstHalf, secondHalf);
    }

    return result;
}

/**
 * Merge segments by combining the shortest ones.
 */
function mergeSegments(segments, targetCount) {
    const result = [...segments];

    while (result.length > targetCount) {
        // Find the shortest adjacent pair
        let shortestPairIndex = 0;
        let shortestPairLength = Infinity;

        for (let i = 0; i < result.length - 1; i++) {
            const pairLength = result[i].length + result[i + 1].length;
            if (pairLength < shortestPairLength) {
                shortestPairLength = pairLength;
                shortestPairIndex = i;
            }
        }

        // Merge the shortest pair
        const merged = result[shortestPairIndex] + ' ' + result[shortestPairIndex + 1];
        result.splice(shortestPairIndex, 2, merged);
    }

    return result;
}

/**
 * Select the best translation segment for a given sentence.
 */
function selectBestTranslationSegment(sentence, segments, index, allSentences, fullTranslation, langCode, warnings) {
    if (!segments || segments.length === 0) {
        warnings.push(`No segments available for ${langCode}, using full translation`);
        return fullTranslation;
    }

    // If we have the exact number of segments, use direct mapping
    if (segments.length === allSentences.length && index < segments.length) {
        return segments[index];
    }

    // If we have only one segment, use it for all sentences
    if (segments.length === 1) {
        // For multi-sentence content with only one translation segment,
        // we need to extract the relevant part
        if (allSentences.length > 1) {
            return extractSentenceFromFullText(sentence, fullTranslation, index, allSentences.length);
        }
        return segments[0];
    }

    // Use proportional mapping
    const proportionalIndex = Math.floor((index / allSentences.length) * segments.length);
    const clampedIndex = Math.min(proportionalIndex, segments.length - 1);

    if (clampedIndex < segments.length) {
        return segments[clampedIndex];
    }

    // Fallback to last available segment
    warnings.push(`Using fallback segment for sentence ${index} in ${langCode}`);
    return segments[segments.length - 1] || fullTranslation;
}

/**
 * Extract a sentence portion from full translation text based on position.
 */
function extractSentenceFromFullText(sentence, fullTranslation, sentenceIndex, totalSentences) {
    const words = fullTranslation.split(/\s+/);
    const wordsPerSentence = Math.ceil(words.length / totalSentences);

    const startIndex = sentenceIndex * wordsPerSentence;
    const endIndex = Math.min(startIndex + wordsPerSentence, words.length);

    return words.slice(startIndex, endIndex).join(' ');
}

module.exports = {
    mapTranslationsToSentences,
    segmentTranslation,
    segmentByLanguagePatterns,
    segmentByPunctuation,
    segmentByLength,
};