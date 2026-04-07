// lib/widgets/auth/apple_signin_button.dart
// Create this new file

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../constants/app_constants.dart';

class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const AppleSignInButton({
    Key? key,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SignInWithApple.isAvailable(),
      builder: (context, snapshot) {
        // Only show button if Apple Sign In is available
        if (!snapshot.hasData || !snapshot.data!) {
          return SizedBox.shrink();
        }

        return Material(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else ...[
                    Icon(
                      Icons.apple,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Continue with Apple',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
