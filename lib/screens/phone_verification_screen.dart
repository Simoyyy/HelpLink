import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/widgets/otp_input_box.dart';

enum _Step { chooseMethod, oldOtp, enterPhone, smsOtp }

/// Full phone verification / change flow.
///
/// [isChange] — true when the user already has a verified phone and wants to
///   change it. Shows an identity-confirmation step first.
/// [existingPhone] — masked display of the current number (e.g. +601*****789).
/// [userEmail] — used for the email OTP path during change confirmation.
/// [userId] — Firestore user doc ID.
/// [onVerified] — called with the new phone number string on success.
class PhoneVerificationScreen extends StatefulWidget {
  final bool isChange;
  final String? existingPhone;
  final String userEmail;
  final String userId;
  final void Function(String phoneNumber) onVerified;

  const PhoneVerificationScreen({
    super.key,
    required this.isChange,
    this.existingPhone,
    required this.userEmail,
    required this.userId,
    required this.onVerified,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  _Step _step = _Step.enterPhone;

  // Old-identity confirmation (change flow only)
  bool _useEmailForOld = true;
  String _oldOtp = '';
  final _oldOtpKey = GlobalKey<OtpInputBoxState>();
  // New phone entry
  final _phoneCtrl = TextEditingController();

  // SMS OTP (Firebase Phone Auth)
  String _smsOtp = '';
  String? _verificationId;
  final _smsOtpKey = GlobalKey<OtpInputBoxState>();

  bool _isLoading = false;
  String? _error;

  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @override
  void initState() {
    super.initState();
    _step = widget.isChange ? _Step.chooseMethod : _Step.enterPhone;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _error = msg);
  void _setLoading(bool v) => setState(() { _isLoading = v; _error = null; });

  // ── Step 1 (change only): choose method ────────────────────────────────────

  Future<void> _sendOldOtp() async {
    _setLoading(true);
    try {
      if (_useEmailForOld) {
        await _functions.httpsCallable('sendPhoneChangeOTP').call({
          'uid': widget.userId,
          'email': widget.userEmail,
          'name': '',
        });
      } else {
        // Send SMS OTP to the existing phone via Firebase Phone Auth
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: widget.existingPhone ?? '',
          timeout: const Duration(seconds: 60),
          verificationCompleted: (_) {},
          verificationFailed: (e) {
            _setLoading(false);
            _setError(e.message ?? 'Failed to send OTP to old number.');
          },
          codeSent: (verificationId, _) {
            setState(() {
              _verificationId = verificationId;
              _step = _Step.oldOtp;
              _isLoading = false;
            });
          },
          codeAutoRetrievalTimeout: (id) => _verificationId = id,
        );
        return;
      }
      setState(() { _step = _Step.oldOtp; _isLoading = false; });
    } on FirebaseFunctionsException catch (e) {
      _setLoading(false);
      _setError(e.message ?? 'Failed to send OTP.');
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
    }
  }

  Future<void> _verifyOldOtp() async {
    if (_oldOtp.length < 6) return;
    _setLoading(true);
    try {
      if (_useEmailForOld) {
        await _functions.httpsCallable('verifyPhoneChangeOTP').call({
          'uid': widget.userId,
          'code': _oldOtp,
        });
      } else {
        // Verify SMS OTP for old number via Firebase Phone Auth
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _oldOtp,
        );
        // Re-authenticate with the old phone credential to confirm identity
        await FirebaseAuth.instance.currentUser
            ?.reauthenticateWithCredential(credential);
      }
      // Reset verificationId so the new phone OTP step starts fresh
      _verificationId = null;
      setState(() { _step = _Step.enterPhone; _isLoading = false; });
    } on FirebaseFunctionsException catch (e) {
      _setLoading(false);
      _setError(e.message ?? 'Incorrect code. Please try again.');
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _setError(e.message ?? 'Incorrect code. Please try again.');
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
    }
  }

  // ── Step 2: enter new phone number ─────────────────────────────────────────

