import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../data/customers_repository.dart';
import '../domain/customer_item.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      appBar: const AppBackHeader(title: 'Customer details'),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const PremiumEmptyState(
              icon: Icons.person_search_rounded,
              title: 'Customer detail unavailable',
              message:
                  'Customer information will appear here when the profile becomes available.',
            );
          }

          return _CustomerDetailBody(customer: customer);
        },
        loading: () => const CrmDetailLoadingView(
          icon: Icons.person_rounded,
          title: 'Loading customer',
          message: 'Fetching customer profile and account details.',
        ),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.person_search_rounded,
          title: 'Customer detail unavailable',
          message: _backendErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(customerDetailProvider(customerId)),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage:
        'Could not load customer details right now. Please try again.',
  ).message;
}

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final contactRows = <_DetailRowData>[
      if (_hasValue(customer.email))
        _DetailRowData(
          icon: Icons.mail_outline_rounded,
          label: 'Email address',
          value: customer.email!,
        ),
      if (_hasValue(customer.phone))
        _DetailRowData(
          icon: Icons.call_outlined,
          label: 'Phone number',
          value: customer.phone!,
        ),
      if (_hasValue(customer.companyName))
        _DetailRowData(
          icon: Icons.business_outlined,
          label: 'Company',
          value: customer.companyName!,
        ),
      if (_hasValue(customer.city))
        _DetailRowData(
          icon: Icons.location_on_outlined,
          label: 'City',
          value: customer.city!,
        ),
      if (_hasValue(customer.cnic))
        _DetailRowData(
          icon: Icons.badge_outlined,
          label: 'CNIC',
          value: customer.cnic!,
        ),
      if (_hasValue(customer.ntn))
        _DetailRowData(
          icon: Icons.receipt_long_outlined,
          label: 'NTN',
          value: customer.ntn!,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _CustomerIdentityCard(customer: customer),
        const SizedBox(height: 14),
        _CustomerOverviewCard(customer: customer),
        if (contactRows.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CustomerDetailsCard(
            title: 'Contact and identity',
            subtitle: 'Primary customer contact and identification details.',
            rows: contactRows,
          ),
        ],
        const SizedBox(height: 14),
        _ActivityCard(customer: customer),
        const SizedBox(height: 14),
        _TechnicalDetailsCard(customer: customer),
      ],
    );
  }

  bool _hasValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty && text != '-';
  }
}

