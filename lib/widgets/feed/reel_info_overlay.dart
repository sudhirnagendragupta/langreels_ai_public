// lib/widgets/feed/reel_info_overlay.dart - Clean version without debug

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_utils.dart';

class ReelInfoOverlay extends StatelessWidget {
  final AILanguageReel reel;

  const ReelInfoOverlay({
    Key? key,
    required this.reel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SupportedLanguages.getLanguageFlag(reel.sourceLanguage ?? 'en'),
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(width: 4),
              Text(
                SupportedLanguages.getLanguageName(reel.sourceLanguage ?? 'en'),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Author info
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                reel.authorAvatar,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reel.authorName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  reel.createdAt.timeAgo,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 12),

        // AI-generated transcript with translation
        if (reel.originalText != null) _buildTranscriptWithTranslation(context),

        SizedBox(height: 8),

        // AI processing indicator
        Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.aiPrimary, size: 14),
            SizedBox(width: 4),
            Text(
              'AI-processed',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.aiPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (reel.transcriptionConfidence != null) ...[
              SizedBox(width: 8),
              Text(
                '${(reel.transcriptionConfidence! * 100).round()}% confidence',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTranscriptWithTranslation(BuildContext context) {
    // Get user's primary language for display
    String userLanguage = 'en';
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languagePrefs = authProvider.userProfile?['languagePreferences']
          as Map<String, dynamic>?;
      userLanguage = languagePrefs?['primaryLanguage'] as String? ?? 'en';
    } catch (e) {
      userLanguage = 'en';
    }

    final sourceLanguage = reel.sourceLanguage ?? 'en';
    final originalText = reel.originalText!;
    final translation = reel.translations[userLanguage] ?? '';

    // Check if we should show translation (different from source language and translation exists)
    final shouldShowTranslation = sourceLanguage != userLanguage &&
        translation.isNotEmpty &&
        translation != originalText;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original text (in source language)
          _buildTextDisplay(
            text: originalText,
            isOriginal: true,
            languageCode: sourceLanguage,
          ),

          // Translation (in user's primary language)
          if (shouldShowTranslation) ...[
            SizedBox(height: 8),
            _buildTextDisplay(
              text: translation,
              isOriginal: false,
              languageCode: userLanguage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextDisplay({
    required String text,
    required bool isOriginal,
    required String languageCode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language label
        Row(
          children: [
            Text(
              SupportedLanguages.getLanguageFlag(languageCode),
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(width: 4),
            Text(
              SupportedLanguages.getLanguageName(languageCode),
              style: AppTextStyles.caption.copyWith(
                color: isOriginal ? AppColors.aiPrimary : Colors.grey[400],
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
            if (isOriginal) ...[
              SizedBox(width: 4),
              Icon(
                Icons.mic,
                color: AppColors.aiPrimary,
                size: 10,
              ),
            ],
          ],
        ),
        SizedBox(height: 4),

        // Text content
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isOriginal ? Colors.white : Colors.grey[300],
            fontWeight: isOriginal ? FontWeight.w600 : FontWeight.normal,
            fontStyle: isOriginal ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
