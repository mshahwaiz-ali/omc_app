part of 'approved_customer_home_view.dart';

class _AtAGlance extends StatelessWidget {
  const _AtAGlance({
    required this.summary,
    required this.onTrackServices,
    required this.onOpenDocuments,
    required this.onOpenPayments,
  });

  final HomeDashboardSummary summary;
  final VoidCallback? onTrackServices;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          _SummaryLink(
            value: summary.activeCases,
            label: 'Active requests',
            icon: Icons.assignment_outlined,
            accent: OmcPremium.services,
            onTap: onTrackServices,
          ),
          const Divider(height: 1),
          _SummaryLink(
            value: summary.pendingDocuments,
            label: 'Documents needed',
            icon: Icons.folder_copy_outlined,
            accent: summary.pendingDocuments > 0
                ? AppTheme.warning
                : OmcPremium.documents,
            onTap: onOpenDocuments,
          ),
          const Divider(height: 1),
          _SummaryLink(
            value: summary.paymentsDue,
            label: 'Payments due',
            icon: Icons.credit_card_rounded,
            accent: summary.paymentsDue > 0
                ? AppTheme.warning
                : OmcPremium.payments,
            onTap: onOpenPayments,
          ),
        ],
      ),
    );
  }
}

class _SummaryLink extends StatelessWidget {
  const _SummaryLink({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          OmcIconBadge(
            icon: icon,
            color: accent,
            size: 40,
            iconSize: 20,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$value',
            style: TextStyle(
              color: value > 0 ? accent : AppTheme.textSecondary,
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: '$label: $value', child: content);
    }

    return Semantics(
      button: true,
      label: '$label: $value',
      hint: 'Open $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
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
        final singleColumn = constraints.maxWidth < 330 || textScale >= 1.5;
        final tileWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                child: Semantics(
                  button: true,
                  label: action.label,
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: action.onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 72),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OmcIconBadge(
                              icon: action.icon,
                              color: action.accent,
                              size: 42,
                              iconSize: 21,
                              radius: 12,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                action.label,
                                softWrap: true,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ExploreRow(
            icon: Icons.grid_view_rounded,
            accent: OmcPremium.services,
            title: 'Browse OMC services',
            subtitle: 'Start a new service from the full catalogue.',
            onTap: onOpenServices,
          ),
          const Divider(height: 24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
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