class _CustomerIdentityCard extends StatelessWidget {
  const _CustomerIdentityCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _CustomerStatusStyle.fromStatus(customer.status);
    final subtitle = _identitySubtitle(customer);
    final initials = _initials(customer.name);

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.035),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CustomerProfileAvatar(
                    name: customer.name,
                    initials: initials,
                    imageUrl: customer.avatarUrl,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(label: customer.statusLabel, style: statusStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _identitySubtitle(CustomerItem customer) {
    final values = <String>[
      if (_valid(customer.companyName)) customer.companyName!.trim(),
      if (_valid(customer.city)) customer.city!.trim(),
    ];

    if (values.isEmpty) return 'Customer profile';
    return values.join(' • ');
  }

  bool _valid(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty && text != '-';
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && word != '-')
        .toList();

    if (words.isEmpty) return 'CU';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _CustomerProfileAvatar extends StatelessWidget {
  const _CustomerProfileAvatar({
    required this.name,
    required this.initials,
    this.imageUrl,
  });

  final String name;
  final String initials;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConfig.resolveFileUrl(imageUrl);

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
      ),
      child: resolvedImageUrl == null
          ? _fallback()
          : Image.network(
              resolvedImageUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              semanticLabel: '$name profile picture',
              errorBuilder: (_, _, _) => _fallback(),
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CustomerOverviewCard extends StatelessWidget {
  const _CustomerOverviewCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Overview',
            subtitle: 'Current customer and account status.',
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _OverviewTile(
                  label: 'Approval',
                  value: _cleanValue(
                    customer.approvalStatus,
                    fallback: customer.statusLabel,
                  ),
                  icon: Icons.verified_user_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewTile(
                  label: 'Account',
                  value: customer.isActive == null
                      ? customer.statusLabel
                      : customer.isActive!
                      ? 'Active'
                      : 'Inactive',
                  icon: Icons.account_circle_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OverviewTile(
                  label: 'Last activity',
                  value: _cleanValue(
                    customer.lastActivityLabel,
                    fallback: 'Not available',
                  ),
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewTile(
                  label: 'Customer since',
                  value: _cleanValue(
                    customer.createdAtLabel,
                    fallback: 'Not available',
                  ),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cleanValue(String? value, {required String fallback}) {
    final text = value?.trim() ?? '';
    return text.isEmpty || text == '-' ? fallback : text;
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppTheme.primary.withValues(alpha: 0.85)),
          const SizedBox(height: 11),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailsCard extends StatelessWidget {
  const _CustomerDetailsCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 8),
          for (var index = 0; index < rows.length; index++) ...[
            _DetailRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.055)),
          ],
        ],
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.data});

  final _DetailRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, size: 19, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  data.value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Recent activity',
            subtitle:
                'Services, document reviews and payment updates will appear here.',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
            ),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 23,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No customer activity yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _activityMessage(customer),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _activityMessage(CustomerItem customer) {
    final activity = customer.lastActivityLabel?.trim() ?? '';
    if (activity.isNotEmpty && activity != '-') {
      return 'Latest profile activity: $activity';
    }

    return 'Linked customer events will be shown here when activity data becomes available.';
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final rows = <_TechnicalRowData>[
      _TechnicalRowData(label: 'Customer ID', value: customer.id),
      if (_valid(customer.linkedErpnextCustomer))
        _TechnicalRowData(
          label: 'ERPNext customer',
          value: customer.linkedErpnextCustomer!,
        ),
      if (_valid(customer.approvalStatus))
        _TechnicalRowData(
          label: 'Approval status',
          value: customer.approvalStatus!,
        ),
      if (customer.isActive != null)
        _TechnicalRowData(
          label: 'Active flag',
          value: customer.isActive! ? 'Yes' : 'No',
        ),
      if (_valid(customer.createdAtLabel))
        _TechnicalRowData(label: 'Created', value: customer.createdAtLabel!),
      if (_valid(customer.updatedAtLabel))
        _TechnicalRowData(label: 'Updated', value: customer.updatedAtLabel!),
    ];

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: AppTheme.primary,
          collapsedIconColor: AppTheme.textSecondary,
          title: const Text(
            'Technical details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              'Backend and account metadata',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.045),
                ),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    _TechnicalRow(data: rows[index]),
                    if (index != rows.length - 1)
                      Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _valid(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty && text != '-';
  }
}

class _TechnicalRowData {
  const _TechnicalRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _TechnicalRow extends StatelessWidget {
  const _TechnicalRow({required this.data});

  final _TechnicalRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              data.label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              data.value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.style});

  final String label;
  final _CustomerStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: style.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CustomerStatusStyle {
  const _CustomerStatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  factory _CustomerStatusStyle.fromStatus(CustomerStatus status) {
    switch (status) {
      case CustomerStatus.active:
        return _CustomerStatusStyle.semantic(const Color(0xFF16794B));
      case CustomerStatus.pending:
        return _CustomerStatusStyle.semantic(const Color(0xFFB26A00));
      case CustomerStatus.prospect:
        return _CustomerStatusStyle.semantic(const Color(0xFF2563A9));
      case CustomerStatus.blocked:
        return _CustomerStatusStyle.semantic(const Color(0xFFB42318));
      case CustomerStatus.inactive:
      case CustomerStatus.unknown:
        return _CustomerStatusStyle.semantic(const Color(0xFF667085));
    }
  }

  factory _CustomerStatusStyle.semantic(Color color) {
    return _CustomerStatusStyle(
      foreground: color,
      background: color.withValues(alpha: 0.08),
      border: color.withValues(alpha: 0.15),
    );
  }

  final Color foreground;
  final Color background;
  final Color border;
}
