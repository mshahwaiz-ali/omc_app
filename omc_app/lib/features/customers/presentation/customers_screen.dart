import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          loading: () => const _CustomersLoading(),
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
      return const _EmptyCustomersState();
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
    final theme = Theme.of(context);
    final statusLabel = _customerStatusLabel(customer.status);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.groups_2_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (customer.companyName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          customer.companyName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusPill(label: statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (customer.phone != null)
                  _InfoChip(icon: Icons.call_rounded, label: customer.phone!),
                if (customer.email != null)
                  _InfoChip(
                    icon: Icons.mail_outline_rounded,
                    label: customer.email!,
                  ),
                if (customer.city != null)
                  _InfoChip(
                    icon: Icons.location_city_rounded,
                    label: customer.city!,
                  ),
                if (customer.lastActivityLabel != null)
                  _InfoChip(
                    icon: Icons.history_rounded,
                    label: customer.lastActivityLabel!,
                  ),
              ],
            ),
          ],
        ),
      ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyCustomersState extends StatelessWidget {
  const _EmptyCustomersState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Icon(
          Icons.groups_2_rounded,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'No customers yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customer records and activity will appear here once the backend returns customer data.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CustomersLoading extends StatelessWidget {
  const _CustomersLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