  Future<void> _sendSmsOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) { _setError('Enter a phone number.'); return; }
    if (!phone.startsWith('+')) {
      _setError('Include the country code, e.g. +601...');
      return;
    }
    _setLoading(true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _verifyWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        _setLoading(false);
        _setError(e.message ?? 'Failed to send SMS. Check the number and try again.');
      },
      codeSent: (String verificationId, int? _) {
        setState(() {
          _verificationId = verificationId;
          _step = _Step.smsOtp;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Step 3: verify SMS OTP for new number ──────────────────────────────────

  Future<void> _verifySmsOtp() async {
    if (_smsOtp.length < 6 || _verificationId == null) return;
    _setLoading(true);
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _smsOtp,
    );
    await _verifyWithCredential(credential);
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      // Link temporarily to prove the user owns this number, then unlink.
      await user.linkWithCredential(credential);
      await user.unlink('phone');
      if (mounted) widget.onVerified(_phoneCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        // The user's account already has this phone linked — treat as verified.
        try { await FirebaseAuth.instance.currentUser?.unlink('phone'); } catch (_) {}
        if (mounted) widget.onVerified(_phoneCtrl.text.trim());
        return;
      }
      if (e.code == 'credential-already-in-use') {
        _setLoading(false);
        _setError('This phone number is already linked to another account.');
        return;
      }
      _setLoading(false);
      _setError(e.message ?? 'Invalid code. Please try again.');
    } catch (_) {
      _setLoading(false);
      _setError('Verification failed. Please try again.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_appBarTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildStep(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.errorRed))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _appBarTitle {
    switch (_step) {
      case _Step.chooseMethod: return 'Confirm Your Identity';
      case _Step.oldOtp: return 'Enter Confirmation Code';
      case _Step.enterPhone: return widget.isChange ? 'Enter New Number' : 'Verify Phone Number';
      case _Step.smsOtp: return 'Enter SMS Code';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.chooseMethod: return _buildChooseMethod();
      case _Step.oldOtp: return _buildOldOtp();
      case _Step.enterPhone: return _buildEnterPhone();
      case _Step.smsOtp: return _buildSmsOtp();
    }
  }

  // ── Choose method ──────────────────────────────────────────────────────────

  Widget _buildChooseMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'To change your phone number, confirm your identity first.',
          style: TextStyle(fontSize: 15, color: AppTheme.textDark, height: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          'How should we send the confirmation code?',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        _methodCard(
          icon: Icons.email_outlined,
          title: 'Send to my email',
          subtitle: _maskEmail(widget.userEmail),
          selected: _useEmailForOld,
          onTap: () => setState(() => _useEmailForOld = true),
        ),
        const SizedBox(height: 12),
        _methodCard(
          icon: Icons.phone_android_outlined,
          title: 'Send to my current phone',
          subtitle: widget.existingPhone ?? '',
          selected: !_useEmailForOld,
          onTap: () => setState(() => _useEmailForOld = false),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOldOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Send Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (selected ? AppTheme.primaryBlue : AppTheme.textMuted).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: selected ? AppTheme.primaryBlue : AppTheme.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppTheme.primaryBlue : AppTheme.textDark)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ])),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 22),
        ]),
      ),
    );
  }

  // ── Old OTP ────────────────────────────────────────────────────────────────

  Widget _buildOldOtp() {
    final destination = _useEmailForOld
        ? 'your email (${_maskEmail(widget.userEmail)})'
        : 'your current phone (${widget.existingPhone ?? ''})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter the 6-digit code sent to $destination.',
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
        const SizedBox(height: 28),
        OtpInputBox(
          key: _oldOtpKey,
          activeColor: AppTheme.primaryBlue,
          onChanged: (v) => setState(() => _oldOtp = v),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _sendOldOtp,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Resend'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue, textStyle: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_oldOtp.length == 6 && !_isLoading) ? _verifyOldOtp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Confirm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ── Enter phone ────────────────────────────────────────────────────────────

  Widget _buildEnterPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter your phone number with the country code.',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
        const SizedBox(height: 8),
        const Text('A verification code will be sent to this number via SMS.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 28),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 15, color: AppTheme.textDark),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_android_outlined, color: AppTheme.primaryBlue),
            hintText: '+601XXXXXXXX',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            helperText: 'Start with your country code, e.g. +60 for Malaysia',
            helperStyle: const TextStyle(fontSize: 11),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendSmsOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Send SMS Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ── SMS OTP ────────────────────────────────────────────────────────────────

  Widget _buildSmsOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter the 6-digit SMS code sent to ${_phoneCtrl.text.trim()}.',
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
        const SizedBox(height: 28),
        OtpInputBox(
          key: _smsOtpKey,
          activeColor: AppTheme.primaryBlue,
          onChanged: (v) => setState(() => _smsOtp = v),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isLoading ? null : () {
              _smsOtpKey.currentState?.clear();
              setState(() { _smsOtp = ''; _step = _Step.enterPhone; });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Change number / Resend'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue, textStyle: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_smsOtp.length == 6 && !_isLoading) ? _verifySmsOtp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Verify & Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? name
        : '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@${parts[1]}';
  }
}
