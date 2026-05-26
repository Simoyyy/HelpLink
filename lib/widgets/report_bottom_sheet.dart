import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/report_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

const List<String> _appCategories = [
  'App crash',
  'Feature not working',
  'Login / signup issue',
  'Map / location issue',
  'Chat issue',
  'Notification issue',
  'Slow performance',
  'Other',
];

const List<String> _requestReasons = [
  'Fake / fraudulent request',
  'Misleading description',
  'Duplicate request',
  'Inappropriate content',
  'Safety concern',
  'Spam',
  'Other',
];

/// Shows the report bottom sheet. Pass [requestId] for a request report,
/// omit it (or pass null) for an app report.
Future<void> showReportSheet(
  BuildContext context, {
  String? requestId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(requestId: requestId),
  );
}

class _ReportSheet extends StatefulWidget {
  final String? requestId;
  const _ReportSheet({this.requestId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  bool get _isRequestReport => widget.requestId != null;

  String? _selectedCategory;
  final _descController = TextEditingController();
  File? _photo;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  List<String> get _options =>
      _isRequestReport ? _requestReasons : _appCategories;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  void _removePhoto() => setState(() => _photo = null);

  Future<void> _submit() async {
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a category.');
      return;
    }
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      setState(() => _errorMessage = 'Please provide a description.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user = auth.userModel!;

    String? photoUrl;
    if (_photo != null) {
      photoUrl = await fs.uploadReportPhoto(
        reporterId: user.uid,
        file: _photo!,
      );
      // Photo upload failed — proceed without photo rather than blocking the report
    }

    final report = ReportModel(
      id: '',
      reporterId: user.uid,
      reporterRole: user.role.name,
      type: _isRequestReport ? ReportType.request : ReportType.app,
      targetId: widget.requestId,
      category: _selectedCategory!,
      description: desc,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );

    final ok = await fs.submitReport(report);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to submit report. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    if (_submitted) {
      return _SuccessOverlay(onClose: () => Navigator.pop(context));
    }

    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final accentColor =
        _isRequestReport ? AppTheme.primaryPurple : AppTheme.primaryBlue;
    final title =
        _isRequestReport ? 'Report this Request' : 'Report an App Issue';
    final categoryLabel = _isRequestReport ? 'Reason' : 'Category';
    final descHint = _isRequestReport
        ? 'Provide details about why this request is problematic...'
        : 'Describe what happened and what you were doing when the issue occurred...';
    final photoLabel =
        _isRequestReport ? 'Evidence photo (optional)' : 'Screenshot (optional)';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPad),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title row ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.flag_rounded, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Category / Reason ──
              Text(categoryLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((opt) {
                  final selected = _selectedCategory == opt;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategory = opt;
                      _errorMessage = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? accentColor
                            : accentColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? accentColor
                              : accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(opt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : accentColor,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Description ──
              Text('Description',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: descHint,
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                  counterStyle:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 16),

              // ── Photo picker ──
              Text(photoLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              if (_photo == null)
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: accentColor, size: 26),
                        const SizedBox(height: 4),
                        Text('Tap to attach a photo',
                            style:
                                TextStyle(fontSize: 12, color: accentColor)),
                      ],
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_photo!,
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: _removePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),

              // ── Error message ──
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppTheme.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.errorRed)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor:
                        accentColor.withValues(alpha: 0.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Report',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Success overlay ─────────────────────────────────────────────────────────

class _SuccessOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Close button ──
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
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
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 20),

            const Text(
              'Report Submitted Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Thank you for helping keep HelpLink safe.\nWe will look into this as soon as possible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.white70, height: 1.5),
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
                    foregroundColor: const Color(0xFF059669),
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
