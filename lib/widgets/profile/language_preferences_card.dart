// lib/widgets/profile/language_preferences_card.dart

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';

class LanguagePreferencesCard extends StatelessWidget {
  final UserLanguagePreferences preferences;
  final Function(UserLanguagePreferences) onPreferencesChanged;

  const LanguagePreferencesCard({
    Key? key,
    required this.preferences,
    required this.onPreferencesChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: AppColors.aiSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Language Preferences',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Primary Language
            _buildLanguageSection(
              'Primary Language',
              'For subtitles and interface',
              preferences.primaryLanguage,
              (language) {
                final newPrefs =
                    preferences.copyWith(primaryLanguage: language);
                onPreferencesChanged(newPrefs);
              },
            ),

            SizedBox(height: 16),

            // Learning Languages
            _buildLearningLanguagesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(
    String title,
    String subtitle,
    String currentLanguage,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[400],
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Text(
                SupportedLanguages.getLanguageFlag(currentLanguage),
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(width: 8),
              Text(
                SupportedLanguages.getLanguageName(currentLanguage),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              Spacer(),
              Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearningLanguagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Languages',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Languages you want to learn',
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[400],
          ),
        ),
        SizedBox(height: 8),
        if (preferences.learningLanguages.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[700]!,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.add, color: Colors.grey[400], size: 20),
                SizedBox(width: 8),
                Text(
                  'Add learning languages',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preferences.learningLanguages.map((langCode) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.aiSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.aiSecondary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SupportedLanguages.getLanguageFlag(langCode),
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(width: 6),
                    Text(
                      SupportedLanguages.getLanguageName(langCode),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
