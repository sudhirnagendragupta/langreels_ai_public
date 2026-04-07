// lib/services/auth_service.dart
// Production version with Apple Sign In and account detection

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_profile.dart';
import '../utils/app_utils.dart';
import 'package:flutter/services.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ===== ACCOUNT DETECTION HELPERS =====

  /// Check what sign-in methods are associated with an email
  static Future<List<String>> getSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      return [];
    }
  }

  /// Get user-friendly provider name
  static String _getProviderName(String method) {
    if (method.contains('google')) return 'Google';
    if (method.contains('apple')) return 'Apple';
    if (method.contains('password')) return 'Email/Password';
    return 'another provider';
  }

  // ===== GOOGLE SIGN-IN =====

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Step 1: Get Google account
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.error('Google sign-in was cancelled');
      }

      final email = googleUser.email;

      // Step 2: Check if this email already exists with different provider
      final signInMethods = await getSignInMethodsForEmail(email);

      // If email exists but NOT with Google, show error
      if (signInMethods.isNotEmpty &&
          !signInMethods.any((m) => m.contains('google'))) {
        final existingProvider = _getProviderName(signInMethods.first);
        await _googleSignIn.signOut(); // Clean up
        return AuthResult.error(
            'An account with this email already exists. Please sign in using $existingProvider.');
      }

      // Step 3: Proceed with Google Sign In
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Failed to sign in with Google');
      }

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final userProfile = UserProfile(
          uid: user.uid,
          username: _generateUsername(user.email ?? user.uid),
          email: user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          languagePreferences: UserLanguagePreferences(),
          stats: UserStats(),
          isActive: true,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userProfile.toMap());
      } else {
        await _updateLastSeen(user.uid);
      }

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } on PlatformException catch (e) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        return AuthResult.success(currentUser);
      }
      return AuthResult.error(
          'Google sign-in error: ${e.message ?? "Unknown error"}');
    } catch (e) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        return AuthResult.success(currentUser);
      }
      return AuthResult.error('An unexpected error occurred');
    }
  }

  /// Sign out from Google
  static Future<void> _signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Silently fail - not critical
    }
  }

  // ===== APPLE SIGN-IN =====

  /// Sign in with Apple
  static Future<AuthResult> signInWithApple() async {
    try {
      // Step 1: Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthResult.error(
            'Apple Sign In is not available on this device');
      }

      // Step 2: Get Apple credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.example.langreelsAi',
          redirectUri: Uri.parse(
            'https://YOUR_FIREBASE_PROJECT_ID.firebaseapp.com/__/auth/handler',
          ),
        ),
      );

      // Step 3: Check if email already exists with different provider
      final email = appleCredential.email;

      if (email != null && email.isNotEmpty) {
        final signInMethods = await getSignInMethodsForEmail(email);

        // If email exists but NOT with Apple, show error
        if (signInMethods.isNotEmpty &&
            !signInMethods.any((m) => m.contains('apple'))) {
          final existingProvider = _getProviderName(signInMethods.first);
          return AuthResult.error(
              'An account with this email already exists. Please sign in using $existingProvider.');
        }
      }

      // Step 4: Proceed with Apple Sign In
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Failed to sign in with Apple');
      }

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        String? displayName;
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          displayName =
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim();
        }

        final userProfile = UserProfile(
          uid: user.uid,
          username: _generateUsername(user.email ?? user.uid),
          email: user.email ?? appleCredential.email ?? '',
          displayName: displayName ?? user.displayName,
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          languagePreferences: UserLanguagePreferences(),
          stats: UserStats(),
          isActive: true,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userProfile.toMap());
      } else {
        await _updateLastSeen(user.uid);
      }

      return AuthResult.success(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Apple sign-in was cancelled');
      }
      return AuthResult.error('Apple sign-in failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        return AuthResult.success(currentUser);
      }
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  /// Sign out from Apple (handled by Firebase)
  static Future<void> _signOutApple() async {
    // Apple sign-out is handled by Firebase Auth
    // No additional cleanup needed
  }

  // ===== EMAIL/PASSWORD AUTH =====

  // Sign up with email and password
  static Future<AuthResult> signUpWithEmailPassword({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    try {
      // Check if username is already taken
      final usernameExists = await _isUsernameExists(username);
      if (usernameExists) {
        return AuthResult.error('Username is already taken');
      }

      // Create user account
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Failed to create user account');
      }

      // Update display name
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      // Create user profile in Firestore
      final userProfile = UserProfile(
        uid: user.uid,
        username: username.toLowerCase().trim(),
        email: email.trim(),
        displayName: displayName,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        languagePreferences: UserLanguagePreferences(),
        stats: UserStats(),
        isActive: true,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userProfile.toMap());

      // Send email verification
      await user.sendEmailVerification();

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Sign in with email and password
  static Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Failed to sign in');
      }

      // Update last seen
      await _updateLastSeen(user.uid);

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Sign out (includes Google and Apple sign-out)
  static Future<AuthResult> signOut() async {
    try {
      // Sign out from Google if signed in
      await _signOutGoogle();

      // Sign out from Apple (handled by Firebase)
      await _signOutApple();

      // Sign out from Firebase
      await _auth.signOut();
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.error('Failed to sign out: ${e.toString()}');
    }
  }

  // Reset password
  static Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to send reset email: ${e.toString()}');
    }
  }

  // Update password
  static Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to update password: ${e.toString()}');
    }
  }

  // Update email
  static Future<AuthResult> updateEmail({
    required String newEmail,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Update email
      await user.updateEmail(newEmail.trim());

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to update email: ${e.toString()}');
    }
  }

  // Delete account
  static Future<AuthResult> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await _deleteUserData(user.uid);

      // Delete user account
      await user.delete();

      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to delete account: ${e.toString()}');
    }
  }

  // Send email verification
  static Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      if (user.emailVerified) {
        return AuthResult.error('Email is already verified');
      }

      await user.sendEmailVerification();
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error(
          'Failed to send verification email: ${e.toString()}');
    }
  }

  // Check if email is verified
  static Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    return user.emailVerified;
  }

  // Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  static Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .update(profile.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  // Check if username exists
  static Future<bool> _isUsernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Update last seen timestamp
  static Future<void> _updateLastSeen(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Delete all user data
  static Future<void> _deleteUserData(String userId) async {
    try {
      final batch = _firestore.batch();

      // Delete user profile
      batch.delete(_firestore.collection('users').doc(userId));

      // Delete user's reels
      final reelsQuery = await _firestore
          .collection('reels')
          .where('authorId', isEqualTo: userId)
          .get();

      for (final doc in reelsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's comments
      final commentsQuery = await _firestore
          .collection('comments')
          .where('authorId', isEqualTo: userId)
          .get();

      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  // Generate username from email
  static String _generateUsername(String emailOrUid) {
    final base =
        emailOrUid.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return base.toLowerCase();
  }

  // Get Firebase Auth error message
  static String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}

// Auth result class
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  AuthResult._(this.isSuccess, this.errorMessage, this.user);

  factory AuthResult.success(User? user) {
    return AuthResult._(true, null, user);
  }

  factory AuthResult.error(String message) {
    return AuthResult._(false, message, null);
  }
}

// Auth state enum
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

// Auth exceptions
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}
