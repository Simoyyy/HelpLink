import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/firestore_service.dart';

class DonorBadge {
  final String emoji;
  final String name;
  final int threshold;
  final Color color;
  const DonorBadge({
    required this.emoji,
    required this.name,
    required this.threshold,
    required this.color,
  });
}

const donorBadges = [
  DonorBadge(
      emoji: '🌱', name: 'Newcomer', threshold: 0, color: Color(0xFF4CAF50)),
  DonorBadge(
      emoji: '🤝', name: 'Helper', threshold: 1, color: Color(0xFF2196F3)),
  DonorBadge(
      emoji: '⭐', name: 'Dedicated', threshold: 10, color: Color(0xFFFFC107)),
  DonorBadge(
      emoji: '🏆', name: 'Champion', threshold: 25, color: Color(0xFF8E24AA)),
  DonorBadge(
      emoji: '💎', name: 'Legend', threshold: 50, color: Color(0xFF00BCD4)),
  DonorBadge(
      emoji: '🌟', name: 'Hero', threshold: 100, color: Color(0xFFB71C1C)),
];

DonorBadge badgeForCount(int completed) {
  DonorBadge result = donorBadges.first;
  for (int i = donorBadges.length - 1; i >= 0; i--) {
    if (completed >= donorBadges[i].threshold) {
      result = donorBadges[i];
      break;
    }
  }
  return result;
}

/// Inline badge chip that fetches the donor's completed count and shows
/// emoji + name. Silently shows the lowest badge while loading.
class DonorBadgeChip extends StatefulWidget {
  final String donorId;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  const DonorBadgeChip({
    super.key,
    required this.donorId,
    this.fontSize = 11,
    this.horizontalPadding = 8,
    this.verticalPadding = 3,
  });

  @override
  State<DonorBadgeChip> createState() => _DonorBadgeChipState();
}

class _DonorBadgeChipState extends State<DonorBadgeChip> {
  Future<Map<String, int>>? _future;

  @override
  Widget build(BuildContext context) {
    _future ??= Provider.of<FirestoreService>(context, listen: false)
        .getDonorStats(widget.donorId);
    return FutureBuilder<Map<String, int>>(
      future: _future,
      builder: (context, snapshot) {
        final completed = snapshot.data?['completed'] ?? 0;
        final badge = badgeForCount(completed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: widget.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: badge.color.withOpacity(0.28),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: badge.color.withOpacity(0.85), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: badge.color.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge.emoji,
                  style: TextStyle(
                      fontSize: widget.fontSize, color: Colors.white)),
              const SizedBox(width: 4),
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
