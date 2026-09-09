import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
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
  int _start = 0;
  String _query = '';
  Timer? _debounce;
  CustomerFilter _selectedFilter = CustomerFilter.all;

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _start = 0;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = customersResultPageProvider((
      start: _start,
      search: _query,
    ));
    final resultAsync = ref.watch(pageProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const AppBackHeader(
            title: 'Customers',
            subtitle: 'Profiles, services and account activity',
            fallbackRoute: '/internal-workspace',
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.invalidate(pageProvider);
                await ref.read(pageProvider.future);
              },
              child: resultAsync.when(
                data: (page) => _buildDirectory(
                  page.items,
                  nextStart: page.nextStart,
                ),
                loading: () => _CustomersLoadingView(
                  searchController: _searchController,
                  onSearch: _search,
                ),
                error: (error, _) => _BackendUnavailableState(
                  searchController: _searchController,
                  onSearch: _search,
                  message: _backendErrorMessage(error),
                  onRetry: () => ref.invalidate(pageProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectory(
    List<CustomerItem> customers, {
    required int? nextStart,
  }) {
    final visibleCustomers = customers.where(_matchesSelectedFilter).toList(
      growable: false,
    );
    final activeCount = customers
        .where((item) => item.status == CustomerStatus.active)
        .length;
    final pendingCount = customers
        .where((item) => item.status == CustomerStatus.pending)
        .length;
    final attentionCount = customers.where(_needsAttention).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _CustomerSearchField(
          controller: _searchController,
          onChanged: _search,
          onClear: () {
            _searchController.clear();
            _search('');
          },
        ),
        const SizedBox(height: 16),
        Text('Filter', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CustomerFilter.values.map((filter) {
            return ChoiceChip(
              label: Text(filter.label),
              selected: filter == _selectedFilter,
              onSelected: (_) => setState(() => _selectedFilter = filter),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 16),
        _PageSummary(
          total: customers.length,
          active: activeCount,
          pending: pendingCount,
          attention: attentionCount,
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Customer directory',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${visibleCustomers.length} shown',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (visibleCustomers.isEmpty)
          const PremiumEmptyState(
            icon: Icons.person_search_rounded,
            title: 'No matching customers',
            message: 'Try another search term or customer account filter.',
          )
        else
          for (var index = 0; index < visibleCustomers.length; index++) ...[
            _CustomerRow(customer: visibleCustomers[index]),
            if (index != visibleCustomers.length - 1)
              const SizedBox(height: 10),
          ],
        const SizedBox(height: 20),
        _PageControls(
          pageNumber: _start ~/ 50 + 1,
          canGoPrevious: _start > 0,
          canGoNext: nextStart != null,
          onPrevious: () => setState(() => _start = (_start - 50).clamp(0, _start)),
          onNext: nextStart == null
              ? null
              : () => setState(() => _start = nextStart),
        ),
      ],
    );
  }

  bool _matchesSelectedFilter(CustomerItem customer) {
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
        return _needsAttention(customer);
    }
  }

  bool _needsAttention(CustomerItem customer) {
    return customer.status == CustomerStatus.pending ||
        customer.status == CustomerStatus.blocked ||
        customer.status == CustomerStatus.unknown;
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

class _CustomerSearchField extends StatelessWidget {
  const _CustomerSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search customers',
        hintText: 'Name, phone, email, CNIC, NTN or ID',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Clear search',
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _PageSummary extends StatelessWidget {
  const _PageSummary({
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
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customers on this page',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'These counts describe only the current server page, not the full customer base.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _SummaryValue(label: 'Total', value: total),
              _SummaryValue(label: 'Active', value: active),
              _SummaryValue(label: 'Pending', value: pending),
              _SummaryValue(label: 'Needs attention', value: attention),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final company = customer.companyName?.trim();
    final contact = _primaryContact(customer);
    final activity = customer.updatedAtLabel ?? customer.lastActivityLabel;

    return Semantics(
      button: true,
      label:
          '${customer.name}. ${company?.isNotEmpty == true ? company : 'No company added'}. ${customer.statusLabel}. ${contact.$2}. Open customer details.',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push('/customers/${Uri.encodeComponent(customer.id)}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CustomerAvatar(
                      name: customer.name,
                      imageUrl: customer.avatarUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            company?.isNotEmpty == true
                                ? company!
                                : 'No company added',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CustomerStatusBadge(status: customer.status, label: customer.statusLabel),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      contact.$1,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        contact.$2,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (activity?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last activity: ${activity!.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View details',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, String) _primaryContact(CustomerItem customer) {
    final phone = customer.phone?.trim();
    if (phone?.isNotEmpty == true) {
      return (Icons.call_outlined, phone!);
    }
    final email = customer.email?.trim();
    if (email?.isNotEmpty == true) {
      return (Icons.mail_outline_rounded, email!);
    }
    return (Icons.contact_page_outlined, 'No contact information available');
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

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiConfig.resolveFileUrl(imageUrl);

    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppTheme.processingSoft,
        shape: BoxShape.circle,
      ),
      child: resolvedUrl == null
          ? _CustomerAvatarInitials(name: name)
          : Image.network(
              resolvedUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _CustomerAvatarInitials(name: name),
            ),
    );
  }
}

class _CustomerAvatarInitials extends StatelessWidget {
  const _CustomerAvatarInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty && part != '-')
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.pageNumber,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageNumber;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final stack =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final previous = OutlinedButton.icon(
      onPressed: canGoPrevious ? onPrevious : null,
      icon: const Icon(Icons.chevron_left_rounded),
      label: const Text('Previous'),
    );
    final next = OutlinedButton.icon(
      onPressed: canGoNext ? onNext : null,
      icon: const Icon(Icons.chevron_right_rounded),
      label: const Text('Next'),
    );
    final page = Text(
      'Page $pageNumber',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          page,
          const SizedBox(height: 10),
          previous,
          const SizedBox(height: 8),
          next,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: previous),
        const SizedBox(width: 12),
        page,
        const SizedBox(width: 12),
        Expanded(child: next),
      ],
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
    case CustomerStatus.inactive:
      return const _StatusPresentation(
        foreground: AppTheme.textSecondary,
        background: AppTheme.processingSoft,
        icon: Icons.pause_circle_outline_rounded,
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
    case CustomerStatus.unknown:
      return const _StatusPresentation(
        foreground: AppTheme.textSecondary,
        background: AppTheme.processingSoft,
        icon: Icons.help_outline_rounded,
      );
  }
}

class _CustomersLoadingView extends StatelessWidget {
  const _CustomersLoadingView({
    required this.searchController,
    required this.onSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _CustomerSearchField(
          controller: searchController,
          onChanged: onSearch,
          onClear: () {
            searchController.clear();
            onSearch('');
          },
        ),
        const SizedBox(height: 18),
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 18),
        for (var index = 0; index < 4; index++) ...[
          PremiumCard(
            padding: const EdgeInsets.all(16),
            child: const SizedBox(height: 104),
          ),
          if (index != 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BackendUnavailableState extends StatelessWidget {
  const _BackendUnavailableState({
    required this.searchController,
    required this.onSearch,
    required this.message,
    required this.onRetry,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _CustomerSearchField(
          controller: searchController,
          onChanged: onSearch,
          onClear: () {
            searchController.clear();
            onSearch('');
          },
        ),
        const SizedBox(height: 18),
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
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage: 'Could not load customers right now. Please try again.',
  ).message;
}
