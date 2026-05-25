import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/feedback_prompt.dart';

class CompletionQrScreen extends StatefulWidget {
  final HelpRequest request;
  const CompletionQrScreen({super.key, required this.request});

  @override
  State<CompletionQrScreen> createState() => _CompletionQrScreenState();
}

class _CompletionQrScreenState extends State<CompletionQrScreen> {
  String? _token;
  bool _isLoading = true;
  bool _isRevoking = false;

  StreamSubscription<HelpRequest?>? _completionSub;
  HelpRequest? _liveRequest;
  bool _showThankYou = false;
  bool _thankYouShown = false;

  @override
  void initState() {
    super.initState();
    _liveRequest = widget.request;
    _initToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_completionSub == null) {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      _completionSub = fs.getRequestStream(widget.request.id).listen((req) {
        if (req == null || !mounted) return;
        setState(() => _liveRequest = req);
        if (!_thankYouShown && req.status == RequestStatus.completed) {
          _thankYouShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showThankYou = true);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    super.dispose();
  }

  Future<void> _initToken() async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final existing = widget.request.completionToken;
    if (existing != null && existing.isNotEmpty) {
      setState(() {
        _token = existing;
        _isLoading = false;
      });
    } else {
      final token = await fs.generateCompletionToken(widget.request.id);
      if (mounted) setState(() { _token = token; _isLoading = false; });
    }
  }

  Future<void> _regenerate() async {
    setState(() => _isLoading = true);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final token = await fs.generateCompletionToken(widget.request.id);
    if (mounted) setState(() { _token = token; _isLoading = false; });
  }

  Future<void> _revokeAndExit() async {
    setState(() => _isRevoking = true);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    await fs.revokeCompletionToken(widget.request.id);
    if (mounted) Navigator.pop(context);
  }

  String get _qrData =>
      'helplink_complete::${widget.request.id}::${_token ?? ''}';

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundGrey,
          body: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.beneficiaryGradientStart,
                      AppTheme.beneficiaryGradientEnd,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                    ),
                    const Expanded(
                      child: Text(
                        'Completion QR Code',
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // QR card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.qr_code_2_rounded,
                                size: 36, color: AppTheme.beneficiaryGradientStart),
                            const SizedBox(height: 12),
                            const Text(
                              'Show this QR to your donor',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'They will scan it to instantly confirm\nand complete the request.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 28),
                            if (_isLoading)
                              const SizedBox(
                                height: 220,
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.beneficiaryGradientStart
                                          .withValues(alpha: 0.3)),
                                ),
                                child: QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppTheme.beneficiaryGradientStart,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/lottie/QR Code Scanner.json',
                                  width: 28,
                                  height: 28,
                                  repeat: true,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Waiting for donor to scan…',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.beneficiaryGradientStart
                              .withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.beneficiaryGradientStart
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16,
                                color: AppTheme.beneficiaryGradientStart),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Only show this QR after you have received the help. '
                                'Scanning it will immediately mark the request as completed.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.beneficiaryGradientStart),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Regenerate button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _regenerate,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Regenerate QR Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.beneficiaryGradientStart,
                            side: BorderSide(
                                color: AppTheme.beneficiaryGradientStart
                                    .withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Hide / revoke
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isRevoking ? null : _revokeAndExit,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: _isRevoking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorRed,
                            side: BorderSide(
                                color: AppTheme.errorRed.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Thank-you overlay — shown immediately when donor scans the QR
        if (_showThankYou)
          Positioned.fill(
            child: _ThankYouOverlay(
              onClose: () async {
                setState(() => _showThankYou = false);
                final req = _liveRequest ?? widget.request;
                final userId = Provider.of<AuthService>(context, listen: false)
                    .userModel
                    ?.uid ?? '';
                // Capture Navigator before async gap to avoid BuildContext-across-async warning.
                final nav = Navigator.of(context);
                if (mounted) {
                  await showFeedbackPrompt(
                    context: context,
                    request: req,
                    isDonor: false,
                    userId: userId,
                  );
                }
                nav.pop(true);
              },
            ),
          ),
      ],
    );
  }
}

// ── Thank-you overlay ─────────────────────────────────────────────────────────

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
          colors: [
            AppTheme.beneficiaryGradientStart,
            AppTheme.beneficiaryGradientEnd,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // X button
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
              'Request Completed!',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your courage to ask for help is truly appreciated.\nYou are never alone — the community is here for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.white70, height: 1.5),
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
                    foregroundColor: AppTheme.beneficiaryGradientStart,
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
