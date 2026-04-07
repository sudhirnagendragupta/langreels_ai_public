// lib/models/sentence_data.dart
// Model for individual sentence with timing and translations

class SentenceData {
  final String originalText;
  final double startTime;
  final double endTime;
  final int index;
  final double confidence;
  final Map<String, String> translations;
  final List<WordData>? words; // Optional word-level data

  SentenceData({
    required this.originalText,
    required this.startTime,
    required this.endTime,
    required this.index,
    required this.confidence,
    required this.translations,
    this.words,
  });

  /// Get translation for a specific language code
  String getTranslation(String languageCode) {
    return translations[languageCode] ?? originalText;
  }

  /// Get sentence duration in seconds
  double get duration => endTime - startTime;

  /// Get sentence duration as Duration object
  Duration get durationObject =>
      Duration(milliseconds: (duration * 1000).round());

  /// Check if sentence contains a specific text (case-insensitive)
  bool contains(String searchText) {
    final search = searchText.toLowerCase();
    return originalText.toLowerCase().contains(search) ||
        translations.values
            .any((translation) => translation.toLowerCase().contains(search));
  }

  /// Get formatted time range string
  String get timeRangeString {
    final start = Duration(milliseconds: (startTime * 1000).round());
    final end = Duration(milliseconds: (endTime * 1000).round());
    return '${_formatDuration(start)} - ${_formatDuration(end)}';
  }

  /// Check if this sentence is currently active at given video position
  bool isActiveAt(double videoPosition) {
    return videoPosition >= startTime && videoPosition <= endTime;
  }

  /// Get confidence level as string
  String get confidenceLevel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  /// Check if sentence is short enough for comfortable reading
  bool get isComfortableLength => originalText.length <= 100;

  /// Get word count
  int get wordCount => originalText.split(' ').length;

  /// Get reading time estimate in seconds (average 200 words per minute)
  double get estimatedReadingTime => (wordCount / 200) * 60;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  /// Create from Firestore map
  factory SentenceData.fromMap(Map<String, dynamic> map) {
    return SentenceData(
      originalText: map['originalText'] ?? '',
      startTime: (map['startTime'] ?? 0.0).toDouble(),
      endTime: (map['endTime'] ?? 0.0).toDouble(),
      index: map['index'] ?? 0,
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      translations: Map<String, String>.from(map['translations'] ?? {}),
      words: map['words'] != null
          ? (map['words'] as List<dynamic>)
              .map((wordMap) =>
                  WordData.fromMap(wordMap as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'originalText': originalText,
      'startTime': startTime,
      'endTime': endTime,
      'index': index,
      'confidence': confidence,
      'translations': translations,
      'words': words?.map((word) => word.toMap()).toList(),
    };
  }

  /// Create a copy with updated fields
  SentenceData copyWith({
    String? originalText,
    double? startTime,
    double? endTime,
    int? index,
    double? confidence,
    Map<String, String>? translations,
    List<WordData>? words,
  }) {
    return SentenceData(
      originalText: originalText ?? this.originalText,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      index: index ?? this.index,
      confidence: confidence ?? this.confidence,
      translations: translations ?? this.translations,
      words: words ?? this.words,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SentenceData &&
        other.originalText == originalText &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.index == index;
  }

  @override
  int get hashCode {
    return originalText.hashCode ^
        startTime.hashCode ^
        endTime.hashCode ^
        index.hashCode;
  }

  @override
  String toString() {
    return 'SentenceData(index: $index, text: "${originalText.length > 50 ? originalText.substring(0, 50) + '...' : originalText}", time: ${timeRangeString}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Individual word data with timing (optional, for advanced features)
class WordData {
  final String word;
  final double startTime;
  final double endTime;
  final double confidence;

  WordData({
    required this.word,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });

  double get duration => endTime - startTime;

  bool isActiveAt(double videoPosition) {
    return videoPosition >= startTime && videoPosition <= endTime;
  }

  factory WordData.fromMap(Map<String, dynamic> map) {
    return WordData(
      word: map['word'] ?? '',
      startTime: (map['startTime'] ?? 0.0).toDouble(),
      endTime: (map['endTime'] ?? 0.0).toDouble(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'startTime': startTime,
      'endTime': endTime,
      'confidence': confidence,
    };
  }

  @override
  String toString() {
    return 'WordData(word: "$word", time: $startTime-$endTime, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Metadata about sentence processing
class SentenceMetadata {
  final int totalSentences;
  final double totalDuration;
  final double averageConfidence;
  final double extractionConfidence;
  final List<String> translationMappingWarnings;
  final String processingTimestamp;

  SentenceMetadata({
    required this.totalSentences,
    required this.totalDuration,
    required this.averageConfidence,
    required this.extractionConfidence,
    required this.translationMappingWarnings,
    required this.processingTimestamp,
  });

  /// Get average sentence duration
  double get averageSentenceDuration =>
      totalSentences > 0 ? totalDuration / totalSentences : 0.0;

  /// Get overall quality score (0.0 to 1.0)
  double get qualityScore {
    double confidenceScore = averageConfidence;
    double warningPenalty = translationMappingWarnings.length * 0.1;
    return (confidenceScore - warningPenalty).clamp(0.0, 1.0);
  }

  /// Get quality description
  String get qualityDescription {
    final score = qualityScore;
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.8) return 'Very Good';
    if (score >= 0.7) return 'Good';
    if (score >= 0.6) return 'Fair';
    return 'Poor';
  }

  /// Check if sentence data is reliable for learning
  bool get isReliableForLearning => qualityScore >= 0.7;

  factory SentenceMetadata.fromMap(Map<String, dynamic> map) {
    return SentenceMetadata(
      totalSentences: map['totalSentences'] ?? 0,
      totalDuration: (map['totalDuration'] ?? 0.0).toDouble(),
      averageConfidence: (map['averageConfidence'] ?? 0.0).toDouble(),
      extractionConfidence: (map['extractionConfidence'] ?? 0.0).toDouble(),
      translationMappingWarnings:
          List<String>.from(map['translationMappingWarnings'] ?? []),
      processingTimestamp: map['processingTimestamp'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSentences': totalSentences,
      'totalDuration': totalDuration,
      'averageConfidence': averageConfidence,
      'extractionConfidence': extractionConfidence,
      'translationMappingWarnings': translationMappingWarnings,
      'processingTimestamp': processingTimestamp,
    };
  }

  @override
  String toString() {
    return 'SentenceMetadata(sentences: $totalSentences, duration: ${totalDuration.toStringAsFixed(1)}s, quality: $qualityDescription)';
  }
}
