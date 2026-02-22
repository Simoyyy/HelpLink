import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/beneficiary/new_request_screen.dart';
import 'package:helplink/screens/donor/chat_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Purple gradient header ───
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Beneficiary',
                              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(onPressed: () {}, icon: const Icon(Icons.person_outline, color: Colors.white)),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined, color: Colors.white)),
                          IconButton(onPressed: () => authService.signOut(), icon: const Icon(Icons.logout, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<Map<String, int>>(
                    future: firestoreService.getBeneficiaryStats(user.uid),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ?? {'total': 0, 'active': 0, 'completed': 0};
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Requests', style: TextStyle(fontSize: 14, color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text('${stats['active']}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: AppTheme.successGreen, borderRadius: BorderRadius.circular(20)),
                              child: const Text('New Match!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Stats cards ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FutureBuilder<Map<String, int>>(
                future: firestoreService.getBeneficiaryStats(user.uid),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {'total': 0, 'active': 0, 'completed': 0};
                  return Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Requests', '${stats['total']}')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Completed\nRequests', '${stats['completed']}')),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ─── Action buttons ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRequestScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppTheme.primaryPurple, borderRadius: BorderRadius.circular(16)),
                        child: const Column(
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 28),
                            SizedBox(height: 8),
                            Text('New Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.history, color: AppTheme.textDark, size: 28),
                          SizedBox(height: 8),
                          Text('History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── SOS Emergency Button ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS - Emergency Assistance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Tap for immediate help', style: TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Your Requests ───
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Your Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<HelpRequest>>(
              stream: firestoreService.getBeneficiaryRequests(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                      child: const Center(
                        child: Text('No requests yet. Tap "New Request" to get started!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final request = snapshot.data![index];
                    return _buildRequestCard(request, user.uid, user.fullName);
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Tips section ───
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
                        Text('Tips for Better Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem('Be clear and specific about what you need'),
                    _buildTipItem('Include your location for faster matching'),
                    _buildTipItem('Choose anonymous mode for privacy if needed'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Request Limits info ───
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
                        Text('Request Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Maximum 5 requests per week',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem('Requests reset every Monday at 12:00 AM'),
                    _buildTipItem('Plan your requests carefully to ensure you get the help you need'),
                    _buildTipItem('Combine multiple needs into one request when possible'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(HelpRequest request, String userId, String userName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.status == RequestStatus.matched
              ? AppTheme.successGreen.withOpacity(0.3)
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ),
              _buildStatusBadge(request.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(request.categoryLabel, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          if (request.status == RequestStatus.matched && request.donorName != null) ...[
            const SizedBox(height: 12),
            Text('Donor: ${request.donorName}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
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
                  Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primaryPurple),
                  const SizedBox(width: 6),
                  Text('Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case RequestStatus.pending:
        bgColor = const Color(0xFFFFF8E1);
        textColor = AppTheme.warningOrange;
        break;
      case RequestStatus.matched:
        bgColor = const Color(0xFFE8F5E9);
        textColor = AppTheme.successGreen;
        break;
      case RequestStatus.active:
        bgColor = const Color(0xFFE3F2FD);
        textColor = AppTheme.primaryBlue;
        break;
      case RequestStatus.completed:
        bgColor = Colors.grey[100]!;
        textColor = AppTheme.textMuted;
        break;
      case RequestStatus.cancelled:
        bgColor = const Color(0xFFFFEBEE);
        textColor = AppTheme.errorRed;
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
          Icon(Icons.circle, size: 8, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.name[0].toUpperCase() + status.name.substring(1),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textDark))),
        ],
      ),
    );
  }
}
