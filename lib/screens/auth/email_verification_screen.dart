import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/utils/theme.dart';
import 'package:helplink/widgets/otp_input_box.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _otpKey = GlobalKey<OtpInputBoxState>();
  String _code = '';
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      final type = message.data['type'];
      final code = message.data['code'];
      if (type == 'otp' && code != null && (code as String).length == 6) {
        _otpKey.currentState?.fill(code);
        setState(() => _code = code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification code received!'),
            backgroundColor: HelpLinkTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final authService = context.read<AuthService>();
    final success = await authService.verifyEmailOTP(_code);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email verified! Please log in.'),
          backgroundColor: HelpLinkTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Incorrect code. Please try again.'),
          backgroundColor: HelpLinkTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _resend() async {
    final authService = context.read<AuthService>();
    final success = await authService.resendVerificationEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'New code sent!'
            : (authService.errorMessage ?? 'Failed to resend')),
        backgroundColor:
            success ? HelpLinkTheme.success : HelpLinkTheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    if (success) {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final email = authService.currentUser?.email ?? 'your email';

    return Scaffold(
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 32,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HelpLinkTheme.beneficiaryGradientStart,
                  HelpLinkTheme.beneficiaryGradientEnd,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to $email',
                  style:
                      const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 36),

                  // Email icon + label
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: HelpLinkTheme.beneficiaryPrimary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 36,
                            color: HelpLinkTheme.beneficiaryPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Check your inbox',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: const TextStyle(
                                fontSize: 13,
                                color: HelpLinkTheme.textSecondary)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text('Verification Code',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  OtpInputBox(
                    key: _otpKey,
                    activeColor: HelpLinkTheme.beneficiaryPrimary,
                    onChanged: (v) => setState(() => _code = v),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: authService.isLoading ? null : _resend,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Resend Code'),
                      style: TextButton.styleFrom(
                        foregroundColor: HelpLinkTheme.beneficiaryPrimary,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_code.length == 6 && !authService.isLoading)
                              ? _verify
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HelpLinkTheme.beneficiaryPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            HelpLinkTheme.beneficiaryPrimary
                                .withValues(alpha: 0.4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: authService.isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: Lottie.asset(
                                  'assets/lottie/loading.json',
                                  fit: BoxFit.contain))
                          : const Text('Verify Email',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Why verify?',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                          'Email verification confirms your identity and keeps your account secure.',
                          style: TextStyle(
                              fontSize: 13,
                              color: HelpLinkTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
