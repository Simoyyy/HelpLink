import 'package:flutter/material.dart';
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
import 'package:helplink/utils/app_theme.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  int _selectedTab = 0;
  String _selectedCategory = 'All';

  final _aiService = AIService();
  Future<List<RecommendedRequest>>? _recommendationsFuture;
  bool _recInitialized = false;

  VoidCallback? _closeChat;

  @override
  void dispose() {
    _closeChat?.call();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recInitialized) {
      _recInitialized = true;
      _loadRecommendations();
    }
  }

  void _loadRecommendations() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user =
        Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    setState(() {
      _recommendationsFuture = Future.wait([
        fs.getAvailableRequestsOnce(),
        fs.getDonorHistoryCategories(user.uid),
      ]).then((results) => _aiService.getRecommendedRequests(
            donor: user,
            availableRequests: results[0] as List<HelpRequest>,
            previousCategories: results[1] as List<String>,
          ));
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
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
                                style: TextStyle(fontSize: 14, color: Colors.white70)),
                            Text(user.fullName,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Donor',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      Row(children: [
                        IconButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const DonorProfileScreen())),
                            icon: const Icon(Icons.person_outline,
                                color: Colors.white)),
                        IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined,
                                color: Colors.white)),
                        IconButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await authService.signOut();
                              navigator.pushReplacementNamed('/login');
                            },
                            icon: const Icon(Icons.logout, color: Colors.white)),
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
                                builder: (_) =>
                                    const DonorOngoingScreen())),
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
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Active Assistance',
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.white70)),
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

            const SizedBox(height: 4),

            // ─── Tab selector ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(
                    child: _buildTab('Browse Nearby',
                        Icons.location_on_outlined, 0)),
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
                        Icon(Icons.refresh, size: 16, color: AppTheme.primaryBlue),
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Finding best matches for you...',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Column(
                        children: [
                          Text('🔍', style: TextStyle(fontSize: 28)),
                          SizedBox(height: 8),
                          Text('No recommendations right now.',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark)),
                          SizedBox(height: 4),
                          Text('Browse available requests below.',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 230,
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
                      onTap: () =>
                          setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : Colors.white,
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
                  category: _filterCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              'No help requests available in this category.',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14))));
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
            bottomLeft:
                index == 0 ? const Radius.circular(16) : Radius.zero,
            bottomRight:
                index == 1 ? const Radius.circular(16) : Radius.zero,
          ),
          border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.textMuted),
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
            child: const Text('View Details',
                style: TextStyle(fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  Widget _buildRequestCard(HelpRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        Row(children: [
          _buildCategoryTag(request.categoryLabel),
          if (request.isAnonymous) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          AppTheme.warningOrange.withValues(alpha: 0.3))),
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
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Expanded(
              child: Text(request.location ?? 'Location not specified',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('By: ${request.displayName}',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RequestDetailScreen(request: request))),
            child: const Text('View Details →',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue)),
          ),
        ]),
      ]),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
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
