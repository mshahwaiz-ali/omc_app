import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../data/referral_summary.dart';

class ReferralSummaryCard extends StatelessWidget {
  const ReferralSummaryCard({
    super.key,
    required this.summary,
    required this.onRefresh,
    required this.onViewReferrals,
  });

  final ReferralSummary summary;
  final VoidCallback onRefresh;
  final VoidCallback onViewReferrals;

  @override
  Widget build(BuildContext context) {
    final statusLabel = summary.isActive ? 'Active' : 'Inactive';

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group_add_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Referral Code',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Share this code with customers joining OMC.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, active: summary.isActive),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    summary.code,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy referral code',
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: 'Share referral code',
                  onPressed: summary.isActive ? _share : null,
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CountTile(
                  label: 'Total',
                  value: summary.totalReferrals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountTile(
                  label: 'Consented',
                  value: summary.consentedReferrals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountTile(
                  label: 'Active',
                  value: summary.activeReferrals,
                ),
              ),
            ],
          ),
          if (!summary.isActive) ...[
            const SizedBox(height: 12),
            const Text(
              'This referral code is inactive and cannot be used for new signups.',
              style: TextStyle(
                color: Color(0xFFB42318),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewReferrals,
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: const Text('View referrals'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Refresh referral summary',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: summary.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral code copied.')));
  }

  Future<void> _share() async {
    await Share.share(
      'Join OMC using my referral code: ${summary.code}',
      subject: 'OMC referral code',
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? const Color(0xFF067647)
        : const Color(0xFFB42318);
    final background = active
        ? const Color(0xFFEAF8F0)
        : const Color(0xFFFFF1F0);
    final border = active ? const Color(0xFFBFE8D0) : const Color(0xFFFFD5D2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
