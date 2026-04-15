import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/beneficiary/edit_request_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class BeneficiaryRequestDetailScreen extends StatelessWidget {
  final HelpRequest request;
  final String userId;
  final String userName;

  const BeneficiaryRequestDetailScreen({
    super.key,
    required this.request,
    required this.userId,
    required this.userName,
  });

  static const List<String> _ratingLabels = [
    'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'
  ];

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final dateStr = DateFormat('M/d/yyyy').format(request.createdAt);
    final canEdit = request.status == RequestStatus.pending;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // ── Purple header ───────────────────────────────────────────────
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
                const SizedBox(width: 12),
                const Text(
                  'Request Details',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),

          // ── Scrollable content ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status pill
                  _StatusPill(status: request.status),
                  const SizedBox(height: 16),

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
                          request.title,
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
                          value: request.categoryLabel,
                        ),
                        const SizedBox(height: 12),
                        if (request.location != null &&
                            request.location!.isNotEmpty) ...[
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: request.location!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Requested by',
                          value: request.displayName,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date Posted',
                          value: dateStr,
                        ),
                        if ((request.status == RequestStatus.matched ||
                                request.status == RequestStatus.active) &&
                            request.donorName != null) ...[
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.volunteer_activism_outlined,
                            label: 'Donor',
                            value: request.donorName!,
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
                          request.description,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  // Feedback card (when completed and feedback was given)
                  if (request.status == RequestStatus.completed &&
                      request.beneficiaryFeedbackGiven) ...[
                    const SizedBox(height: 16),
                    _FeedbackCard(
                      requestId: request.id,
                      isDonor: false,
                      ratingLabels: _ratingLabels,
                      color: AppTheme.primaryPurple,
                    ),
                  ],

                  // Message button (when matched/active)
                  if (request.status == RequestStatus.matched ||
                      request.status == RequestStatus.active) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                            color: AppTheme.primaryPurple),
                        label: const Text('Message Donor',
                            style: TextStyle(
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppTheme.primaryPurple),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  // Edit / Delete (pending only)
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditRequestScreen(request: request),
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
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmDelete(context),
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.white),
                            label: const Text('Delete',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
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
              final error = await fs.deleteHelpRequest(request.id);
              if (context.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error),
                      backgroundColor: AppTheme.errorRed));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        final int rating = (data['experienceRating'] as num?)?.toInt() ?? 0;
        final String? comment = data['comment'] as String?;
        final int? appRating = (data['appRating'] as num?)?.toInt();
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
                  Icon(Icons.rate_review_outlined, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text('Your Feedback',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              ),
              const SizedBox(height: 12),
              // Stars
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
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
                        fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
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
