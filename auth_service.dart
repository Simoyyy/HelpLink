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
  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Store verification code temporarily (in production, store server-side)
  String? _verificationCode;

  /// Sign up a new user
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        _errorMessage = 'Failed to create account. Please try again.';
        _setLoading(false);
        return false;
      }

      // Generate 6-digit verification code
      _verificationCode = _generateVerificationCode();

      // Create user document in Firestore
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

      // Store verification code in Firestore
      await _firestore
          .collection('email_verifications')
          .doc(credential.user!.uid)
          .set({
        'code': _verificationCode,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      });

      // Send verification email via Firebase Auth
      await credential.user!.sendEmailVerification();

      _userModel = user;
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

  /// Verify email with 6-digit code
  Future<bool> verifyEmail(String code) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final userId = currentUser?.uid;
      if (userId == null) {
        _errorMessage = 'No user session found. Please sign up again.';
        _setLoading(false);
        return false;
      }

      // Check verification code from Firestore
      final verificationDoc = await _firestore
          .collection('email_verifications')
          .doc(userId)
          .get();

      if (!verificationDoc.exists) {
        _errorMessage = 'Verification code not found. Please request a new one.';
        _setLoading(false);
        return false;
      }

      final data = verificationDoc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        _errorMessage = 'Verification code has expired. Please request a new one.';
        _setLoading(false);
        return false;
      }

      if (code != storedCode) {
        _errorMessage = 'Invalid verification code. Please try again.';
        _setLoading(false);
        return false;
      }

      // Mark email as verified in Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'isEmailVerified': true});

      // Clean up verification document
      await _firestore
          .collection('email_verifications')
          .doc(userId)
          .delete();

      // Update local model
      _userModel = _userModel?.copyWith(isEmailVerified: true);

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Resend verification code
  Future<bool> resendVerificationCode() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final userId = currentUser?.uid;
      if (userId == null) {
        _errorMessage = 'No user session found.';
        _setLoading(false);
        return false;
      }

      _verificationCode = _generateVerificationCode();

      await _firestore
          .collection('email_verifications')
          .doc(userId)
          .set({
        'code': _verificationCode,
        'email': currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      });

      await currentUser!.sendEmailVerification();

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to resend code. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Sign in existing user
  Future<bool> signIn({
    required String email,
    required String password,
    required String role,
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

      // Fetch user data from Firestore
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

      // Validate role matches
      if (_userModel!.role != role) {
        _errorMessage =
            'This account is registered as a ${_userModel!.role}. '
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

  /// Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
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

  // ── Helpers ──

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

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
