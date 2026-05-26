import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';

enum _StatusFilter { all, active, completed, cancelled }

enum _DateFilter { allTime, today, thisWeek, thisMonth }

class DonorHistoryScreen extends StatelessWidget {
  const DonorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: user == null
          ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120))
          : _HistoryContent(userId: user.uid),
    );
  }
}

class _HistoryContent extends StatefulWidget {
  final String userId;
  const _HistoryContent({required this.userId});

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  _DateFilter _dateFilter = _DateFilter.allTime;

  List<HelpRequest> _applyFilters(List<HelpRequest> all) {
    var list = all;

    switch (_statusFilter) {
      case _StatusFilter.active:
        list = list
            .where((r) =>
                r.status == RequestStatus.matched ||
                r.status == RequestStatus.active ||
                r.status == RequestStatus.pendingConfirmation)
            .toList();
        break;
      case _StatusFilter.completed:
        list = list.where((r) => r.status == RequestStatus.completed).toList();
        break;
      case _StatusFilter.cancelled:
        list = list.where((r) => r.status == RequestStatus.cancelled).toList();
        break;
      case _StatusFilter.all:
        break;
    }

    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        list = list.where((r) => r.createdAt.isAfter(start)).toList();
        break;
      case _DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(start.year, start.month, start.day);
        list = list.where((r) => r.createdAt.isAfter(weekStart)).toList();
        break;
      case _DateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        list = list.where((r) => r.createdAt.isAfter(start)).toList();
        break;
      case _DateFilter.allTime:
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final fs = Provider.of<FirestoreService>(context);

    return Column(
      children: [
        // ── Blue header ───────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 20),
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
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 24),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Assistance History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'View all your donor assistance',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),

        // ── Filters card ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 6),
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                ],
              ),
              const SizedBox(height: 12),

              const Text('Status',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statusChip('All', _StatusFilter.all),
                    const SizedBox(width: 8),
                    _statusChip('Active', _StatusFilter.active),
                    const SizedBox(width: 8),
                    _statusChip('Completed', _StatusFilter.completed),
                    const SizedBox(width: 8),
                    _statusChip('Cancelled', _StatusFilter.cancelled),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text('Date Range',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _dateChip('All Time', _DateFilter.allTime),
                    const SizedBox(width: 8),
                    _dateChip('Today', _DateFilter.today),
                    const SizedBox(width: 8),
                    _dateChip('This Week', _DateFilter.thisWeek),
                    const SizedBox(width: 8),
                    _dateChip('This Month', _DateFilter.thisMonth),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<HelpRequest>>(
            stream: fs.getDonorAllAssistance(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
              }

              final filtered = _applyFilters(snapshot.data ?? []);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset('assets/lottie/empty_requests.json',
                          width: 160, height: 160, repeat: true),
                      const SizedBox(height: 8),
                      const Text('No assistance history found.',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _HistoryCard(
                  request: filtered[i],
                  userId: widget.userId,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, _StatusFilter value) {
    final active = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.textMuted)),
      ),
    );
  }

  Widget _dateChip(String label, _DateFilter value) {
    final active = _dateFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _dateFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.textMuted)),
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HelpRequest request;
  final String userId;

  const _HistoryCard({required this.request, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M/d/yyyy').format(request.createdAt);
    final isActive = request.status == RequestStatus.matched ||
        request.status == RequestStatus.active ||
        request.status == RequestStatus.pendingConfirmation;
    final isCompleted = request.status == RequestStatus.completed;
    final isCancelled = request.status == RequestStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark),
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(request.status),
            ],
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            request.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Category chip + location
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _categoryChip(request.categoryLabel),
              if (request.location != null && request.location!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(request.location!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Created date
          Text('Created: $dateStr',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),

          // Beneficiary name
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text('Beneficiary: ${request.displayName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Action links row
          Row(
            children: [
              if (isCompleted && !request.donorFeedbackGiven)
                _textLink(
                  'Provide Feedback',
                  Icons.star_outline_rounded,
                  AppTheme.primaryBlue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedbackScreen(
                        request: request,
                        isDonor: true,
                        currentUserId: userId,
                      ),
                    ),
                  ),
                )
              else if (isCompleted && request.donorFeedbackGiven)
                _textLink(
                  'View Details',
                  Icons.arrow_forward,
                  AppTheme.textMuted,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: request),
                    ),
                  ),
                )
              else if (isActive)
                _textLink(
                  'View Details',
                  Icons.arrow_forward,
                  AppTheme.primaryBlue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: request),
                    ),
                  ),
                )
              else if (isCancelled)
                _textLink(
                  'View Details',
                  Icons.arrow_forward,
                  AppTheme.errorRed,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: request),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textLink(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _statusBadge(RequestStatus status) {
    String label;
    Color color;
    Color bg;
    IconData icon;
    switch (status) {
      case RequestStatus.pending:
        label = 'Pending';
        color = AppTheme.warningOrange;
        bg = const Color(0xFFFFF8E1);
        icon = Icons.hourglass_top_rounded;
        break;
      case RequestStatus.matched:
        label = 'Accepted';
        color = AppTheme.primaryBlue;
        bg = const Color(0xFFE3F2FD);
        icon = Icons.handshake_rounded;
        break;
      case RequestStatus.active:
        label = 'Active';
        color = AppTheme.primaryBlue;
        bg = const Color(0xFFE3F2FD);
        icon = Icons.bolt_rounded;
        break;
      case RequestStatus.pendingConfirmation:
        label = 'Awaiting Confirmation';
        color = AppTheme.primaryBlue;
        bg = const Color(0xFFE3F2FD);
        icon = Icons.pending_rounded;
        break;
      case RequestStatus.completed:
        label = 'Completed';
        color = AppTheme.successGreen;
        bg = const Color(0xFFE8F5E9);
        icon = Icons.check_circle_rounded;
        break;
      case RequestStatus.cancelled:
        label = 'Cancelled';
        color = AppTheme.errorRed;
        bg = const Color(0xFFFFEBEE);
        icon = Icons.cancel_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue)),
    );
  }
}
