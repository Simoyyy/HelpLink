import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

enum _Step { guide, preview, validating, success, failed }

class ICVerificationScreen extends StatefulWidget {
  const ICVerificationScreen({super.key});

  @override
  State<ICVerificationScreen> createState() => _ICVerificationScreenState();
}

class _ICVerificationScreenState extends State<ICVerificationScreen> {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  _Step _step = _Step.guide;
  File? _icImage;
  String _failReason = '';

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _icImage = File(picked.path);
      _step = _Step.preview;
    });
  }

  Future<void> _verify() async {
    if (_icImage == null) return;
    setState(() => _step = _Step.validating);

    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    try {
      final bytes = await _icImage!.readAsBytes();
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final response = await model.generateContent([
        Content.multi([
          TextPart(
            'You are a Malaysian IC (MyKad) verification system. '
            'Analyse this image carefully. A valid Malaysian MyKad typically has: '
            'a blue background, "MYKAD" or "MyKad" text, a 12-digit IC number in '
            'XXXXXX-XX-XXXX format, a photo of the card holder, and the Malaysian '
            'government crest or Jalur Gemilang. '
            'Respond on the first line with exactly VALID or INVALID. '
            'On the second line, give one brief reason.',
          ),
          DataPart('image/jpeg', bytes),
        ]),
      ]);

      final text = response.text?.trim() ?? '';
      final firstLine = text.split('\n').first.trim().toUpperCase();

      if (firstLine == 'VALID') {
        await firestore.updateUserProfile(
          userId: auth.userModel!.uid,
          data: {
            'isICVerified': true,
            'icVerifiedAt': FieldValue.serverTimestamp(),
          },
        );
        await auth.loadUserData();
        if (mounted) setState(() => _step = _Step.success);
      } else {
        final lines = text.split('\n');
        setState(() {
          _step = _Step.failed;
          _failReason = lines.length > 1
              ? lines[1].trim()
              : 'The image does not appear to be a valid Malaysian MyKad.';
        });
      }
    } catch (_) {
      setState(() {
        _step = _Step.failed;
        _failReason = 'Verification service unavailable. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
        automaticallyImplyLeading: _step != _Step.success,
        title: const Text('IC Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.guide:
        return _GuideView(onCapture: _pickImage);
      case _Step.preview:
        return _PreviewView(
            image: _icImage!, onRetake: _pickImage, onSubmit: _verify);
      case _Step.validating:
        return const _ValidatingView();
      case _Step.success:
        return _SuccessView(onDone: () => Navigator.pop(context));
      case _Step.failed:
        return _FailedView(
          reason: _failReason,
          onRetry: () => setState(() {
            _icImage = null;
            _step = _Step.guide;
          }),
        );
    }
  }
}

// ─── Guide ───────────────────────────────────────────────────────────────────

class _GuideView extends StatelessWidget {
  final VoidCallback onCapture;
  const _GuideView({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFBFCFFF),
                    width: 2,
                    style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_rounded,
                      size: 64,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  const Text('Your MyKad goes here',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('How to verify your IC',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 16),
          _tip(Icons.light_mode_rounded, 'Good lighting',
              'Place your IC on a flat surface in a well-lit area'),
          _tip(Icons.crop_free_rounded, 'Full card visible',
              'Ensure all four corners of the IC are in frame'),
          _tip(Icons.do_not_disturb_on_rounded, 'No glare',
              'Avoid reflections or shadows on the card'),
          _tip(Icons.high_quality_rounded, 'Clear image',
              'Hold steady to avoid blur'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Take Photo of IC',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textDark)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preview ─────────────────────────────────────────────────────────────────

class _PreviewView extends StatelessWidget {
  final File image;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;
  const _PreviewView(
      {required this.image, required this.onRetake, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(image, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
          const Text('Does your IC look clear and readable?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 6),
          const Text('All text and the IC number must be fully visible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: const Text('Verify IC'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Validating ───────────────────────────────────────────────────────────────

class _ValidatingView extends StatelessWidget {
  const _ValidatingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/loading.json', width: 120, height: 120),
            const SizedBox(height: 16),
            const Text('Analysing your IC…',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text(
                'Our AI is verifying your identity card.\nThis may take a few seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Success ──────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/success.json',
                width: 160, height: 160, repeat: false),
            const SizedBox(height: 16),
            const Text('Identity Verified!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen)),
            const SizedBox(height: 8),
            const Text(
                'Your IC has been verified successfully.\nA verified badge has been added to your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Failed ───────────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  const _FailedView({required this.reason, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gpp_bad_rounded,
                  size: 40, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 16),
            const Text('Verification Failed',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorRed)),
            const SizedBox(height: 8),
            Text(reason,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
