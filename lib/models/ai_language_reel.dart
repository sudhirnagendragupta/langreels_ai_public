// lib/models/ai_language_reel.dart
// Enhanced version with sentence-based learning support

import 'package:cloud_firestore/cloud_firestore.dart';
import 'sentence_data.dart'; // Import the new sentence model

enum ProcessingStatus {
  uploading,
  moderating,
  extractingAudio,
  transcribing,
  translating,
  completed,
  failed
}

class AILanguageReel {
  final String id;

  // User-provided data
  final String authorId;
  final String authorName;
  final String? authorDisplayName;
  final String authorAvatar;
  final String videoUrl;
  final DateTime createdAt;

  // AI-generated content
  final String? originalText; // Transcribed speech
  final String? sourceLanguage; // Auto-detected language
  final Map<String, String> translations; // Multi-language translations
  final double? transcriptionConfidence; // AI confidence score

  // NEW: Sentence-based learning data
  final bool hasSentenceData; // Does this reel have sentence timing?
  final int totalSentences; // Number of sentences extracted
  final List<SentenceData>?
      sentences; // Sentence data with timing and translations
  final SentenceMetadata? sentenceMetadata; // Processing metadata

  // Processing metadata
  final ProcessingStatus processingStatus;
  final bool isProcessed;
  final bool passedModeration;
  final DateTime? processedAt;
  final String? processingError;
  final Map<String, dynamic>? processingMetadata;

  // Social features
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final List<String> likedBy;
  final List<String> savedBy;
  final DateTime updatedAt;

  // Content metadata
  final List<String> tags;
  final String? category;
  final String? difficulty; // beginner, intermediate, advanced
  final double? avgRating;
  final int ratingCount;

  AILanguageReel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorDisplayName,
    required this.authorAvatar,
    required this.videoUrl,
    required this.createdAt,
    this.originalText,
    this.sourceLanguage,
    this.translations = const {},
    this.transcriptionConfidence,

