// lib/services/firebase_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_language_reel.dart';
import '../models/user_profile.dart';
import '../models/sentence_data.dart';
import '../constants/app_constants.dart';
import '../utils/app_utils.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Uuid _uuid = Uuid();

  // Collections
  static const String _reelsCollection = 'reels';
  static const String _usersCollection = 'users';
  static const String _commentsCollection = 'comments';
  static const String _translationsCollection = 'translations';
  static const String _usageMetricsCollection = 'usage_metrics';

  // Current user helpers
  static String? get currentUserId => _auth.currentUser?.uid;
  static User? get currentUser => _auth.currentUser;

  /// ===== REEL MANAGEMENT =====

  // Create initial reel when video is uploaded (AI processing starts)
  static Future<String?> createInitialReel({
    required String videoUrl,
    required String authorId,
    required String authorName,
    String? authorDisplayName, // NEW parameter
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.getIdToken(true); // Force refresh
      }
      // Extract reel ID using the EXACT same logic as Cloud Functions
      final reelId = _extractReelIdFromVideoUrl(videoUrl);

      if (reelId == null) {
        return null;
      }

      final reel = AILanguageReel(
        id: reelId,
        authorId: authorId,
        authorName: authorName,
        authorDisplayName: authorDisplayName, // NEW: Include display name
        authorAvatar: AppUtils.generateAvatar(authorName),
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.uploading,
      );

      await _firestore
          .collection(_reelsCollection)
          .doc(reelId)
          .set(reel.toMap());

      return reelId;
    } catch (e) {
      return null;
    }
  }

  // Add this helper method - MATCHES your Cloud Functions getReelIdFromPath() logic
  static String? _extractReelIdFromVideoUrl(String videoUrl) {
    try {
      String filePath = '';

      if (videoUrl.startsWith('gs://')) {
        // gs:// format: gs://bucket/videos/reels/userId/reel_uuid.mp4
        final uri = Uri.parse(videoUrl);
        filePath = uri.pathSegments.skip(1).join('/'); // Skip bucket name
      } else if (videoUrl.contains('firebasestorage') &&
          videoUrl.contains('/o/')) {
        // Firebase download URL format:
        // https://firebasestorage.googleapis.com/v0/b/bucket/o/videos%2Freels%2FuserId%2Freel_uuid.mp4?alt=media&token=...

        // Extract the part between '/o/' and '?alt='
        final startIndex = videoUrl.indexOf('/o/') + 3;
        final endIndex = videoUrl.indexOf('?alt=');

        if (startIndex > 2 && endIndex > startIndex) {
          final encodedPath = videoUrl.substring(startIndex, endIndex);
          filePath = Uri.decodeComponent(encodedPath);
          // print('🔍 Decoded path from URL: $filePath');
        }
      }

      // print('🔍 Final extracted file path: $filePath');

      // Apply the EXACT same logic as Cloud Functions getReelIdFromPath()
      final pathParts = filePath.split('/');

      if (filePath.startsWith('videos/reels/') && pathParts.length >= 4) {
        // Handle: videos/reels/{userId}/reel_{UUID}.mp4
        final fileName = pathParts.last; // Get last segment
        final cleanFileName = fileName.replaceAll('.mp4', '');

        if (cleanFileName.startsWith('reel_')) {
          final extractedId =
              cleanFileName.substring(5); // Remove "reel_" prefix
          // print('✅ Extracted reel ID: $extractedId');
          return extractedId;
        }
      }

      // print('❌ Could not extract reel ID from path: $filePath');
      return null;
    } catch (e) {
      // print('❌ Error extracting reel ID from URL: $e');
      return null;
    }
  }

  // Get all processed reels for home feed
  static Stream<List<AILanguageReel>> getProcessedReelsStream({
    int limit = AppConstants.reelsPerPage,
    String? languageFilter,
    String? difficultyFilter,
    String? categoryFilter,
  }) {
    Query query = _firestore
        .collection(_reelsCollection)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true);

    // Apply filters - FIXED: Use sourceLanguage instead of originalLanguage
    if (languageFilter != null && languageFilter != 'all') {
      query = query.where('sourceLanguage', isEqualTo: languageFilter);
    }

    if (difficultyFilter != null && difficultyFilter != 'all') {
      query = query.where('difficulty', isEqualTo: difficultyFilter);
    }

    if (categoryFilter != null && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AILanguageReel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Multi-select language filtering method with proper error handling
  static Stream<List<AILanguageReel>> getProcessedReelsStreamWithLanguages({
    int limit = AppConstants.reelsPerPage,
    List<String>? languageFilters,
    String? difficultyFilter,
    String? categoryFilter,
    bool populateSentences = true,
  }) {
    Query query = _firestore
        .collection(_reelsCollection)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true);

    // Apply language filters
    if (languageFilters != null &&
        languageFilters.isNotEmpty &&
        !languageFilters.contains('all')) {
      // For single language, use server-side filtering
      if (languageFilters.length == 1) {
        query = query.where('sourceLanguage', isEqualTo: languageFilters.first);
      }
      // For multiple languages, we'll filter client-side after fetching
    }

    if (difficultyFilter != null && difficultyFilter != 'all') {
      query = query.where('difficulty', isEqualTo: difficultyFilter);
    }

    if (categoryFilter != null && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit * 2) // Fetch more to account for client-side filtering
        .snapshots()
        .asyncMap((snapshot) async {
      List<AILanguageReel> reels = snapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Client-side filtering for multiple languages
      if (languageFilters != null &&
          languageFilters.isNotEmpty &&
          !languageFilters.contains('all') &&
          languageFilters.length > 1) {
        reels = reels.where((reel) {
          final reelLanguage = reel.sourceLanguage ?? '';
          return languageFilters.contains(reelLanguage);
        }).toList();
      }

      // Limit results after filtering
      if (reels.length > limit) {
        reels = reels.take(limit).toList();
      }

      // Populate sentence data if requested
      if (populateSentences) {
        final populatedReels = <AILanguageReel>[];

        for (final reel in reels) {
          if (reel.hasSentenceData && reel.totalSentences > 0) {
            try {
              // CRITICAL FIX: Wrap in try-catch to handle permission errors gracefully
              final populatedReel = await populateReelWithSentences(reel);
              populatedReels.add(populatedReel);
            } catch (e) {
              // If sentence population fails (e.g., permission error),
              // just return the reel without sentences rather than failing the entire stream
              // print('⚠️ Failed to populate sentences for ${reel.id}: $e');
              populatedReels.add(reel);
            }
          } else {
            populatedReels.add(reel);
          }
        }

        return populatedReels;
      }

      return reels;
    }).handleError((error) {
      // CRITICAL FIX: Catch errors at stream level
      // Log but don't propagate to prevent stream termination
      // print('⚠️ Stream error (continuing): $error');
      return <AILanguageReel>[]; // Return empty list to keep stream alive
    });
  }

  // Replace the searchReelsWithLanguages method in your FirebaseService class

  static Future<List<AILanguageReel>> searchReelsWithLanguages({
    required String query,
    List<String>? sourceLanguages,
    int limit = 50,
  }) async {
    try {
      Query reelsQuery = _firestore
          .collection(_reelsCollection)
          .where('isProcessed', isEqualTo: true)
          .where('passedModeration', isEqualTo: true);

      final reelsSnapshot = await reelsQuery
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      List<AILanguageReel> allReels = reelsSnapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filter by languages
      if (sourceLanguages != null &&
          sourceLanguages.isNotEmpty &&
          !sourceLanguages.contains('all')) {
        allReels = allReels.where((reel) {
          final reelLanguage = reel.sourceLanguage ?? '';
          return sourceLanguages.contains(reelLanguage);
        }).toList();
      }

      final searchResults = <AILanguageReel>[];
      final queryLower = query.toLowerCase();

      for (int i = 0; i < allReels.length; i++) {
        final reel = allReels[i];
        final reelDoc = reelsSnapshot.docs[i];
        bool matches = false;

        // Check original text
        if (reel.originalText?.toLowerCase().contains(queryLower) ?? false) {
          matches = true;
        }

        // Check translations in separate document
        if (!matches) {
          final docData = reelDoc.data() as Map<String, dynamic>;
          final translationsDocPath = docData['translationsDocPath'] as String?;

          if (translationsDocPath != null) {
            try {
              final translationsDoc =
                  await _firestore.doc(translationsDocPath).get();

              if (translationsDoc.exists) {
                final translationsData =
                    translationsDoc.data() as Map<String, dynamic>;

                if (translationsData['sentences'] != null) {
                  final sentences =
                      translationsData['sentences'] as List<dynamic>;

                  for (final sentenceData in sentences) {
                    final sentenceMap = sentenceData as Map<String, dynamic>;
                    final translations =
                        sentenceMap['translations'] as Map<String, dynamic>?;

                    if (translations != null) {
                      for (final translation in translations.values) {
                        if (translation
                            .toString()
                            .toLowerCase()
                            .contains(queryLower)) {
                          matches = true;
                          break;
                        }
                      }
                      if (matches) break;
                    }
                  }
                }
              }
            } catch (e) {
              // Continue without translation search for this reel
            }
          }
        }

        if (matches) {
          searchResults.add(reel);
        }

        if (searchResults.length >= limit) break;
      }

      return searchResults;
    } catch (e) {
      return [];
    }
  }

  // Watch processing status for a specific reel
  static Stream<AILanguageReel?> watchReelProcessingStatus(String reelId) {
    return _firestore.collection(_reelsCollection).doc(reelId).snapshots().map(
        (doc) => doc.exists
            ? AILanguageReel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
            : null);
  }

  // Get user's reels (both processed and processing)
  static Stream<List<AILanguageReel>> getUserReelsStream(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection(_reelsCollection)
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AILanguageReel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get saved/bookmarked reels for a user
  // Replace the getSavedReelsStream method in firebase_service.dart with this fixed version:

// Get saved/bookmarked reels for a user - FIXED VERSION
  // Get saved/bookmarked reels for a user - WITH SENTENCES
  static Stream<List<AILanguageReel>> getSavedReelsStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      try {
        if (!userDoc.exists) {
          // print('❌ User document does not exist');
          return <AILanguageReel>[];
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final savedReelIds = List<String>.from(userData['savedReels'] ?? []);

        // print('📊 Found ${savedReelIds.length} saved reel IDs: $savedReelIds');

        if (savedReelIds.isEmpty) return <AILanguageReel>[];

        List<AILanguageReel> reels = [];

        for (String reelId in savedReelIds) {
          // print('🔍 Fetching reel: $reelId');
          final reel = await getReelByIdWithSentences(reelId);
          if (reel != null) {
            // print(
            //     '✅ Reel loaded: ${reel.id}, hasText: ${reel.originalText != null}, sentences: ${reel.sentences?.length ?? 0}');
            reels.add(reel);
          } else {
            // print('❌ Reel not found: $reelId');
          }
        }

        reels.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // print('📦 Returning ${reels.length} saved reels');
        return reels;
      } catch (e) {
        // print('❌ Error loading saved reels: $e');
        return <AILanguageReel>[];
      }
    });
  }

  // Get liked reels stream
  static Stream<List<AILanguageReel>> getLikedReelsStream(String userId) {
    return _firestore
        .collection(_reelsCollection)
        .where('likedBy', arrayContains: userId)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        List<AILanguageReel> reels = [];

        for (var doc in snapshot.docs) {
          // Use the method that populates sentences
          final reel = await getReelByIdWithSentences(doc.id);
          if (reel != null) {
            reels.add(reel);
          }
        }

        return reels;
      } catch (e) {
        // print('Error loading liked reels: $e');
        return <AILanguageReel>[];
      }
    });
  }

  // Get reel by ID
  static Future<AILanguageReel?> getReelById(String reelId) async {
    try {
      final doc =
          await _firestore.collection(_reelsCollection).doc(reelId).get();
      if (doc.exists) {
        return AILanguageReel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      // print('Error getting reel: $e');
      return null;
    }
  }

  // Update reel view count
  static Future<void> incrementReelViews(String reelId) async {
    try {
      await _firestore.collection(_reelsCollection).doc(reelId).update({
        'views': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // print('Error incrementing views: $e');
    }
  }

  /// ===== SOCIAL INTERACTIONS =====

  // Toggle like for a reel
  static Future<void> toggleLike(String reelId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reelRef = _firestore.collection(_reelsCollection).doc(reelId);
        final reelDoc = await transaction.get(reelRef);

        if (!reelDoc.exists) {
          throw Exception('Reel not found');
        }

        final currentData = reelDoc.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(currentData['likedBy'] ?? []);

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
        } else {
          likedBy.add(userId);
        }

        transaction.update(reelRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      // print('Error toggling like: $e');
      rethrow;
    }
  }

  // Toggle save/bookmark for a reel
  static Future<void> toggleSaveReel(String reelId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // READ PHASE: All reads must happen first
        final userRef = _firestore.collection(_usersCollection).doc(userId);
        final reelRef = _firestore.collection(_reelsCollection).doc(reelId);

        // Read user document
        final userDoc = await transaction.get(userRef);

        // Read reel document
        final reelDoc = await transaction.get(reelRef);

        // COMPUTATION PHASE: Process the data
        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          userData = userDoc.data() as Map<String, dynamic>;
        }

        final savedReels = List<String>.from(userData['savedReels'] ?? []);
        bool isSaving = false;

        if (savedReels.contains(reelId)) {
          savedReels.remove(reelId);
          isSaving = false;
        } else {
          savedReels.add(reelId);
          isSaving = true;
        }

        // Prepare reel savedBy array
        List<String> savedBy = [];
        if (reelDoc.exists) {
          final reelData = reelDoc.data() as Map<String, dynamic>;
          savedBy = List<String>.from(reelData['savedBy'] ?? []);

          if (isSaving) {
            if (!savedBy.contains(userId)) savedBy.add(userId);
          } else {
            savedBy.remove(userId);
          }
        }

        // WRITE PHASE: All writes must happen after all reads
        // Update user document
        transaction.set(
            userRef,
            {
              ...userData,
              'savedReels': savedReels,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        // Update reel document (only if it exists)
        if (reelDoc.exists) {
          transaction.update(reelRef, {
            'savedBy': savedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // print('Error toggling save reel: $e');
      rethrow;
    }
  }

  // Share reel (increment share count)
  static Future<void> shareReel(String reelId) async {
    try {
      await _firestore.collection(_reelsCollection).doc(reelId).update({
        'shares': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // print('Error sharing reel: $e');
    }
  }

  /// ===== COMMENTS =====

  // Add comment to a reel
  static Future<void> addComment({
    required String reelId,
    required String text,
    required String authorId,
    required String authorName,
    String? authorDisplayName, // NEW parameter
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Add comment document
        final commentRef = _firestore.collection(_commentsCollection).doc();
        final comment = ReelComment(
          id: commentRef.id,
          reelId: reelId,
          authorId: authorId,
          authorName: authorName,
          authorDisplayName: authorDisplayName, // NEW: Pass to comment
          authorAvatar: AppUtils.generateAvatar(authorName),
          text: text,
          createdAt: DateTime.now(),
        );

        transaction.set(commentRef, comment.toMap());

        // Update reel comment count
        final reelRef = _firestore.collection(_reelsCollection).doc(reelId);
        transaction.update(reelRef, {
          'comments': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get comments for a reel
  static Stream<List<ReelComment>> getCommentsStream(String reelId) {
    return _firestore
        .collection(_commentsCollection)
        .where('reelId', isEqualTo: reelId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReelComment.fromMap(doc.data(), doc.id))
            .toList()
          ..sort(
              (a, b) => a.createdAt.compareTo(b.createdAt))); // Manual sorting
  }

  // Toggle like on comment
  static Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final commentRef =
            _firestore.collection(_commentsCollection).doc(commentId);
        final commentDoc = await transaction.get(commentRef);

        if (!commentDoc.exists) return;

        final data = commentDoc.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
        } else {
          likedBy.add(userId);
        }

        transaction.update(commentRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });
    } catch (e) {
      // print('Error toggling comment like: $e');
    }
  }

  /// ===== VIDEO UPLOAD =====

  // Upload video to Firebase Storage
  static Future<String?> uploadVideo({
    required File videoFile,
    required String userId,
    Function(double)? onProgress,
  }) async {
    try {
      final videoId = _uuid.v4();
      final fileName = 'reel_$videoId.mp4';
      final ref = _storage.ref().child('videos/reels/$userId/$fileName');

      final uploadTask = ref.putFile(videoFile);

      // Listen to upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // print('Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      // print('Error uploading video: $e');
      return null;
    }
  }

  /// ===== USER MANAGEMENT =====

  // Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      // print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection(_usersCollection).doc(profile.uid).update({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // print('Error updating user profile: $e');
      return false;
    }
  }

  // Update user language preferences
  static Future<bool> updateUserLanguagePreferences(
    String userId,
    UserLanguagePreferences preferences,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'languagePreferences': preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // print('Error updating language preferences: $e');
      return false;
    }
  }

  // Get user stats and counts
  // REPLACE the getUserCounts method in lib/services/firebase_service.dart with this:

  static Future<Map<String, int>> getUserCounts(String userId) async {
    try {
      // Get user's reel count
      final userReelsSnapshot = await _firestore
          .collection(_reelsCollection)
          .where('authorId', isEqualTo: userId)
          .where('isProcessed', isEqualTo: true)
          .get();

      // Get user document for saved reels, followers, and following
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      if (!userDoc.exists) {
        return {
          'reels': 0,
          'saved': 0,
          'followers': 0,
          'following': 0,
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // Handle both array and count formats
      int followersCount;
      int followingCount;

      // Try count fields first (your current format)
      if (userData.containsKey('followersCount')) {
        followersCount = userData['followersCount'] as int? ?? 0;
      } else {
        // Fallback to array format
        final followers = List<String>.from(userData['followers'] ?? []);
        followersCount = followers.length;
      }

      if (userData.containsKey('followingCount')) {
        followingCount = userData['followingCount'] as int? ?? 0;
      } else {
        // Fallback to array format
        final following = List<String>.from(userData['following'] ?? []);
        followingCount = following.length;
      }

      // Handle saved reels
      int savedCount;
      if (userData.containsKey('savedReelsCount')) {
        savedCount = userData['savedReelsCount'] as int? ?? 0;
      } else {
        // Fallback to array format
        final savedReels = List<String>.from(userData['savedReels'] ?? []);
        savedCount = savedReels.length;
      }

      return {
        'reels': userReelsSnapshot.docs.length,
        'saved': savedCount,
        'followers': followersCount,
        'following': followingCount,
      };
    } catch (e) {
      // print('Error getting user counts: $e');
      return {
        'reels': 0,
        'saved': 0,
        'followers': 0,
        'following': 0,
      };
    }
  }

  // REPLACE the existing follow methods in lib/services/firebase_service.dart with these:

  /// ===== FOLLOW/UNFOLLOW FUNCTIONALITY =====

// Follow a user
  static Future<bool> followUser(String userToFollowId) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null || currentUid == userToFollowId) return false;

      await _firestore.runTransaction((transaction) async {
        // Read phase - get both user documents
        final currentUserRef =
            _firestore.collection(_usersCollection).doc(currentUid);
        final targetUserRef =
            _firestore.collection(_usersCollection).doc(userToFollowId);

        final currentUserDoc = await transaction.get(currentUserRef);
        final targetUserDoc = await transaction.get(targetUserRef);

        // Computation phase
        Map<String, dynamic> currentUserData = {};
        Map<String, dynamic> targetUserData = {};

        if (currentUserDoc.exists) {
          currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        }
        if (targetUserDoc.exists) {
          targetUserData = targetUserDoc.data() as Map<String, dynamic>;
        }

        // Get current arrays
        final following = List<String>.from(currentUserData['following'] ?? []);
        final followers = List<String>.from(targetUserData['followers'] ?? []);

        // Add if not already following
        if (!following.contains(userToFollowId)) {
          following.add(userToFollowId);
        }
        if (!followers.contains(currentUid)) {
          followers.add(currentUid);
        }

        // Write phase - update both documents with arrays AND counts
        transaction.set(
            currentUserRef,
            {
              ...currentUserData,
              'following': following,
              'followingCount': following.length, // Store both array and count
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        transaction.set(
            targetUserRef,
            {
              ...targetUserData,
              'followers': followers,
              'followersCount': followers.length, // Store both array and count
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      // print('Error following user: $e');
      return false;
    }
  }

// Unfollow a user
  static Future<bool> unfollowUser(String userToUnfollowId) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null || currentUid == userToUnfollowId) return false;

      await _firestore.runTransaction((transaction) async {
        // Read phase - get both user documents
        final currentUserRef =
            _firestore.collection(_usersCollection).doc(currentUid);
        final targetUserRef =
            _firestore.collection(_usersCollection).doc(userToUnfollowId);

        final currentUserDoc = await transaction.get(currentUserRef);
        final targetUserDoc = await transaction.get(targetUserRef);

        // Computation phase
        Map<String, dynamic> currentUserData = {};
        Map<String, dynamic> targetUserData = {};

        if (currentUserDoc.exists) {
          currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        }
        if (targetUserDoc.exists) {
          targetUserData = targetUserDoc.data() as Map<String, dynamic>;
        }

        // Get current arrays
        final following = List<String>.from(currentUserData['following'] ?? []);
        final followers = List<String>.from(targetUserData['followers'] ?? []);

        // Remove from arrays
        following.remove(userToUnfollowId);
        followers.remove(currentUid);

        // Write phase - update both documents with arrays AND counts
        transaction.set(
            currentUserRef,
            {
              ...currentUserData,
              'following': following,
              'followingCount': following.length, // Store both array and count
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        transaction.set(
            targetUserRef,
            {
              ...targetUserData,
              'followers': followers,
              'followersCount': followers.length, // Store both array and count
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      // print('Error unfollowing user: $e');
      return false;
    }
  }

// Check if current user is following another user
  static Future<bool> isFollowing(String userId) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null || currentUid == userId) return false;

      final userDoc =
          await _firestore.collection(_usersCollection).doc(currentUid).get();
      if (!userDoc.exists) return false;

      final following = List<String>.from(userDoc.data()?['following'] ?? []);
      return following.contains(userId);
    } catch (e) {
      // print('Error checking follow status: $e');
      return false;
    }
  }

// Get followers list with user data
  static Future<List<Map<String, dynamic>>> getFollowersList(
      String userId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) return [];

      final followers = List<String>.from(userDoc.data()?['followers'] ?? []);
      if (followers.isEmpty) return [];

      // Fetch user data for each follower
      final List<Map<String, dynamic>> followersData = [];

      // Process in batches of 10 (Firestore 'in' query limit)
      for (int i = 0; i < followers.length; i += 10) {
        final batch = followers.skip(i).take(10).toList();

        final usersSnapshot = await _firestore
            .collection(_usersCollection)
            .where('uid', whereIn: batch)
            .get();

        for (final doc in usersSnapshot.docs) {
          final userData = doc.data();
          followersData.add({
            'uid': userData['uid'],
            'username': userData['username'],
            'profileImageUrl': userData['profileImageUrl'],
            'bio': userData['bio'],
          });
        }
      }

      return followersData;
    } catch (e) {
      // print('Error getting followers list: $e');
      return [];
    }
  }

// Get following list with user data
  static Future<List<Map<String, dynamic>>> getFollowingList(
      String userId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) return [];

      final following = List<String>.from(userDoc.data()?['following'] ?? []);
      if (following.isEmpty) return [];

      // Fetch user data for each user being followed
      final List<Map<String, dynamic>> followingData = [];

      // Process in batches of 10 (Firestore 'in' query limit)
      for (int i = 0; i < following.length; i += 10) {
        final batch = following.skip(i).take(10).toList();

        final usersSnapshot = await _firestore
            .collection(_usersCollection)
            .where('uid', whereIn: batch)
            .get();

        for (final doc in usersSnapshot.docs) {
          final userData = doc.data();
          followingData.add({
            'uid': userData['uid'],
            'username': userData['username'],
            'profileImageUrl': userData['profileImageUrl'],
            'bio': userData['bio'],
          });
        }
      }

      return followingData;
    } catch (e) {
      // print('Error getting following list: $e');
      return [];
    }
  }

  /// ===== SEARCH & DISCOVERY =====

  // // Original search method - keeping for backward compatibility
  // static Future<List<AILanguageReel>> searchReels({
  //   String? query,
  //   String? sourceLanguage,
  //   String? difficulty,
  //   String? category,
  //   int limit = AppConstants.reelsPerPage,
  // }) async {
  //   try {
  //     Query firestoreQuery = _firestore
  //         .collection(_reelsCollection)
  //         .where('isProcessed', isEqualTo: true)
  //         .where('passedModeration', isEqualTo: true);

  //     // Apply filters
  //     if (sourceLanguage != null && sourceLanguage != 'all') {
  //       firestoreQuery =
  //           firestoreQuery.where('sourceLanguage', isEqualTo: sourceLanguage);
  //     }

  //     if (difficulty != null && difficulty != 'all') {
  //       firestoreQuery =
  //           firestoreQuery.where('difficulty', isEqualTo: difficulty);
  //     }

  //     if (category != null && category != 'all') {
  //       firestoreQuery = firestoreQuery.where('category', isEqualTo: category);
  //     }

  //     final snapshot = await firestoreQuery
  //         .orderBy('createdAt', descending: true)
  //         .limit(limit * 2) // Get more to filter by text search
  //         .get();

  //     List<AILanguageReel> reels = snapshot.docs
  //         .map((doc) => AILanguageReel.fromMap(
  //             doc.data() as Map<String, dynamic>, doc.id))
  //         .toList();

  //     // If we have a text query, filter by content
  //     if (query != null && query.isNotEmpty) {
  //       final queryLower = query.toLowerCase();
  //       reels = reels.where((reel) {
  //         final originalText = reel.originalText?.toLowerCase() ?? '';
  //         final authorName = reel.authorName.toLowerCase();
  //         final tags = reel.tags.join(' ').toLowerCase();

  //         return originalText.contains(queryLower) ||
  //             authorName.contains(queryLower) ||
  //             tags.contains(queryLower);
  //       }).toList();
  //     }

  //     return reels.take(limit).toList();
  //   } catch (e) {
  //     // print('Error searching reels: $e');
  //     return [];
  //   }
  // }

  // Get reels by specific language for learning
  static Stream<List<AILanguageReel>> getReelsByLanguage(
    String languageCode, {
    int limit = AppConstants.reelsPerPage,
  }) {
    return _firestore
        .collection(_reelsCollection)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true)
        .where('sourceLanguage', isEqualTo: languageCode)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AILanguageReel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // // Get trending reels (by engagement)
  // static Future<List<AILanguageReel>> getTrendingReels({
  //   int limit = AppConstants.reelsPerPage,
  //   Duration timeWindow = const Duration(days: 7),
  // }) async {
  //   try {
  //     final cutoffDate = DateTime.now().subtract(timeWindow);

  //     final snapshot = await _firestore
  //         .collection(_reelsCollection)
  //         .where('isProcessed', isEqualTo: true)
  //         .where('passedModeration', isEqualTo: true)
  //         .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
  //         .orderBy('createdAt', descending: true)
  //         .limit(limit * 3) // Get more to sort by engagement
  //         .get();

  //     List<AILanguageReel> reels = snapshot.docs
  //         .map((doc) => AILanguageReel.fromMap(
  //             doc.data() as Map<String, dynamic>, doc.id))
  //         .toList();

  //     // Sort by engagement rate
  //     reels.sort((a, b) => b.engagementRate.compareTo(a.engagementRate));

  //     return reels.take(limit).toList();
  //   } catch (e) {
  //     // print('Error getting trending reels: $e');
  //     return [];
  //   }
  // }
  // Add these methods inside your FirebaseService class

  /// Get trending reels based on likes and views
  static Future<List<AILanguageReel>> getTrendingReels({
    int limit = 10,
    int hoursBack = 168, // 7 days instead of 24 hours for more data
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_reelsCollection)
          .where('isProcessed', isEqualTo: true)
          .where('passedModeration', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100) // Get more to filter by time
          .get();

      List<AILanguageReel> reels = snapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filter by time (last 7 days)
      final cutoffTime = DateTime.now().subtract(Duration(hours: hoursBack));
      reels =
          reels.where((reel) => reel.createdAt.isAfter(cutoffTime)).toList();

      // Sort by engagement score with time decay
      reels.sort((a, b) {
        double scoreA = _calculateTrendingScore(a, hoursBack);
        double scoreB = _calculateTrendingScore(b, hoursBack);
        return scoreB.compareTo(scoreA);
      });

      return reels.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

// Updated scoring with time decay
  static double _calculateTrendingScore(AILanguageReel reel, int hoursBack) {
    final hoursOld = DateTime.now().difference(reel.createdAt).inHours;
    final maxAge = hoursBack.toDouble();
    final ageDecay = 1.0 - (hoursOld / maxAge); // Linear decay over time window

    final engagementScore = (reel.likes * 10.0) + (reel.views * 1.0);

    return engagementScore *
        ageDecay.clamp(0.1, 1.0); // Min 10% of original score
  }

  /// Simple trending score: likes + views with time decay
  static double _calculateSimpleTrendingScore(AILanguageReel reel) {
    final hoursOld = DateTime.now().difference(reel.createdAt).inHours;
    final ageDecay = 1.0 / (1.0 + hoursOld / 24.0); // Decay over 24 hours

    // Simple score: likes worth more than views
    final score = (reel.likes * 10.0) + (reel.views * 1.0);

    return score * ageDecay;
  }

  /// Get popular languages based on content volume and engagement
  static Future<List<String>> getPopularLanguages({
    int limit = 6,
    int daysBack = 7,
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection(_reelsCollection)
          .where('isProcessed', isEqualTo: true)
          .where('passedModeration', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();

      // Count by language
      Map<String, Map<String, int>> languageStats = {};

      for (final doc in snapshot.docs) {
        final reel =
            AILanguageReel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        final language = reel.sourceLanguage ?? 'en';

        if (!languageStats.containsKey(language)) {
          languageStats[language] = {
            'count': 0,
            'totalViews': 0,
            'totalLikes': 0,
          };
        }

        languageStats[language]!['count'] =
            languageStats[language]!['count']! + 1;
        languageStats[language]!['totalViews'] =
            languageStats[language]!['totalViews']! + reel.views;
        languageStats[language]!['totalLikes'] =
            languageStats[language]!['totalLikes']! + reel.likes;
      }

      // Sort by simple popularity score
      List<MapEntry<String, Map<String, int>>> sortedLanguages =
          languageStats.entries.toList();

      sortedLanguages.sort((a, b) {
        double scoreA = _calculateSimpleLanguageScore(a.value);
        double scoreB = _calculateSimpleLanguageScore(b.value);
        return scoreB.compareTo(scoreA);
      });

      return sortedLanguages.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      return ['en', 'es', 'fr', 'de', 'ja', 'ko'];
    }
  }

  /// Simple language popularity: content count + average likes + average views
  static double _calculateSimpleLanguageScore(Map<String, int> stats) {
    final count = stats['count']!.toDouble();
    final avgViews = count > 0 ? stats['totalViews']! / count : 0.0;
    final avgLikes = count > 0 ? stats['totalLikes']! / count : 0.0;

    // Simple formula: content volume + engagement
    return (count * 5.0) + (avgLikes * 10.0) + (avgViews * 1.0);
  }

  // REPLACE the searchUsers method in lib/services/firebase_service.dart

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final queryLower = query.toLowerCase().trim();

      // Search by username (starts with) - REMOVED isActive filter
      final usernameQuery = await _firestore
          .collection(_usersCollection)
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThan: queryLower + '\uf8ff')
          .limit(20)
          .get();

      Set<String> userIds = {};
      List<Map<String, dynamic>> results = [];

      // Add username matches
      for (final doc in usernameQuery.docs) {
        final data = doc.data();

        // Filter out inactive users in code instead of query
        final isActive = data['isActive'] ?? true;
        if (!isActive) continue;

        if (!userIds.contains(data['uid'])) {
          userIds.add(data['uid']);
          results.add({
            'uid': data['uid'],
            'username': data['username'],
            'displayName': data['displayName'], // Include displayName
            'email': data['email'],
            'profileImageUrl': data['profileImageUrl'],
            'bio': data['bio'],
            'followersCount': data['followersCount'] ?? 0,
            'followingCount': data['followingCount'] ?? 0,
          });
        }
      }

      // If no results with "starts with", try contains search
      if (results.isEmpty) {
        // Fetch more users and filter in memory
        final allUsersQuery =
            await _firestore.collection(_usersCollection).limit(100).get();

        for (final doc in allUsersQuery.docs) {
          final data = doc.data();
          final username = (data['username'] as String? ?? '').toLowerCase();
          final displayName =
              (data['displayName'] as String? ?? '').toLowerCase();
          final isActive = data['isActive'] ?? true;

          if (!isActive) continue;

          // Check if query matches username or display name
          if (username.contains(queryLower) ||
              displayName.contains(queryLower)) {
            if (!userIds.contains(data['uid'])) {
              userIds.add(data['uid']);
              results.add({
                'uid': data['uid'],
                'username': data['username'],
                'displayName': data['displayName'],
                'email': data['email'],
                'profileImageUrl': data['profileImageUrl'],
                'bio': data['bio'],
                'followersCount': data['followersCount'] ?? 0,
                'followingCount': data['followingCount'] ?? 0,
              });
            }
          }

          if (results.length >= 20) break;
        }
      }

      return results;
    } catch (e) {
      // print('Error searching users: $e');
      return [];
    }
  }

  /// ===== AI PROCESSING SUPPORT =====

  // Retry failed processing
  static Future<bool> retryProcessing(String reelId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user owns the reel
      final reelDoc =
          await _firestore.collection(_reelsCollection).doc(reelId).get();
      if (!reelDoc.exists) {
        throw Exception('Reel not found');
      }

      final reelData = reelDoc.data() as Map<String, dynamic>;
      if (reelData['authorId'] != user.uid) {
        throw Exception('You can only retry your own reels');
      }

      // Reset processing status to trigger pipeline again
      await _firestore.collection(_reelsCollection).doc(reelId).update({
        'processingStatus': 'uploading',
        'processingError': null,
        'failedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // print('Error retrying processing: $e');
      return false;
    }
  }

  // Get processing statistics for monitoring
  static Future<Map<String, dynamic>> getProcessingStats() async {
    try {
      final yesterday = DateTime.now().subtract(Duration(days: 1));

      // Get recent reels
      final recentSnapshot = await _firestore
          .collection(_reelsCollection)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      final total = recentSnapshot.docs.length;
      final completed = recentSnapshot.docs
          .where((doc) => doc.data()['processingStatus'] == 'completed')
          .length;
      final failed = recentSnapshot.docs
          .where((doc) => doc.data()['processingStatus'] == 'failed')
          .length;
      final processing = total - completed - failed;

      return {
        'total': total,
        'completed': completed,
        'failed': failed,
        'processing': processing,
        'successRate':
            total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      // print('Error getting processing stats: $e');
      return {
        'total': 0,
        'completed': 0,
        'failed': 0,
        'processing': 0,
        'successRate': '0',
      };
    }
  }

  /// ===== ADMIN & MODERATION =====

  // Report inappropriate content
  static Future<bool> reportContent({
    required String contentId,
    required String contentType, // 'reel' or 'comment'
    required String reason,
    String? description,
  }) async {
    try {
      final reportId = _uuid.v4();
      await _firestore.collection('reports').doc(reportId).set({
        'id': reportId,
        'contentId': contentId,
        'contentType': contentType,
        'reporterId': currentUserId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // print('Error reporting content: $e');
      return false;
    }
  }

  // Block/unblock user
  static Future<bool> toggleBlockUser(String userIdToBlock) async {
    try {
      final currentUid = currentUserId;
      if (currentUid == null) return false;

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(_usersCollection).doc(currentUid);
        final userDoc = await transaction.get(userRef);

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          userData = userDoc.data() as Map<String, dynamic>;
        }

        final blockedUsers = List<String>.from(userData['blockedUsers'] ?? []);

        if (blockedUsers.contains(userIdToBlock)) {
          blockedUsers.remove(userIdToBlock);
        } else {
          blockedUsers.add(userIdToBlock);
        }

        transaction.set(
            userRef,
            {
              ...userData,
              'blockedUsers': blockedUsers,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      // print('Error toggling block user: $e');
      return false;
    }
  }

  /// ===== ANALYTICS & METRICS =====

  // Log user activity for analytics
  static Future<void> logUserActivity({
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _firestore.collection('user_activity').add({
        'userId': userId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // print('Error logging user activity: $e');
    }
  }

  // Get user engagement metrics
  static Future<Map<String, dynamic>> getUserEngagementMetrics(
    String userId, {
    int days = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // Get user's reels from the time period
      final reelsSnapshot = await _firestore
          .collection(_reelsCollection)
          .where('authorId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();

      int totalViews = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;

      for (final doc in reelsSnapshot.docs) {
        final data = doc.data();
        totalViews += (data['views'] as int?) ?? 0;
        totalLikes += (data['likes'] as int?) ?? 0;
        totalComments += (data['comments'] as int?) ?? 0;
        totalShares += (data['shares'] as int?) ?? 0;
      }

      final totalReels = reelsSnapshot.docs.length;
      final engagementRate = totalViews > 0
          ? (totalLikes + totalComments + totalShares) / totalViews
          : 0.0;

      return {
        'totalReels': totalReels,
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'engagementRate': engagementRate,
        'avgViewsPerReel': totalReels > 0 ? totalViews / totalReels : 0.0,
      };
    } catch (e) {
      // print('Error getting engagement metrics: $e');
      return {};
    }
  }

  /// ===== TRANSLATION MANAGEMENT =====

  // Fetch translations for a specific reel
  static Future<Map<String, String>> getReelTranslations(String reelId) async {
    try {
      final doc = await _firestore
          .collection(_translationsCollection)
          .doc(reelId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final translations =
            data['translations'] as Map<String, dynamic>? ?? {};

        // Convert to Map<String, String>
        return translations
            .map((key, value) => MapEntry(key, value.toString()));
      }

      return {};
    } catch (e) {
      // print('Error fetching translations for reel $reelId: $e');
      return {};
    }
  }

  // Get source language from translations collection
  static Future<String?> getReelSourceLanguage(String reelId) async {
    try {
      final doc = await _firestore
          .collection(_translationsCollection)
          .doc(reelId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['originalLanguage'] as String?;
      }

      return null;
    } catch (e) {
      // print('Error fetching source language for reel $reelId: $e');
      return null;
    }
  }

  /// ===== UTILITY METHODS =====

  // Check if user has saved a reel
  static Future<bool> isReelSaved(String reelId, String userId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final savedReels = List<String>.from(userData['savedReels'] ?? []);
      return savedReels.contains(reelId);
    } catch (e) {
      // print('Error checking if reel is saved: $e');
      return false;
    }
  }

  // Delete a reel (only by author)
  static Future<bool> deleteReel(String reelId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reelRef = _firestore.collection(_reelsCollection).doc(reelId);
        final reelDoc = await transaction.get(reelRef);

        if (!reelDoc.exists) {
          throw Exception('Reel not found');
        }

        final reelData = reelDoc.data() as Map<String, dynamic>;
        if (reelData['authorId'] != userId) {
          throw Exception('You can only delete your own reels');
        }

        // Delete the reel document
        transaction.delete(reelRef);

        // Delete associated comments
        final commentsSnapshot = await _firestore
            .collection(_commentsCollection)
            .where('reelId', isEqualTo: reelId)
            .get();

        for (final doc in commentsSnapshot.docs) {
          transaction.delete(doc.reference);
        }
      });

      return true;
    } catch (e) {
      // print('Error deleting reel: $e');
      return false;
    }
  }

  // Batch operations for better performance
  static WriteBatch createBatch() => _firestore.batch();

  static Future<void> commitBatch(WriteBatch batch) async {
    try {
      await batch.commit();
    } catch (e) {
      // print('Error committing batch: $e');
      rethrow;
    }
  }

  /// ===== SENTENCE-BASED LEARNING METHODS =====

  /// Fetch sentence data for a specific reel
  static Future<List<SentenceData>> getReelSentences(String reelId) async {
    try {
      final doc = await _firestore
          .collection(_translationsCollection)
          .doc(reelId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sentencesData = data['sentences'] as List<dynamic>? ?? [];

        return sentencesData
            .map((sentenceMap) =>
                SentenceData.fromMap(sentenceMap as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      // print('Error fetching sentences for reel $reelId: $e');
      return [];
    }
  }

  /// Fetch sentence metadata for a specific reel
  static Future<SentenceMetadata?> getReelSentenceMetadata(
      String reelId) async {
    try {
      final doc = await _firestore
          .collection(_translationsCollection)
          .doc(reelId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final metadataMap = data['sentenceMetadata'];

        if (metadataMap != null && metadataMap is Map) {
          return SentenceMetadata.fromMap(
              Map<String, dynamic>.from(metadataMap));
        }
      }

      return null;
    } catch (e) {
      // print('Error fetching sentence metadata for reel $reelId: $e');
      return null;
    }
  }

  /// Populate reel with sentence data from translations collection
  static Future<AILanguageReel> populateReelWithSentences(
      AILanguageReel reel) async {
    try {
      // Skip if reel doesn't have sentence data flag
      if (!reel.hasSentenceData) {
        return reel;
      }

      // Skip if sentences are already populated
      if (reel.sentences != null && reel.sentences!.isNotEmpty) {
        return reel;
      }

      // Fetch the entire translations document
      final doc = await _firestore
          .collection(_translationsCollection)
          .doc(reel.id)
          .get();

      if (!doc.exists) {
        return reel;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Extract sentence data
      final sentencesData = data['sentences'] as List<dynamic>? ?? [];
      final sentences = sentencesData
          .map((sentenceMap) =>
              SentenceData.fromMap(sentenceMap as Map<String, dynamic>))
          .toList();

      // Extract sentence metadata
      final sentenceMetadata = data['sentenceMetadata'] != null
          ? SentenceMetadata.fromMap(
              data['sentenceMetadata'] as Map<String, dynamic>)
          : null;

      // Extract root-level translation data
      final sourceLanguage = data['originalLanguage'] as String?;
      final rootTranslations =
          Map<String, String>.from(data['translations'] ?? {});

      // Return updated reel with ALL data populated
      return reel.copyWith(
        sentences: sentences,
        sentenceMetadata: sentenceMetadata,
        hasSentenceData: sentences.isNotEmpty,
        totalSentences: sentences.length,
        sourceLanguage: sourceLanguage,
        translations: rootTranslations,
      );
    } catch (e) {
      // print('Error populating reel with sentences: $e');
      return reel;
    }
  }

  /// UPDATED: Enhanced reel stream that includes sentence data for long-form content
  static Stream<List<AILanguageReel>> getProcessedReelsStreamWithSentences({
    int limit = AppConstants.reelsPerPage,
    String? languageFilter,
    String? difficultyFilter,
    String? categoryFilter,
    bool populateSentences = true,
  }) {
    Query query = _firestore
        .collection(_reelsCollection)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true);

    // FIXED: Apply filters using correct field names
    if (languageFilter != null && languageFilter != 'all') {
      query = query.where('sourceLanguage', isEqualTo: languageFilter);
    }

    if (difficultyFilter != null && difficultyFilter != 'all') {
      query = query.where('difficulty', isEqualTo: difficultyFilter);
    }

    if (categoryFilter != null && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final reels = snapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Populate sentence data for long-form content if requested
      if (populateSentences) {
        final populatedReels = <AILanguageReel>[];

        for (final reel in reels) {
          if (reel.isLongForm) {
            final populatedReel = await populateReelWithSentences(reel);
            populatedReels.add(populatedReel);
          } else {
            populatedReels.add(reel);
          }
        }

        return populatedReels;
      }

      return reels;
    });
  }

  /// Get reels specifically for sentence-based learning
  static Stream<List<AILanguageReel>> getSentenceBasedLearningReels({
    int limit = AppConstants.reelsPerPage,
    String? languageFilter,
    String? difficultyFilter,
  }) {
    Query query = _firestore
        .collection(_reelsCollection)
        .where('isProcessed', isEqualTo: true)
        .where('passedModeration', isEqualTo: true)
        .where('hasSentenceData', isEqualTo: true)
        .where('totalSentences', isGreaterThan: 1); // Only long-form content

    // Apply filters
    if (languageFilter != null && languageFilter != 'all') {
      query = query.where('sourceLanguage', isEqualTo: languageFilter);
    }

    if (difficultyFilter != null && difficultyFilter != 'all') {
      query = query.where('difficulty', isEqualTo: difficultyFilter);
    }

    return query
        .orderBy('totalSentences',
            descending: false) // Start with shorter content
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final reels = snapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Always populate sentence data for these reels
      final populatedReels = <AILanguageReel>[];

      for (final reel in reels) {
        final populatedReel = await populateReelWithSentences(reel);
        populatedReels.add(populatedReel);
      }

      return populatedReels;
    });
  }

  /// Search sentences across all reels
  static Future<List<SentenceSearchResult>> searchSentences({
    required String query,
    String? sourceLanguage,
    String? targetLanguage,
    int limit = 50,
  }) async {
    try {
      // First, get reels that match basic criteria
      Query reelsQuery = _firestore
          .collection(_reelsCollection)
          .where('isProcessed', isEqualTo: true)
          .where('passedModeration', isEqualTo: true)
          .where('hasSentenceData', isEqualTo: true);

      if (sourceLanguage != null && sourceLanguage != 'all') {
        reelsQuery =
            reelsQuery.where('sourceLanguage', isEqualTo: sourceLanguage);
      }

      final reelsSnapshot = await reelsQuery.limit(limit * 2).get();

      final searchResults = <SentenceSearchResult>[];

      for (final reelDoc in reelsSnapshot.docs) {
        final reel = AILanguageReel.fromMap(
            reelDoc.data() as Map<String, dynamic>, reelDoc.id);

        // Get sentence data for this reel
        final sentences = await getReelSentences(reel.id);

        // Search through sentences
        for (final sentence in sentences) {
          bool matches = false;
          String matchedText = '';

          // Check original text
          if (sentence.originalText
              .toLowerCase()
              .contains(query.toLowerCase())) {
            matches = true;
            matchedText = sentence.originalText;
          }

          // Check specific target language if specified
          if (!matches && targetLanguage != null) {
            final translation = sentence.getTranslation(targetLanguage);
            if (translation.toLowerCase().contains(query.toLowerCase())) {
              matches = true;
              matchedText = translation;
            }
          }

          // Check all translations if no target language specified
          if (!matches && targetLanguage == null) {
            for (final translation in sentence.translations.values) {
              if (translation.toLowerCase().contains(query.toLowerCase())) {
                matches = true;
                matchedText = translation;
                break;
              }
            }
          }

          if (matches) {
            searchResults.add(SentenceSearchResult(
              reel: reel,
              sentence: sentence,
              matchedText: matchedText,
              relevanceScore: _calculateRelevanceScore(query, matchedText),
            ));
          }
        }

        if (searchResults.length >= limit) break;
      }

      // Sort by relevance score
      searchResults
          .sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return searchResults.take(limit).toList();
    } catch (e) {
      // print('Error searching sentences: $e');
      return [];
    }
  }

  /// Calculate relevance score for search results
  static double _calculateRelevanceScore(String query, String text) {
    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();

    // Exact match gets highest score
    if (textLower == queryLower) return 1.0;

    // Word match gets high score
    if (textLower.split(' ').contains(queryLower)) return 0.9;

    // Contains query gets medium score
    if (textLower.contains(queryLower)) return 0.7;

    // Partial word match gets lower score
    final queryWords = queryLower.split(' ');
    final textWords = textLower.split(' ');

    int matchingWords = 0;
    for (final queryWord in queryWords) {
      for (final textWord in textWords) {
        if (textWord.contains(queryWord) || queryWord.contains(textWord)) {
          matchingWords++;
          break;
        }
      }
    }

    return (matchingWords / queryWords.length) * 0.5;
  }

  /// Get statistics about sentence-based content
  static Future<SentenceContentStats> getSentenceContentStats() async {
    try {
      // Get all processed reels
      final reelsSnapshot = await _firestore
          .collection(_reelsCollection)
          .where('isProcessed', isEqualTo: true)
          .where('passedModeration', isEqualTo: true)
          .get();

      int totalReels = reelsSnapshot.docs.length;
      int reelsWithSentences = 0;
      int totalSentences = 0;
      int longFormReels = 0;
      Map<String, int> languageDistribution = {};

      for (final doc in reelsSnapshot.docs) {
        final data = doc.data();
        final hasSentenceData = data['hasSentenceData'] ?? false;
        final sentenceCount = data['totalSentences'] ?? 0;
        final language = data['sourceLanguage'] ?? 'unknown';

        if (hasSentenceData) {
          reelsWithSentences++;
          totalSentences += sentenceCount as int;

          if (sentenceCount > 1) {
            longFormReels++;
          }
        }

        languageDistribution[language] =
            (languageDistribution[language] ?? 0) + 1;
      }

      return SentenceContentStats(
        totalReels: totalReels,
        reelsWithSentences: reelsWithSentences,
        totalSentences: totalSentences,
        longFormReels: longFormReels,
        averageSentencesPerReel:
            reelsWithSentences > 0 ? totalSentences / reelsWithSentences : 0.0,
        sentenceDataCoverage:
            totalReels > 0 ? reelsWithSentences / totalReels : 0.0,
        languageDistribution: languageDistribution,
      );
    } catch (e) {
      // print('Error getting sentence content stats: $e');
      return SentenceContentStats.empty();
    }
  }

  /// Enhanced reel fetching that always includes sentence data
  static Future<AILanguageReel?> getReelByIdWithSentences(String reelId) async {
    try {
      final reel = await getReelById(reelId);
      if (reel == null) return null;

      return await populateReelWithSentences(reel);
    } catch (e) {
      // print('Error getting reel with sentences: $e');
      return null;
    }
  }

  /// Watch reel processing with sentence data population
  static Stream<AILanguageReel?> watchReelProcessingStatusWithSentences(
      String reelId) {
    return _firestore
        .collection(_reelsCollection)
        .doc(reelId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return null;

      final reel =
          AILanguageReel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Populate sentence data if processing is complete and has sentence data
      if (reel.isProcessed && reel.hasSentenceData) {
        return await populateReelWithSentences(reel);
      }

      return reel;
    });
  }

  /// Enhanced getUserReelsStream with sentence data
  static Stream<List<AILanguageReel>> getUserReelsStreamWithSentences(
    String userId, {
    int limit = 50,
    bool populateSentences = true,
  }) {
    return _firestore
        .collection(_reelsCollection)
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final reels = snapshot.docs
          .map((doc) => AILanguageReel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (!populateSentences) return reels;

      // Populate sentence data for processed reels with sentence data
      final populatedReels = <AILanguageReel>[];

      for (final reel in reels) {
        if (reel.isProcessed && reel.hasSentenceData) {
          final populatedReel = await populateReelWithSentences(reel);
          populatedReels.add(populatedReel);
        } else {
          populatedReels.add(reel);
        }
      }

      return populatedReels;
    });
  }
}

/// Result object for sentence search
class SentenceSearchResult {
  final AILanguageReel reel;
  final SentenceData sentence;
  final String matchedText;
  final double relevanceScore;

  SentenceSearchResult({
    required this.reel,
    required this.sentence,
    required this.matchedText,
    required this.relevanceScore,
  });

  @override
  String toString() {
    return 'SentenceSearchResult(reel: ${reel.id}, sentence: ${sentence.index}, score: ${relevanceScore.toStringAsFixed(2)})';
  }
}

/// Statistics about sentence-based content
class SentenceContentStats {
  final int totalReels;
  final int reelsWithSentences;
  final int totalSentences;
  final int longFormReels;
  final double averageSentencesPerReel;
  final double sentenceDataCoverage;
  final Map<String, int> languageDistribution;

  SentenceContentStats({
    required this.totalReels,
    required this.reelsWithSentences,
    required this.totalSentences,
    required this.longFormReels,
    required this.averageSentencesPerReel,
    required this.sentenceDataCoverage,
    required this.languageDistribution,
  });

  factory SentenceContentStats.empty() {
    return SentenceContentStats(
      totalReels: 0,
      reelsWithSentences: 0,
      totalSentences: 0,
      longFormReels: 0,
      averageSentencesPerReel: 0.0,
      sentenceDataCoverage: 0.0,
      languageDistribution: {},
    );
  }

  @override
  String toString() {
    return 'SentenceContentStats(total: $totalReels, withSentences: $reelsWithSentences, coverage: ${(sentenceDataCoverage * 100).toStringAsFixed(1)}%)';
  }
}
