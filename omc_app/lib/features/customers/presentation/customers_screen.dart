import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_card.dart';
import '../data/customers_repository.dart';
import '../domain/customer_item.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(customersProvider);
          return ref.read(customersProvider.future);
        },
        child: customersAsync.when(
          data: (customers) => _CustomersContent(customers: customers),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _CustomersContent(customers: []),
        ),
      ),
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
            'Customer records and activity will appear here once the backend returns customer data.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _CustomerCard(customer: customers[index]);
      },
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
      trailing: _StatusPill(label: _customerStatusLabel(customer.status)),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
