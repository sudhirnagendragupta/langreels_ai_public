// lib/utils/password_validator.dart
// SIMPLIFIED VERSION - Only checks the 5 core requirements

/// Password strength levels
enum PasswordStrength {
  weak,
  medium,
  strong,
}

/// Password validation result
class PasswordValidationResult {
  final bool isValid;
  final PasswordStrength strength;
  final List<String> errors;
  final List<String> suggestions;
  final double strengthScore; // 0.0 to 1.0

  PasswordValidationResult({
    required this.isValid,
    required this.strength,
    required this.errors,
    required this.suggestions,
    required this.strengthScore,
  });
}

class PasswordValidator {
  // Minimum requirements
  static const int minLength = 8;
  static const int maxLength = 64;

  /// Validates password and returns detailed result
  static PasswordValidationResult validate(String password) {
    final errors = <String>[];
    final suggestions = <String>[];
    int strengthPoints = 0;
    const maxPoints = 7;

    // Check minimum length
    if (password.isEmpty) {
      errors.add('Password is required');
      return PasswordValidationResult(
        isValid: false,
        strength: PasswordStrength.weak,
        errors: errors,
        suggestions: ['Enter a password'],
        strengthScore: 0.0,
      );
    }

    if (password.length < minLength) {
      errors.add('Password must be at least $minLength characters');
      suggestions.add('Add more characters (min $minLength)');
    } else {
      strengthPoints++; // +1 for meeting minimum length
    }

    if (password.length > maxLength) {
      errors.add('Password must be less than $maxLength characters');
    }

    // Check for uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      errors.add('Password must contain at least one uppercase letter');
      suggestions.add('Add an uppercase letter (A-Z)');
    } else {
      strengthPoints++; // +1 for uppercase
    }

    // Check for lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      errors.add('Password must contain at least one lowercase letter');
      suggestions.add('Add a lowercase letter (a-z)');
    } else {
      strengthPoints++; // +1 for lowercase
    }

    // Check for number
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      errors.add('Password must contain at least one number');
      suggestions.add('Add a number (0-9)');
    } else {
      strengthPoints++; // +1 for number
    }

    // Check for special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(password)) {
      errors.add('Password must contain at least one special character');
      suggestions.add('Add a special character (!@#\$%^&*...)');
    } else {
      strengthPoints++; // +1 for special char
    }

    // Bonus points for longer passwords
    if (password.length >= 12) {
      strengthPoints++; // +1 for 12+ characters
    }

    if (password.length >= 16) {
      strengthPoints++; // +1 for 16+ characters
    }

    // Calculate strength score (0.0 to 1.0)
    final strengthScore = strengthPoints / maxPoints;

    // Determine strength level
    PasswordStrength strength;
    if (strengthScore >= 0.75) {
      strength = PasswordStrength.strong;
    } else if (strengthScore >= 0.5) {
      strength = PasswordStrength.medium;
    } else {
      strength = PasswordStrength.weak;
    }

    // Final validation
    final isValid = errors.isEmpty;

    return PasswordValidationResult(
      isValid: isValid,
      strength: strength,
      errors: errors,
      suggestions: suggestions,
      strengthScore: strengthScore,
    );
  }

  /// Quick validation for minimum requirements (for form validation)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    final result = validate(value);

    if (result.errors.isNotEmpty) {
      // Return the first critical error
      return result.errors.first;
    }

    return null;
  }

  /// Check if password meets minimum requirements
  static bool meetsMinimumRequirements(String password) {
    return password.length >= minLength &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(password);
  }

  /// Get password strength as text
  static String getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }
}
