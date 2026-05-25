import 'package:flutter/material.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/screens/feedback_screen.dart';
import 'package:helplink/utils/app_theme.dart';

Future<void> showFeedbackPrompt({
  required BuildContext context,
  required HelpRequest request,
  required bool isDonor,
  required String userId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedbackPromptSheet(
      request: request,
      isDonor: isDonor,
      userId: userId,
    ),
  );
}

class _FeedbackPromptSheet extends StatelessWidget {
  final HelpRequest request;
  final bool isDonor;
  final String userId;

  const _FeedbackPromptSheet({
    required this.request,
    required this.isDonor,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // X dismiss button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 18, color: AppTheme.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: color, size: 34),
          ),
          const SizedBox(height: 16),

          Text(
            'How was your experience?',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              isDonor
                  ? 'Your feedback helps us recognise great donors and improve the HelpLink community.'
                  : 'Let us know how your experience was with the donor who helped you.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeedbackScreen(
                      request: request,
                      isDonor: isDonor,
                      currentUserId: userId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Give Feedback',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later',
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
