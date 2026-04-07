// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/app_constants.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider? _authProvider;
  Map<String, dynamic>? _currentUserProfile;
  Map<String, Map<String, int>> _userCounts = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    _currentUserProfile = authProvider.userProfile;

    // Load counts when auth is updated
    if (authProvider.userId != null) {
      loadUserCounts(authProvider.userId!);
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      _isLoading = true;
      // REMOVED: notifyListeners() here - don't notify during async operation start

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final userData = doc.data();
        if (_authProvider?.userId == userId) {
          _currentUserProfile = userData;
        }

        // Also load counts
        await loadUserCounts(userId);

        _isLoading = false;
        notifyListeners(); // MOVED: Only notify after all data is loaded
        return userData;
      }

      _isLoading = false;
      notifyListeners(); // MOVED: Only notify after operation completes
      return null;
    } catch (e) {
      _errorMessage = 'Failed to load user profile: $e';
      _isLoading = false;
      notifyListeners(); // MOVED: Only notify after operation completes
      return null;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final userId = _authProvider?.userId;
      if (userId == null) return false;

      _isLoading = true;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update(profileData);

      // Update local profile
      _currentUserProfile = {...?_currentUserProfile, ...profileData};

      // Refresh AuthProvider profile data
      if (_authProvider != null) {
        await _authProvider!.refreshUserProfile();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLanguagePreferences(
      Map<String, dynamic> preferences) async {
    try {
      final userId = _authProvider?.userId;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'languagePreferences': preferences,
      });

      // Update local profile
      if (_currentUserProfile != null) {
        _currentUserProfile!['languagePreferences'] = preferences;
      }

      // Refresh AuthProvider profile data
      if (_authProvider != null) {
        await _authProvider!.refreshUserProfile();
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update language preferences: $e';
    }
  }

  Map<String, int> getUserCounts(String userId) {
    // Return cached counts or trigger a fresh load
    if (_userCounts[userId] == null) {
      loadUserCounts(userId); // Load in background
      return {
        'reels': 0,
        'saved': 0,
        'followers': 0,
        'following': 0, // ADD THIS
      };
    }

    return _userCounts[userId]!;
  }

  Future<void> loadUserCounts(String userId) async {
    try {
      // Use the FirebaseService method you already have
      final counts = await FirebaseService.getUserCounts(userId);
      _userCounts[userId] = counts;
      notifyListeners();
    } catch (e) {
      _userCounts[userId] = {
        'reels': 0,
        'saved': 0,
        'followers': 0,
      };
      notifyListeners();
    }
  }

  // Method to manually refresh counts (called after reel creation, etc.)
  Future<void> refreshUserCounts(String userId) async {
    await loadUserCounts(userId);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearData() {
    _currentUserProfile = null;
    _userCounts.clear();
    _errorMessage = null;
    notifyListeners();
  }

  // AVATAR FUNCTIONALITY

  // Update profile image
  Future<void> updateProfileImage(String userId, String? imageUrl) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'profileImageUrl': imageUrl,
        'avatarData': null, // Clear custom avatar when setting image
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updates);

      // Update local profile if it's the current user
      if (_authProvider?.userId == userId && _currentUserProfile != null) {
        _currentUserProfile = {
          ..._currentUserProfile!,
          ...updates,
        };
      }

      // CRITICAL: Refresh AuthProvider profile data so UI updates immediately
      if (_authProvider != null) {
        await _authProvider!.refreshUserProfile();
      }
    } catch (e) {
      _errorMessage = 'Failed to update profile image: $e';

      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update avatar data
  Future<void> updateAvatarData(
      String userId, Map<String, dynamic> avatarData) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'avatarData': avatarData,
        'profileImageUrl': null, // Clear image when setting custom avatar
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updates);

      // Update local profile if it's the current user
      if (_authProvider?.userId == userId && _currentUserProfile != null) {
        _currentUserProfile = {
          ..._currentUserProfile!,
          ...updates,
        };
      }

      // CRITICAL: Refresh AuthProvider profile data so UI updates immediately
      if (_authProvider != null) {
        await _authProvider!.refreshUserProfile();
      }
    } catch (e) {
      _errorMessage = 'Failed to update avatar data: $e';

      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get avatar widget - works with your existing data structure
  Widget getAvatarWidget(String userId, {double size = 50}) {
    // For current user, use cached profile
    Map<String, dynamic>? userProfile;
    if (_authProvider?.userId == userId) {
      userProfile = _currentUserProfile;
    }

    // If no cached data, this will return fallback
    final profileImageUrl = userProfile?['profileImageUrl'] as String?;
    final avatarData = userProfile?['avatarData'] as Map<String, dynamic>?;
    final username = userProfile?['username'] as String? ?? 'U';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25 - 1),
        child: _buildAvatarContent(profileImageUrl, avatarData, username, size),
      ),
    );
  }

  Widget _buildAvatarContent(
    String? profileImageUrl,
    Map<String, dynamic>? avatarData,
    String username,
    double size,
  ) {
    // 1. Profile image has highest priority
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return Image.network(
        profileImageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.aiPrimary, AppColors.primary],
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAvatar(username, size);
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
                size: size * 0.4,
              ),
            ),
          );
        }
      } else if (avatarData['type'] == 'character') {
        final emoji = avatarData['emoji'] as String?;
        if (emoji != null) {
          return Container(
            color: AppColors.surfaceDark,
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
          );
        }
      }
    }

    // 3. Fallback to initial
    return _buildFallbackAvatar(username, size);
  }

  Widget _buildFallbackAvatar(String username, double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.aiPrimary, AppColors.primary],
        ),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ADD these methods to lib/providers/user_provider.dart (replace existing follow methods):

  /// ===== FOLLOW/UNFOLLOW FUNCTIONALITY =====

// Follow a user
  Future<bool> followUser(String userToFollowId) async {
    try {
      final success = await FirebaseService.followUser(userToFollowId);
      if (success) {
        // Refresh both users' counts
        await loadUserCounts(_authProvider!.userId!);
        await loadUserCounts(userToFollowId);

        // Refresh auth provider profile to get updated following list
        if (_authProvider != null) {
          await _authProvider!.refreshUserProfile();
        }

        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to follow user: $e';
      notifyListeners();
      return false;
    }
  }

// Unfollow a user
  Future<bool> unfollowUser(String userToUnfollowId) async {
    try {
      final success = await FirebaseService.unfollowUser(userToUnfollowId);
      if (success) {
        // Refresh both users' counts
        await loadUserCounts(_authProvider!.userId!);
        await loadUserCounts(userToUnfollowId);

        // Refresh auth provider profile to get updated following list
        if (_authProvider != null) {
          await _authProvider!.refreshUserProfile();
        }

        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to unfollow user: $e';
      notifyListeners();
      return false;
    }
  }

// Check if current user is following another user
  Future<bool> isFollowing(String userId) async {
    try {
      return await FirebaseService.isFollowing(userId);
    } catch (e) {
      return false;
    }
  }

// Get followers list
  Future<List<Map<String, dynamic>>> getFollowersList(String userId) async {
    try {
      return await FirebaseService.getFollowersList(userId);
    } catch (e) {
      _errorMessage = 'Failed to load followers: $e';
      notifyListeners();
      return [];
    }
  }

// Get following list
  Future<List<Map<String, dynamic>>> getFollowingList(String userId) async {
    try {
      return await FirebaseService.getFollowingList(userId);
    } catch (e) {
      _errorMessage = 'Failed to load following: $e';
      notifyListeners();
      return [];
    }
  }
}
