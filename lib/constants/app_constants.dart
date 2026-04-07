// lib/constants/app_constants.dart

import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'LangReels AI';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-powered language learning platform';

  // Video Constraints
  static const int maxVideoDurationSeconds = 120; // 2 minutes
  static const int minVideoDurationSeconds = 5; // 5 seconds
  static const double videoAspectRatio = 9 / 16; // TikTok style
  static const int maxVideoFileSizeMB = 100;

  // AI Processing
  static const int processingTimeoutSeconds = 300; // 5 minutes
  static const double transcriptionConfidenceThreshold = 0.7;
  static const int maxRetryAttempts = 3;

  // Pagination
  static const int reelsPerPage = 20;
  static const int commentsPerPage = 50;
  static const int usersPerPage = 30;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration videoLoadTimeout = Duration(seconds: 10);
}

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF2196F3); // Modern blue
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  // Secondary Colors
  static const Color secondary = Color(0xFF00BCD4); // Cyan
  static const Color secondaryDark = Color(0xFF00838F);
  static const Color secondaryLight = Color(0xFF4DD0E1);

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFF9800); // Orange
  static const Color error = Color(0xFFF44336); // Red
  static const Color info = Color(0xFF2196F3); // Blue

  // AI Feature Colors
  static const Color aiPrimary = Color(0xFF6C63FF); // Purple for AI features
  static const Color aiSecondary = Color(0xFF00D4AA); // Teal for processing
  static const Color aiAccent = Color(0xFFFF6B6B); // Coral for highlights

  // Dark Theme
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2D2D2D);

  // Light Theme
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF5F5F5);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnLight = Color(0xFF212121);

  // Social Colors
  static const Color like = Color(0xFFE91E63); // Pink
  static const Color comment = Color(0xFF2196F3); // Blue
  static const Color share = Color(0xFF4CAF50); // Green
  static const Color save = Color(0xFFFF9800); // Orange

  // Processing Status Colors
  static const Color uploading = Color(0xFF2196F3);
  static const Color moderating = Color(0xFF9C27B0);
  static const Color transcribing = Color(0xFF4CAF50);
  static const Color translating = Color(0xFF00BCD4);
  static const Color completed = Color(0xFF8BC34A);
  static const Color failed = Color(0xFFF44336);
}

class AppTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Button Text
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Caption & Labels
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Special Styles
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
  );
}

class SupportedLanguages {
  static const Map<String, LanguageInfo> languages = {
    'en': LanguageInfo('English', '🇺🇸', 'en-US'),
    'es': LanguageInfo('Spanish', '🇪🇸', 'es-ES'),
    'fr': LanguageInfo('French', '🇫🇷', 'fr-FR'),
    'de': LanguageInfo('German', '🇩🇪', 'de-DE'),
    'it': LanguageInfo('Italian', '🇮🇹', 'it-IT'),
    'pt': LanguageInfo('Portuguese', '🇧🇷', 'pt-BR'),
    'ja': LanguageInfo('Japanese', '🇯🇵', 'ja-JP'),
    'ko': LanguageInfo('Korean', '🇰🇷', 'ko-KR'),
    'zh': LanguageInfo('Chinese', '🇨🇳', 'zh-CN'),
    'hi': LanguageInfo('Hindi', '🇮🇳', 'hi-IN'),
    'kn': LanguageInfo('Kannada', '🇮🇳', 'kn-IN'),
    'mr': LanguageInfo('Marathi', '🇮🇳', 'mr-IN'),
    'ar': LanguageInfo('Arabic', '🇸🇦', 'ar-SA'),
    'ru': LanguageInfo('Russian', '🇷🇺', 'ru-RU'),
    'nl': LanguageInfo('Dutch', '🇳🇱', 'nl-NL'),
  };

  static String getLanguageName(String code) {
    return languages[code]?.name ?? code.toUpperCase();
  }

  static String getLanguageFlag(String code) {
    return languages[code]?.flag ?? '🌐';
  }

  static String getLanguageLocale(String code) {
    return languages[code]?.locale ?? code;
  }

  static List<String> get supportedCodes => languages.keys.toList();

  static List<MapEntry<String, LanguageInfo>> get languageEntries =>
      languages.entries.toList();

  static List<LanguageInfo> get allLanguages => languages.values.toList();
}

class LanguageInfo {
  final String name;
  final String flag;
  final String locale;

  const LanguageInfo(this.name, this.flag, this.locale);
}

class AppRoutes {
  // Auth Routes
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Main Routes
  static const String home = '/home';
  static const String main = '/main';
  static const String create = '/create';
  static const String profile = '/profile';
  static const String search = '/search';

  // Secondary Routes
  static const String settings = '/settings';
  static const String languageSettings = '/language-settings';
  static const String editProfile = '/edit-profile';
  static const String reelDetails = '/reel-details';
  static const String userProfile = '/user-profile';
  static const String processing = '/processing';

  // AI Routes
  static const String aiCreate = '/ai-create';
  static const String processingStatus = '/processing-status';
  static const String aiInsights = '/ai-insights';
}

class AppImages {
  static const String _basePath = 'assets/images/';

  // Logos & Branding
  static const String logo = '${_basePath}logo.png';
  static const String logoWhite = '${_basePath}logo_white.png';
  static const String logoIcon = '${_basePath}logo_icon.png';

  // Onboarding
  static const String onboarding1 = '${_basePath}onboarding_1.png';
  static const String onboarding2 = '${_basePath}onboarding_2.png';
  static const String onboarding3 = '${_basePath}onboarding_3.png';

  // Placeholders
  static const String avatarPlaceholder = '${_basePath}avatar_placeholder.png';
  static const String videoPlaceholder = '${_basePath}video_placeholder.png';
  static const String noContent = '${_basePath}no_content.png';

  // AI Features
  static const String aiProcessor = '${_basePath}ai_processor.png';
  static const String aiTranscription = '${_basePath}ai_transcription.png';
  static const String aiTranslation = '${_basePath}ai_translation.png';
}

class AppAnimations {
  static const String _basePath = 'assets/animations/';

  // Loading Animations
  static const String loading = '${_basePath}loading.json';
  static const String aiProcessing = '${_basePath}ai_processing.json';
  static const String uploading = '${_basePath}uploading.json';

  // Success/Error Animations
  static const String success = '${_basePath}success.json';
  static const String error = '${_basePath}error.json';
  static const String celebration = '${_basePath}celebration.json';

  // Feature Animations
  static const String microphone = '${_basePath}microphone.json';
  static const String translation = '${_basePath}translation.json';
  static const String globe = '${_basePath}globe.json';
}

class ProcessingStatusColors {
  static Color getStatusColor(String status) {
    switch (status) {
      case 'uploading':
        return AppColors.uploading;
      case 'moderating':
        return AppColors.moderating;
      case 'extractingAudio':
        return AppColors.info;
      case 'transcribing':
        return AppColors.transcribing;
      case 'translating':
        return AppColors.translating;
      case 'completed':
        return AppColors.completed;
      case 'failed':
        return AppColors.failed;
      default:
        return AppColors.info;
    }
  }

  static String getStatusMessage(String status) {
    switch (status) {
      case 'uploading':
        return 'Uploading video...';
      case 'moderating':
        return 'Checking content safety...';
      case 'extractingAudio':
        return 'Extracting audio...';
      case 'transcribing':
        return 'Converting speech to text...';
      case 'translating':
        return 'Creating translations...';
      case 'completed':
        return 'Ready to share!';
      case 'failed':
        return 'Processing failed';
      default:
        return 'Processing...';
    }
  }
}
