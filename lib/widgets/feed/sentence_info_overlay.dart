// lib/widgets/feed/sentence_info_overlay.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../models/sentence_data.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../screens/profile/other_user_profile_screen.dart';
import '../../screens/main_screen.dart';

class SentenceInfoOverlay extends StatelessWidget {
  final AILanguageReel reel;
  final int currentSentenceIndex;
  final bool isStudyMode;

  const SentenceInfoOverlay({
    Key? key,
    required this.reel,
    required this.currentSentenceIndex,
    this.isStudyMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language and processing indicator
        _buildLanguageIndicator(),

        SizedBox(height: 12),

        // Author info
        _buildAuthorInfo(context), // Pass context here

        SizedBox(height: 12),

        // Content info - different based on mode
        if (isStudyMode)
          _buildStudyModeInfo(context)
        else
          _buildNormalModeInfo(context),
      ],
    );
  }

  // Helper method to get user's preferred language
  String _getUserPreferredLanguage(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languagePrefs = authProvider.userProfile?['languagePreferences']
          as Map<String, dynamic>?;
      return languagePrefs?['primaryLanguage'] as String? ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  Widget _buildLanguageIndicator() {
    return SizedBox.shrink(); // Remove the entire top language indicator
  }

  Widget _buildAuthorInfo(BuildContext context) {
    // Add context parameter
    // Use display name if available, otherwise fall back to username
    final displayName = reel.authorDisplayName?.isNotEmpty == true
        ? reel.authorDisplayName!
        : reel.authorName;
    final shouldShowUsername = reel.authorDisplayName?.isNotEmpty == true;

    return GestureDetector(
      onTap: () => _navigateToUserProfile(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (shouldShowUsername) ...[
                      Text(
                        '@${reel.authorName}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        ' • ',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
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
          ),
        ],
      ),
    );
  }

  void _navigateToUserProfile(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.userId;

    if (reel.authorId == currentUserId) {
      // Navigate to own profile (main screen, profile tab)
      final mainScreenState =
          context.findAncestorStateOfType<MainScreenState>();
      if (mainScreenState != null) {
        mainScreenState.navigateToTab(3); // Profile tab index
      }
    } else {
      // Navigate to other user's profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(
            userId: reel.authorId,
            username: reel.authorName,
          ),
        ),
      );
    }
  }

  Widget _buildNormalModeInfo(BuildContext context) {
    return SizedBox.shrink(); // Remove all the detailed content in normal mode
  }

  Widget _buildStudyModeInfo(BuildContext context) {
    return SizedBox.shrink(); // Remove all the clutter
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.grey[400],
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview(SentenceData sentence, String userLanguage) {
    final sourceLanguage = reel.sourceLanguage ?? 'en';
    final originalText = sentence.originalText;
    final translation = sentence.getTranslation(userLanguage);
    final shouldShowTranslation = sourceLanguage != userLanguage &&
        translation.isNotEmpty &&
        translation != originalText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original text with language indicator
        _buildLanguageLabeledText(
          text: originalText,
          languageCode: sourceLanguage,
          isOriginal: true,
          maxLines: 2,
        ),

        // Translation if different
        if (shouldShowTranslation) ...[
          SizedBox(height: 6),
          _buildLanguageLabeledText(
            text: translation,
            languageCode: userLanguage,
            isOriginal: false,
            maxLines: 2,
          ),
        ],

        // First sentence indicator
      ],
    );
  }

  Widget _buildSimpleContentPreview(
      String originalText, String translation, String userLanguage) {
    final sourceLanguage = reel.sourceLanguage ?? 'en';
    final shouldShowTranslation = sourceLanguage != userLanguage &&
        translation.isNotEmpty &&
        translation != originalText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original text with language indicator
        _buildLanguageLabeledText(
          text: originalText,
          languageCode: sourceLanguage,
          isOriginal: true,
          maxLines: 2,
        ),

        // Translation if different
        if (shouldShowTranslation) ...[
          SizedBox(height: 6),
          _buildLanguageLabeledText(
            text: translation,
            languageCode: userLanguage,
            isOriginal: false,
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageLabeledText({
    required String text,
    required String languageCode,
    required bool isOriginal,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language label
        Row(
          children: [
            Text(
              SupportedLanguages.getLanguageFlag(languageCode),
              style: TextStyle(fontSize: 10),
            ),
            SizedBox(width: 3),
            Text(
              SupportedLanguages.getLanguageName(languageCode),
              style: AppTextStyles.caption.copyWith(
                color: isOriginal ? AppColors.aiPrimary : Colors.grey[500],
                fontWeight: FontWeight.w500,
                fontSize: 9,
              ),
            ),
            if (isOriginal) ...[
              SizedBox(width: 3),
              Icon(
                Icons.mic,
                color: AppColors.aiPrimary,
                size: 9,
              ),
            ],
          ],
        ),
        SizedBox(height: 2),

        // Text content
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: isOriginal ? Colors.white : Colors.grey[300],
            fontWeight: isOriginal ? FontWeight.w600 : FontWeight.normal,
            fontStyle: isOriginal ? FontStyle.normal : FontStyle.italic,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
