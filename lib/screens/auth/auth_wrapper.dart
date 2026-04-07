// lib/screens/auth/auth_wrapper.dart
// CORRECTED VERSION - Uses existing GoogleSignInButton and AppleSignInButton widgets

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/auth/google_signin_button.dart';
import '../../widgets/auth/apple_signin_button.dart';
import '../../widgets/password_strength_indicator.dart';
import '../../utils/password_validator.dart';

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _scrollController = ScrollController();
  final _emailFieldKey = GlobalKey();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToForm() {
    // Scroll to show the form fields
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        final context = _emailFieldKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.3, // Position at 30% from top
          );
        }
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await AuthService.signInWithGoogle();

      if (result.isSuccess) {
        if (mounted) {
          context.showSuccessSnackbar('Signed in successfully!');
        }
      } else {
        if (mounted) {
          context.showErrorSnackbar(result.errorMessage ?? 'Sign in failed');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isAppleLoading = true);

    try {
      final result = await AuthService.signInWithApple();

      if (result.isSuccess) {
        if (mounted) {
          context.showSuccessSnackbar('Signed in successfully!');
        }
      } else {
        if (mounted) {
          context.showErrorSnackbar(result.errorMessage ?? 'Sign in failed');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isAppleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(height: 60),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.aiPrimary, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
              ),

              SizedBox(height: 32),

              Text(
                _isLogin ? 'Welcome Back!' : 'Join LangReels',
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text(
                _isLogin
                    ? 'Sign in to continue your language learning journey'
                    : 'Start your AI-powered language learning journey',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 40),

              // Google Sign-In Button
              GoogleSignInButton(
                onPressed: _handleGoogleSignIn,
                isLoading: _isGoogleLoading,
              ),

              SizedBox(height: 16),

              // Apple Sign-In Button
              AppleSignInButton(
                onPressed: _handleAppleSignIn,
                isLoading: _isAppleLoading,
              ),

              SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[700])),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[700])),
                ],
              ),

              SizedBox(height: 24),

              // Tab buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() => _isLogin = true);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              _isLogin ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isLogin
                                ? AppColors.primary
                                : Colors.grey[700]!,
                          ),
                        ),
                        child: Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() => _isLogin = false);
                          _scrollToForm();
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isLogin
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isLogin
                                ? AppColors.primary
                                : Colors.grey[700]!,
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Email Field
              TextFormField(
                key: _emailFieldKey,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon:
                      Icon(Icons.email_outlined, color: Colors.grey[400]),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Username Field (Sign Up only)
              if (!_isLogin) ...[
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon:
                        Icon(Icons.person_outline, color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: Colors.white),
                onChanged: (value) {
                  // Update UI for password strength indicator
                  if (!_isLogin && mounted) {
                    setState(() {});
                    // Auto-scroll when strength indicator appears
                    if (value.isNotEmpty) {
                      Future.delayed(Duration(milliseconds: 100), () {
                        if (mounted && _scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    }
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      if (mounted) {
                        setState(() => _obscurePassword = !_obscurePassword);
                      }
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),

              // Password Strength Indicator (Sign Up only)
              if (!_isLogin && _passwordController.text.isNotEmpty) ...[
                SizedBox(height: 16),
                PasswordStrengthIndicator(
                  password: _passwordController.text,
                  showDetails: true,
                ),
              ],

              SizedBox(height: 24),

              // Sign In/Up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? 'Sign In' : 'Sign Up',
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              if (_isLogin) ...[
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.showInfoSnackbar('Password reset coming soon');
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],

              // FIXED: Add mounted check and better error handling
              _buildErrorDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Separate error display widget with proper checks
  Widget _buildErrorDisplay() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!mounted || authProvider.errorMessage == null) {
          return SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  authProvider.errorMessage!,
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        context.showErrorSnackbar('Please fill in all fields');
      }
      return;
    }

    if (!_isLogin) {
      if (username.isEmpty) {
        if (mounted) {
          context.showErrorSnackbar('Please enter a username');
        }
        return;
      }

      // Validate password strength for sign-up
      final validation = PasswordValidator.validate(password);
      if (!validation.isValid) {
        if (mounted) {
          context.showErrorSnackbar(validation.errors.first);
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      if (_isLogin) {
        final result = await AuthService.signInWithEmailPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          if (result.isSuccess) {
            context.showSuccessSnackbar('Welcome back!');
          } else {
            context.showErrorSnackbar(result.errorMessage ?? 'Sign in failed');
          }
        }
      } else {
        final result = await AuthService.signUpWithEmailPassword(
          email: email,
          password: password,
          username: username,
        );

        if (mounted) {
          if (result.isSuccess) {
            context.showSuccessSnackbar(
                'Account created! Please check your email for verification.');
          } else {
            context.showErrorSnackbar(result.errorMessage ?? 'Sign up failed');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
