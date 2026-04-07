// lib/screens/main_screen.dart - Complete working version with video pause

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/reel_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_utils.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'create/create_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // FIXED: Callback to communicate with home screen
  Function(bool)? _homeScreenVisibilityCallback;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize screens with callback registration
    _screens = [
      HomeScreen(
        onVisibilityChanged: (callback) {
          _homeScreenVisibilityCallback = callback;
          // print('📱 MainScreen: Home screen callback registered');
        },
      ),
      SearchScreen(),
      CreateScreen(),
      ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // print('📱 App lifecycle state changed to: $state');
  }

  // Public method to navigate to specific tab
  void navigateToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      _notifyHomeScreenVisibility(index);

      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: AppConstants.shortAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    // print('📱 MainScreen: Tab tapped - $index');

    // FIXED: Notify home screen before changing tab
    _notifyHomeScreenVisibility(index);

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: AppConstants.shortAnimation,
      curve: Curves.easeInOut,
    );
  }

  // FIXED: Direct communication with home screen
  void _notifyHomeScreenVisibility(int newIndex) {
    if (_homeScreenVisibilityCallback != null) {
      final isHomeVisible = newIndex == 0;
      // print('📱 MainScreen: Notifying home screen visibility = $isHomeVisible');
      _homeScreenVisibilityCallback!(isHomeVisible);
    } else {
      // print('📱 MainScreen: No home screen callback available');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // print('📱 MainScreen: Page changed to $index');

          // FIXED: Handle swipe navigation
          _notifyHomeScreenVisibility(index);

          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isActive: _currentIndex == 0,
                ),
                _buildNavItem(
                  icon: Icons.search,
                  label: 'Search',
                  index: 1,
                  isActive: _currentIndex == 1,
                ),
                _buildCreateButton(),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 3,
                  isActive: _currentIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.grey[400],
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isActive ? AppColors.primary : Colors.grey[400],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.aiPrimary, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // Getter for current index (used by other screens)
  int get currentIndex => _currentIndex;
}
