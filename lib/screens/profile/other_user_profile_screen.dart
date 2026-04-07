// lib/screens/profile/other_user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reel_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/video/reel_grid_item.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const OtherUserProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  Map<String, dynamic>? _userProfileData;
  Map<String, int> _userCounts = {};
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final reelProvider = Provider.of<ReelProvider>(context, listen: false);

      // Load user profile as Map instead of UserProfile object
      final profileData = await userProvider.getUserProfile(widget.userId);
      final counts = await FirebaseService.getUserCounts(widget.userId);
      final following = await userProvider.isFollowing(widget.userId);

      // Load user's reels
      reelProvider.loadUserReels(widget.userId);

      if (profileData == null) {
        // Profile not found
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        // Store as Map instead of UserProfile
        _userProfileData = profileData;
        _userCounts = counts;
        _isFollowing = following;
        _isLoading = false;
      });
    } catch (e) {
      // print('Error loading user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      bool success;
      if (_isFollowing) {
        success = await userProvider.unfollowUser(widget.userId);
      } else {
        success = await userProvider.followUser(widget.userId);
      }

      if (success) {
        setState(() {
          _isFollowing = !_isFollowing;
          // Update follower count immediately
          if (_isFollowing) {
            _userCounts['followers'] = (_userCounts['followers'] ?? 0) + 1;
          } else {
            _userCounts['followers'] = (_userCounts['followers'] ?? 0) - 1;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating follow status: $e')),
      );
    } finally {
      setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(widget.username),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_userProfileData == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(widget.username),
        ),
        body: Center(
          child: Text(
            'User not found',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      '@${_userProfileData!['username']}',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Info
                    _buildProfileHeader(),

                    // Follow Button
                    _buildFollowButton(),

                    // Stats
                    _buildStatsSection(),

                    // User's Reels
                    _buildReelsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profileImageUrl = _userProfileData!['profileImageUrl'] as String?;
    final displayName = _userProfileData!['displayName'] as String?;
    final username = _userProfileData!['username'] as String;
    final bio = _userProfileData!['bio'] as String?;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackAvatar(username),
                    )
                  : _buildFallbackAvatar(username),
            ),
          ),

          SizedBox(height: 16),

          // Display Name (if exists) - Primary
          if (displayName != null && displayName.isNotEmpty) ...[
            Text(
              displayName,
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
          ],

          // Username - with @ symbol
          Text(
            '@$username',
            style: (displayName != null && displayName.isNotEmpty)
                ? AppTextStyles.bodyLarge.copyWith(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w500,
                  )
                : AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            textAlign: TextAlign.center,
          ),

          if (bio != null && bio.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              bio,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.aiPrimary, AppColors.primary],
        ),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: AppTextStyles.h1.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isFollowLoading ? null : _toggleFollow,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isFollowing ? Colors.grey[700] : AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isFollowLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isFollowing
                      ? 'Unfollow'
                      : 'Follow', // CHANGED: "Following" -> "Unfollow"
                  style:
                      AppTextStyles.buttonLarge.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            _buildStatItem('Reels', _userCounts['reels'] ?? 0),
            _buildStatItem('Following', _userCounts['following'] ?? 0),
            _buildStatItem('Followers', _userCounts['followers'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
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

  Widget _buildReelsSection() {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        final userReels = reelProvider.getUserReels(widget.userId);

        if (userReels.isEmpty) {
          return Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No reels yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reels',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: userReels.length,
                itemBuilder: (context, index) {
                  final reel = userReels[index];
                  return ReelGridItem(
                    reel: reel,
                    onTap: () {
                      // TODO: Open reel viewer
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening reel...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
