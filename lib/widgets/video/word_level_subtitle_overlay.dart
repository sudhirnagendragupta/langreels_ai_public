// lib/widgets/video/word_level_subtitle_overlay.dart

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/sentence_data.dart';

class WordLevelSubtitleOverlay extends StatelessWidget {
  final SentenceData sentence;
  final String userLanguage;
  final double currentVideoPosition;
  final bool isStudyMode;

  const WordLevelSubtitleOverlay({
    Key? key,
    required this.sentence,
    required this.userLanguage,
    required this.currentVideoPosition,
    required this.isStudyMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In study mode, show the full sentence like before
    if (isStudyMode) {
      return _buildStudyModeSubtitle();
    }

    // In normal mode, show progressive word-level subtitles
    return _buildWordLevelSubtitle();
  }

  Widget _buildWordLevelSubtitle() {
    final translation = sentence.getTranslation(userLanguage);
    final isTranslated = sentence.originalText != translation;

    // Get words that should be visible at current time
    final visibleWords = _getVisibleWords();
    final visibleTranslationWords = _getVisibleTranslationWords(translation);

    // If no words are visible yet, don't show anything
    if (visibleWords.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Original language with progressive reveal
          _buildProgressiveText(
            visibleWords,
            TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),

          // Translation (if different) with progressive reveal
          if (isTranslated && visibleTranslationWords.isNotEmpty) ...[
            SizedBox(height: 6),
            _buildProgressiveText(
              visibleTranslationWords,
              TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyModeSubtitle() {
    final translation = sentence.getTranslation(userLanguage);
    final isTranslated = sentence.originalText != translation;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Full original text in study mode
          if (isTranslated) ...[
            Text(
              sentence.originalText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
          ],

          // Full translation
          Text(
            translation,
            style: TextStyle(
              color: isTranslated ? AppColors.textSecondary : Colors.white,
              fontSize: isTranslated ? 14 : 16,
              fontStyle: isTranslated ? FontStyle.italic : FontStyle.normal,
              fontWeight: isTranslated ? FontWeight.normal : FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          // Study mode indicator
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sentence ${sentence.index + 1}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressiveText(List<String> words, TextStyle style) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isLastWord = index == words.length - 1;

          return TextSpan(
            text: word + (isLastWord ? '' : ' '),
            style: style,
          );
        }).toList(),
      ),
    );
  }

  List<String> _getVisibleWords() {
    if (sentence.words == null || sentence.words!.isEmpty) {
      // Fallback: if no word-level data, show full sentence when time is in range
      if (currentVideoPosition >= sentence.startTime &&
          currentVideoPosition <= sentence.endTime) {
        return sentence.originalText.split(' ');
      }
      return [];
    }

    // Get words that should be visible based on current video position
    final visibleWords = <String>[];

    for (final word in sentence.words!) {
      if (currentVideoPosition >= word.startTime) {
        visibleWords.add(word.word);
      } else {
        break; // Stop at first word that hasn't started yet
      }
    }

    return visibleWords;
  }

  List<String> _getVisibleTranslationWords(String translation) {
    // For translation, we need to estimate word timing since we don't have
    // word-level timing for translations. We'll use a simple approach:
    // map the progress through original words to translation words.

    if (sentence.words == null || sentence.words!.isEmpty) {
      // Fallback: show full translation when sentence is active
      if (currentVideoPosition >= sentence.startTime &&
          currentVideoPosition <= sentence.endTime) {
        return translation.split(' ');
      }
      return [];
    }

    final originalWords = sentence.words!;
    final translationWords = translation.split(' ');

    // Calculate how many original words are visible
    int visibleOriginalCount = 0;
    for (final word in originalWords) {
      if (currentVideoPosition >= word.startTime) {
        visibleOriginalCount++;
      } else {
        break;
      }
    }

    // Map to translation words proportionally
    final progressRatio = visibleOriginalCount / originalWords.length;
    final visibleTranslationCount = (progressRatio * translationWords.length)
        .round()
        .clamp(0, translationWords.length);

    return translationWords.take(visibleTranslationCount).toList();
  }

  /// Helper method to get the current word being spoken (for highlighting)
  WordData? getCurrentWord() {
    if (sentence.words == null || sentence.words!.isEmpty) return null;

    for (final word in sentence.words!) {
      if (currentVideoPosition >= word.startTime &&
          currentVideoPosition <= word.endTime) {
        return word;
      }
    }
    return null;
  }

  /// Enhanced version with current word highlighting
  Widget _buildProgressiveTextWithHighlight(
      List<String> words, TextStyle baseStyle) {
    final currentWord = getCurrentWord();

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isLastWord = index == words.length - 1;

          // Check if this is the currently spoken word
          final isCurrentWord = currentWord != null &&
              currentWord.word.replaceAll(RegExp(r'[^\w\s]'), '') ==
                  word.replaceAll(RegExp(r'[^\w\s]'), '');

          return TextSpan(
            text: word + (isLastWord ? '' : ' '),
            style: baseStyle.copyWith(
              // Highlight current word
              backgroundColor:
                  isCurrentWord ? AppColors.primary.withOpacity(0.3) : null,
              fontWeight:
                  isCurrentWord ? FontWeight.bold : baseStyle.fontWeight,
            ),
          );
        }).toList(),
      ),
    );
  }
}
