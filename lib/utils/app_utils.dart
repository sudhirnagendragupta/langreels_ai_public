// lib/utils/app_utils.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class AppUtils {
  // Date & Time Formatting
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  static String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // File Size Formatting
  static String formatFileSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  // Validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // UPDATED: Enhanced password validation
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(password)) {
      return false;
    }
    return true;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (!isValidUsername(value)) {
      return 'Username must be 3-20 characters (letters, numbers, underscore)';
    }
    return null;
  }

  // UPDATED: Enhanced password validation with detailed error messages
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Generate Avatar
  static String generateAvatar(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  // Generate Color from String
  static Color generateColorFromString(String text) {
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    hash = hash.abs();

    return Color.fromRGBO(
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
      1.0,
    );
  }

  // NEW: Avatar utilities for comments
  static String getInitials(String name) {
    if (name.isEmpty) return 'U';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  static Color getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.primary;

    // Generate a consistent color based on the name
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    hash = hash.abs();

    // Define a set of pleasing colors for avatars
    final colors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
      Color(0xFFEF4444), // Red
      Color(0xFFF59E0B), // Amber
      Color(0xFF10B981), // Emerald
      Color(0xFF06B6D4), // Cyan
      Color(0xFF3B82F6), // Blue
      Color(0xFF84CC16), // Lime
      Color(0xFFF97316), // Orange
    ];

    return colors[hash % colors.length];
  }

  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Device Info
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Responsive Sizing
  static double getResponsiveWidth(BuildContext context, double baseWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 768) {
      return baseWidth * 1.2; // Larger screens
    } else if (screenWidth < 360) {
      return baseWidth * 0.9; // Smaller screens
    }
    return baseWidth;
  }

  static double getResponsiveFontSize(
      BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 768) {
      return baseFontSize * 1.1;
    } else if (screenWidth < 360) {
      return baseFontSize * 0.95;
    }
    return baseFontSize;
  }

  // Error Handling
  static String getErrorMessage(dynamic error) {
    if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (error.toString().contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    } else if (error.toString().contains('not-found')) {
      return 'Content not found.';
    } else if (error.toString().contains('unauthenticated')) {
      return 'Please log in to continue.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  // Snackbar Utilities
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Loading Dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              if (message != null) ...[
                SizedBox(height: 16),
                Text(
                  message,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Confirmation Dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTextStyles.h4),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText, style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppColors.primary,
            ),
            child: Text(confirmText, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Language Helpers
  static String getLanguageDisplayName(String languageCode) {
    return SupportedLanguages.getLanguageName(languageCode);
  }

  static String getLanguageFlag(String languageCode) {
    return SupportedLanguages.getLanguageFlag(languageCode);
  }

  // Video Helpers
  static bool isValidVideoFile(String path) {
    final extensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    return extensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  static Duration? parseVideoDuration(String? durationString) {
    if (durationString == null) return null;

    try {
      final parts = durationString.split(':');
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      } else if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // URL Helpers
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Theme Helpers
  static Brightness getBrightness(BuildContext context) {
    return Theme.of(context).brightness;
  }

  static bool isDarkMode(BuildContext context) {
    return getBrightness(context) == Brightness.dark;
  }

  // Safe Area Helpers
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double getBottomSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }
}

// Extensions for enhanced functionality
extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get truncate {
    if (length <= 50) return this;
    return '${substring(0, 47)}...';
  }

  bool get isValidEmail => AppUtils.isValidEmail(this);
  bool get isValidUsername => AppUtils.isValidUsername(this);
  bool get isValidPassword => AppUtils.isValidPassword(this);
}

extension DateTimeExtensions on DateTime {
  String get timeAgo => AppUtils.formatTimeAgo(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

extension DurationExtensions on Duration {
  String get formatted => AppUtils.formatDuration(this);
}

extension IntExtensions on int {
  String get formatted => AppUtils.formatCount(this);
  String get fileSize => AppUtils.formatFileSize(this);
}

extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet => AppUtils.isTablet(this);
  bool get isLandscape => AppUtils.isLandscape(this);
  bool get isDarkMode => AppUtils.isDarkMode(this);

  void showSuccessSnackbar(String message) =>
      AppUtils.showSuccessSnackbar(this, message);

  void showErrorSnackbar(String message) =>
      AppUtils.showErrorSnackbar(this, message);

  void showInfoSnackbar(String message) =>
      AppUtils.showInfoSnackbar(this, message);

  void showLoadingDialog([String? message]) =>
      AppUtils.showLoadingDialog(this, message: message);

  void hideLoadingDialog() => AppUtils.hideLoadingDialog(this);

  Future<bool> showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) =>
      AppUtils.showConfirmationDialog(
        this,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
      );
}
