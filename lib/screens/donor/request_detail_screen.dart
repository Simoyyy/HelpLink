import 'dart:async';
import 'package:flutter/material.dart';
import 'package:helplink/screens/donor/delivery_completion_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/beneficiary_profile.dart';
import 'package:helplink/utils/feedback_prompt.dart';
import 'package:helplink/widgets/location_map_preview.dart';
import 'package:helplink/widgets/report_bottom_sheet.dart';
import 'package:intl/intl.dart';

const List<String> _ratingLabels = [
  'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'
];

class RequestDetailScreen extends StatefulWidget {
  final HelpRequest request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _acceptAnonymously = false;
  bool _isLoading = false;

  late HelpRequest _currentRequest;
  StreamSubscription<HelpRequest?>? _requestSub;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _ticker = Timer.periodic(
        const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestSub == null) {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      _requestSub = fs.getRequestStream(_currentRequest.id).listen((r) {
        if (r != null && mounted) {
          setState(() => _currentRequest = r);
        }
      });
    }
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return 'Awaiting Donor';
      case RequestStatus.matched:
        return 'Matched';
      case RequestStatus.active:
        return 'In Progress';
      case RequestStatus.pendingConfirmation:
        return 'Awaiting Confirmation';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData get _statusIcon {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.matched:
        return Icons.handshake_rounded;
      case RequestStatus.active:
        return Icons.bolt_rounded;
      case RequestStatus.pendingConfirmation:
        return Icons.pending_rounded;
      case RequestStatus.completed:
        return Icons.check_circle_rounded;
      case RequestStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color get _accent => _currentRequest.isEmergency
      ? AppTheme.errorRed
      : AppTheme.primaryBlue;

  Color get _statusColor {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return const Color(0xFFB8860B);
      case RequestStatus.matched:
        return _accent;
      case RequestStatus.active:
        return AppTheme.successGreen;
      case RequestStatus.pendingConfirmation:
        return _accent;
      case RequestStatus.completed:
        return AppTheme.successGreen;
      case RequestStatus.cancelled:
        return AppTheme.errorRed;
    }
  }

