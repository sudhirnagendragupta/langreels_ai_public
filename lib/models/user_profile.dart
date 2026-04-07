// lib/models/user_profile.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? profileImageUrl; // NEW: For uploaded images
  final Map<String, dynamic>? avatarData; // NEW: For custom avatars
  final String? bio;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final UserLanguagePreferences languagePreferences;
  final UserStats stats;
  final List<String> savedReels;
  final List<String> following;
  final List<String> followers;
  final Map<String, dynamic> settings;
  final bool isVerified;
  final bool isActive;

  UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.displayName,
    this.photoURL,
    this.profileImageUrl, // NEW
    this.avatarData, // NEW
    this.bio,
    required this.createdAt,
    required this.lastSeenAt,
    required this.languagePreferences,
    required this.stats,
    this.savedReels = const [],
    this.following = const [],
    this.followers = const [],
    this.settings = const {},
    this.isVerified = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'profileImageUrl': profileImageUrl, // NEW
      'avatarData': avatarData, // NEW
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'languagePreferences': languagePreferences.toMap(),
      'stats': stats.toMap(),
      'savedReels': savedReels,
      'following': following,
      'followers': followers,
      'settings': settings,
      'isVerified': isVerified,
      'isActive': isActive,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      profileImageUrl:
          map['profileImageUrl'], // NEW - will be null for existing users
      avatarData: map['avatarData'] != null
          ? Map<String, dynamic>.from(map['avatarData'])
          : null, // NEW - will be null for existing users
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastSeenAt: (map['lastSeenAt'] as Timestamp).toDate(),
      languagePreferences:
          UserLanguagePreferences.fromMap(map['languagePreferences'] ?? {}),
      stats: UserStats.fromMap(map['stats'] ?? {}),
      savedReels: List<String>.from(map['savedReels'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? username,
    String? email,
    String? displayName,
    String? photoURL,
    String? profileImageUrl, // NEW
    Map<String, dynamic>? avatarData, // NEW
    String? bio,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    UserLanguagePreferences? languagePreferences,
    UserStats? stats,
    List<String>? savedReels,
    List<String>? following,
    List<String>? followers,
    Map<String, dynamic>? settings,
    bool? isVerified,
    bool? isActive,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl, // NEW
      avatarData: avatarData ?? this.avatarData, // NEW
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      languagePreferences: languagePreferences ?? this.languagePreferences,
      stats: stats ?? this.stats,
      savedReels: savedReels ?? this.savedReels,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      settings: settings ?? this.settings,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
    );
  }

  String get displayInitial {
    if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    return 'U';
  }
}

class UserLanguagePreferences {
  final String primaryLanguage; // For UI and subtitles
  final List<String> learningLanguages; // Languages they want to learn
  final Map<String, String> proficiencyLevels; // Skill levels per language
  final Map<String, bool> notificationSettings; // Per-language notifications
  final String preferredSubtitleLanguage;
  final bool showOriginalFirst; // Show original before translation
  final bool autoTranslate; // Auto-translate content
  final List<String> hiddenLanguages; // Languages to hide from feed

  UserLanguagePreferences({
    this.primaryLanguage = 'en',
    this.learningLanguages = const [],
    this.proficiencyLevels = const {},
    this.notificationSettings = const {},
    this.preferredSubtitleLanguage = 'en',
    this.showOriginalFirst = true,
    this.autoTranslate = true,
    this.hiddenLanguages = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'primaryLanguage': primaryLanguage,
      'learningLanguages': learningLanguages,
      'proficiencyLevels': proficiencyLevels,
      'notificationSettings': notificationSettings,
      'preferredSubtitleLanguage': preferredSubtitleLanguage,
      'showOriginalFirst': showOriginalFirst,
      'autoTranslate': autoTranslate,
      'hiddenLanguages': hiddenLanguages,
    };
  }

  factory UserLanguagePreferences.fromMap(Map<String, dynamic> map) {
    return UserLanguagePreferences(
      primaryLanguage: map['primaryLanguage'] ?? 'en',
      learningLanguages: List<String>.from(map['learningLanguages'] ?? []),
      proficiencyLevels:
          Map<String, String>.from(map['proficiencyLevels'] ?? {}),
      notificationSettings:
          Map<String, bool>.from(map['notificationSettings'] ?? {}),
      preferredSubtitleLanguage: map['preferredSubtitleLanguage'] ?? 'en',
      showOriginalFirst: map['showOriginalFirst'] ?? true,
      autoTranslate: map['autoTranslate'] ?? true,
      hiddenLanguages: List<String>.from(map['hiddenLanguages'] ?? []),
    );
  }

