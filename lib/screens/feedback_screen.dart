import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  final HelpRequest request;
  final bool isDonor;
  final String currentUserId;

  const FeedbackScreen({
    super.key,
    required this.request,
    required this.isDonor,
    required this.currentUserId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _experienceRating = 0;
  int _appRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _ratingLabels = [
    'Poor',
    'Fair',
    'Good',
    'Very Good',
    'Excellent',
  ];

  Color get _primaryColor =>
      widget.isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple;
  Color get _gradientStart => widget.isDonor
      ? AppTheme.donorGradientStart
      : AppTheme.beneficiaryGradientStart;
  Color get _gradientEnd =>
      widget.isDonor ? AppTheme.donorGradientEnd : AppTheme.beneficiaryGradientEnd;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChips(),
                  const SizedBox(height: 20),
                  _buildRequestSummaryCard(),
                  const SizedBox(height: 16),
                  _buildExperienceRating(),
                  const SizedBox(height: 16),
                  _buildCommentBox(),
                  if (!widget.isDonor) ...[
                    const SizedBox(height: 16),
                    _buildAppRating(),
                  ],
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Your feedback helps improve the HelpLink community',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(0, topPad + 6, 0, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, _gradientEnd],
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            'Feedback',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Share your experience and help us grow stronger together',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip('Thank you! \u2665', Icons.favorite_border),
        const SizedBox(width: 10),
        _chip('Making a difference \u2728', Icons.auto_awesome),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor)),
        ],
      ),
    );
  }

  Widget _buildRequestSummaryCard() {
    final otherPartyName = widget.isDonor
        ? widget.request.displayName
        : (widget.request.donorName ?? 'Donor');
    final roleText = widget.isDonor
        ? 'Assistance provided to $otherPartyName'
        : 'Assistance received from $otherPartyName';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.volunteer_activism,
                color: _primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  roleText,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceRating() {
    final question = widget.isDonor
        ? 'How would you rate your experience with the beneficiary?'
        : 'How would you rate your experience with the donor?';

    return _ratingCard(
      label: 'Rating',
      title: question,
      rating: _experienceRating,
      onTap: (val) => setState(() => _experienceRating = val),
    );
  }

  Widget _buildAppRating() {
    return _ratingCard(
      label: 'App Rating',
      title: "How's Your HelpLink Experience?",
      rating: _appRating,
      onTap: (val) => setState(() => _appRating = val),
    );
  }

  Widget _ratingCard({
    required String label,
    required String title,
    required int rating,
    required ValueChanged<int> onTap,
  }) {
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
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => onTap(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppTheme.warningOrange,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                _ratingLabels[rating - 1],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentBox() {
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
          const Text('Comments',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          const Text('Additional comments (optional)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share more about your experience...',
              filled: true,
              fillColor: AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _experienceRating > 0 && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? _submit : null,
        icon: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain))
            : const Icon(Icons.thumb_up_outlined, size: 20),
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit Feedback',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: AppTheme.textMuted,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final success = await fs.submitFeedback(
      requestId: widget.request.id,
      reviewerId: widget.currentUserId,
      isDonor: widget.isDonor,
      experienceRating: _experienceRating,
      appRating: (!widget.isDonor && _appRating > 0) ? _appRating : null,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted. Thank you!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
