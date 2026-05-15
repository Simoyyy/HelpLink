import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/widgets/otp_input_box.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 1 — email
  final _emailController = TextEditingController();
  String? _emailError;

  // Step 2 — code verification
  bool _codeSent = false;
  String _sentToEmail = '';
  String _code = '';
  String? _codeError;
  final _otpKey = GlobalKey<OtpInputBoxState>();

  // Step 3 — new password (revealed after code verified)
  bool _codeVerified = false;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Step 1: send OTP ──────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    setState(() => _emailError = null);

    final authService = context.read<AuthService>();
    final error = await authService.sendPasswordResetOTP(email);

    if (!mounted) return;
    if (error != null) {
      setState(() => _emailError = error);
    } else {
      setState(() {
        _sentToEmail = email;
        _codeSent = true;
      });
    }
  }

  // ── Step 2: verify code ───────────────────────────────────────────────────

  Future<void> _verifyCode() async {
    if (_code.length < 6) {
      setState(() => _codeError = 'Please enter all 6 digits.');
      return;
    }
    setState(() => _codeError = null);

    final authService = context.read<AuthService>();
    final error =
        await authService.checkPasswordResetCode(_sentToEmail, _code);

    if (!mounted) return;
    if (error != null) {
      // Wrong code — clear input and show error
      _otpKey.currentState?.clear();
      setState(() {
        _code = '';
        _codeError = error;
      });
    } else {
      setState(() => _codeVerified = true);
    }
  }

  Future<void> _resendCode() async {
    final authService = context.read<AuthService>();
    final error = await authService.sendPasswordResetOTP(_sentToEmail);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'New code sent!'),
        backgroundColor:
            error == null ? AppTheme.successGreen : AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    if (error == null) {
      _otpKey.currentState?.clear();
      setState(() {
        _code = '';
        _codeError = null;
      });
    }
  }

  // ── Step 3: reset password ────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 6) {
      setState(
          () => _passwordError = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _passwordError = 'Passwords do not match.');
      return;
    }
    setState(() => _passwordError = null);

    final authService = context.read<AuthService>();
    final error = await authService.resetPasswordWithOTP(
      email: _sentToEmail,
      code: _code,
      newPassword: password,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() => _passwordError = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset successfully! Please log in.'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              IconButton(
                onPressed: () {
                  if (_codeVerified) {
                    setState(() {
                      _codeVerified = false;
                      _passwordError = null;
                    });
                  } else if (_codeSent) {
                    setState(() {
                      _codeSent = false;
                      _codeError = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 24),
              if (!_codeSent)
                ..._emailStep(authService)
              else if (!_codeVerified)
                ..._codeStep(authService)
              else
                ..._passwordStep(authService),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1 UI ─────────────────────────────────────────────────────────────

  List<Widget> _emailStep(AuthService authService) => [
        const Text('Forgot Password',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text("Enter your email and we'll send you a reset code.",
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
        const SizedBox(height: 40),
        if (_emailError != null) ...[
          _errorBox(_emailError!),
          const SizedBox(height: 16),
        ],
        const Text('Email',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'your.email@example.com',
            prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: authService.isLoading ? null : _sendCode,
            child: authService.isLoading
                ? _loader()
                : const Text('Send Reset Code'),
          ),
        ),
        const SizedBox(height: 32),
      ];

  // ── Step 2 UI ─────────────────────────────────────────────────────────────

  List<Widget> _codeStep(AuthService authService) => [
        const Text('Enter Reset Code',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: AppTheme.textMuted),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _sentToEmail,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        OtpInputBox(
          key: _otpKey,
          activeColor: AppTheme.primaryBlue,
          onChanged: (v) => setState(() => _code = v),
        ),

        if (_codeError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_codeError!),
        ],

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: authService.isLoading ? null : _resendCode,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Resend Code'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_code.length == 6 && !authService.isLoading)
                ? _verifyCode
                : null,
            child: authService.isLoading ? _loader() : const Text('Verify Code'),
          ),
        ),
        const SizedBox(height: 32),
      ];

  // ── Step 3 UI ─────────────────────────────────────────────────────────────

  List<Widget> _passwordStep(AuthService authService) => [
        const Text('New Password',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('Choose a strong password for your account.',
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
        const SizedBox(height: 32),

        // Verified badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.successGreen.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppTheme.successGreen, size: 18),
              SizedBox(width: 8),
              Text('Code verified',
                  style: TextStyle(
                      color: AppTheme.successGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text('New Password',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[500],
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Text('Confirm New Password',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[500],
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),

        if (_passwordError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_passwordError!),
        ],

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: authService.isLoading ? null : _resetPassword,
            child: authService.isLoading
                ? _loader()
                : const Text('Reset Password'),
          ),
        ),
        const SizedBox(height: 32),
      ];

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppTheme.errorRed, fontSize: 14)),
            ),
          ],
        ),
      );

  Widget _loader() => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: Colors.white),
      );
}
