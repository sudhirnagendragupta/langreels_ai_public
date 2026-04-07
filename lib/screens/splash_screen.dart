// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Offset> _slideAnimation;

  bool _disposed = false; // Track disposal state

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: AppConstants.shortAnimation,
      vsync: this,
    );

    // Logo scale animation
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Text fade animation
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    // Slide animation
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startSplashSequence() async {
    try {
      // Start logo animation
      if (!_disposed && mounted) {
        await _logoController.forward();
      }

      // Wait a bit, then start text animation
      await Future.delayed(Duration(milliseconds: 200));

      if (!_disposed && mounted) {
        await _textController.forward();
      }

      // Wait for minimum splash duration
      await Future.delayed(Duration(milliseconds: 1500));

      // Initialize auth and navigate
      if (!_disposed && mounted) {
        await _initializeAuth();
      }
    } catch (e) {
      // print('Splash animation error: $e');
      // If animations fail, still try to initialize auth
      if (!_disposed && mounted) {
        await _initializeAuth();
      }
    }
  }

  Future<void> _initializeAuth() async {
    try {
      // AuthProvider initialization is handled automatically in its constructor
      // The AppNavigator will check the auth state and navigate appropriately
      // No need to call any specific methods here

      // Just wait a moment for any provider initialization to complete
      await Future.delayed(Duration(milliseconds: 500));

      // Navigation will be handled by AppNavigator in main.dart
      // based on the auth state
    } catch (e) {
      // print('Auth initialization error: $e');
      // Continue anyway - AuthProvider will handle the error state
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundDark,
              AppColors.aiPrimary.withOpacity(0.1),
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.aiPrimary, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aiPrimary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 40),

                // Animated Text
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _textAnimation,
                    child: Column(
                      children: [
                        Text(
                          'LangReels AI',
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'AI-Powered Language Learning',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[400],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 60),

                // Loading Indicator
                FadeTransition(
                  opacity: _textAnimation,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.aiPrimary,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
