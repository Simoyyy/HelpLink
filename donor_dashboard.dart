import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  int _selectedTab = 0;
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Food', 'Medical', 'Education', 'Transportation', 'Housing'];

  RequestCategory? get _filterCategory {
    switch (_selectedCategory) {
      case 'Food': return RequestCategory.food;
      case 'Medical': return RequestCategory.medical;
      case 'Education': return RequestCategory.education;
      case 'Transportation': return RequestCategory.transportation;
      case 'Housing': return RequestCategory.housing;
      default: return null;
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
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome back,', style: TextStyle(fontSize: 14, color: Colors.white70)),
                          Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Donor', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      Row(children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.person_outline, color: Colors.white)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined, color: Colors.white)),
                        IconButton(onPressed: () => authService.signOut(), icon: const Icon(Icons.logout, color: Colors.white)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<List<HelpRequest>>(
                    stream: firestoreService.getDonorActiveAssistance(user.uid),
                    builder: (context, snapshot) {
                      final activeCount = snapshot.data?.length ?? 0;
                      return Container(
                        width: double.infinity, padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Active Assistance', style: TextStyle(fontSize: 14, color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text('$activeCount', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: AppTheme.successGreen, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Helping Now!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ],
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
                Expanded(child: _buildTab('Browse Nearby', Icons.location_on_outlined, 0)),
                Expanded(child: _buildTab('History', Icons.history, 1)),
              ]),
            ),

            const SizedBox(height: 20),

            // ─── My Active Assistance ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('My Active Assistance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                GestureDetector(onTap: () {}, child: const Text('View All →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue))),
              ]),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<HelpRequest>>(
              stream: firestoreService.getDonorActiveAssistance(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Center(child: Text('No active assistance yet.\nBrowse requests below to start helping!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 14))),
                    ),
                  );
                }
                return SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => _buildActiveCard(snapshot.data![index], user.uid, user.fullName),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Categories ───
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMuted))),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryBlue : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(cat, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppTheme.textDark)),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ─── Available Help Requests ───
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Available Help Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
            const SizedBox(height: 12),

            StreamBuilder<List<HelpRequest>>(
              stream: firestoreService.getAvailableRequests(category: _filterCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No help requests available in this category.', style: TextStyle(color: Colors.grey[500], fontSize: 14))));
                }
                return ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) => _buildRequestCard(snapshot.data![index]),
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
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: index == 0 ? const Radius.circular(16) : Radius.zero,
            bottomRight: index == 1 ? const Radius.circular(16) : Radius.zero,
          ),
          border: Border.all(color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textMuted)),
        ]),
      ),
    );
  }

  Widget _buildActiveCard(HelpRequest request, String donorId, String donorName) {
    return Container(
      width: 300, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(request.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark), overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.successGreen, borderRadius: BorderRadius.circular(12)),
            child: const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(request.categoryLabel, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(request: request, currentUserId: donorId, currentUserName: donorName))),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white, minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request))),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppTheme.primaryBlue)),
              child: const Text('Details'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildRequestCard(HelpRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(request.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 6),
        Text(request.description, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          _buildCategoryTag(request.categoryLabel),
          if (request.isAnonymous) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.warningOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_off, size: 14, color: AppTheme.warningOrange),
                const SizedBox(width: 4),
                Text('Anonymous', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.warningOrange)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Expanded(child: Text(request.location, style: TextStyle(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('By: ${request.displayName}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request))),
            child: const Text('View Details →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCategoryTag(String label) {
    Color color;
    switch (label.toLowerCase()) {
      case 'food': color = AppTheme.primaryBlue; break;
      case 'medical': color = AppTheme.errorRed; break;
      case 'education': color = AppTheme.successGreen; break;
      case 'transportation': color = AppTheme.warningOrange; break;
      case 'housing': color = AppTheme.primaryPurple; break;
      default: color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}
