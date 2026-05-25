import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

/// Result returned after the delivery completion flow.
enum DeliveryResult { none, pendingConfirmation, completedViaQr }

class DeliveryCompletionScreen extends StatefulWidget {
  final HelpRequest request;
  const DeliveryCompletionScreen({super.key, required this.request});

  @override
  State<DeliveryCompletionScreen> createState() =>
      _DeliveryCompletionScreenState();
}

class _DeliveryCompletionScreenState extends State<DeliveryCompletionScreen> {
  File? _photo;
  bool _isBusy = false;
  bool _scanning = false;
  bool _showThankYou = false;
  final MobileScannerController _scanCtrl = MobileScannerController();

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  // ── Upload helper ─────────────────────────────────────────────────────────

  Future<String?> _uploadPhoto(FirestoreService fs) async {
    if (_photo == null) return null;
    return fs.uploadCompletionPhoto(
        requestId: widget.request.id, photoFile: _photo!);
  }

  // ── Mark as Delivered (mutual confirmation path) ──────────────────────────

  Future<void> _submitDelivery() async {
    setState(() => _isBusy = true);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final photoUrl = await _uploadPhoto(fs);
    final ok = await fs.submitDelivery(
        requestId: widget.request.id, photoUrl: photoUrl);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, DeliveryResult.pendingConfirmation);
    } else {
      setState(() => _isBusy = false);
      _showError('Failed to submit. Please try again.');
    }
  }

  // ── QR scanner ───────────────────────────────────────────────────────────

  void _openScanner() => setState(() => _scanning = true);
  void _closeScanner() => setState(() => _scanning = false);

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_isBusy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    _closeScanner();

    final parts = raw.split('::');
    if (parts.length != 3 || parts[0] != 'helplink_complete') {
      _showError('Invalid QR code. Please scan the QR from the beneficiary\'s app.');
      return;
    }
    if (parts[1] != widget.request.id) {
      _showError('This QR code belongs to a different request.');
      return;
    }

    setState(() => _isBusy = true);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final photoUrl = await _uploadPhoto(fs);
    final ok = await fs.verifyQrAndComplete(
      requestId: widget.request.id,
      token: parts[2],
      photoUrl: photoUrl,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _showThankYou = true);
    } else {
      setState(() => _isBusy = false);
      _showError('QR verification failed. The code may have expired or already been used.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.errorRed));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen QR scanner (shown when _scanning)
          if (_scanning) ...[
            MobileScanner(
              controller: _scanCtrl,
              onDetect: _onQrDetected,
            ),
            // Scanner overlay
            Positioned.fill(
              child: Column(
                children: [
                  Container(
                    color: Colors.black54,
                    padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _closeScanner,
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 26),
                        ),
                        const Expanded(
                          child: Text(
                            'Scan Beneficiary QR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
                    child: const Text(
                      'Point the camera at the QR code on the beneficiary\'s screen',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            if (_isBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
          ],

          // Thank-you overlay (shown after successful QR scan)
          if (_showThankYou)
            Positioned.fill(
              child: _ThankYouOverlay(
                onClose: () =>
                    Navigator.pop(context, DeliveryResult.completedViaQr),
              ),
            ),

          // Main completion UI (hidden while scanning or showing thank-you)
          if (!_scanning && !_showThankYou)
            Container(
              color: AppTheme.backgroundGrey,
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.fromLTRB(16, topPad + 10, 16, 20),
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
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, DeliveryResult.none),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                        ),
                        const Expanded(
                          child: Text(
                            'Submit Delivery',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Request info chip
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.volunteer_activism_outlined,
                                      size: 20,
                                      color: AppTheme.primaryBlue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.request.title,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textDark),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                          'For ${widget.request.displayName}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Optional proof photo ───────────────────────
                          const Text('Proof Photo (Optional)',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          const Text(
                            'Take a photo of the help being delivered as proof.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 12),

                          if (_photo != null) ...[
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_photo!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _photo = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _takePhoto,
                                  icon: const Icon(Icons.camera_alt_outlined,
                                      size: 16),
                                  label: const Text('Retake',
                                      style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryBlue,
                                    side: const BorderSide(
                                        color: AppTheme.primaryBlue),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ]),
                          ] else
                            Center(
                              child: SizedBox(
                                width: 200,
                                child: _photoButton(
                                  icon: Icons.camera_alt_outlined,
                                  label: 'Take Photo',
                                  onTap: _takePhoto,
                                ),
                              ),
                            ),

                          const SizedBox(height: 28),

                          // ── Divider ─────────────────────────────────────
                          const Row(children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Complete via',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted)),
                            ),
                            Expanded(child: Divider()),
                          ]),

                          const SizedBox(height: 20),

                          // ── Primary: Scan QR ──────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isBusy ? null : _openScanner,
                              icon: const Icon(Icons.qr_code_scanner_rounded,
                                  size: 20),
                              label: const Text('Scan Beneficiary QR Code',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Instantly completes the request',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.8)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Row(children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(child: Divider()),
                          ]),

                          const SizedBox(height: 20),

                          // ── Secondary: Mark Delivered ─────────────────
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isBusy ? null : _submitDelivery,
                              icon: _isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 20),
                              label: const Text('Mark as Delivered',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.successGreen,
                                side: BorderSide(
                                    color: AppTheme.successGreen
                                        .withValues(alpha: 0.7)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Beneficiary will confirm receipt in their app',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppTheme.primaryBlue),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Thank-you overlay shown after successful QR scan ──────────────────────────

class _ThankYouOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _ThankYouOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // X button top-right
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

            // Animation
            Lottie.asset(
              'assets/lottie/Thank You.json',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 20),

            const Text(
              'Thank You!',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your kindness made a difference today.\nThe request has been completed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
              ),
            ),

            const Spacer(),

            // Close button
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
