import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserRole _activeRole = UserRole.beneficiary;
  UserRole get activeRole => _activeRole;

  Future<void> loadActiveRole() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('activeRole');
    _activeRole =
        saved == UserRole.donor.name ? UserRole.donor : UserRole.beneficiary;
    notifyListeners();
  }

  Future<void> setActiveRole(UserRole role) async {
    _activeRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeRole', role.name);
    notifyListeners();
  }

  /// Register a new user — returns null on success, error string on failure.
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final success = await signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
    return success ? null : _errorMessage;
  }

  /// Sign up a new user and send email verification OTP.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
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
        role: UserRole.beneficiary,
        isEmailVerified: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(user.toFirestore());

      _userModel = user;

      // Send OTP via Cloud Function (non-fatal if it fails — user can resend)
      try {
        await _functions.httpsCallable('sendEmailVerificationOTP').call({
          'uid': credential.user!.uid,
          'email': email.trim(),
          'name': fullName.trim(),
        });
      } catch (_) {}

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      await credential?.user?.delete();
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Verify email using the 6-digit OTP code.
  Future<bool> verifyEmailOTP(String code) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = currentUser;
      if (user == null) {
        _errorMessage = 'No user session found. Please sign up again.';
        _setLoading(false);
        return false;
      }

      await _functions.httpsCallable('verifyEmailOTP').call({
        'uid': user.uid,
        'code': code.trim(),
      });

      _userModel = _userModel?.copyWith(isEmailVerified: true);
      _setLoading(false);
      return true;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = _getOTPErrorMessage(e.code, e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Resend the email verification OTP.
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

      await _functions.httpsCallable('sendEmailVerificationOTP').call({
        'uid': user.uid,
        'email': user.email,
        'name': _userModel?.fullName ?? 'there',
      });

      _setLoading(false);
      return true;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = e.message ?? 'Failed to resend code.';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to resend code. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// Sign in existing user.
  Future<bool> signIn({
    required String email,
    required String password,
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
      await loadActiveRole();

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

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  /// Validate a password reset OTP without changing the password.
  Future<String?> checkPasswordResetCode(String email, String code) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _functions.httpsCallable('checkPasswordResetCode').call({
        'email': email.trim(),
        'code': code.trim(),
      });
      _setLoading(false);
      return null;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = _getOTPErrorMessage(e.code, e.message);
      _setLoading(false);
      return _errorMessage;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      _setLoading(false);
      return _errorMessage;
    }
  }

  /// Send password reset OTP to the given email.
  Future<String?> sendPasswordResetOTP(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _functions.httpsCallable('sendPasswordResetOTP').call({
        'email': email.trim(),
      });
      _setLoading(false);
      return null;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = e.message ?? 'Failed to send reset code.';
      _setLoading(false);
      return _errorMessage;
    } catch (e) {
      _errorMessage = 'Failed to send reset code. Please try again.';
      _setLoading(false);
      return _errorMessage;
    }
  }

  /// Verify OTP and reset password in one step.
  Future<String?> resetPasswordWithOTP({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _functions.httpsCallable('resetPasswordWithOTP').call({
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
      _setLoading(false);
      return null;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = _getOTPErrorMessage(e.code, e.message);
      _setLoading(false);
      return _errorMessage;
    } catch (e) {
      _errorMessage = 'Failed to reset password. Please try again.';
      _setLoading(false);
      return _errorMessage;
    }
  }

  /// Load current user data.
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

  /// Alias for loadUserData (used by AuthWrapper).
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

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  String _getOTPErrorMessage(String code, String? message) {
    switch (code) {
      case 'not-found':
        return message ?? 'No code found. Please request a new one.';
      case 'deadline-exceeded':
        return message ?? 'Code expired. Please request a new one.';
      case 'unauthenticated':
        return 'Incorrect code. Please try again.';
      case 'already-exists':
        return 'Code already used. Please request a new one.';
      case 'invalid-argument':
        return message ?? 'Invalid request.';
      case 'unavailable':
        return message ?? 'Email service unavailable. Please try again.';
      case 'internal':
        return 'Something went wrong. Please try again later.';
      default:
        return message ?? 'Operation failed. Please try again.';
    }
  }
}
