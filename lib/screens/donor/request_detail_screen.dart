import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:intl/intl.dart';

const List<String> _ratingLabels = [
  'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'
];

class RequestDetailScreen extends StatefulWidget {
  final HelpRequest request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _acceptAnonymously = false;
  bool _isLoading = false;

  late HelpRequest _currentRequest;
  StreamSubscription<HelpRequest?>? _requestSub;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestSub == null) {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      _requestSub = fs.getRequestStream(_currentRequest.id).listen((r) {
        if (r != null && mounted) {
          setState(() => _currentRequest = r);
        }
      });
    }
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return 'Awaiting Donor';
      case RequestStatus.matched:
        return 'Matched';
      case RequestStatus.active:
        return 'In Progress';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get _statusColor {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return const Color(0xFFB8860B);
      case RequestStatus.matched:
        return AppTheme.primaryBlue;
      case RequestStatus.active:
        return AppTheme.successGreen;
      case RequestStatus.completed:
        return AppTheme.textMuted;
      case RequestStatus.cancelled:
        return AppTheme.errorRed;
    }
  }

  Color get _statusBgColor {
    switch (_currentRequest.status) {
      case RequestStatus.pending:
        return const Color(0xFFFFF8DC);
      case RequestStatus.matched:
        return AppTheme.primaryBlue.withValues(alpha: 0.1);
      case RequestStatus.active:
        return AppTheme.successGreen.withValues(alpha: 0.1);
      case RequestStatus.completed:
        return AppTheme.textMuted.withValues(alpha: 0.1);
      case RequestStatus.cancelled:
        return AppTheme.errorRed.withValues(alpha: 0.1);
    }
  }

  Future<void> _offerHelp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final user = authService.userModel;
    if (user == null) return;

    setState(() => _isLoading = true);

    final donorName =
        _acceptAnonymously ? 'Anonymous Donor' : user.fullName;

    final error = await firestoreService.offerHelp(
      requestId: _currentRequest.id,
      donorId: user.uid,
      donorName: donorName,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error), backgroundColor: AppTheme.errorRed),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_acceptAnonymously
                ? 'You have anonymously offered to help!'
                : 'You have offered to help! The beneficiary will be notified.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    final isDonor = user != null && user.role.name == 'donor';
    final isPending = _currentRequest.status == RequestStatus.pending;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Blue gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 48, 0, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.donorGradientStart,
                  AppTheme.donorGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
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
                      const Text(
                        'Request Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    _currentRequest.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info rows
                  _buildInfoRow(
                    Icons.sell_outlined,
                    'Category',
                    _currentRequest.categoryLabel,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'Location',
                    _currentRequest.location ?? 'Not specified',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Requested by',
                    _currentRequest.displayName,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    'Date Posted',
                    DateFormat('M/d/yyyy').format(_currentRequest.createdAt),
                  ),
                  if (_currentRequest.donorName != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.volunteer_activism,
                      'Donor',
                      _currentRequest.donorName!,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentRequest.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
                  ),

                  // Feedback card (completed + feedback given)
                  if (_currentRequest.status == RequestStatus.completed &&
                      _currentRequest.donorFeedbackGiven) ...[
                    const SizedBox(height: 24),
                    _buildFeedbackCard(context),
                  ],

                  const SizedBox(height: 24),

                  // Accept Anonymously section (only for donors on pending requests)
                  if (isDonor && isPending) ...[
                    // Anonymous checkbox
                    GestureDetector(
                      onTap: () => setState(
                          () => _acceptAnonymously = !_acceptAnonymously),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _acceptAnonymously
                                ? AppTheme.primaryBlue
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptAnonymously,
                                onChanged: (v) => setState(
                                    () => _acceptAnonymously = v ?? false),
                                activeColor: AppTheme.primaryBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.visibility_off,
                                          size: 18,
                                          color: AppTheme.primaryBlue),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Accept Anonymously',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your identity will remain hidden from the beneficiary. You\'ll appear as "Anonymous Donor".',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Accept button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _offerHelp,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(
                                _acceptAnonymously
                                    ? Icons.visibility_off
                                    : Icons.volunteer_activism,
                                size: 20),
                        label: Text(
                          _acceptAnonymously
                              ? 'Accept Anonymously'
                              : 'Offer to Help',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _acceptAnonymously
                              ? const Color(0xFF1E293B)
                              : AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    return FutureBuilder<Map<String, dynamic>?>(
      future: fs.getFeedback(requestId: _currentRequest.id, isDonor: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final int rating = (data['experienceRating'] as num?)?.toInt() ?? 0;
        final String? comment = data['comment'] as String?;
        final ratingLabel = rating > 0 ? _ratingLabels[rating - 1] : '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Your Feedback',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppTheme.warningOrange,
                    size: 22,
                  ),
                ),
              ),
              if (ratingLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ratingLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue)),
              ],
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Text(comment,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.4)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
