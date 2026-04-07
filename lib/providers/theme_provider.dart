// lib/providers/theme_provider.dart - SIMPLE VERSION

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true; // Start with dark mode

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      // print('Loaded theme: isDarkMode = $_isDarkMode');
      notifyListeners();
    } catch (e) {
      // print('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      // print('Toggled theme: isDarkMode = $_isDarkMode');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', _isDarkMode);

      notifyListeners();
      // print(
      //     'Theme toggle completed - Theme is now: ${_isDarkMode ? "Dark" : "Light"}');
    } catch (e) {
      // print('Error toggling theme: $e');
    }
  }

  // For debugging - call this to check state
  void debugTheme() {
    // print(
    //     'Current theme state: isDarkMode = $_isDarkMode, themeMode = $themeMode');
  }
}
