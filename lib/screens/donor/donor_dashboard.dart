import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/services/ai_service.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/ai_chat_screen.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/screens/donor/donor_history_screen.dart';
import 'package:helplink/screens/donor/donor_ongoing_screen.dart';
import 'package:helplink/screens/donor/donor_profile_screen.dart';
import 'package:helplink/screens/donor/set_location_screen.dart';
import 'package:helplink/screens/notification_screen.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/donor_badges.dart';
import 'package:helplink/widgets/report_bottom_sheet.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final int _selectedTab = 0;
  String _selectedCategory = 'All';

  final _aiService = AIService();
  Future<List<RecommendedRequest>>? _recommendationsFuture;
  bool _recInitialized = false;
  Future<Map<String, int>>? _statsFuture;

  VoidCallback? _closeChat;

  @override
  void dispose() {
    _closeChat?.call();
    super.dispose();
  }

  static const _bgAsset =
      'assets/images/Help and support to climbing employee from mentor or leader hand.jpg';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recInitialized) {
      _recInitialized = true;
      precacheImage(
          ResizeImage(const AssetImage(_bgAsset), width: 800), context);
      _loadRecommendations();
      _loadStats();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerification());
    }
  }

  void _checkVerification() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.icVerificationPromptShown) return;
    final user = authService.userModel;
    if (user != null && user.isICVerified != true) {
      authService.markICVerificationPromptShown();
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _VerificationPromptSheet(
          onVerify: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/ic-verification');
          },
          onLater: () => Navigator.pop(context),
        ),
      );
    }
  }

  void _loadRecommendations() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    setState(() {
      _recommendationsFuture = Future.wait([
        fs.getAvailableRequestsOnce(excludeUserId: user.uid),
        fs.getDonorHistoryCategories(user.uid),
      ]).then((results) => _aiService.getRecommendedRequests(
            donor: user,
            availableRequests: results[0] as List<HelpRequest>,
            previousCategories: results[1] as List<String>,
          ));
    });
  }

  void _loadStats() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    setState(() {
      _statsFuture = fs.getDonorStats(user.uid);
    });
  }

  final List<String> _categories = [
    'All',
    'Food',
    'Medical',
    'Education',
    'Transportation',
    'Housing',
  ];

  RequestCategory? get _filterCategory {
    switch (_selectedCategory) {
      case 'Food':
        return RequestCategory.food;
      case 'Medical':
        return RequestCategory.medical;
      case 'Education':
        return RequestCategory.education;
      case 'Transportation':
        return RequestCategory.transportation;
      case 'Housing':
        return RequestCategory.housing;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = authService.userModel;

    if (user == null) {
      return Scaffold(
          body: Center(
              child: Lottie.asset('assets/lottie/loading.json',
                  width: 120, height: 120)));
    }

    final initials = user.fullName.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    Widget initialsWidget = Center(
      child: Text(initials,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: _buildChibiRobotFab(context, user),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Blue gradient header ───
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.donorGradientStart,
                    AppTheme.donorGradientEnd
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Welcome back,',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white70)),
                            Text(user.fullName,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Donor',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 6),
                                FutureBuilder<Map<String, int>>(
                                  future: _statsFuture,
                                  builder: (context, snapshot) {
                                    final completed =
                                        snapshot.data?['completed'] ?? 0;
                                    DonorBadge badge = donorBadges.first;
                                    for (int i = donorBadges.length - 1;
                                        i >= 0;
                                        i--) {
                                      if (completed >=
                                          donorBadges[i].threshold) {
                                        badge = donorBadges[i];
                                        break;
                                      }
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badge.color,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: badge.color, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(badge.emoji,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          const SizedBox(width: 4),
                                          Text(badge.name,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DonorProfileScreen())),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      NotificationScreen(user: user))),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 22),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => showReportSheet(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.flag_outlined,
                                color: Colors.white, size: 22),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await authService.setActiveRole(UserRole.beneficiary);
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/beneficiary-dashboard');
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            await authService.signOut();
                            navigator.pushReplacementNamed('/login');
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<List<HelpRequest>>(
                    stream: firestoreService.getDonorActiveAssistance(user.uid),
                    builder: (context, snapshot) {
                      final activeCount = snapshot.data?.length ?? 0;
                      return GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DonorOngoingScreen())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Active Assistance',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70)),
                                    const SizedBox(height: 4),
                                    Text('$activeCount',
                                        style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('Helping Now!',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Stats & Badges ───
            _buildStatsSection(),

            const SizedBox(height: 16),

            // ─── Tab selector ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(
                    child: _buildTab(
                        'Browse Nearby', Icons.location_on_outlined, 0)),
                Expanded(child: _buildTab('History', Icons.history, 1)),
              ]),
            ),

            const SizedBox(height: 20),

            // ─── Recommended Requests (AI) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Recommended Requests',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9333EA), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✨', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 3),
                            Text('AI',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _loadRecommendations,
                    child: const Row(
                      children: [
                        Icon(Icons.refresh,
                            size: 16, color: AppTheme.primaryBlue),
                        SizedBox(width: 4),
                        Text('Refresh',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('AI-powered suggestions just for you',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<RecommendedRequest>>(
              future: _recommendationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset('assets/lottie/loading.json',
                              width: 120, height: 120),
                          const Text('Finding best matches for you...',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset('assets/lottie/empty_state.json',
                            width: 160, height: 160),
                        const Text('No recommendations right now.',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark)),
                        const SizedBox(height: 4),
                        const Text('Browse available requests below.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  height: 265,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) =>
                        _buildRecommendedCard(snapshot.data![index]),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Categories ───
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Categories',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted))),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppTheme.primaryBlue : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textDark)),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ─── Available Help Requests ───
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Available Help Requests',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark))),
            const SizedBox(height: 12),

            StreamBuilder<List<HelpRequest>>(
              stream: firestoreService.getAvailableRequests(
                  category: _filterCategory, excludeUserId: user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Lottie.asset('assets/lottie/loading.json',
                              width: 120, height: 120)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset('assets/lottie/empty_requests.json',
                            width: 180, height: 180),
                        const Text('No help requests available.',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark)),
                        const SizedBox(height: 4),
                        const Text('Check back later or try another category.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) =>
                      _buildRequestCard(snapshot.data![index]),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SetLocationScreen()));
        } else if (index == 1) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DonorHistoryScreen()));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: index == 0 ? const Radius.circular(16) : Radius.zero,
            bottomRight: index == 1 ? const Radius.circular(16) : Radius.zero,
          ),
          border: Border.all(
              color:
                  isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18, color: isSelected ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textMuted)),
        ]),
      ),
    );
  }

  Widget _buildRecommendedCard(RecommendedRequest rec) {
    final request = rec.request;
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Urgent banner — shown above title when description signals critical need
        if (rec.isUrgent)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_rounded, size: 14, color: Color(0xFFFF3B30)),
              SizedBox(width: 5),
              Text('URGENT NEED',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF3B30),
                      letterSpacing: 0.5)),
            ]),
          ),
        Row(children: [
          Expanded(
            child: Text(request.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark),
                overflow: TextOverflow.ellipsis),
          ),
          if (rec.isUrgent)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.warning_rounded,
                  size: 18, color: Color(0xFFFF3B30)),
            ),
          if (request.isEmergency)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('SOS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 4),
        _buildCategoryTag(request.categoryLabel),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Expanded(
            child: Text(request.location ?? 'No location',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 8),
        // AI reason
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF9333EA).withValues(alpha: 0.08),
                const Color(0xFF06B6D4).withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF9333EA).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Text('✨', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(rec.reason,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9333EA),
                      fontStyle: FontStyle.italic)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RequestDetailScreen(request: request))),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('View Details', style: TextStyle(fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  Widget _buildRequestCard(HelpRequest request) {
    final dateStr = DateFormat('MMM d, yyyy').format(request.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(request.title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        const SizedBox(height: 4),
        Text(request.description,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(children: [
          _buildCategoryTag(request.categoryLabel),
          if (request.isAnonymous) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_off,
                    size: 14, color: AppTheme.warningOrange),
                const SizedBox(width: 4),
                Text('Anonymous',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.warningOrange)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        _iconRow(Icons.location_on_outlined,
            request.location ?? 'Location not specified'),
        const SizedBox(height: 4),
        _iconRow(Icons.calendar_today_outlined, 'Posted on $dateStr'),
        const SizedBox(height: 4),
        _iconRow(Icons.person_outline, 'By: ${request.displayName}'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RequestDetailScreen(request: request))),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('View Details',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
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

  Widget _buildCategoryTag(String label) {
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
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final completed = stats?['completed'] ?? 0;
          final active = stats?['active'] ?? 0;
          final total = stats?['total'] ?? 0;
          final loading = snapshot.connectionState == ConnectionState.waiting;

          // Determine current and next badge
          DonorBadge currentBadge = donorBadges.first;
          DonorBadge? nextBadge;
          for (int i = donorBadges.length - 1; i >= 0; i--) {
            if (completed >= donorBadges[i].threshold) {
              currentBadge = donorBadges[i];
              nextBadge =
                  i < donorBadges.length - 1 ? donorBadges[i + 1] : null;
              break;
            }
          }

          final progress = nextBadge == null
              ? 1.0
              : ((completed - currentBadge.threshold) /
                      (nextBadge.threshold - currentBadge.threshold))
                  .clamp(0.0, 1.0);

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
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
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insights_rounded,
                            color: AppTheme.primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Your Impact',
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
                        _statBox(loading ? '–' : '$completed', 'Completed',
                            AppTheme.successGreen),
                        Container(width: 1, color: const Color(0xFFE2E8F0)),
                        _statBox(loading ? '–' : '$active', 'Active',
                            AppTheme.primaryBlue),
                        Container(width: 1, color: const Color(0xFFE2E8F0)),
                        _statBox(loading ? '–' : '$total', 'Total',
                            AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 24, color: Color(0xFFE2E8F0)),
                ),

                // ── Current badge ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: currentBadge.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: currentBadge.color.withValues(alpha: 0.45),
                              width: 2),
                        ),
                        child: Center(
                          child: Text(currentBadge.emoji,
                              style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(currentBadge.name,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: currentBadge.color)),
                              if (nextBadge == null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: currentBadge.color
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('MAX',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: currentBadge.color)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              nextBadge != null
                                  ? '${nextBadge.threshold - completed} more to reach ${nextBadge.name} ${nextBadge.emoji}'
                                  : 'Highest rank achieved! 🎉',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Progress bar ──
                if (nextBadge != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFE8EEF4),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(currentBadge.color),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${currentBadge.emoji} $completed helped',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                        Text('${nextBadge.threshold} for ${nextBadge.emoji}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                const SizedBox(height: 12),

                // ── All badges row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: donorBadges.map((badge) {
                      final earned = completed >= badge.threshold;
                      final isCurrent =
                          badge.threshold == currentBadge.threshold;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isCurrent ? 42 : 36,
                            height: isCurrent ? 42 : 36,
                            decoration: BoxDecoration(
                              color: earned
                                  ? badge.color.withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrent
                                    ? badge.color
                                    : earned
                                        ? badge.color.withValues(alpha: 0.4)
                                        : const Color(0xFFE2E8F0),
                                width: isCurrent ? 2.5 : 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(badge.emoji,
                                  style:
                                      TextStyle(fontSize: isCurrent ? 22 : 18)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isCurrent || earned
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: earned
                                  ? badge.color
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
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
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildChibiRobotFab(BuildContext context, UserModel user) {
    return GestureDetector(
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
            colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('🤖', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

class _VerificationPromptSheet extends StatelessWidget {
  final VoidCallback onVerify;
  final VoidCallback onLater;

  const _VerificationPromptSheet(
      {required this.onVerify, required this.onLater});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 36, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify Your Identity',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your IC verification to build trust with beneficiaries and unlock full access to HelpLink features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onVerify,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Verify IC Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onLater,
            child: const Text('Remind me later',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}
