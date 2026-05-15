import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class DonorHistoryScreen extends StatelessWidget {
  const DonorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: user == null
          ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120))
          : _HistoryContent(userId: user.uid),
    );
  }
}

class _HistoryContent extends StatefulWidget {
  final String userId;

  const _HistoryContent({required this.userId});

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Food',
    'Medical',
    'Education',
    'Transportation',
    'Housing',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<List<HelpRequest>>(
      stream: firestoreService.getDonorAllAssistance(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
        }

        final allRequests = snapshot.data ?? [];

        // Filter by category
        final filteredRequests = _selectedCategory == 'All'
            ? allRequests
            : allRequests
                .where((r) =>
                    r.categoryLabel.toLowerCase() ==
                    _selectedCategory.toLowerCase())
                .toList();

        // Count per category
        final categoryCounts = <String, int>{'All': allRequests.length};
        for (final cat in _categories.skip(1)) {
          categoryCounts[cat] = allRequests
              .where((r) =>
                  r.categoryLabel.toLowerCase() == cat.toLowerCase())
              .length;
        }

        return Column(
          children: [
            // Blue gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 48, 0, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.donorGradientStart,
                    AppTheme.donorGradientEnd,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Assistance History',
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
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Total count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Total assistance provided: ${allRequests.length}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter label
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Filter by Category',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category filter chips
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;
                          final count = categoryCounts[cat] ?? 0;
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
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '$cat ($count)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Request cards
                    if (filteredRequests.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Lottie.asset('assets/lottie/empty_requests.json',
                                  width: 160, height: 160, repeat: true),
                              const SizedBox(height: 8),
                              const Text('No assistance history yet.',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 14)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) =>
                            _buildHistoryCard(filteredRequests[index]),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(HelpRequest request) {
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
          // Title
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            request.description,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Status + Category tags
          Row(
            children: [
              _buildStatusTag(request.status),
              const SizedBox(width: 8),
              _buildCategoryTag(request.categoryLabel),
            ],
          ),
          const SizedBox(height: 12),

          // Beneficiary
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Beneficiary: ${request.displayName}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Location
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.location ?? 'Location not specified',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Accepted date
          if (request.matchedAt != null)
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Accepted on ${DateFormat.yMMMd().format(request.matchedAt!)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              if (request.status == RequestStatus.completed)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Feedback functionality placeholder
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feedback feature coming soon!'),
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Provide\nFeedback',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (request.status == RequestStatus.completed)
                const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestDetailScreen(request: request),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(RequestStatus status) {
    String label;
    Color color;
    switch (status) {
      case RequestStatus.pending:
        label = 'Pending';
        color = AppTheme.warningOrange;
        break;
      case RequestStatus.matched:
        label = 'Pending';
        color = AppTheme.warningOrange;
        break;
      case RequestStatus.active:
        label = 'Active';
        color = AppTheme.primaryBlue;
        break;
      case RequestStatus.completed:
        label = 'Completed';
        color = AppTheme.successGreen;
        break;
      case RequestStatus.cancelled:
        label = 'Cancelled';
        color = AppTheme.errorRed;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: color),
      ),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
