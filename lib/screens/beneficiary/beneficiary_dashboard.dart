import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/ai_chat_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_requests_screen.dart';
import 'package:helplink/screens/beneficiary/new_request_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_request_detail_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/screens/notification_screen.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/widgets/report_bottom_sheet.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  static const _bgAsset =
      'assets/images/thank-you-note-for-donation-examples.jpg';

  VoidCallback? _closeChat;

  // 0 = all time, otherwise number of days
  int _filterDays = 0;
  RequestCategory? _filterCategory;
  final Set<String> _seenMatchIds = {};
  Future<Map<String, int>>? _statsFuture;

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

  void _loadStats() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    setState(() {
      _statsFuture = fs.getBeneficiaryStats(user.uid);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statsFuture == null) {
      precacheImage(
          ResizeImage(const AssetImage(_bgAsset), width: 800), context);
      _loadStats();
    }
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final total = stats?['total'] ?? 0;
          final active = stats?['active'] ?? 0;
          final completed = stats?['completed'] ?? 0;
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insights_rounded,
                            color: AppTheme.primaryPurple, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Your Activity',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      const Spacer(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Stats row ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _statBox(loading ? '–' : '$total', 'Total\nSubmitted',
                            AppTheme.primaryPurple),
                        Container(width: 1, color: const Color(0xFFE2E8F0)),
                        _statBox(loading ? '–' : '$active', 'Active',
                            AppTheme.primaryBlue),
                        Container(width: 1, color: const Color(0xFFE2E8F0)),
                        _statBox(loading ? '–' : '$completed', 'Completed',
                            AppTheme.successGreen),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
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

    final initials = user.fullName.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final initialsWidget = Center(
      child: Text(initials,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
    );

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
                  r.status == RequestStatus.active ||
                  r.status == RequestStatus.pendingConfirmation)
              .length;
          final bool hasNewMatch = requests
              .where((r) => r.status == RequestStatus.matched)
              .any((r) => !_seenMatchIds.contains(r.id));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Label 1 & 2 & 9: Purple gradient header ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: ResizeImage(
                          const AssetImage(_bgAsset), width: 800),
                      fit: BoxFit.cover,
                      opacity: 0.6,
                    ),
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
                                      fontSize: 14, color: Colors.black54),
                                ),
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple,
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
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                    context, '/beneficiary-profile'),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.2),
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        width: 2),
                                  ),
                                  child: ClipOval(
                                    child: user.profileImageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: user.profileImageUrl!,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            memCacheWidth: 80,
                                            memCacheHeight: 80,
                                            placeholder: (_, __) => initialsWidget,
                                            errorWidget: (_, __, ___) => initialsWidget,
                                          )
                                        : initialsWidget,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          NotificationScreen(user: user)),
                                ),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                      Icons.notifications_active_rounded,
                                      color: Colors.black,
                                      size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => showReportSheet(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.flag_outlined,
                                      color: Colors.black, size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  await authService.setActiveRole(UserRole.donor);
                                  if (context.mounted) {
                                    Navigator.pushReplacementNamed(
                                        context, '/donor-dashboard');
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.swap_horiz_rounded,
                                      color: Colors.black, size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final navigator = Navigator.of(context);
                                  await authService.signOut();
                                  if (mounted) {
                                    navigator.pushReplacementNamed('/login');
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.logout,
                                      color: Colors.black, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Label 2: Active Requests count — tappable, navigates to Ongoing Requests
                      GestureDetector(
                        onTap: () {
                          // Mark all matched requests as seen
                          final matchedRequests = requests
                              .where((r) => r.status == RequestStatus.matched)
                              .map((r) => r.id)
                              .toSet();
                          setState(() {
                            _seenMatchIds.addAll(matchedRequests);
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const BeneficiaryRequestsScreen()),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryPurple.withValues(alpha: 0.8),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppTheme.successGreen,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white24,
                                        ),
                                        child: Lottie.asset(
                                          'assets/lottie/new_match.json',
                                          width: 20,
                                          height: 20,
                                          repeat: true,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('New Match!',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Statistics Dashboard ───
                _buildStatsSection(),

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
                                Icon(Icons.add_circle_rounded,
                                    color: Colors.white, size: 32),
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
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
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

                const SizedBox(height: 16),

                // ─── Mental Health Support Button ───

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.psychology_rounded,
                                  color: AppTheme.primaryPurple),
                              SizedBox(width: 8),
                              Text('Mental Health Support'),
                            ],
                          ),
                          content: const Text(
                            'Here are some helplines you can contact for mental health support:\n\n'
                            'Malaysia: Befrienders Kuala Lumpur (03-7956 8145)\n'
                            'Singapore: Samaritans of Singapore (1800-221 4444)\n'
                            'International: Befrienders Worldwide\n\n'
                            'Please seek professional help if needed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 24),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                              'assets/images/MHH-Asking-for-Help-with-Mental-Health-A-Sign-of-Strength-1024x536.png'),
                          fit: BoxFit.cover,
                          opacity: 0.7,
                        ),
                        color: AppTheme.primaryPurple.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.psychology_rounded,
                              color: Colors.white, size: 36),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Mental Health Support',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              Text('Get help when you need it',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                                    leading: Icon(
                                      _categoryIconData(cat),
                                      size: 13,
                                      color: _filterCategory == cat
                                          ? Colors.white
                                          : _categoryIconColor(cat),
                                    ),
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
                    return Center(
                      child: Lottie.asset(
                        'assets/lottie/loading.json',
                        width: 120,
                        height: 120,
                        repeat: true,
                      ),
                    );
                  }
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Lottie.asset(
                              'assets/lottie/empty_state.json',
                              width: 160,
                              height: 160,
                              repeat: true,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              requests.isEmpty
                                  ? 'No requests yet.\nTap "New Request" to get started!'
                                  : 'No requests match\nthe selected filters.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: AppTheme.textMuted),
                            ),
                          ],
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
                            'Be clear and specific about what you need',
                            icon: Icons.lightbulb_rounded,
                            color: Colors.amber.shade700),
                        _buildTipItem(
                            'Include your location for faster matching',
                            icon: Icons.location_on_rounded,
                            color: Colors.blue),
                        _buildTipItem(
                            'Choose anonymous mode for privacy if needed',
                            icon: Icons.lock_rounded,
                            color: Colors.green),
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
                        _buildTipItem('Requests reset every Monday at 12:00 AM',
                            icon: Icons.calendar_today_rounded,
                            color: AppTheme.primaryPurple),
                        _buildTipItem(
                            'Plan your requests carefully to ensure you get the help you need',
                            icon: Icons.schedule_rounded,
                            color: Colors.orange),
                        _buildTipItem(
                            'Combine multiple needs into one request when possible',
                            icon: Icons.merge_type_rounded,
                            color: Colors.teal),
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BeneficiaryRequestDetailScreen(
            request: request,
            userId: userId,
            userName: userName,
          ),
        ),
      ),
      child: Container(
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
            const SizedBox(height: 6),
            _categoryIcon(request.category),
            if (request.status == RequestStatus.matched &&
                request.donorName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded,
                      size: 14, color: AppTheme.successGreen),
                  const SizedBox(width: 5),
                  Text('Donor: ${request.donorName}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
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
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Message',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIconData(RequestCategory category) {
    switch (category) {
      case RequestCategory.food:
        return Icons.restaurant_rounded;
      case RequestCategory.medical:
        return Icons.medical_services_rounded;
      case RequestCategory.education:
        return Icons.menu_book_rounded;
      case RequestCategory.transportation:
        return Icons.directions_car_rounded;
      case RequestCategory.housing:
        return Icons.house_rounded;
      case RequestCategory.other:
        return Icons.category_rounded;
    }
  }

  Color _categoryIconColor(RequestCategory category) {
    switch (category) {
      case RequestCategory.food:
        return Colors.orange;
      case RequestCategory.medical:
        return Colors.red;
      case RequestCategory.education:
        return Colors.green;
      case RequestCategory.transportation:
        return Colors.amber.shade700;
      case RequestCategory.housing:
        return AppTheme.primaryPurple;
      case RequestCategory.other:
        return AppTheme.primaryBlue;
    }
  }

  Widget _categoryIcon(RequestCategory category) {
    final color = _categoryIconColor(category);
    final icon = _categoryIconData(category);
    final label = category == RequestCategory.other
        ? 'Others'
        : category.name[0].toUpperCase() + category.name.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
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
      case RequestStatus.pendingConfirmation:
        bgColor = const Color(0xFFE3F2FD);
        textColor = AppTheme.primaryBlue;
        icon = Icons.pending_rounded;
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
                fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? leading,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 5)],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text,
      {IconData icon = Icons.check_circle_outline_rounded,
      Color color = Colors.green}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 14, color: AppTheme.textDark))),
        ],
      ),
    );
  }
}
