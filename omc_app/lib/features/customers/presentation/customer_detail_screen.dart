import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
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
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(title: 'Customer details'),
      body: SafeArea(
        top: false,
        child: customerAsync.when(
          data: (customer) {
            if (customer == null) {
              return const PremiumEmptyState(
                icon: Icons.person_search_rounded,
                title: 'Customer detail unavailable',
                message:
                    'This scoped customer record is not available in the current directory view.',
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _IdentityAndStatusCard(customer: customer),
        const SizedBox(height: 24),
        const _SectionHeading(
          title: 'Contact & tax identity',
          supporting:
              'Customer contact and identification fields from the scoped profile.',
        ),
        const SizedBox(height: 10),
        _CustomerDetailsCard(
          rows: [
            _DetailRowData(
              icon: Icons.mail_outline_rounded,
              label: 'Email address',
              value: _addedValue(customer.email),
            ),
            _DetailRowData(
              icon: Icons.call_outlined,
              label: 'Phone number',
              value: _addedValue(customer.phone),
            ),
            _DetailRowData(
              icon: Icons.business_outlined,
              label: 'Company',
              value: _addedValue(customer.companyName),
            ),
            _DetailRowData(
              icon: Icons.location_on_outlined,
              label: 'City',
              value: _addedValue(customer.city),
            ),
            _DetailRowData(
              icon: Icons.badge_outlined,
              label: 'CNIC',
              value: _addedValue(customer.cnic),
            ),
            _DetailRowData(
              icon: Icons.receipt_long_outlined,
              label: 'NTN',
              value: _addedValue(customer.ntn),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeading(
          title: 'Activity',
          supporting: 'Recorded profile activity and customer age.',
        ),
        const SizedBox(height: 10),
        _ActivityCard(customer: customer),
        const SizedBox(height: 18),
        _TechnicalDetailsCard(customer: customer),
      ],
    );
  }
}

class _IdentityAndStatusCard extends StatelessWidget {
  const _IdentityAndStatusCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final identitySupporting = <String>[
      if (_hasValue(customer.companyName)) customer.companyName!.trim(),
      if (_hasValue(customer.city)) customer.city!.trim(),
    ];
    final approval = _cleanValue(customer.approvalStatus);
    final accountState = customer.isActive == null
        ? null
        : customer.isActive!
        ? 'Active'
        : 'Inactive';

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35;
              final identity = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      identitySupporting.isEmpty
                          ? 'Customer profile'
                          : identitySupporting.join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
              final avatar = _CustomerProfileAvatar(
                name: customer.name,
                imageUrl: customer.avatarUrl,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(height: 16),
                    Row(children: [identity]),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [avatar, const SizedBox(width: 16), identity],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('Account status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _CustomerStatusBadge(
            status: customer.status,
            label: customer.statusLabel,
          ),
          if (approval != null || accountState != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                if (approval != null)
                  _StatusFact(label: 'Approval', value: approval),
                if (accountState != null)
                  _StatusFact(label: 'Account', value: accountState),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerProfileAvatar extends StatelessWidget {
  const _CustomerProfileAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConfig.resolveFileUrl(imageUrl);
    final initials = _initials(name);

    return Semantics(
      label: resolvedImageUrl == null
          ? 'Profile photo placeholder for $name'
          : 'Profile photo for $name',
      child: Container(
        width: 64,
        height: 64,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppTheme.processingSoft,
          shape: BoxShape.circle,
        ),
        child: resolvedImageUrl == null
            ? _AvatarInitials(initials: initials)
            : Image.network(
                resolvedImageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                semanticLabel: '$name profile picture',
                errorBuilder: (_, _, _) => _AvatarInitials(initials: initials),
              ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusFact extends StatelessWidget {
  const _StatusFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _CustomerDetailsCard extends StatelessWidget {
  const _CustomerDetailsCard({required this.rows});

  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _DetailRow(data: rows[index]),
            if (index != rows.length - 1) const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.cardSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(data.icon, size: 20, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                SelectableText(
                  data.value,
                  style: Theme.of(context).textTheme.bodyLarge,
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
    final lastActivity = _cleanValue(customer.lastActivityLabel);
    final customerSince = _cleanValue(customer.createdAtLabel);

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ActivityRow(
            icon: Icons.schedule_rounded,
            label: 'Last activity',
            value: lastActivity ?? 'Not available',
          ),
          const Divider(height: 1),
          _ActivityRow(
            icon: Icons.calendar_today_outlined,
            label: 'Customer since',
            value: customerSince ?? 'Not available',
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final rows = <_TechnicalRowData>[
      _TechnicalRowData(label: 'Customer ID', value: customer.id),
      if (_hasValue(customer.linkedErpnextCustomer))
        _TechnicalRowData(
          label: 'ERPNext customer',
          value: customer.linkedErpnextCustomer!.trim(),
        ),
      if (_hasValue(customer.approvalStatus))
        _TechnicalRowData(
          label: 'Approval status',
          value: customer.approvalStatus!.trim(),
        ),
      if (customer.isActive != null)
        _TechnicalRowData(
          label: 'Active flag',
          value: customer.isActive! ? 'Yes' : 'No',
        ),
      if (_hasValue(customer.createdAtLabel))
        _TechnicalRowData(
          label: 'Created',
          value: customer.createdAtLabel!.trim(),
        ),
      if (_hasValue(customer.updatedAtLabel))
        _TechnicalRowData(
          label: 'Updated',
          value: customer.updatedAtLabel!.trim(),
        ),
    ];

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Technical details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            'Backend and account metadata',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            Material(
              color: AppTheme.cardSoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    _TechnicalRow(data: rows[index]),
                    if (index != rows.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final stack =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;

    if (stack) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            SelectableText(
              data.value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              data.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              data.value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.supporting});

  final String title;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(supporting, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _CustomerStatusBadge extends StatelessWidget {
  const _CustomerStatusBadge({required this.status, required this.label});

  final CustomerStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final presentation = _statusPresentation(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: presentation.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(presentation.icon, size: 16, color: presentation.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: presentation.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
}

_StatusPresentation _statusPresentation(CustomerStatus status) {
  switch (status) {
    case CustomerStatus.active:
      return const _StatusPresentation(
        foreground: AppTheme.success,
        background: AppTheme.successSoft,
        icon: Icons.check_circle_outline_rounded,
      );
    case CustomerStatus.pending:
      return const _StatusPresentation(
        foreground: AppTheme.warning,
        background: AppTheme.warningSoft,
        icon: Icons.schedule_rounded,
      );
    case CustomerStatus.prospect:
      return const _StatusPresentation(
        foreground: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.person_search_outlined,
      );
    case CustomerStatus.blocked:
      return const _StatusPresentation(
        foreground: AppTheme.danger,
        background: AppTheme.dangerSoft,
        icon: Icons.block_rounded,
      );
    case CustomerStatus.inactive:
      return const _StatusPresentation(
        foreground: AppTheme.textSecondary,
        background: AppTheme.processingSoft,
        icon: Icons.pause_circle_outline_rounded,
      );
    case CustomerStatus.unknown:
      return const _StatusPresentation(
        foreground: AppTheme.textSecondary,
        background: AppTheme.processingSoft,
        icon: Icons.help_outline_rounded,
      );
  }
}

bool _hasValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && text != '-';
}

String? _cleanValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || text == '-' ? null : text;
}

String _addedValue(String? value) {
  return _cleanValue(value) ?? 'Not added';
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty && word != '-')
      .toList();

  if (words.isEmpty) return 'CU';
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}
