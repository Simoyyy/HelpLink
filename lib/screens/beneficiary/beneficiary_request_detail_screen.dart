import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/beneficiary/completion_qr_screen.dart';
import 'package:helplink/screens/beneficiary/edit_request_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/donor_badges.dart';
import 'package:helplink/utils/feedback_prompt.dart';
import 'package:helplink/widgets/report_bottom_sheet.dart';

class BeneficiaryRequestDetailScreen extends StatefulWidget {
  final HelpRequest request;
  final String userId;
  final String userName;

  const BeneficiaryRequestDetailScreen({
    super.key,
    required this.request,
    required this.userId,
    required this.userName,
  });

  @override
  State<BeneficiaryRequestDetailScreen> createState() =>
      _BeneficiaryRequestDetailScreenState();
}

class _BeneficiaryRequestDetailScreenState
    extends State<BeneficiaryRequestDetailScreen> {
  static const List<String> _ratingLabels = [
    'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'
  ];

  StreamSubscription<HelpRequest?>? _requestSub;
  HelpRequest? _liveRequest;
  bool _showThankYou = false;
  bool _thankYouShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestSub == null) {
      _liveRequest = widget.request;
      final fs = Provider.of<FirestoreService>(context, listen: false);
      _requestSub =
          fs.getRequestStream(widget.request.id).listen((req) {
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
    _requestSub?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liveRequest = _liveRequest ?? widget.request;
    final topPad = MediaQuery.of(context).padding.top;
    final dateStr = DateFormat('M/d/yyyy').format(liveRequest.createdAt);
    final canEdit = liveRequest.status == RequestStatus.pending;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundGrey,
          body: Column(
            children: [
              // ── Purple header ─────────────────────────────────────────────
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
                        'Request Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showReportSheet(
                        context,
                        requestId: liveRequest.id,
                      ),
                      icon: const Icon(Icons.flag_outlined,
                          color: Colors.white),
                      tooltip: 'Report this request',
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status pill
                      _StatusPill(status: liveRequest.status),
                      const SizedBox(height: 16),

                      // Main details card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveRequest.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.local_offer_outlined,
                              label: 'Category',
                              value: liveRequest.categoryLabel,
                            ),
                            const SizedBox(height: 12),
                            if (liveRequest.location != null &&
                                liveRequest.location!.isNotEmpty) ...[
                              _InfoRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: liveRequest.location!,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Requested by',
                              value: liveRequest.displayName,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Date Posted',
                              value: dateStr,
                            ),
                            if ((liveRequest.status ==
                                        RequestStatus.matched ||
                                    liveRequest.status ==
                                        RequestStatus.active) &&
                                liveRequest.donorName != null) ...[
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.volunteer_activism_outlined,
                                label: 'Donor',
                                value: liveRequest.donorName!,
                                trailing: liveRequest.donorId != null
                                    ? DonorBadgeChip(
                                        donorId: liveRequest.donorId!)
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            const Text(
                              'Description',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              liveRequest.description,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textMuted,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),

                      // Feedback card (completed + feedback given)
                      if (liveRequest.status == RequestStatus.completed &&
                          liveRequest.beneficiaryFeedbackGiven) ...[
                        const SizedBox(height: 16),
                        _FeedbackCard(
                          requestId: liveRequest.id,
                          isDonor: false,
                          ratingLabels: _ratingLabels,
                          color: AppTheme.primaryPurple,
                        ),
                      ],

                      // Provide feedback (completed, not yet given)
                      if (liveRequest.status == RequestStatus.completed &&
                          !liveRequest.beneficiaryFeedbackGiven) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.primaryPurple
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.check_circle_outline,
                                    size: 18,
                                    color: AppTheme.primaryPurple),
                                SizedBox(width: 8),
                                Text('Request Completed!',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryPurple)),
                              ]),
                              const SizedBox(height: 6),
                              const Text(
                                'How was your experience? Share your feedback.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FeedbackScreen(
                                        request: liveRequest,
                                        isDonor: false,
                                        currentUserId: widget.userId,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                      Icons.rate_review_outlined,
                                      size: 18,
                                      color: Colors.white),
                                  label: const Text('Provide Feedback',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Awaiting confirmation ─────────────────────────────
                      if (liveRequest.status ==
                          RequestStatus.pendingConfirmation) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.primaryBlue
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.local_shipping_outlined,
                                    size: 18,
                                    color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                const Text('Your donor has delivered!',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryBlue)),
                              ]),
                              const SizedBox(height: 6),
                              const Text(
                                'Please confirm that you have received the help.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final fs =
                                          Provider.of<FirestoreService>(
                                              context,
                                              listen: false);
                                      final ok = await fs.confirmDelivery(
                                          liveRequest.id);
                                      if (!context.mounted) return;
                                      if (!ok) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Failed. Please try again.'),
                                          backgroundColor:
                                              AppTheme.errorRed,
                                        ));
                                      }
                                      // stream handles thank-you + feedback
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                    ),
                                    child: const Text('Confirm Received',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.textMuted,
                                      side: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                    ),
                                    child: const Text('Not Yet'),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  request: liveRequest,
                                  currentUserId: widget.userId,
                                  currentUserName: widget.userName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: AppTheme.primaryPurple),
                            label: const Text('Message Donor',
                                style: TextStyle(
                                    color: AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.primaryPurple),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      // Message + Cancel + Show QR (matched/active)
                      if (liveRequest.status == RequestStatus.matched ||
                          liveRequest.status ==
                              RequestStatus.active) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  request: liveRequest,
                                  currentUserId: widget.userId,
                                  currentUserName: widget.userName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: AppTheme.primaryPurple),
                            label: const Text('Message Donor',
                                style: TextStyle(
                                    color: AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.primaryPurple),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompletionQrScreen(
                                      request: liveRequest),
                                ),
                              );
                              // QR screen already showed the overlay + feedback prompt.
                              // Suppress the stream-triggered overlay on this screen.
                              if (result == true && mounted) {
                                setState(() => _thankYouShown = true);
                              }
                            },
                            icon: const Icon(Icons.qr_code_rounded,
                                size: 18, color: Colors.white),
                            label: const Text('Show Completion QR',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppTheme.beneficiaryGradientStart,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmCancel(context, liveRequest),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: AppTheme.errorRed),
                            label: const Text('Cancel Request',
                                style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.errorRed),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      // Edit + Cancel (pending)
                      if (canEdit) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditRequestScreen(
                                    request: liveRequest),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: Colors.white),
                            label: const Text('Edit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmCancelPending(context),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: AppTheme.errorRed),
                            label: const Text('Cancel Request',
                                style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.errorRed),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      // Delete (cancelled)
                      if (liveRequest.status ==
                          RequestStatus.cancelled) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmDelete(context),
                            icon: const Icon(
                                Icons.delete_forever_outlined,
                                size: 18,
                                color: Colors.white),
                            label: const Text('Delete Request',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Thank-you overlay ───────────────────────────────────────────────
        if (_showThankYou)
          Positioned.fill(
            child: _BeneficiaryThankYouOverlay(
              onClose: () async {
                setState(() => _showThankYou = false);
                final liveReq = _liveRequest ?? widget.request;
                if (mounted) {
                  await showFeedbackPrompt(
                    context: context,
                    request: liveReq,
                    isDonor: false,
                    userId: widget.userId,
                  );
                }
              },
            ),
          ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _confirmCancelPending(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
            'Are you sure you want to cancel this request? It will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final fs =
                  Provider.of<FirestoreService>(context, listen: false);
              final error =
                  await fs.deleteHelpRequest(widget.request.id);
              if (context.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error),
                      backgroundColor: AppTheme.errorRed));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                    content: Text('Request cancelled.'),
                    backgroundColor: AppTheme.successGreen,
                  ));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Cancel Request',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Are you sure you want to delete this request? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final fs =
                  Provider.of<FirestoreService>(context, listen: false);
              final error =
                  await fs.deleteHelpRequest(widget.request.id);
              if (context.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error),
                      backgroundColor: AppTheme.errorRed));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                    content: Text('Request deleted.'),
                    backgroundColor: AppTheme.successGreen,
                  ));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, HelpRequest liveRequest) {
    final hasDonor = liveRequest.donorName != null;
    final reasons = [
      'I no longer need help',
      'Found help elsewhere',
      'Changed my mind',
      if (hasDonor) 'Miscommunication with donor',
      'Other',
    ];

    String? selectedReason;
    final otherController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancel Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDonor)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'This will cancel the request and notify your donor'
                      ' (${liveRequest.donorName}).',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ),
                const Text('Please select a reason:',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    title: Text(r,
                        style: const TextStyle(fontSize: 14)),
                    value: r,
                    groupValue: selectedReason,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primaryPurple,
                    onChanged: (v) =>
                        setDialogState(() => selectedReason = v),
                  ),
                ),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherController,
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
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.errorRed.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70),
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      final reason = selectedReason == 'Other'
                          ? (otherController.text.trim().isEmpty
                              ? 'Other'
                              : otherController.text.trim())
                          : selectedReason!;
                      final fs = Provider.of<FirestoreService>(context,
                          listen: false);
                      Navigator.pop(ctx);
                      final result =
                          await fs.cancelRequestWithReason(
                        requestId: liveRequest.id,
                        reason: reason,
                        cancelledBy: 'beneficiary',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(result != null
                              ? 'Request cancelled.'
                              : 'Failed to cancel. Please try again.'),
                          backgroundColor: result != null
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ));
                      }
                    },
              child: const Text('Cancel Request',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Beneficiary thank-you overlay ─────────────────────────────────────────────

class _BeneficiaryThankYouOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _BeneficiaryThankYouOverlay({required this.onClose});

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

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final RequestStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case RequestStatus.pending:
        bg = const Color(0xFFFFF8E1);
        fg = AppTheme.warningOrange;
        label = 'Awaiting Donor';
        break;
      case RequestStatus.matched:
        bg = const Color(0xFFEDE7F6);
        fg = AppTheme.primaryPurple;
        label = 'Accepted';
        break;
      case RequestStatus.pendingConfirmation:
        bg = const Color(0xFFE3F2FD);
        fg = AppTheme.primaryBlue;
        label = 'Awaiting Your Confirmation';
        break;
      case RequestStatus.active:
        bg = const Color(0xFFE3F2FD);
        fg = AppTheme.primaryBlue;
        label = 'In Progress';
        break;
      case RequestStatus.completed:
        bg = Colors.grey[100]!;
        fg = AppTheme.textMuted;
        label = 'Completed';
        break;
      case RequestStatus.cancelled:
        bg = const Color(0xFFFFEBEE);
        fg = AppTheme.errorRed;
        label = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.trailing});

  @override
  Widget build(BuildContext context) {
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
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ── Feedback display card ─────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final String requestId;
  final bool isDonor;
  final List<String> ratingLabels;
  final Color color;

  const _FeedbackCard({
    required this.requestId,
    required this.isDonor,
    required this.ratingLabels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    return FutureBuilder<Map<String, dynamic>?>(
      future: fs.getFeedback(requestId: requestId, isDonor: isDonor),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final int rating =
            (data['experienceRating'] as num?)?.toInt() ?? 0;
        final String? comment = data['comment'] as String?;
        final int? appRating =
            (data['appRating'] as num?)?.toInt();
        final ratingLabel =
            rating > 0 ? ratingLabels[rating - 1] : '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 18, color: color),
                  const SizedBox(width: 8),
                  Text('Your Feedback',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color)),
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
                    color: const Color(0xFFF97316),
                    size: 22,
                  ),
                ),
              ),
              if (ratingLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ratingLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Text(comment,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4)),
              ],
              if (appRating != null) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                const Text('App Rating',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < appRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF97316),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(ratingLabels[appRating - 1],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ],
          ),
        );
      },
    );
  }
}
