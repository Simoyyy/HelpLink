import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/constants.dart';

class AuthService extends ChangeNotifier {
  static const String _kLoginTimestampKey = 'loginTimestamp';
  static const int _kSessionDays = 30;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  // Holds signup data in memory until the Firestore doc is created after OTP.
  UserModel? _pendingUserData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserRole _activeRole = UserRole.beneficiary;
  UserRole get activeRole => _activeRole;

  bool _icVerificationPromptShown = false;
  bool get icVerificationPromptShown => _icVerificationPromptShown;
  void markICVerificationPromptShown() => _icVerificationPromptShown = true;

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

  /// Sign up: creates Firebase Auth account and sends OTP.
  /// The Firestore user document is NOT created here — it is created only
  /// after the user successfully enters the OTP in [verifyEmailOTP].
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

      // Persist fullName in Firebase Auth so it survives app restarts before
      // the Firestore document has been created.
      await credential.user!.updateDisplayName(fullName.trim());

      _pendingUserData = UserModel(
        uid: credential.user!.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        role: UserRole.beneficiary,
        isEmailVerified: false,
        createdAt: DateTime.now(),
      );

      // Send OTP via Cloud Function (non-fatal if it fails — user can resend)
      try {
        String? fcmToken;
        try { fcmToken = await FirebaseMessaging.instance.getToken(); } catch (_) {}
        await _functions.httpsCallable('sendEmailVerificationOTP').call({
          'uid': credential.user!.uid,
          'email': email.trim(),
          'name': fullName.trim(),
          if (fcmToken != null) 'fcmToken': fcmToken,
        });
      } catch (e) {
        debugPrint('OTP send failed: $e');
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Account exists in Firebase Auth — check if it's still unverified
        // (no Firestore doc). If so, re-send OTP so the user can complete
        // registration. If it's fully verified, show the normal error.
        return await _recoverUnverifiedAccount(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
        );
      }
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

  /// Called when "email-already-in-use" is returned during sign-up.
  /// Signs in with the given credentials and checks for a Firestore document.
  /// If none exists (OTP was never completed), re-sends OTP and returns true
  /// so the caller navigates to the verification screen.
  Future<bool> _recoverUnverifiedAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final existing = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = existing.user!.uid;

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        // Unverified account — update displayName with the new fullName and
        // re-send OTP so the user can complete verification.
        await existing.user!.updateDisplayName(fullName);
        _pendingUserData = UserModel(
          uid: uid,
          fullName: fullName,
          email: email,
          role: UserRole.beneficiary,
          isEmailVerified: false,
          createdAt: DateTime.now(),
        );
        try {
          String? fcmToken;
          try { fcmToken = await FirebaseMessaging.instance.getToken(); } catch (_) {}
          await _functions.httpsCallable('sendEmailVerificationOTP').call({
            'uid': uid,
            'email': email,
            'name': fullName,
            if (fcmToken != null) 'fcmToken': fcmToken,
          });
        } catch (_) {}
        _setLoading(false);
        return true;
      } else {
        // Account is fully verified — sign back out and show error.
        await _auth.signOut();
        _errorMessage = 'This email is already registered. Please log in.';
        _setLoading(false);
        return false;
      }
    } catch (_) {
      // Wrong password or sign-in failed — the account is protected.
      _errorMessage = 'This email is already registered. Please log in.';
      _setLoading(false);
      return false;
    }
  }

  /// Verify email using the 6-digit OTP code.
  /// On success, creates the Firestore user document with isEmailVerified: true.
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

      // OTP accepted — create the Firestore user document now.
      final pending = _pendingUserData ??
          UserModel(
            uid: user.uid,
            fullName: user.displayName ?? '',
            email: user.email ?? '',
            role: UserRole.beneficiary,
            isEmailVerified: true,
            createdAt: DateTime.now(),
          );

      final verifiedUser = pending.copyWith(isEmailVerified: true);

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(verifiedUser.toFirestore());

      _userModel = verifiedUser;
      _pendingUserData = null;

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

      String? fcmToken;
      try { fcmToken = await FirebaseMessaging.instance.getToken(); } catch (_) {}
      await _functions.httpsCallable('sendEmailVerificationOTP').call({
        'uid': user.uid,
        'email': user.email,
        'name': _pendingUserData?.fullName ?? _userModel?.fullName ?? user.displayName ?? 'there',
        if (fcmToken != null) 'fcmToken': fcmToken,
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
        // Firebase Auth account exists but OTP was never completed.
        // Restore pending data so login_screen routes to /verify-email
        // where the user can resend and complete verification.
        _pendingUserData ??= UserModel(
          uid: credential.user!.uid,
          fullName: credential.user!.displayName ?? '',
          email: email.trim(),
          role: UserRole.beneficiary,
          isEmailVerified: false,
          createdAt: DateTime.now(),
        );
        _userModel = _pendingUserData;
        await loadActiveRole();
        _setLoading(false);
        return true;
      }

      _userModel = UserModel.fromFirestore(userDoc);
      await loadActiveRole();
      await _saveLoginTimestamp();

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoginTimestampKey);
    await _auth.signOut();
    _userModel = null;
    _pendingUserData = null;
    _icVerificationPromptShown = false;
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

  /// Load current user data from Firestore.
  /// If no Firestore document exists (OTP not yet completed), restores
  /// pending data from Firebase Auth so the verification screen works.
  Future<void> loadUserData() async {
    if (currentUser == null) return;

    if (await _isSessionExpired()) {
      await signOut();
      return;
    }

    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        _userModel = UserModel.fromFirestore(userDoc);
        notifyListeners();
      } else if (_pendingUserData == null) {
        // No Firestore document yet — unverified account on app restart.
        // Restore from Firebase Auth displayName so the verification screen
        // can show the correct email and the resend button works.
        // Guard with _pendingUserData == null to prevent redundant notifyListeners calls.
        _pendingUserData = UserModel(
          uid: currentUser!.uid,
          fullName: currentUser!.displayName ?? '',
          email: currentUser!.email ?? '',
          role: UserRole.beneficiary,
          isEmailVerified: false,
          createdAt: DateTime.now(),
        );
        _userModel = _pendingUserData;
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

  Future<void> _saveLoginTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kLoginTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns true if more than 30 days have passed since the last login.
  /// If no timestamp exists (user was already logged in before this feature
  /// was added), saves the current time and returns false so they are not
  /// immediately logged out.
  Future<bool> _isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt(_kLoginTimestampKey);
    if (savedMs == null) {
      await prefs.setInt(
          _kLoginTimestampKey, DateTime.now().millisecondsSinceEpoch);
      return false;
    }
    final loginTime = DateTime.fromMillisecondsSinceEpoch(savedMs);
    return DateTime.now().difference(loginTime).inDays >= _kSessionDays;
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

  String _getOTPErrorMessage(String code, String? message) {
    switch (code.toLowerCase()) {
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