  UserLanguagePreferences copyWith({
    String? primaryLanguage,
    List<String>? learningLanguages,
    Map<String, String>? proficiencyLevels,
    Map<String, bool>? notificationSettings,
    String? preferredSubtitleLanguage,
    bool? showOriginalFirst,
    bool? autoTranslate,
    List<String>? hiddenLanguages,
  }) {
    return UserLanguagePreferences(
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      learningLanguages: learningLanguages ?? this.learningLanguages,
      proficiencyLevels: proficiencyLevels ?? this.proficiencyLevels,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      showOriginalFirst: showOriginalFirst ?? this.showOriginalFirst,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      hiddenLanguages: hiddenLanguages ?? this.hiddenLanguages,
    );
  }

  // Helper methods
  bool isLearning(String languageCode) =>
      learningLanguages.contains(languageCode);

  String getProficiencyLevel(String languageCode) =>
      proficiencyLevels[languageCode] ?? 'beginner';

  bool isLanguageHidden(String languageCode) =>
      hiddenLanguages.contains(languageCode);

  bool getNotificationSetting(String languageCode) =>
      notificationSettings[languageCode] ?? true;
}

class UserStats {
  final int reelsCreated;
  final int reelsLiked;
  final int reelsShared;
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final int followersCount;
  final int followingCount;
  final int savedReelsCount;
  final Map<String, int> languageStats; // Videos per language
  final Map<String, int> weeklyActivity; // Activity by day
  final DateTime? lastReelCreated;
  final int streakDays;
  final List<String> achievements;

  UserStats({
    this.reelsCreated = 0,
    this.reelsLiked = 0,
    this.reelsShared = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalShares = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.savedReelsCount = 0,
    this.languageStats = const {},
    this.weeklyActivity = const {},
    this.lastReelCreated,
    this.streakDays = 0,
    this.achievements = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'reelsCreated': reelsCreated,
      'reelsLiked': reelsLiked,
      'reelsShared': reelsShared,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'totalShares': totalShares,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'savedReelsCount': savedReelsCount,
      'languageStats': languageStats,
      'weeklyActivity': weeklyActivity,
      'lastReelCreated':
          lastReelCreated != null ? Timestamp.fromDate(lastReelCreated!) : null,
      'streakDays': streakDays,
      'achievements': achievements,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      reelsCreated: map['reelsCreated'] ?? 0,
      reelsLiked: map['reelsLiked'] ?? 0,
      reelsShared: map['reelsShared'] ?? 0,
      totalViews: map['totalViews'] ?? 0,
      totalLikes: map['totalLikes'] ?? 0,
      totalComments: map['totalComments'] ?? 0,
      totalShares: map['totalShares'] ?? 0,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      savedReelsCount: map['savedReelsCount'] ?? 0,
      languageStats: Map<String, int>.from(map['languageStats'] ?? {}),
      weeklyActivity: Map<String, int>.from(map['weeklyActivity'] ?? {}),
      lastReelCreated: map['lastReelCreated'] != null
          ? (map['lastReelCreated'] as Timestamp).toDate()
          : null,
      streakDays: map['streakDays'] ?? 0,
      achievements: List<String>.from(map['achievements'] ?? []),
    );
  }

  // Helper methods
  double get engagementRate {
    if (totalViews == 0) return 0.0;
    return (totalLikes + totalComments + totalShares) / totalViews;
  }

  double get averageViewsPerReel {
    if (reelsCreated == 0) return 0.0;
    return totalViews / reelsCreated;
  }

  String get mostActiveLanguage {
    if (languageStats.isEmpty) return 'en';
    return languageStats.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  bool get isActiveCreator => reelsCreated >= 5;
  bool get isInfluencer => followersCount >= 1000;
  bool get isPolyglot => languageStats.length >= 3;

  UserStats copyWith({
    int? reelsCreated,
    int? reelsLiked,
    int? reelsShared,
    int? totalViews,
    int? totalLikes,
    int? totalComments,
    int? totalShares,
    int? followersCount,
    int? followingCount,
    int? savedReelsCount,
    Map<String, int>? languageStats,
    Map<String, int>? weeklyActivity,
    DateTime? lastReelCreated,
    int? streakDays,
    List<String>? achievements,
  }) {
    return UserStats(
      reelsCreated: reelsCreated ?? this.reelsCreated,
      reelsLiked: reelsLiked ?? this.reelsLiked,
      reelsShared: reelsShared ?? this.reelsShared,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      totalComments: totalComments ?? this.totalComments,
      totalShares: totalShares ?? this.totalShares,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      savedReelsCount: savedReelsCount ?? this.savedReelsCount,
      languageStats: languageStats ?? this.languageStats,
      weeklyActivity: weeklyActivity ?? this.weeklyActivity,
      lastReelCreated: lastReelCreated ?? this.lastReelCreated,
      streakDays: streakDays ?? this.streakDays,
      achievements: achievements ?? this.achievements,
    );
  }
}
