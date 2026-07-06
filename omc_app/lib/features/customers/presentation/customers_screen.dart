import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../../core/widgets/premium_list_card.dart';
import '../data/customers_repository.dart';
import '../domain/customer_item.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(customersProvider);
          return ref.read(customersProvider.future);
        },
        child: customersAsync.when(
          data: (customers) => _CustomersContent(customers: customers),
          loading: () => const _CustomersLoadingView(),
          error: (error, _) => _BackendUnavailableState(
            icon: Icons.groups_2_rounded,
            title: 'Customers unavailable',
            message: _backendErrorMessage(error),
            onRetry: () => ref.invalidate(customersProvider),
          ),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load customers right now. Please try again.';
}

class _BackendUnavailableState extends StatelessWidget {
  const _BackendUnavailableState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PremiumEmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _CustomersContent extends StatelessWidget {
  const _CustomersContent({required this.customers});

  final List<CustomerItem> customers;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.groups_2_rounded,
        title: 'No customers yet',
        message:
            'Customer records and activity will appear here when customer data is available.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: customers.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return PremiumListHeader(
            icon: Icons.groups_2_rounded,
            title: 'Customers',
            subtitle: 'Browse customer records, activity and account context.',
            metaLabel: '${customers.length} total',
          );
        }

        return _CustomerCard(customer: customers[index - 1]);
      },
    );
  }
}

class _CustomersLoadingView extends StatelessWidget {
  const _CustomersLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const PremiumListHeader(
            icon: Icons.groups_2_rounded,
            title: 'Customers',
            subtitle: 'Browse customer records, activity and account context.',
            metaLabel: 'Loading',
          );
        }

        return const PremiumListCard(
          icon: Icons.groups_2_rounded,
          title: 'Loading customer',
          subtitle: 'Fetching account details',
          children: [
            PremiumInfoChip(icon: Icons.call_rounded, label: 'Phone'),
            PremiumInfoChip(icon: Icons.location_city_rounded, label: 'City'),
            PremiumInfoChip(icon: Icons.history_rounded, label: 'Activity'),
          ],
        );
      },
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemCount: 4,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    return PremiumListCard(
      icon: Icons.groups_2_rounded,
      title: customer.name,
      subtitle: customer.companyName,
      trailing: PremiumInfoChip(label: _customerStatusLabel(customer.status)),
      onTap: () {
        context.push('/customers/${Uri.encodeComponent(customer.id)}');
      },
      children: [
        if (customer.phone != null)
          PremiumInfoChip(icon: Icons.call_rounded, label: customer.phone!),
        if (customer.email != null)
          PremiumInfoChip(
            icon: Icons.mail_outline_rounded,
            label: customer.email!,
          ),
        if (customer.city != null)
          PremiumInfoChip(
            icon: Icons.location_city_rounded,
            label: customer.city!,
          ),
        if (customer.lastActivityLabel != null)
          PremiumInfoChip(
            icon: Icons.history_rounded,
            label: customer.lastActivityLabel!,
          ),
      ],
    );
  }

  String _customerStatusLabel(CustomerStatus status) {
    switch (status) {
      case CustomerStatus.active:
        return 'Active';
      case CustomerStatus.inactive:
        return 'Inactive';
      case CustomerStatus.prospect:
        return 'Prospect';
      case CustomerStatus.blocked:
        return 'Blocked';
      case CustomerStatus.unknown:
        return 'Unknown';
    }
  }
}
