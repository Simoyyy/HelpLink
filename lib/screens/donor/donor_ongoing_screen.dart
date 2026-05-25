import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/delivery_completion_screen.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/feedback_prompt.dart';

class DonorOngoingScreen extends StatelessWidget {
  const DonorOngoingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        Provider.of<AuthService>(context, listen: false).userModel;
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: user == null
          ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120))
          : _OngoingContent(userId: user.uid, userName: user.fullName),
    );
  }
}

class _OngoingContent extends StatefulWidget {
  final String userId;
  final String userName;
  const _OngoingContent({required this.userId, required this.userName});

  @override
  State<_OngoingContent> createState() => _OngoingContentState();
}

class _OngoingContentState extends State<_OngoingContent> {
  // 0 = All, 1 = Pending for Feedback (completed), 2 = In Progress (matched/active)
  int _selectedFilter = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context);

    return StreamBuilder<List<HelpRequest>>(
      stream: fs.getDonorOngoingRequests(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
        }

        final all = snapshot.data ?? [];

        // Pending for Feedback = completed requests (help given, awaiting review)
        final pendingFeedback =
            all.where((r) => r.status == RequestStatus.completed).toList();

        // In Progress = matched / active / pendingConfirmation
        final inProgress = all
            .where((r) =>
                r.status == RequestStatus.matched ||
                r.status == RequestStatus.active ||
                r.status == RequestStatus.pendingConfirmation)
            .toList();

        List<HelpRequest> shown;
        String subtitle;
        switch (_selectedFilter) {
          case 1:
            shown = pendingFeedback;
            subtitle = 'Pending for Feedback requests: ${pendingFeedback.length}';
            break;
          case 2:
            shown = inProgress;
            subtitle = 'In Progress requests: ${inProgress.length}';
            break;
          default:
            shown = all;
            subtitle = 'Active assistance: ${all.length}';
        }

        return Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 48, 0, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Ongoing Requests',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // ── Filter tabs ──
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _filterTab('All (${all.length})', 0),
                  _filterTab(
                      'Pending for\nFeedback (${pendingFeedback.length})', 1),
                  _filterTab('In Progress\n(${inProgress.length})', 2),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textMuted)),
              ),
            ),

            const SizedBox(height: 12),

            // ── Request cards ──
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset('assets/lottie/empty_requests.json',
                              width: 160, height: 160, repeat: true),
                          const SizedBox(height: 8),
                          const Text('No requests in this category.',
                              style: TextStyle(
                                  fontSize: 14, color: AppTheme.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: shown.length,
                      itemBuilder: (context, index) =>
                          _buildCard(shown[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterTab(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textMuted)),
        ),
      ),
    );
  }

  Widget _buildCard(HelpRequest request) {
    final isPendingFeedback = request.status == RequestStatus.completed;

    final age = (request.matchedAt != null && !isPendingFeedback)
        ? DateTime.now().difference(request.matchedAt!)
        : null;
    final isExpired = age != null && age.inHours >= 4;
    final isOverdue = age != null && age.inHours >= 2 && !isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 6),
          Text(request.description,
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),

          // Status + Category tags
          Row(children: [
            _statusTag(request.status, isPendingFeedback),
            const SizedBox(width: 8),
            _categoryTag(request.categoryLabel),
          ]),
          if (age != null && !isPendingFeedback) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (isExpired
                        ? AppTheme.errorRed
                        : isOverdue
                            ? AppTheme.warningOrange
                            : AppTheme.primaryBlue)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isExpired
                          ? AppTheme.errorRed
                          : isOverdue
                              ? AppTheme.warningOrange
                              : AppTheme.primaryBlue)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isExpired
                    ? '⚠ Auto-withdrawal pending — ${_formatOverdue(age)} overdue'
                    : '⏱ Auto-withdrawal in ${_formatRemaining(age)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? AppTheme.errorRed
                      : isOverdue
                          ? AppTheme.warningOrange
                          : AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Beneficiary
          Row(children: [
            Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Beneficiary: ${request.displayName}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),

          // Location
          Row(children: [
            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(request.location ?? 'Location not specified',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),

          // Date
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'Started on ${DateFormat.yMMMd().format(request.matchedAt ?? request.createdAt)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ]),

          const SizedBox(height: 16),

          // Action buttons
          if (isPendingFeedback)
            _pendingFeedbackButtons(request)
          else if (request.status == RequestStatus.pendingConfirmation)
            _pendingConfirmationButtons(request)
          else
            _inProgressButtons(request),
        ],
      ),
    );
  }

  // ── Pending for Feedback buttons (completed requests) ──
  Widget _pendingFeedbackButtons(HelpRequest request) {
    if (request.donorFeedbackGiven) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(request: request))),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: AppTheme.primaryBlue),
          ),
          child: const Text('View Details'),
        ),
      );
    }
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FeedbackScreen(
                      request: request,
                      isDonor: true,
                      currentUserId: widget.userId))),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Provide\nFeedback',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(request: request))),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: AppTheme.primaryBlue),
          ),
          child: const Text('View Details'),
        ),
      ),
    ]);
  }

  // ── In Progress buttons (matched / active requests) ──
  Widget _inProgressButtons(HelpRequest request) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<DeliveryResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DeliveryCompletionScreen(request: request),
                  ),
                );
                if (!mounted) return;
                if (result == DeliveryResult.completedViaQr) {
                  await showFeedbackPrompt(
                    context: context,
                    request: request,
                    isDonor: true,
                    userId: widget.userId,
                  );
                } else if (result == DeliveryResult.pendingConfirmation) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Marked as delivered. Waiting for beneficiary confirmation.'),
                    backgroundColor: AppTheme.primaryBlue,
                  ));
                }
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Submit\nDelivery',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatScreen(
                          request: request,
                          currentUserId: widget.userId,
                          currentUserName: widget.userName))),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: request))),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppTheme.primaryBlue),
              ),
              child: const Text('View\nDetails',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmCancel(request),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Cancel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRemaining(Duration age) {
    final remaining = const Duration(hours: 4) - age;
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatOverdue(Duration age) {
    final overdue = age - const Duration(hours: 4);
    final h = overdue.inHours;
    final m = overdue.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  static const _donorCancelReasons = [
    'Unable to fulfil at this time',
    'Emergency / personal reason',
    'Miscommunication with beneficiary',
    'Other',
  ];

  void _confirmCancel(HelpRequest request) async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final strikeInfo = await fs.getDonorStrikeInfo(widget.userId);
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
                        requestId: request.id,
                        reason: reason,
                        cancelledBy: 'donor',
                        donorId: widget.userId,
                      );
                      if (!mounted) return;
                      _showStrikeSnackbar(result, isWithdraw: false);
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
        ? 'You already have 1 strike. This action will result in a 24-hour ban from accepting requests.'
        : 'This will count as a cancellation strike. A 2nd strike within 30 days results in a 24-hour ban.';
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
            child: Text(message,
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  void _showStrikeSnackbar(String? result, {required bool isWithdraw}) {
    final action = isWithdraw ? 'Withdrawn.' : 'Cancelled.';
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Failed to ${isWithdraw ? 'withdraw' : 'cancel'}. Please try again.'),
        backgroundColor: AppTheme.errorRed,
      ));
    } else if (result == 'banned') {
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
        content: Text('$action The request is now open again.'),
        backgroundColor: AppTheme.successGreen,
      ));
    }
  }

  // ── Awaiting beneficiary confirmation buttons ──
  Widget _pendingConfirmationButtons(HelpRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 14, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Awaiting beneficiary confirmation…',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      request: request,
                      currentUserId: widget.userId,
                      currentUserName: widget.userName),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Message',
                  style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RequestDetailScreen(request: request)),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppTheme.primaryBlue),
              ),
              child: const Text('View\nDetails',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _statusTag(RequestStatus status, bool isPendingFeedback) {
    final String label;
    final Color color;

    if (isPendingFeedback) {
      label = 'Pending Feedback';
      color = AppTheme.successGreen;
    } else if (status == RequestStatus.pendingConfirmation) {
      label = 'Awaiting Confirmation';
      color = AppTheme.primaryBlue;
    } else if (status == RequestStatus.active) {
      label = 'In Progress';
      color = AppTheme.primaryBlue;
    } else {
      label = 'Pending';
      color = AppTheme.warningOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _categoryTag(String label) {
    Color color;
    switch (label.toLowerCase()) {
      case 'food':
        color = AppTheme.primaryBlue;
        break;
      case 'medical':
        color = AppTheme.errorRed;
        break;
      case 'education':
        color = AppTheme.successGreen;
        break;
      case 'transportation':
        color = AppTheme.warningOrange;
        break;
      case 'housing':
        color = AppTheme.primaryPurple;
        break;
      default:
        color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}
