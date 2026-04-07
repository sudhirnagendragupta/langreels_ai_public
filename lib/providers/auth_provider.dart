// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isFirstTime = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isFirstTime => _isFirstTime;
  String? get userId => _user?.uid;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) async {
        _user = user;

        if (user != null) {
          await _loadUserProfile(user.uid);
        } else {
          _userProfile = null;
        }

        _isLoading = false;
        notifyListeners();
      });

      // Check if this is first time opening the app
      _isFirstTime = await _checkFirstTime();
    } catch (e) {
      // print('Auth initialization error: $e');
      _isLoading = false;
      _errorMessage = 'Failed to initialize authentication';
      notifyListeners();
    }
  }

  Future<bool> _checkFirstTime() async {
    // You can implement your own logic here
    // For now, let's assume it's not first time
    return false;
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _userProfile = doc.data();
      } else {
        // Create default profile
        _userProfile = {
          'uid': userId,
          'email': _user?.email ?? '',
          'username': _generateUsername(_user?.email ?? ''),
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
          'reelsCount': 0,
          'followersCount': 0,
          'savedReels': [],
          'languagePreferences': {
            'primaryLanguage': 'en',
            'learningLanguages': ['es', 'fr'],
            'proficiencyLevels': {'es': 'beginner', 'fr': 'beginner'},
          },
        };

        // Save to Firestore
        await _firestore.collection('users').doc(userId).set(_userProfile!);
      }
    } catch (e) {
      // print('Error loading user profile: $e');
      // Create minimal profile if Firestore fails
      _userProfile = {
        'uid': userId,
        'email': _user?.email ?? '',
        'username': _generateUsername(_user?.email ?? ''),
        'bio': '',
        'reelsCount': 0,
        'followersCount': 0,
        'savedReels': [],
        'languagePreferences': {
          'primaryLanguage': 'en',
          'learningLanguages': ['es', 'fr'],
          'proficiencyLevels': {'es': 'beginner', 'fr': 'beginner'},
        },
      };
    }
  }

  String _generateUsername(String email) {
    return email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  // Method aliases for backward compatibility
  Future<bool> signIn(String email, String password) async {
    return await signInWithEmailAndPassword(email, password);
  }

  Future<bool> signUp(String email, String password) async {
    return await createUserWithEmailAndPassword(email, password);
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        // User profile will be loaded automatically by auth state listener
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      // print('Sign in error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      // print('Unexpected sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        // User profile will be created automatically by auth state listener
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      // print('Sign up error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      // print('Unexpected sign up error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userProfile = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign out';
      // print('Sign out error: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email';
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    _isFirstTime = false;
    notifyListeners();
  }

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Public method to refresh user profile data
  Future<void> refreshUserProfile() async {
    if (_user?.uid != null) {
      await _loadUserProfile(_user!.uid);
      notifyListeners();
    }
  }
}
