import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

enum _Step { guide, preview, validating, uploading, pending, failed }

class ICVerificationScreen extends StatefulWidget {
  const ICVerificationScreen({super.key});

  @override
  State<ICVerificationScreen> createState() => _ICVerificationScreenState();
}

class _ICVerificationScreenState extends State<ICVerificationScreen> {
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

  Future<bool> _validateWithAI(File image) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return true;

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final bytes = await image.readAsBytes();

    final prompt = TextPart(
      'Examine this image carefully.\n'
      'A valid Malaysian MyKad (National Identity Card) is a predominantly BLUE card and contains:\n'
      '- A photo of the card holder\n'
      '- A 12-digit IC number\n'
      '- Text in Malay and English\n\n'
      'Is this image clearly showing a blue Malaysian MyKad?\n'
      'Respond ONLY with valid JSON (no markdown, no code blocks):\n'
      '{"isValid": true, "reason": "brief reason"}\n'
      'Set isValid=true ONLY if the image is clearly a blue Malaysian MyKad.',
    );

    final response = await model.generateContent([
      Content.multi([prompt, DataPart('image/jpeg', bytes)]),
    ]);

    final text = (response.text ?? '').trim();
    final cleaned = text
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    return parsed['isValid'] == true;
  }

  Future<void> _submit() async {
    if (_icImage == null) return;
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    setState(() => _step = _Step.validating);

    // AI gate — check image is a blue Malaysian IC before uploading
    try {
      final isValid = await _validateWithAI(_icImage!);
      if (!isValid) {
        if (mounted) {
          setState(() {
            _step = _Step.failed;
            _failReason =
                'The photo does not appear to be a Malaysian IC (MyKad). '
                'Please upload a clear photo of your blue IC card with all corners visible.';
          });
        }
        return;
      }
    } catch (_) {
      // If AI is unreachable, allow the upload so manual review can proceed
    }

    setState(() => _step = _Step.uploading);

    try {
      final uploaded = await firestore.uploadICPhoto(
        userId: auth.userModel!.uid,
        file: _icImage!,
      );
      if (!uploaded) throw Exception('Upload failed');

      await firestore.updateUserProfile(
        userId: auth.userModel!.uid,
        data: {'icPendingVerification': true},
      );
      await auth.loadUserData();

      if (mounted) setState(() => _step = _Step.pending);
    } catch (_) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _failReason =
              'Failed to upload photo. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen overlay steps — no AppBar
    if (_step == _Step.pending) {
      return Scaffold(
        body: _PendingView(onClose: () => Navigator.pop(context)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
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
            image: _icImage!, onRetake: _pickImage, onSubmit: _submit);
      case _Step.validating:
        return const _ValidatingView();
      case _Step.uploading:
        return const _UploadingView();
      case _Step.pending:
        return const SizedBox.shrink(); // handled in build()
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
            const Text('Checking your IC photo…',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text(
                'Our AI is verifying this is a valid Malaysian IC card.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Uploading ────────────────────────────────────────────────────────────────

class _UploadingView extends StatelessWidget {
  const _UploadingView();

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
            const Text('Uploading your photo…',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text(
                'Please wait while we securely upload your IC photo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Pending ──────────────────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  final VoidCallback onClose;
  const _PendingView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.donorGradientStart,
            AppTheme.donorGradientEnd,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Close button ──
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Animation ──
            Lottie.asset(
              'assets/lottie/success.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              repeat: false,
            ),

            const SizedBox(height: 20),

            const Text(
              'Photos Received!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'We will verify your IC in 1–3 working days.\nYou will be notified once the review is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.white70, height: 1.5),
              ),
            ),

            const Spacer(),

            // ── Close button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.donorGradientStart,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
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
