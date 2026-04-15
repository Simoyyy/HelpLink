import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Register a new user — returns null on success, error string on failure.
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final success = await signUp(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
    return success ? null : _errorMessage;
  }

  /// Sign up a new user
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        _errorMessage = 'Failed to create account. Please try again.';
        _setLoading(false);
        return false;
      }

      final user = UserModel(
        uid: credential.user!.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        role: role,
        isEmailVerified: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(user.toFirestore());

      // Send standard Firebase email verification link
      await credential.user!.sendEmailVerification();

      _userModel = user;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      // If Firestore setup failed after the Firebase Auth account was created,
      // delete the orphaned auth account so the user can retry with the same email.
      await credential?.user?.delete();
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Confirm email verification using Firebase's emailVerified flag.
  Future<bool> verifyEmail() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;

      if (user == null) {
        _errorMessage = 'No user session found. Please sign up again.';
        _setLoading(false);
        return false;
      }

      if (!user.emailVerified) {
        _errorMessage =
            'Your email is not verified yet. Please click the verification link in your email.';
        _setLoading(false);
        return false;
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({'isEmailVerified': true});

      _userModel = _userModel?.copyWith(isEmailVerified: true);

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Resend the standard Firebase email verification message.
  Future<bool> resendVerificationEmail() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = currentUser;
      if (user == null) {
        _errorMessage = 'No user session found.';
        _setLoading(false);
        return false;
      }

      await user.sendEmailVerification();

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage =
          'Failed to resend verification email. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Sign in existing user
  Future<bool> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        _errorMessage = 'Failed to sign in. Please try again.';
        _setLoading(false);
        return false;
      }

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        _errorMessage = 'Account not found. Please sign up first.';
        await _auth.signOut();
        _setLoading(false);
        return false;
      }

      _userModel = UserModel.fromFirestore(userDoc);

      if (_userModel!.role != role) {
        _errorMessage =
            'This account is registered as a ${_userModel!.role.name}. '
            'Please select the correct role.';
        await _auth.signOut();
        _userModel = null;
        _setLoading(false);
        return false;
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  /// Reset password — returns null on success, error string on failure.
  Future<String?> resetPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return _errorMessage;
    }
  }

  /// Load current user data
  Future<void> loadUserData() async {
    if (currentUser == null) return;

    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        _userModel = UserModel.fromFirestore(userDoc);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  /// Alias for loadUserData (used by AuthWrapper)
  Future<void> fetchUserData() => loadUserData();

  /// Change password — returns null on success, error string on failure.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        _setLoading(false);
        return 'No user session found.';
      }

      // Re-authenticate before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return _getAuthErrorMessage(e.code);
    } catch (e) {
      _setLoading(false);
      return 'Failed to change password. Please try again.';
    }
  }

  // ── Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
