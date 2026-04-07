// lib/widgets/feed/reel_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../utils/app_utils.dart';
import 'comments_modal.dart'; // Import the new comments modal
import 'enhanced_share_modal.dart';
import '../../screens/main_screen.dart';

class ReelActionButtons extends StatelessWidget {
  final AILanguageReel reel;
  final bool isStudyMode;
  final VoidCallback? onToggleStudyMode;

  const ReelActionButtons({
    Key? key,
    required this.reel,
    this.isStudyMode = false,
    this.onToggleStudyMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final userId = authProvider.userId;

    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        // Find the latest version of this reel from provider
        final latestReel = reelProvider.getReelById(reel.id) ?? reel;

        if (isStudyMode) {
          return _buildStudyModeActions(context);
        }

        return Column(
          children: [
            // Like Button
            _buildActionButton(
              icon: latestReel.likedBy.contains(userId)
                  ? Icons.favorite
                  : Icons.favorite_outline,
              count: latestReel.likes,
              color: latestReel.likedBy.contains(userId)
                  ? AppColors.like
                  : Colors.white,
              onTap: isAuthenticated
                  ? () => reelProvider.toggleLike(latestReel.id)
                  : () => _showLoginPrompt(context),
            ),
            SizedBox(height: 20),

            // Comment Button
            _buildActionButton(
              icon: Icons.comment_outlined,
              count: latestReel.comments,
              color: Colors.white,
              onTap: () => _showCommentsModal(context, latestReel),
            ),
            SizedBox(height: 20),

            // Save Button
            _buildActionButton(
              icon: latestReel.savedBy.contains(userId)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
              count: null, // Don't show save count
              color: latestReel.savedBy.contains(userId)
                  ? AppColors.save
                  : Colors.white,
              onTap: isAuthenticated
                  ? () => reelProvider.toggleSave(latestReel.id)
                  : () => _showLoginPrompt(context),
            ),
            SizedBox(height: 20),

            // Share Button
            _buildActionButton(
              icon: Icons.share_outlined,
              count: latestReel.shares > 0 ? latestReel.shares : null,
              color: Colors.white,
              onTap: () => _shareReel(context, latestReel),
            ),

            // Study Mode Toggle (only for sentence-based reels)
            if (onToggleStudyMode != null) ...[
              SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.school_outlined,
                count: null,
                color: AppColors.warning,
                onTap: onToggleStudyMode ?? () {},
                isSpecial: true,
              ),
              SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStudyModeActions(BuildContext context) {
    return Column(
      children: [
        // Exit Study Mode
        _buildActionButton(
          icon: Icons.close,
          count: null,
          color: AppColors.error,
          onTap: onToggleStudyMode ?? () {},
          isSpecial: true,
        ),

        SizedBox(height: 20),

        // Study Mode Indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.school,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                'Study\nMode',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Sentence count indicator
        if (reel.hasSentenceData)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${reel.totalSentences}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'sentences',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int? count,
    required Color color,
    required VoidCallback onTap,
    bool isSpecial = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSpecial
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(25),
              border: isSpecial
                  ? Border.all(
                      color: color.withOpacity(0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          if (count != null && count > 0) ...[
            SizedBox(height: 4),
            Text(
              count.formatted,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCommentsModal(BuildContext context, AILanguageReel reel) {
    // Get MainScreenState reference before opening modal
    final mainScreenState = context.findAncestorStateOfType<MainScreenState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsModal(
        reel: reel,
        onNavigateToOwnProfile: () {
          // This callback runs AFTER the modal is closed
          if (mainScreenState != null) {
            mainScreenState.navigateToTab(3); // Navigate to profile tab
          }
        },
      ),
    );
  }

  void _shareReel(BuildContext context, AILanguageReel reel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EnhancedShareModal(reel: reel),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please sign in to interact with reels'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'Sign In',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to login screen
            // You can implement navigation to login here
          },
        ),
      ),
    );
  }
}
