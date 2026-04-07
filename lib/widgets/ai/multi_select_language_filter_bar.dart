// lib/widgets/ai/multi_select_language_filter_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/reel_provider.dart';
import 'language_selection_drawer.dart';

class MultiSelectLanguageFilterBar extends StatelessWidget {
  const MultiSelectLanguageFilterBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        final selectedLanguages = reelProvider.selectedLanguages;
        final popularLanguages = ['en', 'es', 'fr', 'de'];

        return Container(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('all', 'All', selectedLanguages.contains('all'),
                  reelProvider),
              ...popularLanguages.map(
                (langCode) => _buildFilterChip(
                  langCode,
                  SupportedLanguages.getLanguageName(langCode),
                  selectedLanguages.contains(langCode),
                  reelProvider,
                ),
              ),
              _buildMoreChip(selectedLanguages, popularLanguages, context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      String value, String label, bool isSelected, ReelProvider provider) {
    return GestureDetector(
      onTap: () => provider.toggleLanguageSelection(value),
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != 'all') ...[
                Text(SupportedLanguages.getLanguageFlag(value),
                    style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreChip(
      List<String> selected, List<String> popular, BuildContext context) {
    final popularWithAll = ['all', ...popular];
    final additionalCount =
        selected.where((lang) => !popularWithAll.contains(lang)).length;

    return GestureDetector(
      onTap: () => _showDrawer(context),
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: additionalCount > 0
              ? AppColors.primary.withOpacity(0.7)
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: additionalCount > 0
                ? AppColors.primary
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              additionalCount > 0 ? 'More (+$additionalCount)' : 'More',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight:
                    additionalCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguageSelectionDrawer(),
    );
  }
}
