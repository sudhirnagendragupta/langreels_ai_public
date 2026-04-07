// lib/screens/profile/profile_screen.dart - Complete with avatar functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_constants.dart';
import '../../models/ai_language_reel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reel_provider.dart';

import '../../utils/app_utils.dart';

import '../../widgets/video/reel_grid_item.dart';
import '../main_screen.dart';
import 'other_user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  // FIXED: Add this to track when profile tab is active
  bool _isProfileTabActive = false;

  // FIXED: Keep alive to maintain state
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load profile data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  // FIXED: Add lifecycle management
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we're on the profile tab
    final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
    final isCurrentlyOnProfile =
        mainScreenState?.currentIndex == 3; // Profile tab index

    if (isCurrentlyOnProfile != _isProfileTabActive) {
      setState(() {
        _isProfileTabActive = isCurrentlyOnProfile;
      });

      // Notify main screen about tab change to pause videos
      if (isCurrentlyOnProfile) {
        _pauseAllVideos();
      }
    }
  }

  // FIXED: Method to pause all videos when entering profile
  void _pauseAllVideos() {
    // This will be handled by the main screen's video management
  }

  void _loadProfileData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);

    if (authProvider.userId != null) {
      userProvider.getUserProfile(authProvider.userId!);
      userProvider.loadUserCounts(authProvider.userId!);
      reelProvider.loadUserReels(authProvider.userId!);
      reelProvider.loadSavedReels(authProvider.userId!);
      reelProvider.loadLikedReels(authProvider.userId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // In profile_screen.dart, update the Consumer to listen for changes and refresh counts:

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Consumer3<AuthProvider, UserProvider, ReelProvider>(
          builder: (context, authProvider, userProvider, reelProvider, child) {
            final user = authProvider.user;
            final userProfile = authProvider.userProfile;

            if (user == null || userProfile == null) {
              return _buildLoadingState();
            }

            // CRITICAL FIX: Listen for changes in saved reels and refresh counts

            return RefreshIndicator(
              onRefresh: () =>
                  _refreshProfile(authProvider, userProvider, reelProvider),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Profile Header with Enhanced Avatar
                          _buildProfileHeader(userProfile, userProvider),

                          // Subtle Social Stats
                          _buildSocialStats(userProvider, user.uid),

                          // Main Content Stats
                          _buildContentStats(
                              reelProvider, userProvider, user.uid),

                          // // Language Preferences
                          // _buildLanguageSection(userProfile, userProvider),

                          // Content Tabs
                          _buildTabSection(),

                          // Tab Content
                          Container(
                            height: 600,
                            child: _buildTabContent(reelProvider, user.uid),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.1),
      margin: EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // Replace the profile header section in profile_screen.dart with this:

  Widget _buildProfileHeader(dynamic userProfile, UserProvider userProvider) {
    // Extract display name safely
    final displayName = userProfile?['displayName'] as String?;
    final hasDisplayName = displayName != null && displayName.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.aiPrimary.withOpacity(0.1),
            AppColors.backgroundDark,
          ],
        ),
      ),
      child: Column(
        children: [
          // Top Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _showSettingsMenu,
                icon: Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Profile Avatar and Info
          Column(
            children: [
              _buildProfileAvatar(userProfile, userProvider),

              SizedBox(height: 16),

              // Display Name (Primary) - Show if exists
              if (hasDisplayName) ...[
                Text(
                  displayName!,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
              ],

              // Username - Style changes based on whether display name exists
              Text(
                '@${userProfile?['username'] as String? ?? 'user'}',
                style: hasDisplayName
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

              SizedBox(height: 8),

              // Email
              Text(
                userProfile?['email'] as String? ?? 'user@example.com',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              // Bio (if exists)
              if (userProfile?['bio'] != null &&
                  (userProfile?['bio'] as String).trim().isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (userProfile?['bio'] as String).trim(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Enhanced Avatar Widget
  Widget _buildProfileAvatar(dynamic userProfile, UserProvider userProvider) {
    final profileImageUrl = userProfile?['profileImageUrl'] as String?;
    final avatarData = userProfile?['avatarData'] as Map<String, dynamic>?;
    final username = userProfile?['username'] as String? ?? 'User';
    final userId = userProfile?['uid'] as String?;

    return GestureDetector(
      onTap: () => _showAvatarOptions(userProvider, userId ?? ''),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: _buildAvatarContent(profileImageUrl, avatarData, username),
            ),
          ),

          // Edit button overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.backgroundDark, width: 2),
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(
      String? imageUrl, Map<String, dynamic>? avatarData, String username) {
    // 1. Profile image has highest priority
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.aiPrimary, AppColors.primary]),
            ),
            child: Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildTextAvatar(username);
        },
      );
    }

    // 2. Custom avatar data
    if (avatarData != null) {
      if (avatarData['type'] == 'gradient') {
        final colorValues = (avatarData['colors'] as List<dynamic>?)
            ?.map((colorValue) => Color(colorValue as int))
            .toList();
        final iconCode = avatarData['icon'] as int?;

        if (colorValues != null &&
            colorValues.length >= 2 &&
            iconCode != null) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colorValues,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                IconData(iconCode, fontFamily: 'MaterialIcons'),
                color: Colors.white,
                size: 40,
              ),
            ),
          );
        }
      } else if (avatarData['type'] == 'character') {
        final emoji = avatarData['emoji'] as String?;
        if (emoji != null) {
          return Container(
            color: AppColors.surfaceDark,
            child: Center(child: Text(emoji, style: TextStyle(fontSize: 50))),
          );
        }
      }
    }

    // 3. Fallback to text initial
    return _buildTextAvatar(username);
  }

  Widget _buildTextAvatar(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [AppColors.aiPrimary, AppColors.primary]),
      ),
      child: Center(
        child: Text(
          username[0].toUpperCase(),
          style: AppTextStyles.h1.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Avatar Options Modal
  void _showAvatarOptions(UserProvider userProvider, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Picture',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),

            // Camera Option
            _buildAvatarOption(
              icon: Icons.camera_alt,
              title: 'Take Photo',
              subtitle: 'Use camera to capture new photo',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera(userProvider, userId);
              },
            ),

            // Gallery Option
            _buildAvatarOption(
              icon: Icons.photo_library,
              title: 'Choose from Gallery',
              subtitle: 'Select from existing photos',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery(userProvider, userId);
              },
            ),

            // Avatar Selection
            _buildAvatarOption(
              icon: Icons.face,
              title: 'Choose Avatar',
              subtitle: 'Select from preset avatars',
              onTap: () {
                Navigator.pop(context);
                _showAvatarSelection(userProvider, userId);
              },
            ),

            // Remove Photo (if exists)
            Consumer<UserProvider>(
              builder: (context, provider, child) {
                final profile = provider.currentUserProfile;
                final hasProfileImage = profile?['profileImageUrl'] != null;

                if (!hasProfileImage) return SizedBox.shrink();

                return _buildAvatarOption(
                  icon: Icons.delete_outline,
                  title: 'Remove Photo',
                  subtitle: 'Remove current profile picture',
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage(userProvider, userId);
                  },
                  isDestructive: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.primary,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDestructive ? AppColors.error : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // Image Picker Methods
  Future<void> _pickImageFromCamera(
      UserProvider userProvider, String userId) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        await _uploadProfileImage(File(pickedFile.path), userProvider, userId);
      }
    } catch (e) {
      context.showErrorSnackbar('Failed to capture photo. Please try again.');
    }
  }

  Future<void> _pickImageFromGallery(
      UserProvider userProvider, String userId) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        await _uploadProfileImage(File(pickedFile.path), userProvider, userId);
      }
    } catch (e) {
      context.showErrorSnackbar('Failed to select photo. Please try again.');
    }
  }

  // Upload Profile Image
  Future<void> _uploadProfileImage(
      File imageFile, UserProvider userProvider, String userId) async {
    if (_isUploadingImage) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Uploading profile picture...',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Upload to Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_images').child(userId);

      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile
      await userProvider.updateProfileImage(userId, downloadUrl);

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      context.showSuccessSnackbar('Profile picture updated successfully!');
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      context.showErrorSnackbar(
          'Failed to upload profile picture. Please try again.');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // Remove Profile Image
  Future<void> _removeProfileImage(
      UserProvider userProvider, String userId) async {
    try {
      final bool? shouldRemove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Text(
            'Remove Profile Picture',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to remove your profile picture?',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );

      if (shouldRemove == true) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Removing profile picture...',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        );

        try {
          // Delete from Firebase Storage
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child(userId);
          await storageRef.delete();
        } catch (e) {
          // File might not exist, that's okay
        }

        // Update user profile to remove image URL
        await userProvider.updateProfileImage(userId, null);

        // Close loading dialog
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        context.showSuccessSnackbar('Profile picture removed successfully!');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      context.showErrorSnackbar(
          'Failed to remove profile picture. Please try again.');
    }
  }

  // Avatar Selection Screen
  void _showAvatarSelection(UserProvider userProvider, String userId) {
    final List<Map<String, dynamic>> avatarOptions = [
      // Gradient Avatars
      {
        'type': 'gradient',
        'colors': [Color(0xFF667eea), Color(0xFF764ba2)],
        'icon': Icons.person
      },
      {
        'type': 'gradient',
        'colors': [Color(0xFFf093fb), Color(0xFFf5576c)],
        'icon': Icons.favorite
      },
      {
        'type': 'gradient',
        'colors': [Color(0xFF4facfe), Color(0xFF00f2fe)],
        'icon': Icons.star
      },
      {
        'type': 'gradient',
        'colors': [Color(0xFF43e97b), Color(0xFF38f9d7)],
        'icon': Icons.eco
      },
      {
        'type': 'gradient',
        'colors': [Color(0xFFfa709a), Color(0xFFfee140)],
        'icon': Icons.palette
      },
      {
        'type': 'gradient',
        'colors': [Color(0xFFa8edea), Color(0xFFfed6e3)],
        'icon': Icons.wb_sunny
      },

      // Character Avatars
      {'type': 'character', 'emoji': '🦸‍♂️', 'name': 'Hero'},
      {'type': 'character', 'emoji': '🦸‍♀️', 'name': 'Heroine'},
      {'type': 'character', 'emoji': '👨‍🚀', 'name': 'Astronaut'},
      {'type': 'character', 'emoji': '👩‍🎨', 'name': 'Artist'},
      {'type': 'character', 'emoji': '🧙‍♂️', 'name': 'Wizard'},
      {'type': 'character', 'emoji': '🧙‍♀️', 'name': 'Witch'},
      {'type': 'character', 'emoji': '👨‍💻', 'name': 'Developer'},
      {'type': 'character', 'emoji': '👩‍🔬', 'name': 'Scientist'},
      {'type': 'character', 'emoji': '🦁', 'name': 'Lion'},
      {'type': 'character', 'emoji': '🐼', 'name': 'Panda'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Avatar',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Avatar Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: avatarOptions.length,
                itemBuilder: (context, index) {
                  final avatar = avatarOptions[index];
                  return _buildAvatarGridOption(avatar, userProvider, userId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarGridOption(
      Map<String, dynamic> avatar, UserProvider userProvider, String userId) {
    return GestureDetector(
      onTap: () => _selectAvatar(avatar, userProvider, userId),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: avatar['type'] == 'gradient'
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: avatar['colors'],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      avatar['icon'],
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                )
              : Container(
                  color: AppColors.surfaceDark,
                  child: Center(
                    child: Text(
                      avatar['emoji'],
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _selectAvatar(Map<String, dynamic> avatar,
      UserProvider userProvider, String userId) async {
    Navigator.pop(context); // Close avatar selection

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Setting avatar...',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Save avatar data to Firestore
      final avatarData = {
        'type': avatar['type'],
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (avatar['type'] == 'gradient') {
        avatarData['colors'] =
            avatar['colors'].map((color) => color.value).toList();
        avatarData['icon'] = avatar['icon'].codePoint;
      } else if (avatar['type'] == 'character') {
        avatarData['emoji'] = avatar['emoji'];
        avatarData['name'] = avatar['name'];
      }

      // Update user profile with avatar data
      await userProvider.updateAvatarData(userId, avatarData);

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      context.showSuccessSnackbar('Avatar updated successfully!');
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      context.showErrorSnackbar('Failed to update avatar. Please try again.');
    }
  }

  // Rest of your existing methods remain the same...
  Widget _buildLanguageSection(dynamic userProfile, UserProvider userProvider) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language Preferences',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Primary: ${(userProfile?['languagePreferences'] as Map?)?['primaryLanguage'] ?? 'English'}',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Learning: ${((userProfile?['languagePreferences'] as Map?)?['learningLanguages'] as List?)?.join(', ') ?? 'Spanish, French'}',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _showLanguageSettings(),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Update Languages',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TabBar(
          controller: _tabController,
          padding: EdgeInsets.all(4),
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.aiPrimary, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          dividerColor: Colors.transparent,
          isScrollable: false,
          tabs: [
            _buildCompactTab(text: 'My Reels', icon: Icons.video_collection),
            _buildCompactTab(text: 'Saved', icon: Icons.bookmark),
            _buildCompactTab(text: 'Liked', icon: Icons.favorite),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTab({required String text, required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ReelProvider reelProvider, String userId) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildScrollableTab(_buildMyReelsContent(reelProvider.userReels)),
        _buildScrollableTab(_buildSavedReelsContent(reelProvider.savedReels)),
        _buildScrollableTab(_buildLikedReelsContent(reelProvider.likedReels)),
      ],
    );
  }

  Widget _buildScrollableTab(Widget content) {
    return Container(
      child: SingleChildScrollView(
        child: content, // Remove padding from here
      ),
    );
  }

  Widget _buildMyReelsContent(List<AILanguageReel> userReels) {
    if (userReels.isEmpty) {
      return _buildEmptyStateContent(
        icon: Icons.videocam_outlined,
        title: 'No Reels Yet',
        subtitle: 'Create your first AI-powered reel to get started!',
        actionText: 'Create Reel',
        onActionTap: () {
          final mainScreenState =
              context.findAncestorStateOfType<MainScreenState>();
          mainScreenState?.navigateToTab(2);
        },
      );
    }
    return _buildReelsGridContent(userReels);
  }

  Widget _buildSavedReelsContent(List<AILanguageReel> savedReels) {
    if (savedReels.isEmpty) {
      return _buildEmptyStateContent(
        icon: Icons.bookmark_outline,
        title: 'No Saved Reels',
        subtitle: 'Reels you save will appear here',
      );
    }
    return _buildReelsGridContent(savedReels);
  }

  Widget _buildLikedReelsContent(List<AILanguageReel> likedReels) {
    if (likedReels.isEmpty) {
      return _buildEmptyStateContent(
        icon: Icons.favorite_outline,
        title: 'No Liked Reels',
        subtitle: 'Reels you like will appear here',
      );
    }
    return _buildReelsGridContent(likedReels);
  }

  Widget _buildReelsGridContent(List<AILanguageReel> reels) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 320, // Fixed height instead of aspect ratio
        ),
        itemCount: reels.length,
        itemBuilder: (context, index) {
          final reel = reels[index];
          return ReelGridItem(
            reel: reel,
            onTap: () => _openReelViewer(reel, reels, index),
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateContent({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Container(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.grey[400], size: 40),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onActionTap != null) ...[
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: onActionTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(actionText, style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _openReelViewer(
      AILanguageReel reel, List<AILanguageReel> reels, int index) {
    context.showInfoSnackbar('Opening reel viewer...');
  }

  // In profile_screen.dart, update the _refreshProfile method to force refresh everything:

  Future<void> _refreshProfile(
    AuthProvider authProvider,
    UserProvider userProvider,
    ReelProvider reelProvider,
  ) async {
    if (authProvider.userId != null) {
      // print(
      //     '🔍 PROFILE DEBUG: Starting profile refresh for user ${authProvider.userId}');

      // Refresh user profile
      await userProvider.getUserProfile(authProvider.userId!);
      // print('🔍 PROFILE DEBUG: User profile refreshed');

      // Force refresh user counts
      await userProvider.refreshUserCounts(authProvider.userId!);
      // print('🔍 PROFILE DEBUG: User counts refreshed');

      // Reload all reel data
      reelProvider.loadUserReels(authProvider.userId!);
      reelProvider.loadSavedReels(authProvider.userId!);
      reelProvider.loadLikedReels(authProvider.userId!);
      // print('🔍 PROFILE DEBUG: Reel data reloaded');

      // Small delay to let streams update
      await Future.delayed(Duration(milliseconds: 500));
      // print('🔍 PROFILE DEBUG: Profile refresh completed');
    }
  }

// Also add this method to manually refresh saved count when needed:
  void _onSavedTabTapped() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);

    if (authProvider.userId != null) {
      // print('🔍 PROFILE DEBUG: Saved tab tapped - refreshing...');
      userProvider.refreshUserCounts(authProvider.userId!);
      reelProvider.loadSavedReels(authProvider.userId!);
    }
  }

  // Settings Menu and other methods remain exactly the same as your original code...
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            _buildSettingItem(
              icon: Icons.edit,
              title: 'Edit Profile',
              subtitle: 'Update your profile information',
              onTap: _editProfile,
            ),
            _buildSettingItem(
              icon: Icons.language,
              title: 'Language Preferences',
              subtitle: 'Manage your learning languages',
              onTap: _showLanguageSettings,
            ),
            _buildSettingItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: _showHelp,
            ),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version and information',
              onTap: _showAbout,
            ),
            SizedBox(height: 16),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Sign out of your account',
              onTap: _signOut,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDestructive ? AppColors.error : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    Navigator.pop(context); // Close settings modal

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentProfile = authProvider.userProfile;

    // Controllers for text fields
    final displayNameController = TextEditingController(
        text: currentProfile?['displayName'] as String? ?? '');
    final bioController =
        TextEditingController(text: currentProfile?['bio'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Profile',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Display Name Field
              Text(
                'Display Name',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: displayNameController,
                style: TextStyle(color: Colors.white),
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: 'Your display name',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),

              SizedBox(height: 16),

              // Bio Field
              Text(
                'Bio',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: bioController,
                style: TextStyle(color: Colors.white),
                maxLength: 150,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tell us about yourself...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),

              SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newDisplayName = displayNameController.text.trim();
                    final newBio = bioController.text.trim();
                    final userId = authProvider.userId;
                    final username =
                        currentProfile?['username'] as String? ?? 'user';

                    if (userId == null) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: User not logged in'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: AppColors.primary),
                              SizedBox(height: 16),
                              Text(
                                'Updating profile...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    bool profileUpdateSuccess = false;
                    bool reelsUpdateSuccess = false;

                    try {
                      // Step 1: Update profile in Firestore
                      // print('📝 Updating user profile...');
                      final success = await userProvider.updateUserProfile({
                        'displayName':
                            newDisplayName.isEmpty ? null : newDisplayName,
                        'bio': newBio.isEmpty ? null : newBio,
                      });

                      profileUpdateSuccess = success;

                      if (!success) {
                        throw Exception('Profile update returned false');
                      }

                      // print('✅ Profile updated successfully');

                      // Step 2: Update all user's reels with new display name
                      // This is non-critical - don't fail if it doesn't work
                      try {
                        // print('📝 Updating user reels with display name...');
                        await _updateUserReelsWithDisplayName(
                          userId,
                          newDisplayName.isEmpty ? null : newDisplayName,
                          username,
                        );
                        reelsUpdateSuccess = true;
                        // print('✅ Reels updated successfully');
                      } catch (reelError) {
                        // print(
                        //     '⚠️ Reel update failed (non-critical): $reelError');
                        // Continue - profile is still saved
                        reelsUpdateSuccess = false;
                      }

                      // Step 3: Refresh the profile data
                      await authProvider.refreshUserProfile();

                      // Close loading dialog
                      Navigator.pop(context);
                      // Close edit modal
                      Navigator.pop(context);

                      // Show appropriate success message
                      String message = 'Profile updated successfully!';
                      if (profileUpdateSuccess && !reelsUpdateSuccess) {
                        message =
                            'Profile updated! Your reels will sync shortly.';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppColors.primary,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } catch (e) {
                      // print('❌ Profile update error: $e');

                      // Close loading dialog
                      Navigator.pop(context);

                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Failed to update profile. Please try again.'),
                          backgroundColor: AppColors.error,
                          duration: Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () {
                              // Reopen the edit modal
                              Navigator.pop(context);
                              _editProfile();
                            },
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSettings() {
    Navigator.pop(context);
    _showLanguagePreferencesDialog();
  }

  void _showLanguagePreferencesDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentPrefs = authProvider.userProfile?['languagePreferences']
            as Map<String, dynamic>? ??
        {
          'primaryLanguage': 'en',
          'learningLanguages': ['es', 'fr']
        };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Language Preferences',
            style: AppTextStyles.h4.copyWith(color: Colors.white)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Primary Language (for subtitles):',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: currentPrefs['primaryLanguage'] as String? ?? 'en',
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceDark,
                  underline: SizedBox.shrink(),
                  style: TextStyle(color: Colors.white),
                  items: SupportedLanguages.languageEntries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Row(children: [
                        Text(SupportedLanguages.getLanguageFlag(entry.key)),
                        SizedBox(width: 8),
                        Text(entry.value.name)
                      ]),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary)));
                      try {
                        final newPrefs =
                            Map<String, dynamic>.from(currentPrefs);
                        newPrefs['primaryLanguage'] = value;
                        await userProvider.updateLanguagePreferences(newPrefs);
                        await authProvider.refreshUserProfile();
                        await Future.delayed(Duration(milliseconds: 300));
                        if (mounted) Navigator.pop(context);
                        if (mounted) Navigator.pop(context);
                        if (mounted)
                          context.showSuccessSnackbar(
                              'Subtitles will now show in ${SupportedLanguages.getLanguageName(value)}');
                      } catch (e) {
                        if (mounted) Navigator.pop(context);
                        if (mounted)
                          context
                              .showErrorSnackbar('Failed to update language');
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Colors.grey[400])))
        ],
      ),
    );
  }

  // Add this method to _ProfileScreenState class
  Future<void> _updateUserReelsWithDisplayName(
    String userId,
    String? displayName,
    String username,
  ) async {
    try {
      // print(
      //     '📝 Starting reel update: displayName=$displayName for user=$userId');

      // Get all reels by this user
      final reelsSnapshot = await FirebaseFirestore.instance
          .collection('reels')
          .where('authorId', isEqualTo: userId)
          .get();

      if (reelsSnapshot.docs.isEmpty) {
        // print('ℹ️ No reels found for user $userId');
        return;
      }

      // print('📊 Found ${reelsSnapshot.docs.length} reels to update');

      // Batch update all reels (Firebase supports up to 500 operations per batch)
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in reelsSnapshot.docs) {
        batch.update(doc.reference, {
          'authorDisplayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit all updates at once
      await batch.commit();

      // print(
      //     '✅ Successfully updated ${reelsSnapshot.docs.length} reels with display name');
    } catch (e) {
      // print('⚠️ Error updating reels with display name: $e');
      // Don't throw - profile update should succeed even if reel update fails
      // The display name is still saved in the user profile
    }
  }

  void _showHelp() {
    Navigator.pop(context); // Close settings modal

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Help & Support',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Help Options
            Expanded(
              child: ListView(
                children: [
                  _buildHelpItem(
                    icon: Icons.quiz_outlined,
                    title: 'FAQs',
                    subtitle: 'Find answers to common questions',
                    onTap: () => _showFAQs(),
                  ),
                  _buildHelpItem(
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Support',
                    subtitle: 'Get help from our support team',
                    onTap: () => _contactSupport(),
                  ),
                  _buildHelpItem(
                    icon: Icons.bug_report_outlined,
                    title: 'Report a Bug',
                    subtitle: 'Help us improve the app',
                    onTap: () => _reportBug(),
                  ),
                  _buildHelpItem(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Share your thoughts and suggestions',
                    onTap: () => _sendFeedback(),
                  ),
                  _buildHelpItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    subtitle: 'Read our terms and conditions',
                    onTap: () => _showTerms(),
                  ),
                  _buildHelpItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Learn how we protect your data',
                    onTap: () => _showPrivacy(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ADD THIS HELPER METHOD (place it after _showHelp):
  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.aiPrimary, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'About LangReels AI',
              style: AppTextStyles.h4.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: ${AppConstants.appVersion}',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              AppConstants.appDescription,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            Text(
              'AI-powered language learning platform that makes your content accessible worldwide through automatic transcription, translation, and moderation.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  void _showFAQs() {
    Navigator.pop(context);

    final faqs = [
      {
        'question': 'How do I create a language reel?',
        'answer':
            'Tap the + button at the bottom of the screen, record or upload a video, and our AI will automatically transcribe and translate it into multiple languages.'
      },
      {
        'question': 'Which languages are supported?',
        'answer':
            'We support 15 languages including English, Spanish, French, German, Italian, Portuguese, Russian, Japanese, Korean, Chinese, Arabic, Hindi, Turkish, Dutch, and Polish.'
      },
      {
        'question': 'How does the AI translation work?',
        'answer':
            'Our AI uses advanced speech recognition to transcribe your video, then translates the content into your selected learning languages with timing information for subtitles.'
      },
      {
        'question': 'Can I edit my reels after uploading?',
        'answer':
            'Currently, you cannot edit reels after processing. We recommend reviewing your content before uploading.'
      },
      {
        'question': 'How do I save reels for later?',
        'answer':
            'Tap the bookmark icon on any reel to save it. Access your saved reels from your profile page under the "Saved" tab.'
      },
      {
        'question': 'What video formats are supported?',
        'answer':
            'We support MP4, MOV, and AVI formats. Maximum video length is 2 minutes and file size should be under 100MB for best results.'
      },
      {
        'question': 'How long does AI processing take?',
        'answer':
            'Processing typically takes 2-3 minutes depending on video length. You\'ll receive a notification when your reel is ready.'
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Frequently Asked Questions',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          faq['question']!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              faq['answer']!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[400],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        iconColor: AppColors.primary,
                        collapsedIconColor: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // METHOD 1: Contact Support
  void _contactSupport() {
    Navigator.pop(context);

    final emailController = TextEditingController();
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact Support',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text(
                'Email',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'your.email@example.com',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Message',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: messageController,
                style: TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe your issue or question...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement email sending logic
                    // You can integrate with Firebase Functions or email service
                    Navigator.pop(context);
                    context.showSuccessSnackbar(
                        'Support request sent! We\'ll get back to you soon.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Send Message',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// METHOD 2: Report Bug
  void _reportBug() {
    Navigator.pop(context);

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report a Bug',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text(
                'Bug Title',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: titleController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Brief description of the issue',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Description',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                style: TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'What happened? Steps to reproduce...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      context.showErrorSnackbar('Please fill in all fields');
                      return;
                    }
                    _submitBugReport(
                        titleController.text, descriptionController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit Report',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendFeedback() {
    Navigator.pop(context);

    final feedbackController = TextEditingController();
    String selectedCategory = 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Send Feedback',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  'Category',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceDark,
                      style: TextStyle(color: Colors.white),
                      items: [
                        'General',
                        'Feature Request',
                        'UI/UX',
                        'Performance',
                        'Translation Quality',
                        'Other'
                      ]
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedCategory = value!);
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Your Feedback',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: feedbackController,
                  style: TextStyle(color: Colors.white),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts and suggestions...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (feedbackController.text.isEmpty) {
                        context.showErrorSnackbar('Please enter your feedback');
                        return;
                      }
                      _submitFeedback(
                          selectedCategory, feedbackController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Submit Feedback',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ADD these methods to the _ProfileScreenState class in profile_screen.dart

  Future<void> _submitBugReport(
    String title,
    String description,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await FirebaseFirestore.instance.collection('bug_reports').add({
        'title': title,
        'description': description,
        'userId': authProvider.userId,
        'userEmail': authProvider.userProfile?['email'],
        'userName': authProvider.userProfile?['username'] ??
            authProvider.userProfile?['displayName'] ??
            'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open',
        'appVersion': '1.0.0',
        'platform': Platform.operatingSystem,
      });

      Navigator.pop(context);
      context.showSuccessSnackbar(
          'Bug report submitted. Thank you for helping us improve!');
    } catch (e) {
      print('Error submitting bug report: $e');
      context.showErrorSnackbar('Failed to submit bug report');
    }
  }

  Future<void> _submitFeedback(
    String category,
    String message,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await FirebaseFirestore.instance.collection('feedback').add({
        'category': category,
        'message': message,
        'userId': authProvider.userId,
        'userEmail': authProvider.userProfile?['email'],
        'userName': authProvider.userProfile?['username'] ??
            authProvider.userProfile?['displayName'] ??
            'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      Navigator.pop(context);
      context.showSuccessSnackbar('Feedback sent. Thank you!');
    } catch (e) {
      print('Error submitting feedback: $e');
      context.showErrorSnackbar('Failed to send feedback');
    }
  }

  // METHOD 1: Show Terms
  void _showTerms() {
    Navigator.pop(context);
    _showLegalDocument('Terms of Service', _getTermsContent());
  }

// METHOD 2: Show Privacy
  void _showPrivacy() {
    Navigator.pop(context);
    _showLegalDocument('Privacy Policy', _getPrivacyContent());
  }

// METHOD 3: Generic Legal Document Display
  void _showLegalDocument(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[300],
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// METHOD 4: Terms Content
  String _getTermsContent() {
    return '''
Last Updated: September 29, 2025

1. ACCEPTANCE OF TERMS
By accessing and using LangReels AI, you accept and agree to be bound by the terms and provision of this agreement.

2. USE LICENSE
Permission is granted to temporarily use LangReels AI for personal, non-commercial purposes. This is the grant of a license, not a transfer of title.

3. USER CONTENT
You retain all rights to the content you upload to LangReels AI. By uploading content, you grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, and display your content for the purpose of providing our services.

4. AI PROCESSING
Our AI services automatically process your video content to provide transcription and translation features. By using these services, you consent to this processing.

5. PROHIBITED USES
You may not use LangReels AI to:
• Upload illegal, harmful, or offensive content
• Violate any applicable laws or regulations
• Infringe on intellectual property rights
• Attempt to breach our security measures
• Upload content containing hate speech or violence

6. ACCOUNT TERMINATION
We reserve the right to terminate or suspend your account at our sole discretion, without notice, for conduct that we believe violates these Terms of Service.

7. DISCLAIMER
LangReels AI is provided "as is" without any warranties, expressed or implied. We do not guarantee the accuracy of AI translations or transcriptions.

8. LIMITATION OF LIABILITY
In no event shall LangReels AI be liable for any damages arising out of the use or inability to use our services.

9. INTELLECTUAL PROPERTY
All trademarks, service marks, and logos used on our platform are the property of their respective owners.

10. MODIFICATIONS
We reserve the right to modify these terms at any time. Continued use of the service constitutes acceptance of modified terms.

11. GOVERNING LAW
These terms shall be governed by and construed in accordance with applicable laws.

12. CONTACT
For questions about these Terms, contact us at support@langreels.ai
''';
  }

// METHOD 5: Privacy Policy Content
  String _getPrivacyContent() {
    return '''
Last Updated: September 29, 2025

1. INTRODUCTION
LangReels AI ("we", "our", or "us") respects your privacy and is committed to protecting your personal data.

2. DATA WE COLLECT
• Account Information: Username, email address, profile information
• Content: Videos, audio recordings, and text you upload
• Usage Data: How you interact with our services
• Device Information: Device type, operating system, app version
• Analytics: App performance and usage patterns

3. HOW WE USE YOUR DATA
• To provide and improve our AI language learning services
• To process your video content for transcription and translation
• To communicate with you about our services
• To ensure security and prevent fraud
• To personalize your learning experience

4. AI PROCESSING
Your video and audio content is processed by our AI systems including:
• OpenAI Whisper for transcription
• Google Translate for multi-language translation
• Content moderation systems for safety

5. DATA SHARING
We do not sell your personal data. We may share data with:
• Service providers who help us operate our platform
• AI processing services (OpenAI, Google Cloud)
• Law enforcement if required by law

6. DATA SECURITY
We implement industry-standard security measures to protect your data, including:
• Encryption of data in transit and at rest
• Secure cloud storage with Firebase
• Regular security audits
• Access controls and authentication

7. YOUR RIGHTS
You have the right to:
• Access your personal data
• Correct inaccurate data
• Delete your account and data
• Export your data
• Opt-out of certain data processing

8. DATA RETENTION
We retain your data for as long as your account is active or as needed to provide services. You can request deletion at any time.

9. CHILDREN'S PRIVACY
Our service is not intended for users under 13 years of age. We do not knowingly collect data from children.

10. COOKIES AND TRACKING
We use cookies and similar technologies to improve your experience and analyze usage patterns.

11. INTERNATIONAL DATA TRANSFERS
Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place.

12. CHANGES TO PRIVACY POLICY
We may update this policy from time to time. We will notify you of significant changes.

13. CONTACT US
For privacy concerns or data requests:
Email: privacy@langreels.ai
''';
  }

  void _signOut() async {
    Navigator.pop(context);

    final confirmed = await context.showConfirmationDialog(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      confirmColor: AppColors.error,
    );

    if (confirmed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signOut();

      if (success) {
        context.showSuccessSnackbar('Signed out successfully');
      } else {
        context.showErrorSnackbar('Failed to sign out');
      }
    }
  }

  // ADD these methods to the bottom of your _ProfileScreenState class (before the final closing brace):

  Widget _buildSocialStats(UserProvider userProvider, String userId) {
    final followingCount = userProvider.getUserCounts(userId)['following'] ?? 0;
    final followersCount = userProvider.getUserCounts(userId)['followers'] ?? 0;

    // Only show if user has social activity (following or followers > 0)
    if (followingCount == 0 && followersCount == 0) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (followingCount > 0) ...[
            _buildSocialStatChip(
              '$followingCount following',
              Icons.person_add_outlined,
              Colors.grey[400]!,
              () => _showFollowingList(userId),
            ),
            if (followersCount > 0) SizedBox(width: 16),
          ],
          if (followersCount > 0) ...[
            _buildSocialStatChip(
              '$followersCount followers',
              Icons.people_outlined,
              Colors.grey[400]!,
              () => _showFollowersList(userId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialStatChip(
      String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 6),
            Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStats(
      ReelProvider reelProvider, UserProvider userProvider, String userId) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
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
              _buildContentStatItem(
                'Reels Created',
                reelProvider.userReels.length,
                Icons.videocam,
                AppColors.primary,
                // 'Videos you\'ve shared',
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withOpacity(0.1),
                margin: EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildContentStatItem(
                'Reels Saved',
                reelProvider.savedReels.length,
                Icons.bookmark,
                AppColors.save,
                // 'Videos you\'ve bookmarked',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentStatItem(
      String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 12),
          Text(
            count.toString(),
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // REPLACE the two placeholder methods at the bottom of your profile_screen.dart with these:

  void _showFollowingList(String userId) {
    _showUserListModal(
      title: 'Following',
      listType: 'following',
      userId: userId,
    );
  }

  void _showFollowersList(String userId) {
    _showUserListModal(
      title: 'Followers',
      listType: 'followers',
      userId: userId,
    );
  }

// ADD these new methods after the above two:

  void _showUserListModal({
    required String title,
    required String listType,
    required String userId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // User List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadUserList(userId, listType),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.grey[400], size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Error loading $title',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }

                  final users = snapshot.data ?? [];

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            listType == 'following'
                                ? Icons.person_add_outlined
                                : Icons.people_outlined,
                            color: Colors.grey[400],
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No $title yet',
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            listType == 'following'
                                ? 'Follow other language learners to see their content'
                                : 'Other users haven\'t followed you yet',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.grey[400]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(20),
                    itemCount: users.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserListItem(user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? 'Unknown';
    final displayName = user['displayName'] as String?;
    final profileImageUrl = user['profileImageUrl'] as String?;
    final bio = user['bio'] as String?;
    final userId = user['uid'] as String?;
    final isCurrentUser =
        user['uid'] == Provider.of<AuthProvider>(context, listen: false).userId;

    // Determine what name to show
    final nameToShow =
        displayName?.isNotEmpty == true ? displayName! : '@$username';
    final shouldShowUsername = displayName?.isNotEmpty == true;

    return GestureDetector(
      onTap: () {
        // Close the modal first
        Navigator.pop(context);

        if (isCurrentUser) {
          // Already on own profile, do nothing
          return;
        } else if (userId != null) {
          // Navigate to other user's profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(
                userId: userId,
                username: username,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.aiPrimary,
              ),
              child: profileImageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackAvatarForList(username),
                      ),
                    )
                  : _buildFallbackAvatarForList(username),
            ),

            SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name or username
                  Text(
                    nameToShow,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Username if display name exists
                  if (shouldShowUsername) ...[
                    SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  // Bio
                  if (bio != null && bio.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      bio,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Action Button (if not current user)
            if (!isCurrentUser) ...[
              SizedBox(width: 12),
              Consumer<UserProvider>(
                builder: (context, userProvider, child) => FutureBuilder<bool>(
                  future: userProvider.isFollowing(user['uid']),
                  builder: (context, snapshot) {
                    final isFollowing = snapshot.data ?? false;

                    return ElevatedButton(
                      onPressed: () => _toggleFollow(user['uid'], isFollowing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFollowing ? Colors.grey[700] : AppColors.primary,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size(80, 36),
                      ),
                      child: Text(
                        isFollowing ? 'Unfollow' : 'Follow',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatarForList(String username) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(colors: [AppColors.aiPrimary, AppColors.primary]),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadUserList(
      String userId, String listType) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (listType == 'followers') {
        return await userProvider.getFollowersList(userId);
      } else if (listType == 'following') {
        return await userProvider.getFollowingList(userId);
      }

      return [];
    } catch (e) {
      // print('Error loading $listType: $e');
      return [];
    }
  }

  Future<void> _toggleFollow(String userId, bool isFollowing) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      bool success;
      if (isFollowing) {
        success = await userProvider.unfollowUser(userId);
      } else {
        success = await userProvider.followUser(userId);
      }

      if (success) {
        // Refresh the modal content
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating follow status')),
      );
    }
  }
}
