// lib/widgets/ai/language_filter_chip.dart

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

class LanguageFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageFilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortAnimation,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
