// lib/widgets/profile/profile_stats_card.dart

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_utils.dart';

class ProfileStatsCard extends StatelessWidget {
  final Map<String, int> userCounts;

  const ProfileStatsCard({
    Key? key,
    required this.userCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            _buildStatItem(
              'Reels',
              userCounts['reels'] ?? 0,
              Icons.videocam,
              AppColors.primary,
            ),
            _buildDivider(),
            _buildStatItem(
              'Saved',
              userCounts['saved'] ?? 0,
              Icons.bookmark,
              AppColors.save,
            ),
            _buildDivider(),
            _buildStatItem(
              'Followers',
              userCounts['followers'] ?? 0,
              Icons.people,
              AppColors.aiSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            count.formatted,
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.1),
      margin: EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