  Color get _statusBgColor {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return const Color(0xFFFFF8DC);
      case RequestStatus.matched:
        return _accent.withValues(alpha: 0.1);
      case RequestStatus.active:
        return AppTheme.successGreen.withValues(alpha: 0.1);
      case RequestStatus.pendingConfirmation:
        return _accent.withValues(alpha: 0.1);
      case RequestStatus.completed:
        return const Color(0xFFE8F5E9);
      case RequestStatus.cancelled:
        return AppTheme.errorRed.withValues(alpha: 0.1);
    }
  }

  static const _donorCancelReasons = [
    'Unable to fulfil at this time',
    'Emergency / personal reason',
    'Miscommunication with beneficiary',
    'Other',
  ];

  String _formatRemaining(Duration age) {
    final remaining = const Duration(hours: 4) - age;
    if (remaining.isNegative) return '0m';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _formatOverdue(Duration age) {
    final overdue = age - const Duration(hours: 4);
    final h = overdue.inHours;
    final m = overdue.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  void _confirmCancel() async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user =
        Provider.of<AuthService>(context, listen: false).userModel!;
    final strikeInfo = await fs.getDonorStrikeInfo(user.uid);
    if (!mounted) return;

    final isSecondStrike = (strikeInfo['strikes'] as int) >= 1;
    String? selectedReason;
    final otherCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Cancel Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently cancel the request and notify the beneficiary.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const Text('Please select a reason:',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ..._donorCancelReasons.map((r) => RadioListTile<String>(
                      title: Text(r,
                          style: const TextStyle(fontSize: 14)),
                      value: r,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.errorRed,
                      onChanged: (v) =>
                          setDlg(() => selectedReason = v),
                    )),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Please specify...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 12),
                _strikeWarningBox(isSecondStrike),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed),
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      final reason = selectedReason == 'Other'
                          ? (otherCtrl.text.trim().isEmpty
                              ? 'Other'
                              : otherCtrl.text.trim())
                          : selectedReason!;
                      Navigator.pop(ctx);
                      final result = await fs.cancelRequestWithReason(
                        requestId: _currentRequest.id,
                        reason: reason,
                        cancelledBy: 'donor',
                        donorId: user.uid,
                      );
                      if (!mounted) return;
                      _handleStrikeResult(result, isWithdraw: false);
                    },
              child: const Text('Cancel Request',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strikeWarningBox(bool isSecondStrike) {
    final color = isSecondStrike ? AppTheme.errorRed : AppTheme.warningOrange;
    final message = isSecondStrike
        ? 'You already have 1 strike. This action will result in a 24-hour ban.'
        : 'This will count as a cancellation strike. A 2nd strike within 30 days = 24h ban.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(message, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  void _handleStrikeResult(String? result, {required bool isWithdraw}) {
    final action = isWithdraw ? 'Withdrawn.' : 'Cancelled.';
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Failed to ${isWithdraw ? 'withdraw' : 'cancel'}. Please try again.'),
        backgroundColor: AppTheme.errorRed,
      ));
      return;
    }
    if (result == 'banned') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'You have been banned for 24 hours due to repeated cancellations.'),
        backgroundColor: AppTheme.errorRed,
        duration: Duration(seconds: 5),
      ));
    } else if (result == 'warning') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$action Warning: one more cancellation within 30 days will result in a ban.'),
        backgroundColor: AppTheme.warningOrange,
        duration: const Duration(seconds: 5),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isWithdraw
            ? 'You have withdrawn. The request is now open again.'
            : 'Request has been cancelled.'),
        backgroundColor: AppTheme.successGreen,
      ));
    }
    Navigator.pop(context);
  }

  Future<void> _offerHelp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final user = authService.userModel;
    if (user == null) return;

    setState(() => _isLoading = true);

    final donorName =
        _acceptAnonymously ? 'Anonymous Donor' : user.fullName;

    final error = await firestoreService.offerHelp(
      requestId: _currentRequest.id,
      donorId: user.uid,
      donorName: donorName,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error), backgroundColor: AppTheme.errorRed),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_acceptAnonymously
                ? 'You have anonymously offered to help!'
                : 'You have offered to help! The beneficiary will be notified.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    final isDonor = user != null && authService.activeRole == UserRole.donor;
    final isPending = _currentRequest.status == RequestStatus.pending;

    final age = (_currentRequest.matchedAt != null &&
            (_currentRequest.status == RequestStatus.matched ||
                _currentRequest.status == RequestStatus.active))
        ? DateTime.now().difference(_currentRequest.matchedAt!)
        : null;
    final isExpired = age != null && age.inHours >= 4;
    final isOverdue = age != null && age.inHours >= 2 && !isExpired;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header — blue for normal, red for emergency
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 48, 0, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _currentRequest.isEmergency
                    ? const [Color(0xFFD32F2F), Color(0xFFB71C1C)]
                    : const [
                        AppTheme.donorGradientStart,
                        AppTheme.donorGradientEnd
                      ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Request Details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => showReportSheet(
                          context,
                          requestId: _currentRequest.id,
                        ),
                        icon: const Icon(Icons.flag_outlined,
                            color: Colors.white),
                        tooltip: 'Report this request',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 14, color: _statusColor),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (age != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: (isExpired
                                  ? AppTheme.errorRed
                                  : isOverdue
                                      ? AppTheme.warningOrange
                                      : _accent)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isExpired
                                    ? AppTheme.errorRed
                                    : isOverdue
                                        ? AppTheme.warningOrange
                                        : _accent)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isExpired
                              ? '⚠ Auto-withdrawal pending — ${_formatOverdue(age)} overdue'
                              : '⏱ Auto-withdrawal in ${_formatRemaining(age)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isExpired
                                ? AppTheme.errorRed
                                : isOverdue
                                    ? AppTheme.warningOrange
                                    : _accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Main details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentRequest.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.sell_outlined,
                          'Category',
                          _currentRequest.categoryLabel,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.notes_rounded,
                          'Description',
                          _currentRequest.description,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.person_outline,
                          'Requested by',
                          _currentRequest.displayName,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Date Posted',
                          DateFormat('M/d/yyyy').format(_currentRequest.createdAt),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Location',
                          _currentRequest.location ?? 'Not specified',
                        ),
                        if (_currentRequest.latitude != null &&
                            _currentRequest.longitude != null) ...[
                          const SizedBox(height: 12),
                          LocationMapPreview(
                            latitude: _currentRequest.latitude!,
                            longitude: _currentRequest.longitude!,
                            label: _currentRequest.location,
                          ),
                        ],
                        if (_currentRequest.donorName != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.volunteer_activism,
                            'Donor',
                            _currentRequest.donorName!,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  BeneficiaryProfileCard(
                    beneficiaryId: _currentRequest.beneficiaryId,
                    showVerification: !_currentRequest.isAnonymous,
                  ),

                  // Feedback card (completed + feedback given)
                  if (_currentRequest.status == RequestStatus.completed &&
                      _currentRequest.donorFeedbackGiven) ...[
                    const SizedBox(height: 24),
                    _buildFeedbackCard(context),
                  ],

                  const SizedBox(height: 24),

                  // Submit Delivery + Withdraw / Cancel (donor, matched/active)
                  if (isDonor &&
                      _currentRequest.donorId == user.uid &&
                      (_currentRequest.status == RequestStatus.matched ||
                          _currentRequest.status == RequestStatus.active)) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          final result = await Navigator.push<DeliveryResult>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryCompletionScreen(
                                  request: _currentRequest),
                            ),
                          );
                          if (!mounted) return;
                          if (result == DeliveryResult.completedViaQr) {
                            nav.pop();
                            if (context.mounted) {
                              final user = Provider.of<AuthService>(context,
                                      listen: false)
                                  .userModel;
                              if (user != null) {
                                await showFeedbackPrompt(
                                  context: context,
                                  request: _currentRequest,
                                  isDonor: true,
                                  userId: user.uid,
                                );
                              }
                            }
                          } else if (result ==
                              DeliveryResult.pendingConfirmation) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Delivery submitted! Waiting for the beneficiary to confirm.'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.local_shipping_outlined, size: 20),
                        label: const Text('Submit Delivery',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _confirmCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Request',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: BorderSide(
                              color: AppTheme.errorRed.withValues(alpha: 0.7)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  // Pending confirmation banner (donor view)
                  if (isDonor &&
                      _currentRequest.donorId == user.uid &&
                      _currentRequest.status ==
                          RequestStatus.pendingConfirmation) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Awaiting Beneficiary Confirmation',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _accent),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your delivery has been submitted. The beneficiary will confirm receipt in their app.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _accent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Accept Anonymously section (only for donors on pending requests)
                  if (isDonor && isPending) ...[
                    if (user.isBanned) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.errorRed.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.block,
                                color: AppTheme.errorRed, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Temporarily Banned',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.errorRed)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You are banned for '
                                    '${user.banRemaining.inHours}h '
                                    '${user.banRemaining.inMinutes % 60}m '
                                    'due to repeated cancellations.',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.errorRed),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                    // Anonymous checkbox
                    GestureDetector(
                      onTap: () => setState(
                          () => _acceptAnonymously = !_acceptAnonymously),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _currentRequest.isEmergency
                              ? const Color(0xFFFFF5F5)
                              : const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _acceptAnonymously
                                ? _accent
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptAnonymously,
                                onChanged: (v) => setState(
                                    () => _acceptAnonymously = v ?? false),
                                activeColor: _accent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.visibility_off,
                                          size: 18,
                                          color: _accent),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Accept Anonymously',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your identity will remain hidden from the beneficiary. You\'ll appear as "Anonymous Donor".',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Accept button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _offerHelp,
                        icon: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain),
                              )
                            : Icon(
                                _acceptAnonymously
                                    ? Icons.visibility_off
                                    : Icons.volunteer_activism,
                                size: 20),
                        label: Text(
                          _acceptAnonymously
                              ? 'Accept Anonymously'
                              : 'Offer to Help',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _acceptAnonymously
                              ? const Color(0xFF1E293B)
                              : AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ], // closes else ...[
                ], // closes if (isDonor && isPending) ...[

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    return FutureBuilder<Map<String, dynamic>?>(
      future: fs.getFeedback(requestId: _currentRequest.id, isDonor: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final int rating = (data['experienceRating'] as num?)?.toInt() ?? 0;
        final String? comment = data['comment'] as String?;
        final ratingLabel = rating > 0 ? _ratingLabels[rating - 1] : '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Your Feedback',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppTheme.warningOrange,
                    size: 22,
                  ),
                ),
              ),
              if (ratingLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ratingLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue)),
              ],
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Text(comment,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.4)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}
