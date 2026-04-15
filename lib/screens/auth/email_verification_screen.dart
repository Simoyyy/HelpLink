import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/utils/theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {

  Future<void> _verifyEmail() async {
    final authService = context.read<AuthService>();
    final success = await authService.verifyEmail();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Registration successful! Please log in with your credentials.'),
          backgroundColor: HelpLinkTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showError(authService.errorMessage ?? 'Verification failed');
    }
  }

  Future<void> _resendCode() async {
    final authService = context.read<AuthService>();
    final success = await authService.resendVerificationEmail();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification code resent!'),
          backgroundColor: HelpLinkTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _showError(authService.errorMessage ?? 'Failed to resend code');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HelpLinkTheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final email = authService.currentUser?.email ?? 'your email';

    return Scaffold(
      body: Column(
        children: [
          // Purple gradient header
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
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/signup'),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We've sent a verification link to your email. Please click the link, then return to this screen.",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Email card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: HelpLinkTheme.beneficiaryPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            HelpLinkTheme.beneficiaryPrimary.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: HelpLinkTheme.beneficiaryPrimary,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Icon(Icons.mail_outline,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Check your email',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                              fontSize: 13,
                              color: HelpLinkTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  const SizedBox(height: 24),
                  const Text(
                    'Please check your inbox (and spam folder) for a verification email. After clicking the link, tap the button below.',
                    style: TextStyle(
                        fontSize: 13, color: HelpLinkTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authService.isLoading ? null : _verifyEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HelpLinkTheme.beneficiaryPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: authService.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('I have verified my email',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Resend
                  const Text("Didn't receive the email?",
                      style: TextStyle(
                          fontSize: 13, color: HelpLinkTheme.textSecondary)),
                  TextButton.icon(
                    onPressed: authService.isLoading ? null : _resendCode,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resend verification email'),
                    style: TextButton.styleFrom(
                      foregroundColor: HelpLinkTheme.beneficiaryPrimary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info box
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
                        Text(
                          'Why verify?',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Email verification helps us confirm your identity and keep your account secure.',
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
