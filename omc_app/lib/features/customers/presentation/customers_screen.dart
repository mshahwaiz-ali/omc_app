import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../data/customers_repository.dart';
import '../domain/customer_item.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  CustomerFilter _selectedFilter = CustomerFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppBackHeader(
            title: 'Customers',
            subtitle: 'Profiles, services and account activity',
            fallbackRoute: '/internal-workspace',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(customersProvider);
                await ref.read(customersProvider.future);
              },
              child: customersAsync.when(
                data: _buildCustomerCenter,
                loading: () => const _CustomersLoadingView(),
                error: (error, _) => _BackendUnavailableState(
                  message: _backendErrorMessage(error),
                  onRetry: () => ref.invalidate(customersProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCenter(List<CustomerItem> customers) {
    final query = _searchController.text.trim().toLowerCase();

    final visibleCustomers = customers
        .where((customer) {
          if (query.isNotEmpty && !customer.searchableText.contains(query)) {
            return false;
          }

          switch (_selectedFilter) {
            case CustomerFilter.all:
              return true;
            case CustomerFilter.active:
              return customer.status == CustomerStatus.active;
            case CustomerFilter.pending:
              return customer.status == CustomerStatus.pending;
            case CustomerFilter.inactive:
              return customer.status == CustomerStatus.inactive;
            case CustomerFilter.attention:
              return customer.status == CustomerStatus.pending ||
                  customer.status == CustomerStatus.blocked ||
                  customer.status == CustomerStatus.unknown;
          }
        })
        .toList(growable: false);

    final activeCount = customers
        .where((item) => item.status == CustomerStatus.active)
        .length;
    final pendingCount = customers
        .where((item) => item.status == CustomerStatus.pending)
        .length;
    final attentionCount = customers.where((item) {
      return item.status == CustomerStatus.pending ||
          item.status == CustomerStatus.blocked ||
          item.status == CustomerStatus.unknown;
    }).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 164),
      children: [
        _CustomerSummary(
          total: customers.length,
          active: activeCount,
          pending: pendingCount,
          attention: attentionCount,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search name, phone, CNIC, NTN, email or ID',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CustomerFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = CustomerFilter.values[index];
              final selected = filter == _selectedFilter;

              return ChoiceChip(
                label: Text(filter.label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedFilter = filter);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Customer directory',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Text(
              '${visibleCustomers.length} shown',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleCustomers.isEmpty)
          const PremiumEmptyState(
            icon: Icons.person_search_rounded,
            title: 'No matching customers',
            message: 'Try another search term or customer account filter.',
          )
        else
          for (final customer in visibleCustomers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CustomerCard(customer: customer),
            ),
      ],
    );
  }
}

enum CustomerFilter { all, active, pending, inactive, attention }

extension on CustomerFilter {
  String get label {
    switch (this) {
      case CustomerFilter.all:
        return 'All';
      case CustomerFilter.active:
        return 'Active';
      case CustomerFilter.pending:
        return 'Pending approval';
      case CustomerFilter.inactive:
        return 'Inactive';
      case CustomerFilter.attention:
        return 'Needs attention';
    }
  }
}

class _CustomerSummary extends StatelessWidget {
  const _CustomerSummary({
    required this.total,
    required this.active,
    required this.pending,
    required this.attention,
  });

  final int total;
  final int active;
  final int pending;
  final int attention;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryTile(
              width: width,
              icon: Icons.groups_2_rounded,
              label: 'Total customers',
              value: total,
              color: AppTheme.primary,
              background: AppTheme.primarySoft,
            ),
            _SummaryTile(
              width: width,
              icon: Icons.verified_user_rounded,
              label: 'Active',
              value: active,
              color: AppTheme.success,
              background: const Color(0xFFEAF8EF),
            ),
            _SummaryTile(
              width: width,
              icon: Icons.hourglass_top_rounded,
              label: 'Pending approval',
              value: pending,
              color: AppTheme.warning,
              background: const Color(0xFFFFF4E5),
            ),
            _SummaryTile(
              width: width,
              icon: Icons.priority_high_rounded,
              label: 'Needs attention',
              value: attention,
              color: AppTheme.danger,
              background: AppTheme.dangerSoft,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final double width;
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(customer.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          context.push('/customers/${Uri.encodeComponent(customer.id)}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CustomerAvatar(name: customer.name),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          customer.companyName ?? customer.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      customer.statusLabel,
                      style: TextStyle(
                        color: statusStyle.foreground,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (customer.phone != null)
                    _InfoPill(
                      icon: Icons.call_outlined,
                      label: customer.phone!,
                    ),
                  if (customer.email != null)
                    _InfoPill(
                      icon: Icons.mail_outline_rounded,
                      label: customer.email!,
                    ),
                  if (customer.cnic != null)
                    _InfoPill(
                      icon: Icons.badge_outlined,
                      label: 'CNIC ${customer.cnic}',
                    ),
                  if (customer.ntn != null)
                    _InfoPill(
                      icon: Icons.receipt_long_outlined,
                      label: 'NTN ${customer.ntn}',
                    ),
                  _InfoPill(
                    icon: Icons.fingerprint_rounded,
                    label: customer.id,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer.updatedAtLabel ??
                          customer.lastActivityLabel ??
                          'No activity date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
              .toUpperCase();

    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

_StatusStyle _statusStyle(CustomerStatus status) {
  switch (status) {
    case CustomerStatus.active:
      return const _StatusStyle(
        foreground: AppTheme.success,
        background: Color(0xFFEAF8EF),
      );
    case CustomerStatus.pending:
      return const _StatusStyle(
        foreground: AppTheme.warning,
        background: Color(0xFFFFF4E5),
      );
    case CustomerStatus.inactive:
      return const _StatusStyle(
        foreground: Color(0xFF64748B),
        background: Color(0xFFF1F5F9),
      );
    case CustomerStatus.prospect:
      return const _StatusStyle(
        foreground: AppTheme.info,
        background: Color(0xFFEAF2FF),
      );
    case CustomerStatus.blocked:
      return const _StatusStyle(
        foreground: AppTheme.danger,
        background: AppTheme.dangerSoft,
      );
    case CustomerStatus.unknown:
      return const _StatusStyle(
        foreground: Color(0xFF64748B),
        background: Color(0xFFF1F5F9),
      );
  }
}

class _CustomersLoadingView extends StatelessWidget {
  const _CustomersLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 164),
      children: [
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 18),
        for (var index = 0; index < 4; index++)
          Container(
            height: 126,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
            ),
          ),
      ],
    );
  }
}

class _BackendUnavailableState extends StatelessWidget {
  const _BackendUnavailableState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PremiumEmptyState(
          icon: Icons.groups_2_rounded,
          title: 'Customers unavailable',
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load customers right now. Please try again.';
}
