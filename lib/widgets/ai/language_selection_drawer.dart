// lib/widgets/ai/language_selection_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/reel_provider.dart';

class LanguageSelectionDrawer extends StatefulWidget {
  @override
  _LanguageSelectionDrawerState createState() =>
      _LanguageSelectionDrawerState();
}

class _LanguageSelectionDrawerState extends State<LanguageSelectionDrawer> {
  late List<String> _tempSelection;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ReelProvider>(context, listen: false);
    _tempSelection = List<String>.from(provider.selectedLanguages);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildLanguageList()),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Languages',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getCountText(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCountText() {
    if (_tempSelection.contains('all')) return 'All Languages';
    final count = _tempSelection.length;
    return count == 1 ? '1 Language' : '$count Languages';
  }

  Widget _buildLanguageList() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildLanguageOption('all', 'All Languages', '🌐'),
        SizedBox(height: 12),
        ...SupportedLanguages.languageEntries.map(
          (entry) => _buildLanguageOption(
              entry.key, entry.value.name, entry.value.flag),
        ),
      ],
    );
  }

  Widget _buildLanguageOption(String code, String name, String flag) {
    final isSelected = _tempSelection.contains(code);

    return GestureDetector(
      onTap: () => _toggle(code),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(flag, style: TextStyle(fontSize: 20))),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[500]!,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String code) {
    setState(() {
      if (code == 'all') {
        _tempSelection = ['all'];
      } else {
        _tempSelection.remove('all');
        if (_tempSelection.contains(code)) {
          _tempSelection.remove(code);
        } else {
          _tempSelection.add(code);
        }
        if (_tempSelection.isEmpty) {
          _tempSelection = ['all'];
        }
      }
    });
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _tempSelection = ['all']),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
              child: Text(
                'Clear All',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                final provider =
                    Provider.of<ReelProvider>(context, listen: false);
                provider.setSelectedLanguages(_tempSelection);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Apply Selection',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
