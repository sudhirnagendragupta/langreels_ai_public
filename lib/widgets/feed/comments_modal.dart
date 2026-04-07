// lib/widgets/feed/comments_modal.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_utils.dart';
// import '../common/common_widgets.dart';
import '../../utils/user_profile_extensions.dart';
import '../../screens/profile/other_user_profile_screen.dart';

class CommentsModal extends StatefulWidget {
  final AILanguageReel reel;
  final VoidCallback? onNavigateToOwnProfile; // NEW

  const CommentsModal({
    Key? key,
    required this.reel,
    this.onNavigateToOwnProfile, // NEW
  }) : super(key: key);

  @override
  _CommentsModalState createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    // Load comments when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelProvider>().loadComments(widget.reel.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildCommentsList()),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // Alternative fix: Count from actual comments list
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // FIX: Use actual comments list length for real-time updates
          Consumer<ReelProvider>(
            builder: (context, reelProvider, child) {
              final comments = reelProvider.comments[widget.reel.id] ?? [];

              return Text(
                '${comments.length} Comments',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        final comments = reelProvider.comments[widget.reel.id] ?? [];

        if (comments.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return _buildCommentItem(comment);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.comment_outlined,
              size: 40,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No comments yet',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(ReelComment comment) {
    final authProvider = context.read<AuthProvider>();
    final isMyComment = authProvider.userId == comment.authorId;

    // Use display name if available, otherwise fall back to username
    final displayName = comment.authorDisplayName?.isNotEmpty == true
        ? comment.authorDisplayName!
        : comment.authorName;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar - Make clickable
          GestureDetector(
            onTap: () => _navigateToUserProfile(context, comment), // NEW
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppUtils.getAvatarColor(comment.authorName),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppUtils.getInitials(displayName),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with display name, "You" badge, and time
                Row(
                  children: [
                    // Make display name clickable
                    GestureDetector(
                      onTap: () =>
                          _navigateToUserProfile(context, comment), // NEW
                      child: Text(
                        displayName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMyComment) ...[
                      SizedBox(width: 6),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'You',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    Spacer(),
                    Text(
                      AppUtils.getTimeAgo(comment.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),

                // Comment Text
                Text(
                  comment.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),

                // Comment Actions
                Row(
                  children: [
                    _buildCommentAction(
                      icon: comment.likedBy.contains(authProvider.userId)
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      label: comment.likes > 0 ? '${comment.likes}' : 'Like',
                      color: comment.likedBy.contains(authProvider.userId)
                          ? AppColors.like
                          : AppColors.textSecondary,
                      onTap: () => _toggleCommentLike(comment),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

// NEW: Add this helper method to _CommentsModalState class
  void _navigateToUserProfile(BuildContext context, ReelComment comment) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    // Close the comments modal first
    Navigator.pop(context);

    // Check if it's the current user's comment
    if (comment.authorId == currentUserId) {
      // Use the callback to navigate to own profile
      if (widget.onNavigateToOwnProfile != null) {
        widget.onNavigateToOwnProfile!();
      }
    } else {
      // It's someone else's comment - navigate to their profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(
            userId: comment.authorId,
            username: comment.authorName,
          ),
        ),
      );
    }
  }

  Widget _buildCommentAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return _buildLoginPrompt();
        }

        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            border: Border(
              top: BorderSide(
                color: AppColors.textSecondary.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // User Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppUtils.getAvatarColor(
                        authProvider.userProfile?.username ?? ''),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      AppUtils.getInitials(
                          authProvider.userProfile?.username ?? ''),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Comment Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                SizedBox(width: 8),

                // Send Button
                GestureDetector(
                  onTap: _isPosting ? null : _postComment,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          _commentController.text.trim().isEmpty || _isPosting
                              ? AppColors.textSecondary.withOpacity(0.3)
                              : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isPosting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign in to join the conversation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to login screen
              },
              child: Text(
                'Sign In',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      await context.read<ReelProvider>().addComment(widget.reel.id, text);

      _commentController.clear();

      // Scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment posted!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _toggleCommentLike(ReelComment comment) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      await FirebaseService.toggleCommentLike(comment.id, authProvider.userId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like comment. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
