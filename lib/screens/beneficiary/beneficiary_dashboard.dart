import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/ai_chat_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_requests_screen.dart';
import 'package:helplink/screens/beneficiary/new_request_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/notification_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  VoidCallback? _closeChat;

  // 0 = all time, otherwise number of days
  int _filterDays = 0;
  RequestCategory? _filterCategory;

  List<HelpRequest> _applyFilters(List<HelpRequest> requests) {
    var result = requests;
    if (_filterDays > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: _filterDays));
      result = result.where((r) => r.createdAt.isAfter(cutoff)).toList();
    }
    if (_filterCategory != null) {
      result = result.where((r) => r.category == _filterCategory).toList();
    }
    return result;
  }

  @override
  void dispose() {
    _closeChat?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = authService.userModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: GestureDetector(
        onTap: () {
          if (_closeChat != null) {
            _closeChat!.call();
            setState(() => _closeChat = null);
          } else {
            _closeChat = showFloatingChat(
              context: context,
              user: user,
              onDismissed: () => setState(() => _closeChat = null),
            );
          }
        },
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.beneficiaryGradientStart,
                AppTheme.beneficiaryGradientEnd,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('🤖', style: TextStyle(fontSize: 28)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: StreamBuilder<List<HelpRequest>>(
        stream: firestoreService.getBeneficiaryRequests(user.uid),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];

          final int active = requests
              .where((r) =>
                  r.status == RequestStatus.pending ||
                  r.status == RequestStatus.matched ||
                  r.status == RequestStatus.active)
              .length;
          final bool hasNewMatch =
              requests.any((r) => r.status == RequestStatus.matched);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Label 1 & 2 & 9: Purple gradient header ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.beneficiaryGradientStart,
                        AppTheme.beneficiaryGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label 1 (name + role) & Label 9 (top icons)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.white70),
                                ),
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Beneficiary',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Label 9: profile, notification, logout icons
                          Row(
                            children: [
                              _buildHeaderIcon(
                                icon: Icons.account_circle_rounded,
                                onTap: () => Navigator.pushNamed(
                                    context, '/beneficiary-profile'),
                              ),
                              const SizedBox(width: 8),
                              _buildHeaderIcon(
                                icon: Icons.notifications_active_rounded,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          NotificationScreen(user: user)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildHeaderIcon(
                                icon: Icons.logout,
                                onTap: () async {
                                  final navigator = Navigator.of(context);
                                  await authService.signOut();
                                  if (mounted) {
                                    navigator.pushReplacementNamed('/login');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Label 2: Active Requests count — tappable, navigates to Ongoing Requests
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BeneficiaryRequestsScreen()),
                        ),
                        child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.pending_actions_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Active Requests',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70)),
                                    const SizedBox(height: 4),
                                    Text('$active',
                                        style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                            if (hasNewMatch)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('New Match!',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                          ],
                        ),
                      ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Label 5 & 6: Action buttons (New Request & History) ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const NewRequestScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: AppTheme.primaryPurple,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Column(
                              children: [
                                Icon(Icons.add_circle_rounded, color: Colors.white, size: 32),
                                SizedBox(height: 8),
                                Text('New Request',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/beneficiary-history');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.history_edu_rounded,
                                    color: AppTheme.primaryPurple, size: 32),
                                SizedBox(height: 8),
                                Text('History',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Label 7: SOS Emergency Button ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.crisis_alert_rounded,
                                  color: AppTheme.errorRed),
                              SizedBox(width: 8),
                              Text('Emergency Assistance'),
                            ],
                          ),
                          content: const Text(
                            'This will connect you with emergency assistance services immediately. '
                            'Use this only for urgent situations such as disaster relief.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorRed),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const NewRequestScreen()),
                                );
                              },
                              child: const Text('Get Help Now'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.crisis_alert_rounded,
                              color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SOS - Emergency Assistance',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              Text('Tap for immediate help',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Label 8: Your Requests list ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Requests',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      if (_filterDays > 0 || _filterCategory != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _filterDays = 0;
                            _filterCategory = null;
                          }),
                          child: const Text('Clear',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Filter box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.filter_alt_rounded,
                                size: 16, color: AppTheme.primaryPurple),
                            const SizedBox(width: 6),
                            const Text('Filter',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryPurple)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Date label
                        const Text('Date',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted)),
                        const SizedBox(height: 6),

                        // Date chips
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final entry in {
                                'All': 0,
                                'Last 7 Days': 7,
                                'Last Month': 30,
                                'Last 3 Months': 90,
                                'Last 6 Months': 180,
                                'Last Year': 365,
                              }.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _filterChip(
                                    label: entry.key,
                                    selected: _filterDays == entry.value,
                                    onTap: () => setState(
                                        () => _filterDays = entry.value),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category label
                        const Text('Type',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted)),
                        const SizedBox(height: 6),

                        // Category chips
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _filterChip(
                                  label: 'All',
                                  selected: _filterCategory == null,
                                  onTap: () =>
                                      setState(() => _filterCategory = null),
                                ),
                              ),
                              for (final cat in RequestCategory.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _filterChip(
                                    label: cat == RequestCategory.other
                                        ? 'Others'
                                        : cat.name[0].toUpperCase() +
                                            cat.name.substring(1),
                                    selected: _filterCategory == cat,
                                    onTap: () =>
                                        setState(() => _filterCategory = cat),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Builder(builder: (context) {
                  final filtered = _applyFilters(requests);
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator()));
                  }
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            requests.isEmpty
                                ? 'No requests yet. Tap "New Request" to get started!'
                                : 'No requests match the selected filters.',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildRequestCard(
                        filtered[index], user.uid, user.fullName),
                  );
                }),

                const SizedBox(height: 24),

                // ─── Label 9: Tips for Better Requests ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('💡', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('Tips for Better Requests',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTipItem(
                            'Be clear and specific about what you need'),
                        _buildTipItem(
                            'Include your location for faster matching'),
                        _buildTipItem(
                            'Choose anonymous mode for privacy if needed'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Label 10: Request Limits info ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('⚠️', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('Request Limits',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Maximum 5 requests per week',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 8),
                        _buildTipItem(
                            'Requests reset every Monday at 12:00 AM'),
                        _buildTipItem(
                            'Plan your requests carefully to ensure you get the help you need'),
                        _buildTipItem(
                            'Combine multiple needs into one request when possible'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
      HelpRequest request, String userId, String userName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.status == RequestStatus.matched
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark),
                ),
              ),
              _buildStatusBadge(request.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _categoryIcon(request.category),
              const SizedBox(width: 5),
              Text(request.categoryLabel,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ],
          ),
          if (request.status == RequestStatus.matched &&
              request.donorName != null) ...[
            const SizedBox(height: 12),
            Text('Donor: ${request.donorName}',
                style:
                    const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      request: request,
                      currentUserId: userId,
                      currentUserName: userName,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded,
                      size: 16, color: AppTheme.primaryPurple),
                  const SizedBox(width: 6),
                  Text('Message',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryIcon(RequestCategory category) {
    IconData icon;
    Color color;
    switch (category) {
      case RequestCategory.food:
        icon = Icons.restaurant_rounded;
        color = Colors.orange;
        break;
      case RequestCategory.medical:
        icon = Icons.medical_services_rounded;
        color = Colors.red;
        break;
      case RequestCategory.education:
        icon = Icons.menu_book_rounded;
        color = Colors.green;
        break;
      case RequestCategory.transportation:
        icon = Icons.directions_car_rounded;
        color = Colors.amber.shade700;
        break;
      case RequestCategory.housing:
        icon = Icons.house_rounded;
        color = AppTheme.primaryPurple;
        break;
      case RequestCategory.other:
        icon = Icons.category_rounded;
        color = AppTheme.primaryBlue;
        break;
    }
    return Icon(icon, size: 15, color: color);
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    switch (status) {
      case RequestStatus.pending:
        bgColor = const Color(0xFFFFF8E1);
        textColor = AppTheme.warningOrange;
        icon = Icons.hourglass_top_rounded;
        break;
      case RequestStatus.matched:
        bgColor = const Color(0xFFE8F5E9);
        textColor = AppTheme.successGreen;
        icon = Icons.handshake_rounded;
        break;
      case RequestStatus.active:
        bgColor = const Color(0xFFE3F2FD);
        textColor = AppTheme.primaryBlue;
        icon = Icons.bolt_rounded;
        break;
      case RequestStatus.completed:
        bgColor = Colors.grey[100]!;
        textColor = AppTheme.textMuted;
        icon = Icons.check_circle_rounded;
        break;
      case RequestStatus.cancelled:
        bgColor = const Color(0xFFFFEBEE);
        textColor = AppTheme.errorRed;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.name[0].toUpperCase() + status.name.substring(1),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryPurple : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textDark))),
        ],
      ),
    );
  }
}
