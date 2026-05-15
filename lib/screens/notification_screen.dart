import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  final UserModel user;

  const NotificationScreen({super.key, required this.user});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _showAnnouncements = true;

  bool get _isDonor => widget.user.role == UserRole.donor;

  List<Color> get _gradient =>
      const [Color(0xFF9333EA), Color(0xFF06B6D4)];

  Color get _accent => const Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          _buildHeader(),
          _buildToggle(),
          Expanded(
            child: _showAnnouncements
                ? _buildAnnouncements(firestoreService)
                : _buildMessages(firestoreService),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _toggleBtn(label: 'Announcements', active: _showAnnouncements,
                onTap: () => setState(() => _showAnnouncements = true)),
            const SizedBox(width: 4),
            _toggleBtn(label: 'Messages', active: !_showAnnouncements,
                onTap: () => setState(() => _showAnnouncements = false)),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: _accent.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: active ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  Widget _buildAnnouncements(FirestoreService firestoreService) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmpty(
            icon: Icons.campaign_outlined,
            title: 'No Announcements',
            subtitle: 'System announcements from HelpLink will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildAnnouncementTile(items[i]),
        );
      },
    );
  }

  Widget _buildAnnouncementTile(Map<String, dynamic> a) {
    final createdAt =
        (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradient),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.campaign_outlined,
              color: Colors.white, size: 22),
        ),
        title: Text(
          a['title'] ?? 'Announcement',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(a['body'] ?? '',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Text(
              DateFormat('d MMM yyyy · h:mm a').format(createdAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Widget _buildMessages(FirestoreService firestoreService) {
    final stream = _isDonor
        ? firestoreService.getDonorActiveAssistance(widget.user.uid)
        : firestoreService.getBeneficiaryConversations(widget.user.uid);

    return StreamBuilder<List<HelpRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return _buildEmpty(
            icon: Icons.chat_bubble_outline,
            lottieAsset: 'assets/lottie/chat_empty.json',
            title: 'No Messages Yet',
            subtitle: _isDonor
                ? 'Conversations with beneficiaries will appear here once you accept a request.'
                : 'Conversations with your donors will appear here once your request is matched.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) => _buildConversationTile(requests[i]),
        );
      },
    );
  }

  Widget _buildConversationTile(HelpRequest request) {
    final otherName =
        _isDonor ? request.beneficiaryName : (request.donorName ?? 'Donor');
    final otherRole = _isDonor ? 'Beneficiary' : 'Donor';
    final roleColor =
        _isDonor ? AppTheme.primaryPurple : AppTheme.primaryBlue;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            request: request,
            currentUserId: widget.user.uid,
            currentUserName: widget.user.fullName,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _gradient),
              borderRadius: BorderRadius.circular(22),
            ),
            child:
                const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  otherName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  otherRole,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                request.title,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor(request.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    request.status.name.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(request.status),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  Color _statusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.matched:
        return AppTheme.warningOrange;
      case RequestStatus.active:
        return AppTheme.successGreen;
      case RequestStatus.completed:
        return AppTheme.primaryBlue;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    String lottieAsset = 'assets/lottie/no_notifications.json',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(lottieAsset, width: 160, height: 160, repeat: true),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
