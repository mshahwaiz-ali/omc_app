part of 'approved_customer_home_view.dart';

class _AtAGlance extends StatelessWidget {
  const _AtAGlance({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetric(
            value: summary.activeCases,
            label: 'Active',
            icon: Icons.assignment_outlined,
            accent: OmcPremium.services,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            value: summary.pendingDocuments,
            label: 'Docs needed',
            icon: Icons.folder_copy_outlined,
            accent: OmcPremium.documents,
            attention: summary.pendingDocuments > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            value: summary.paymentsDue,
            label: 'Payments',
            icon: Icons.credit_card_rounded,
            accent: OmcPremium.payments,
            attention: summary.paymentsDue > 0,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.attention = false,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color accent;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final tone = attention ? AppTheme.warning : accent;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: attention
                ? AppTheme.warning.withValues(alpha: 0.30)
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: icon,
              color: tone,
              size: 36,
              iconSize: 19,
              radius: 11,
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTrackServices,
    required this.onOpenDocuments,
    required this.onOpenPayments,
    required this.onOpenSupport,
    required this.onOpenServices,
  });

  final VoidCallback? onTrackServices;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenServices;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      if (onTrackServices != null)
        _QuickAction(
          'My requests',
          Icons.receipt_long_outlined,
          OmcPremium.track,
          onTrackServices!,
        ),
      if (onOpenDocuments != null)
        _QuickAction(
          'Documents',
          Icons.folder_copy_outlined,
          OmcPremium.documents,
          onOpenDocuments!,
        ),
      if (onOpenPayments != null)
        _QuickAction(
          'Payments',
          Icons.credit_card_rounded,
          OmcPremium.payments,
          onOpenPayments!,
        ),
      if (onOpenSupport != null)
        _QuickAction(
          'Get help',
          Icons.support_agent_rounded,
          OmcPremium.system,
          onOpenSupport!,
        ),
      if (onOpenServices != null)
        _QuickAction(
          'New service',
          Icons.add_business_rounded,
          OmcPremium.services,
          onOpenServices!,
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth < 340 || textScale >= 1.5 ? 2 : 3;
        final mainAxisExtent = (106 + ((textScale - 1).clamp(0, 1) * 28))
            .toDouble();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return Semantics(
              button: true,
              label: action.label,
              excludeSemantics: true,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OmcIconBadge(
                          icon: action.icon,
                          color: action.accent,
                          size: 42,
                          iconSize: 21,
                          radius: 13,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.onOpenServices,
    required this.onOpenCalculator,
  });

  final VoidCallback onOpenServices;
  final VoidCallback onOpenCalculator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _ExploreRow(
            icon: Icons.grid_view_rounded,
            accent: OmcPremium.services,
            title: 'Browse OMC services',
            subtitle: 'Start a new service from the full catalogue.',
            onTap: onOpenServices,
          ),
          const Divider(height: 22),
          _ExploreRow(
            icon: Icons.calculate_outlined,
            accent: OmcPremium.tax,
            title: 'Tax calculator',
            subtitle: 'Estimate tax before starting a filing service.',
            onTap: onOpenCalculator,
          ),
        ],
      ),
    );
  }
}

class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              OmcIconBadge(
                icon: icon,
                color: accent,
                size: 42,
                iconSize: 21,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.accent, this.onTap);

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}
