// lib/utils/share_utils.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/ai_language_reel.dart';
import '../constants/app_constants.dart';

class ShareUtils {
  /// Generate a shareable thumbnail for the reel
  static Future<String?> generateThumbnail(AILanguageReel reel) async {
    try {
      // Use existing thumbnail if available, otherwise generate placeholder
      return _generatePlaceholderThumbnail(reel);
    } catch (e) {
      // print('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Generate placeholder thumbnail URL based on reel data
  static String _generatePlaceholderThumbnail(AILanguageReel reel) {
    // Use original text as title, or fallback to "Language Lesson"
    final title = reel.originalText ?? 'Language Lesson';
    final encodedTitle = Uri.encodeComponent(title);
    final language = reel.sourceLanguage?.toUpperCase() ?? 'LANG';

    return 'https://langreels.com/api/thumbnail/${reel.id}?title=$encodedTitle&lang=$language&author=${Uri.encodeComponent(reel.authorName)}';
  }

  /// Build thumbnail widget for rendering
  static Widget _buildThumbnailWidget(AILanguageReel reel) {
    return Container(
      width: 400,
      height: 600,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundDark,
            AppColors.primary.withOpacity(0.3),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LangReels Logo/Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
            SizedBox(height: 24),

            // Title (use originalText as title)
            Text(
              reel.originalText ?? 'Learn Languages with AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),

            // Language Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Learn ${reel.sourceLanguage ?? 'Language'}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 24),

            // Author
            Text(
              'By ${reel.authorName}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),

            // App Branding
            Text(
              'LangReels',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'AI-Powered Language Learning',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate share URLs for different platforms
  static Map<String, String> generateShareUrls(AILanguageReel reel) {
    final baseUrl = 'https://langreels.com/reel/${reel.id}';
    final title = reel.originalText ?? 'Learn Languages with AI';
    final language = reel.sourceLanguage ?? 'Language';
    final shareText =
        'Check out this $language lesson: "$title" on LangReels! 🎓📱';
    final fullShareText = '$shareText\n\n$baseUrl';

    return {
      'base': baseUrl,
      'whatsapp': 'https://wa.me/?text=${Uri.encodeComponent(fullShareText)}',
      'facebook':
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(baseUrl)}',
      'twitter':
          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareText)}&url=${Uri.encodeComponent(baseUrl)}',
      'linkedin':
          'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(baseUrl)}',
      'email':
          'mailto:?subject=${Uri.encodeComponent('Check out this $language lesson on LangReels!')}&body=${Uri.encodeComponent(fullShareText)}',
      'sms': 'sms:?body=${Uri.encodeComponent(fullShareText)}',
    };
  }

  /// Track share analytics
  static void trackShareAnalytics({
    required String reelId,
    required String platform,
    required String userId,
  }) async {
    try {
      // In a real implementation, this would send analytics to your backend
      // print('Share tracked: Reel $reelId shared to $platform by user $userId');

      // You could expand this to track:
      // - Share conversion rates
      // - Most popular sharing platforms
      // - User sharing behavior
      // - Geographic sharing patterns
    } catch (e) {
      // print('Error tracking share analytics: $e');
    }
  }

  /// Generate share metadata for web previews
  static Map<String, dynamic> generateShareMetadata(AILanguageReel reel) {
    final title = reel.originalText ?? 'Learn Languages with AI';
    final language = reel.sourceLanguage ?? 'Language';

    return {
      'title': '$title - Learn $language on LangReels',
      'description':
          'AI-powered language learning with ${reel.authorName}. Master $language through engaging video content.',
      'image': _generatePlaceholderThumbnail(reel),
      'url': 'https://langreels.com/reel/${reel.id}',
      'type': 'video.other',
      'siteName': 'LangReels',
      'locale': _getLocaleFromLanguage(language),
      'video': {
        'tags': [language, 'language learning', 'AI', 'education'],
      },
    };
  }

  /// Convert language to locale format
  static String _getLocaleFromLanguage(String language) {
    final languageMap = {
      'spanish': 'es_ES',
      'french': 'fr_FR',
      'german': 'de_DE',
      'italian': 'it_IT',
      'portuguese': 'pt_PT',
      'japanese': 'ja_JP',
      'korean': 'ko_KR',
      'chinese': 'zh_CN',
      'arabic': 'ar_SA',
      'hindi': 'hi_IN',
      'russian': 'ru_RU',
      'english': 'en_US',
    };

    return languageMap[language.toLowerCase()] ?? 'en_US';
  }

  /// Validate share URL before opening
  static bool isValidShareUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Format share count for display
  static String formatShareCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Generate deep link for existing users
  static String generateDeepLink(AILanguageReel reel) {
    // This would be used for users who already have the app installed
    return 'langreels://reel/${reel.id}';
  }

  /// Generate smart link that works for both web and app users
  static String generateSmartLink(AILanguageReel reel) {
    // Firebase Dynamic Links or similar service would handle this
    return 'https://langreels.app.link/reel/${reel.id}';
  }
}

/// Extension to add share functionality to int (for formatting)
extension ShareFormattingExtension on int {
  String get shareFormatted => ShareUtils.formatShareCount(this);
}
