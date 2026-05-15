import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_request_detail_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';

enum _Filter { all, pending, inProgress }

class BeneficiaryRequestsScreen extends StatefulWidget {
  const BeneficiaryRequestsScreen({super.key});

  @override
  State<BeneficiaryRequestsScreen> createState() =>
      _BeneficiaryRequestsScreenState();
}

class _BeneficiaryRequestsScreenState
    extends State<BeneficiaryRequestsScreen> {
  _Filter _activeFilter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    final topPad = MediaQuery.of(context).padding.top;

    if (user == null) {
      return Scaffold(body: Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120)));
    }

    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // ── Purple header ─────────────────────────────────────────────────
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
                    'Ongoing Requests',
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

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<HelpRequest>>(
              stream: firestoreService.getBeneficiaryRequests(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
                }

                final all = snapshot.data ?? [];

                // completed without feedback = still "in progress" for beneficiary
                bool needsFeedback(HelpRequest r) =>
                    r.status == RequestStatus.completed &&
                    !r.beneficiaryFeedbackGiven;

                // Count for labels
                final pendingCount = all
                    .where((r) => r.status == RequestStatus.pending)
                    .length;
                final inProgressCount = all
                    .where((r) =>
                        r.status == RequestStatus.matched ||
                        r.status == RequestStatus.active ||
                        needsFeedback(r))
                    .length;

                // Filtered list
                List<HelpRequest> filtered;
                switch (_activeFilter) {
                  case _Filter.pending:
                    filtered = all
                        .where((r) => r.status == RequestStatus.pending)
                        .toList();
                    break;
                  case _Filter.inProgress:
                    filtered = all
                        .where((r) =>
                            r.status == RequestStatus.matched ||
                            r.status == RequestStatus.active ||
                            needsFeedback(r))
                        .toList();
                    break;
                  case _Filter.all:
                    // hide fully-done completed (feedback given) from ongoing view
                    filtered = all
                        .where((r) =>
                            r.status != RequestStatus.completed ||
                            !r.beneficiaryFeedbackGiven)
                        .toList();
                }

                return Column(
                  children: [
                    // Filter chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All (${all.length})',
                            active: _activeFilter == _Filter.all,
                            onTap: () =>
                                setState(() => _activeFilter = _Filter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pending ($pendingCount)',
                            active: _activeFilter == _Filter.pending,
                            onTap: () => setState(
                                () => _activeFilter = _Filter.pending),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'In Progress ($inProgressCount)',
                            active: _activeFilter == _Filter.inProgress,
                            onTap: () => setState(
                                () => _activeFilter = _Filter.inProgress),
                          ),
                        ],
                      ),
                    ),

                    // Count subtitle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _subtitleFor(_activeFilter, filtered.length),
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    ),

                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Lottie.asset(
                                      'assets/lottie/empty_requests.json',
                                      width: 160,
                                      height: 160,
                                      repeat: true),
                                  const SizedBox(height: 8),
                                  const Text('No requests found.',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textMuted)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _RequestCard(
                                request: filtered[i],
                                userId: user.uid,
                                userName: user.fullName,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(_Filter filter, int count) {
    switch (filter) {
      case _Filter.all:
        return 'Active requests: $count';
      case _Filter.pending:
        return 'Pending requests: $count';
      case _Filter.inProgress:
        return 'In Progress requests: $count';
    }
  }
}

// ── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primaryPurple : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final HelpRequest request;
  final String userId;
  final String userName;

  const _RequestCard({
    required this.request,
    required this.userId,
    required this.userName,
  });

  bool get _isPending => request.status == RequestStatus.pending;
  bool get _isCompleted => request.status == RequestStatus.completed;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy').format(request.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.status == RequestStatus.matched ||
                  request.status == RequestStatus.active
              ? AppTheme.primaryPurple.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            request.title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            request.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          // Status + Category chips
          Row(
            children: [
              _statusChip(request.status),
              const SizedBox(width: 8),
              _categoryChip(request.categoryLabel),
            ],
          ),
          const SizedBox(height: 8),

          // Donor (only when matched/active)
          if ((request.status == RequestStatus.matched ||
                  request.status == RequestStatus.active) &&
              request.donorName != null) ...[
            _iconRow(Icons.person_outline, 'Donor: ${request.donorName!}'),
            const SizedBox(height: 4),
          ],

          // Location
          if (request.location != null && request.location!.isNotEmpty) ...[
            _iconRow(Icons.location_on_outlined, request.location!),
            const SizedBox(height: 4),
          ],

          // Date
          _iconRow(Icons.calendar_today_outlined, 'Started on $dateStr'),

          const SizedBox(height: 12),

          // Buttons
          if (_isCompleted && request.beneficiaryFeedbackGiven)
            // Feedback already given — full-width View Details only
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BeneficiaryRequestDetailScreen(
                      request: request,
                      userId: userId,
                      userName: userName,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('View Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            )
          else
            Row(
            children: [
              Expanded(
                child: _isPending
                    // Pending: disabled yellow "Awaiting For Donor" button
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.hourglass_top_rounded,
                            size: 16, color: AppTheme.warningOrange),
                        label: const Text('Awaiting For Donor',
                            style: TextStyle(
                                color: AppTheme.warningOrange,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppTheme.warningOrange),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: const Color(0xFFFFF8E1),
                          disabledForegroundColor: AppTheme.warningOrange,
                          disabledBackgroundColor: const Color(0xFFFFF8E1),
                        ),
                      )
                    : _isCompleted
                        // Completed, feedback not yet given
                        ? ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeedbackScreen(
                                  request: request,
                                  isDonor: false,
                                  currentUserId: userId,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.star_outline_rounded,
                                size: 16),
                            label: const Text('Provide Feedback',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          )
                        // Matched/active: Message button
                        : OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  request: request,
                                  currentUserId: userId,
                                  currentUserName: userName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline,
                                size: 16, color: AppTheme.primaryPurple),
                            label: const Text('Message',
                                style: TextStyle(
                                    color: AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.primaryPurple),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeneficiaryRequestDetailScreen(
                        request: request,
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('View Details',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ),
      ],
    );
  }

  Widget _statusChip(RequestStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case RequestStatus.pending:
        bg = const Color(0xFFFFF8E1);
        fg = AppTheme.warningOrange;
        label = 'Pending';
        break;
      case RequestStatus.matched:
        bg = const Color(0xFFEDE7F6);
        fg = AppTheme.primaryPurple;
        label = 'In Progress';
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
    return _chip(label, bg, fg);
  }

  Widget _categoryChip(String label) =>
      _chip(label, const Color(0xFFEDE7F6), AppTheme.primaryPurple);

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
