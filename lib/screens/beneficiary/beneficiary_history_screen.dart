import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/beneficiary/beneficiary_request_detail_screen.dart';
import 'package:helplink/screens/beneficiary/edit_request_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';

enum _StatusFilter { all, pending, accepted, completed }

enum _DateFilter { allTime, today, thisWeek, thisMonth }

class BeneficiaryHistoryScreen extends StatelessWidget {
  const BeneficiaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        Provider.of<AuthService>(context, listen: false).userModel;
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: user == null
          ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120))
          : _HistoryContent(userId: user.uid, userName: user.fullName),
    );
  }
}

class _HistoryContent extends StatefulWidget {
  final String userId;
  final String userName;

  const _HistoryContent({required this.userId, required this.userName});

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  _DateFilter _dateFilter = _DateFilter.allTime;

  List<HelpRequest> _applyFilters(List<HelpRequest> all) {
    var list = all;

    // Status filter
    switch (_statusFilter) {
      case _StatusFilter.pending:
        list = list.where((r) => r.status == RequestStatus.pending).toList();
        break;
      case _StatusFilter.accepted:
        list = list
            .where((r) =>
                r.status == RequestStatus.matched ||
                r.status == RequestStatus.active)
            .toList();
        break;
      case _StatusFilter.completed:
        list =
            list.where((r) => r.status == RequestStatus.completed).toList();
        break;
      case _StatusFilter.all:
        break;
    }

    // Date range filter
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        list = list.where((r) => r.createdAt.isAfter(start)).toList();
        break;
      case _DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final weekStart =
            DateTime(start.year, start.month, start.day);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Request History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'View all your help requests',
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

        // ── Filters card ─────────────────────────────────────────────────
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
              // Header
              Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 18, color: AppTheme.primaryPurple),
                  const SizedBox(width: 6),
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                ],
              ),
              const SizedBox(height: 12),

              // Status row
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
                    _statusChip('Pending', _StatusFilter.pending),
                    const SizedBox(width: 8),
                    _statusChip('Accepted', _StatusFilter.accepted),
                    const SizedBox(width: 8),
                    _statusChip('Completed', _StatusFilter.completed),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Date range row
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

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<HelpRequest>>(
            stream: fs.getBeneficiaryRequests(widget.userId),
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
                      const Text('No requests found.',
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
                  userName: widget.userName,
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
          color: active ? AppTheme.primaryPurple : const Color(0xFFF1F5F9),
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
          color: active ? AppTheme.primaryPurple : const Color(0xFFF1F5F9),
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
  final String userName;

  const _HistoryCard({
    required this.request,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('M/d/yyyy').format(request.createdAt);
    final isAccepted = request.status == RequestStatus.matched ||
        request.status == RequestStatus.active;
    final isCompleted = request.status == RequestStatus.completed;
    final isPending = request.status == RequestStatus.pending;

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
                    Icon(Icons.location_on_outlined,
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
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textMuted)),

          // Donor name (when accepted/completed)
          if ((isAccepted || isCompleted) &&
              request.donorName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Donor: ${request.donorName!}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Action links row
          Row(
            children: [
              // Left action
              if (isPending)
                _textLink(
                  'View Details',
                  Icons.arrow_forward,
                  AppTheme.primaryPurple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeneficiaryRequestDetailScreen(
                        request: request,
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  ),
                )
              else if (isAccepted)
                _textLink(
                  'View Messages',
                  Icons.chat_bubble_outline,
                  AppTheme.primaryPurple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        request: request,
                        currentUserId: userId,
                        currentUserName: userName,
                      ),
                    ),
                  ),
                )
              else if (isCompleted && !request.beneficiaryFeedbackGiven)
                _textLink(
                  'Provide Feedback',
                  Icons.star_outline_rounded,
                  AppTheme.primaryPurple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedbackScreen(
                        request: request,
                        isDonor: false,
                        currentUserId: userId,
                      ),
                    ),
                  ),
                )
              else if (isCompleted && request.beneficiaryFeedbackGiven)
                _textLink(
                  'View Details',
                  Icons.arrow_forward,
                  AppTheme.textMuted,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeneficiaryRequestDetailScreen(
                        request: request,
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // Edit (pending only)
              if (isPending) ...[
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditRequestScreen(request: request),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 14, color: AppTheme.primaryPurple),
                      const SizedBox(width: 3),
                      const Text('Edit',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 14, color: AppTheme.errorRed),
                      const SizedBox(width: 3),
                      const Text('Delete',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
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
    switch (status) {
      case RequestStatus.pending:
        label = 'Pending';
        color = AppTheme.warningOrange;
        bg = const Color(0xFFFFF8E1);
        break;
      case RequestStatus.matched:
        label = 'Accepted';
        color = AppTheme.primaryPurple;
        bg = const Color(0xFFEDE7F6);
        break;
      case RequestStatus.active:
        label = 'Accepted';
        color = AppTheme.primaryBlue;
        bg = const Color(0xFFE3F2FD);
        break;
      case RequestStatus.completed:
        label = 'Completed';
        color = AppTheme.successGreen;
        bg = const Color(0xFFE8F5E9);
        break;
      case RequestStatus.cancelled:
        label = 'Cancelled';
        color = AppTheme.errorRed;
        bg = const Color(0xFFFFEBEE);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
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
        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryPurple)),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final fs =
                  Provider.of<FirestoreService>(context, listen: false);
              await fs.deleteHelpRequest(request.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request deleted.'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
