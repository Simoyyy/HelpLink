import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class DonorOngoingScreen extends StatelessWidget {
  const DonorOngoingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        Provider.of<AuthService>(context, listen: false).userModel;
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: user == null
          ? const Center(child: CircularProgressIndicator())
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

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context);

    return StreamBuilder<List<HelpRequest>>(
      stream: fs.getDonorOngoingRequests(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];

        // Pending for Feedback = completed requests (help given, awaiting review)
        final pendingFeedback =
            all.where((r) => r.status == RequestStatus.completed).toList();

        // In Progress = matched or active (currently being helped)
        final inProgress = all
            .where((r) =>
                r.status == RequestStatus.matched ||
                r.status == RequestStatus.active)
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
                    const Text('Ongoing Requests',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
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
                  ? const Center(
                      child: Text('No requests in this category.',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 14)))
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
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () async {
            final fs =
                Provider.of<FirestoreService>(context, listen: false);
            final success = await fs.markAsCompleted(request.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? 'Request marked as completed!'
                    : 'Failed to update. Please try again.'),
                backgroundColor:
                    success ? AppTheme.successGreen : AppTheme.errorRed,
              ));
            }
          },
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Mark\nComplete',
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
    ]);
  }

  Widget _statusTag(RequestStatus status, bool isPendingFeedback) {
    final String label;
    final Color color;

    if (isPendingFeedback) {
      label = 'Pending Feedback';
      color = AppTheme.successGreen;
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