    // NEW: Sentence-based fields
    this.hasSentenceData = false,
    this.totalSentences = 0,
    this.sentences,
    this.sentenceMetadata,
    this.processingStatus = ProcessingStatus.uploading,
    this.isProcessed = false,
    this.passedModeration = false,
    this.processedAt,
    this.processingError,
    this.processingMetadata,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
    this.likedBy = const [],
    this.savedBy = const [],
    required this.updatedAt,
    this.tags = const [],
    this.category,
    this.difficulty,
    this.avgRating,
    this.ratingCount = 0,
  });

  // Helper methods
  String getTranslation(String languageCode) {
    return translations[languageCode] ?? originalText ?? 'Processing...';
  }

  bool get isReadyToDisplay =>
      isProcessed && passedModeration && originalText != null;

  String get displayLanguage => sourceLanguage ?? 'Unknown';

  // NEW: Sentence-based learning helpers
  bool get isLongForm => hasSentenceData && totalSentences > 1;

  bool get isSentenceBasedLearning =>
      hasSentenceData && sentences != null && sentences!.isNotEmpty;

  bool get isShortFormContent => totalSentences <= 1 || !hasSentenceData;

  /// Get the sentence that should be active at a specific video position
  SentenceData? getCurrentSentence(double videoPosition) {
    if (!isSentenceBasedLearning) return null;

    for (final sentence in sentences!) {
      if (sentence.isActiveAt(videoPosition)) {
        return sentence;
      }
    }
    return null;
  }

  /// Get sentence by index
  SentenceData? getSentenceByIndex(int index) {
    if (!isSentenceBasedLearning || index < 0 || index >= sentences!.length) {
      return null;
    }
    return sentences![index];
  }

  /// Get all sentences for a specific language
  List<String> getSentenceTranslations(String languageCode) {
    if (!isSentenceBasedLearning) return [];

    return sentences!
        .map((sentence) => sentence.getTranslation(languageCode))
        .toList();
  }

  /// Find sentences containing specific text
  List<SentenceData> searchSentences(String query) {
    if (!isSentenceBasedLearning) return [];

    return sentences!.where((sentence) => sentence.contains(query)).toList();
  }

  /// Get total duration of all sentences
  double get totalSentenceDuration {
    if (!isSentenceBasedLearning) return 0.0;

    return sentences!.fold(0.0, (sum, sentence) => sum + sentence.duration);
  }

  /// Get average sentence confidence
  double get averageSentenceConfidence {
    if (!isSentenceBasedLearning) return transcriptionConfidence ?? 0.0;

    final totalConfidence =
        sentences!.fold(0.0, (sum, sentence) => sum + sentence.confidence);
    return totalConfidence / sentences!.length;
  }

  /// Check if content is suitable for sentence-based learning
  bool get isSuitableForSentenceLearning {
    return isSentenceBasedLearning &&
        sentenceMetadata != null &&
        sentenceMetadata!.isReliableForLearning;
  }

  /// Get learning difficulty based on sentence analysis
  String get suggestedDifficulty {
    if (!isSentenceBasedLearning) return difficulty ?? 'unknown';

    final avgWordCount =
        sentences!.fold(0, (sum, sentence) => sum + sentence.wordCount) /
            sentences!.length;
    final avgConfidence = averageSentenceConfidence;

    if (avgWordCount <= 5 && avgConfidence >= 0.9) return 'beginner';
    if (avgWordCount <= 10 && avgConfidence >= 0.8) return 'intermediate';
    return 'advanced';
  }

  // Get human-readable status message
  String get statusMessage {
    switch (processingStatus) {
      case ProcessingStatus.uploading:
        return 'Uploading video...';
      case ProcessingStatus.moderating:
        return 'Checking content guidelines...';
      case ProcessingStatus.extractingAudio:
        return 'Extracting audio...';
      case ProcessingStatus.transcribing:
        return 'Converting speech to text...';
      case ProcessingStatus.translating:
        return 'Generating translations...';
      case ProcessingStatus.completed:
        return 'Ready to view!';
      case ProcessingStatus.failed:
        return processingError ?? 'Processing failed';
    }
  }

  // Get processing progress (0.0 to 1.0)
  double get processingProgress {
    switch (processingStatus) {
      case ProcessingStatus.uploading:
        return 0.1;
      case ProcessingStatus.moderating:
        return 0.25;
      case ProcessingStatus.extractingAudio:
        return 0.4;
      case ProcessingStatus.transcribing:
        return 0.65;
      case ProcessingStatus.translating:
        return 0.85;
      case ProcessingStatus.completed:
        return 1.0;
      case ProcessingStatus.failed:
        return 0.0;
    }
  }

  // Get estimated time remaining (in seconds)
  int get estimatedTimeRemaining {
    switch (processingStatus) {
      case ProcessingStatus.uploading:
        return 180; // 3 minutes
      case ProcessingStatus.moderating:
        return 120; // 2 minutes
      case ProcessingStatus.extractingAudio:
        return 90; // 1.5 minutes
      case ProcessingStatus.transcribing:
        return 60; // 1 minute
      case ProcessingStatus.translating:
        return 30; // 30 seconds
      case ProcessingStatus.completed:
        return 0;
      case ProcessingStatus.failed:
        return 0;
    }
  }

  // Check if user has liked this reel
  bool isLikedBy(String userId) => likedBy.contains(userId);

  // Check if user has saved this reel
  bool isSavedBy(String userId) => savedBy.contains(userId);

  // Get engagement rate
  double get engagementRate {
    if (views == 0) return 0.0;
    return (likes + comments + shares) / views;
  }

  // Get content quality score (based on AI confidence and user engagement)
  double get qualityScore {
    double aiScore = transcriptionConfidence ?? 0.0;
    double engagementScore = engagementRate * 100;
    double ratingScore = avgRating ?? 0.0;

    // NEW: Include sentence quality if available
    double sentenceScore = 1.0;
    if (isSentenceBasedLearning && sentenceMetadata != null) {
      sentenceScore = sentenceMetadata!.qualityScore;
    }

    return (aiScore + engagementScore + ratingScore + sentenceScore) / 4;
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorDisplayName': authorDisplayName,
      'authorAvatar': authorAvatar,
      'videoUrl': videoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'originalText': originalText,
      'sourceLanguage': sourceLanguage,
      'translations': translations,
      'transcriptionConfidence': transcriptionConfidence,

      // NEW: Sentence-based fields
      'hasSentenceData': hasSentenceData,
      'totalSentences': totalSentences,
      'sentences': sentences?.map((s) => s.toMap()).toList(),
      'sentenceMetadata': sentenceMetadata?.toMap(),

      'processingStatus': processingStatus.name,
      'isProcessed': isProcessed,
      'passedModeration': passedModeration,
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processingError': processingError,
      'processingMetadata': processingMetadata,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
      'likedBy': likedBy,
      'savedBy': savedBy,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tags': tags,
      'category': category,
      'difficulty': difficulty,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
    };
  }

  factory AILanguageReel.fromMap(Map<String, dynamic> map, String documentId) {
    return AILanguageReel(
      id: documentId,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorDisplayName: map['authorDisplayName'], // FIXED: This was missing
      authorAvatar: map['authorAvatar'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      originalText: map['originalText'],
      sourceLanguage: map['sourceLanguage'],
      translations: Map<String, String>.from(map['translations'] ?? {}),
      transcriptionConfidence: map['transcriptionConfidence']?.toDouble(),

      // NEW: Sentence-based fields
      hasSentenceData: map['hasSentenceData'] ?? false,
      totalSentences: map['totalSentences'] ?? 0,
      sentences: map['sentences'] != null
          ? (map['sentences'] as List<dynamic>)
              .map((sentenceMap) =>
                  SentenceData.fromMap(sentenceMap as Map<String, dynamic>))
              .toList()
          : null,
      sentenceMetadata: map['sentenceMetadata'] != null
          ? SentenceMetadata.fromMap(
              map['sentenceMetadata'] as Map<String, dynamic>)
          : null,

      processingStatus: ProcessingStatus.values.firstWhere(
        (e) => e.name == map['processingStatus'],
        orElse: () => ProcessingStatus.uploading,
      ),
      isProcessed: map['isProcessed'] ?? false,
      passedModeration: map['passedModeration'] ?? false,
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] as Timestamp).toDate()
          : null,
      processingError: map['processingError'],
      processingMetadata: map['processingMetadata'] != null
          ? Map<String, dynamic>.from(map['processingMetadata'])
          : null,
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      views: map['views'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      savedBy: List<String>.from(map['savedBy'] ?? []),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'],
      difficulty: map['difficulty'],
      avgRating: map['avgRating']?.toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
    );
  }

  // Create a copy with updated fields
  AILanguageReel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorDisplayName, // Added this parameter
    String? authorAvatar,
    String? videoUrl,
    DateTime? createdAt,
    String? originalText,
    String? sourceLanguage,
    Map<String, String>? translations,
    double? transcriptionConfidence,

    // NEW: Sentence-based parameters
    bool? hasSentenceData,
    int? totalSentences,
    List<SentenceData>? sentences,
    SentenceMetadata? sentenceMetadata,
    ProcessingStatus? processingStatus,
    bool? isProcessed,
    bool? passedModeration,
    DateTime? processedAt,
    String? processingError,
    Map<String, dynamic>? processingMetadata,
    int? likes,
    int? comments,
    int? shares,
    int? views,
    List<String>? likedBy,
    List<String>? savedBy,
    DateTime? updatedAt,
    List<String>? tags,
    String? category,
    String? difficulty,
    double? avgRating,
    int? ratingCount,
  }) {
    return AILanguageReel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorDisplayName:
          authorDisplayName ?? this.authorDisplayName, // Added this line
      authorAvatar: authorAvatar ?? this.authorAvatar,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      originalText: originalText ?? this.originalText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      translations: translations ?? this.translations,
      transcriptionConfidence:
          transcriptionConfidence ?? this.transcriptionConfidence,

      // NEW: Sentence-based fields
      hasSentenceData: hasSentenceData ?? this.hasSentenceData,
      totalSentences: totalSentences ?? this.totalSentences,
      sentences: sentences ?? this.sentences,
      sentenceMetadata: sentenceMetadata ?? this.sentenceMetadata,

      processingStatus: processingStatus ?? this.processingStatus,
      isProcessed: isProcessed ?? this.isProcessed,
      passedModeration: passedModeration ?? this.passedModeration,
      processedAt: processedAt ?? this.processedAt,
      processingError: processingError ?? this.processingError,
      processingMetadata: processingMetadata ?? this.processingMetadata,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      likedBy: likedBy ?? this.likedBy,
      savedBy: savedBy ?? this.savedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }

  @override
  String toString() {
    return 'AILanguageReel(id: $id, author: $authorName, language: $sourceLanguage, sentences: $totalSentences, processed: $isProcessed)';
  }
}

// Comment model for reels
class ReelComment {
  final String id;
  final String reelId;
  final String authorId;
  final String authorName;
  final String? authorDisplayName; // Added display name field
  final String authorAvatar;
  final String text;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;

  ReelComment({
    required this.id,
    required this.reelId,
    required this.authorId,
    required this.authorName,
    this.authorDisplayName, // Added this parameter
    required this.authorAvatar,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'reelId': reelId,
      'authorId': authorId,
      'authorName': authorName,
      'authorDisplayName': authorDisplayName, // Added this line
      'authorAvatar': authorAvatar,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  factory ReelComment.fromMap(Map<String, dynamic> map, String documentId) {
    return ReelComment(
      id: documentId,
      reelId: map['reelId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorDisplayName: map['authorDisplayName'], // Added this line
      authorAvatar: map['authorAvatar'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
    );
  }
}
