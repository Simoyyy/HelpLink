import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

class _BeneficiaryData {
  final Map<String, int> stats;
  final UserModel? user;
  const _BeneficiaryData({required this.stats, this.user});
}

Future<_BeneficiaryData> _fetchBeneficiaryData(
    FirestoreService fs, String beneficiaryId) async {
  final results = await Future.wait([
    fs.getBeneficiaryStats(beneficiaryId),
    fs.getUser(beneficiaryId),
  ]);
  return _BeneficiaryData(
    stats: results[0] as Map<String, int>,
    user: results[1] as UserModel?,
  );
}

/// Full card shown in the donor's request detail screen.
class BeneficiaryProfileCard extends StatefulWidget {
  final String beneficiaryId;

  /// Pass false when the request is anonymous to hide IC verification status.
  final bool showVerification;

  const BeneficiaryProfileCard({
    super.key,
    required this.beneficiaryId,
    this.showVerification = true,
  });

  @override
  State<BeneficiaryProfileCard> createState() => _BeneficiaryProfileCardState();
}

class _BeneficiaryProfileCardState extends State<BeneficiaryProfileCard> {
  Future<_BeneficiaryData>? _future;

  @override
  Widget build(BuildContext context) {
    _future ??= _fetchBeneficiaryData(
        Provider.of<FirestoreService>(context, listen: false),
        widget.beneficiaryId);

    return FutureBuilder<_BeneficiaryData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final stats = data.stats;
        final user = data.user;
        final total = stats['total'] ?? 0;
        final inProgress = stats['active'] ?? 0;
        final completed = stats['completed'] ?? 0;
        final fulfillment =
            total > 0 ? ((inProgress + completed) / total * 100).round() : null;
        final isVerified = widget.showVerification &&
            user != null &&
            user.isICVerified == true;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: AppTheme.primaryPurple, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Beneficiary Profile',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const Spacer(),
                    if (isVerified)
                      _VerifiedBadge()
                    else if (widget.showVerification)
                      _UnverifiedBadge(),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Stats row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _statBox(
                          '$total', 'Total\nSubmitted', AppTheme.primaryPurple),
                      Container(width: 1, color: const Color(0xFFE2E8F0)),
                      _statBox(
                          '$inProgress', 'In\nProgress', AppTheme.primaryBlue),
                      Container(width: 1, color: const Color(0xFFE2E8F0)),
                      _statBox(
                          '$completed', 'Completed', AppTheme.successGreen),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 18, color: Color(0xFFE2E8F0)),
              ),

              // ── Footer: member since + fulfillment rate ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      user != null
                          ? 'Member since ${DateFormat('MMM yyyy').format(user.createdAt)}'
                          : 'Member since —',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (fulfillment != null) ...[
                      const Spacer(),
                      const Icon(Icons.trending_up_rounded,
                          size: 13, color: AppTheme.successGreen),
                      const SizedBox(width: 4),
                      Text(
                        '$fulfillment% fulfilled',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Compact chips shown in the chat header next to the Beneficiary role badge.
class BeneficiaryStatsChip extends StatefulWidget {
  final String beneficiaryId;
  const BeneficiaryStatsChip({super.key, required this.beneficiaryId});

  @override
  State<BeneficiaryStatsChip> createState() => _BeneficiaryStatsChipState();
}

class _BeneficiaryStatsChipState extends State<BeneficiaryStatsChip> {
  Future<_BeneficiaryData>? _future;

  @override
  Widget build(BuildContext context) {
    _future ??= _fetchBeneficiaryData(
        Provider.of<FirestoreService>(context, listen: false),
        widget.beneficiaryId);

    return FutureBuilder<_BeneficiaryData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final stats = data.stats;
        final user = data.user;
        final total = stats['total'] ?? 0;
        final completed = stats['completed'] ?? 0;
        final isVerified = user != null && user.isICVerified == true;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isVerified) ...[
              _headerChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified_rounded, size: 10, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Verified',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 5),
            ],
            _headerChip(
              child: Text(
                '📋 $total  ·  ✅ $completed',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              color: AppTheme.beneficiaryGradientStart,
              useGradient: true,
            ),
          ],
        );
      },
    );
  }

  Widget _headerChip({
    required Widget child,
    required Color color,
    bool isOutline = false,
    bool useGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isOutline ? Colors.white : null,
        gradient: !isOutline && useGradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.beneficiaryGradientStart,
                  AppTheme.beneficiaryGradientEnd,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOutline ? Colors.grey.shade300 : color,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ── Internal badge widgets ────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.successGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.verified_rounded, size: 13, color: AppTheme.successGreen),
          SizedBox(width: 4),
          Text('ID Verified',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successGreen)),
        ],
      ),
    );
  }
}

class _UnverifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textMuted),
          SizedBox(width: 4),
          Text('Not Verified',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
