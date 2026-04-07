// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../auth/auth_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'AI-Powered Creation',
      subtitle: 'Record videos and let AI handle the rest',
      description:
          'Simply record yourself teaching any language concept. Our AI automatically transcribes, translates, and makes your content accessible worldwide.',
      icon: Icons.auto_awesome,
      gradient: [AppColors.aiPrimary, AppColors.primary],
    ),
    OnboardingPage(
      title: 'Global Language Access',
      subtitle: 'One video, 15+ languages instantly',
      description:
          'Your content is automatically translated and made available to learners of all supported languages. Create once, teach globally.',
      icon: Icons.translate,
      gradient: [AppColors.aiSecondary, AppColors.secondary],
    ),
    OnboardingPage(
      title: 'Smart Community',
      subtitle: 'Learn from real people worldwide',
      description:
          'Discover authentic language content from native speakers and learners. AI ensures safe, educational content for everyone.',
      icon: Icons.people,
      gradient: [AppColors.success, AppColors.info],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Info
            _buildTopSection(),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Bottom Navigation
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.aiPrimary, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                AppConstants.appName,
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Skip Button
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                'Skip',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    return AnimationLimiter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: AnimationConfiguration.toStaggeredList(
            duration: AppConstants.mediumAnimation,
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              // Icon with gradient background
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: page.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient[0].withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 48),

              // Title
              Text(
                page.title,
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16),

              // Subtitle
              Text(
                page.subtitle,
                style: AppTextStyles.h4.copyWith(
                  color: page.gradient[0],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24),

              // Description
              Text(
                page.description,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: AppConstants.shortAnimation,
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              // Previous Button
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousPage,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Previous',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              if (_currentPage > 0) SizedBox(width: 16),

              // Next/Get Started Button
              Expanded(
                flex: _currentPage == 0 ? 1 : 1,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1
                      ? _completeOnboarding
                      : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppConstants.mediumAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AppConstants.mediumAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.completeOnboarding();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AuthWrapper()),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}
