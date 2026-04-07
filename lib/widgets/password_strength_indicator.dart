// lib/widgets/password_strength_indicator.dart

import 'package:flutter/material.dart';
import '../utils/password_validator.dart';
import '../constants/app_constants.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showDetails;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return SizedBox.shrink();
    }

    final result = PasswordValidator.validate(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        _buildStrengthBar(result),

        if (showDetails) ...[
          SizedBox(height: 8),

          // Strength label
          _buildStrengthLabel(result),

          // Requirements checklist
          if (result.strength != PasswordStrength.strong) ...[
            SizedBox(height: 12),
            _buildRequirementsList(result),
          ],
        ],
      ],
    );
  }

  Widget _buildStrengthBar(PasswordValidationResult result) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.grey[800],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: result.strengthScore,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: _getStrengthColor(result.strength),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthLabel(PasswordValidationResult result) {
    return Row(
      children: [
        Icon(
          _getStrengthIcon(result.strength),
          size: 16,
          color: _getStrengthColor(result.strength),
        ),
        SizedBox(width: 6),
        Text(
          'Password strength: ${PasswordValidator.getStrengthText(result.strength)}',
          style: TextStyle(
            fontSize: 12,
            color: _getStrengthColor(result.strength),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsList(PasswordValidationResult result) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          _buildRequirement(
            'At least 8 characters',
            password.length >= 8,
          ),
          _buildRequirement(
            'One uppercase letter (A-Z)',
            RegExp(r'[A-Z]').hasMatch(password),
          ),
          _buildRequirement(
            'One lowercase letter (a-z)',
            RegExp(r'[a-z]').hasMatch(password),
          ),
          _buildRequirement(
            'One number (0-9)',
            RegExp(r'[0-9]').hasMatch(password),
          ),
          _buildRequirement(
            'One special character (!@#\$%^&*...)',
            RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(password),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey[600],
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? Colors.grey[300] : Colors.grey[500],
                decoration: isMet ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  IconData _getStrengthIcon(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Icons.error;
      case PasswordStrength.medium:
        return Icons.warning;
      case PasswordStrength.strong:
        return Icons.check_circle;
    }
  }
}

/// Compact version for smaller spaces
class CompactPasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const CompactPasswordStrengthIndicator({
    Key? key,
    required this.password,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return SizedBox.shrink();
    }

    final result = PasswordValidator.validate(password);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.grey[800],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: result.strengthScore,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: _getStrengthColor(result.strength),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          PasswordValidator.getStrengthText(result.strength),
          style: TextStyle(
            fontSize: 11,
            color: _getStrengthColor(result.strength),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }
}
