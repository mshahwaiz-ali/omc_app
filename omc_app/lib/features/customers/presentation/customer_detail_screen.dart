import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../data/customers_repository.dart';
import '../domain/customer_item.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return PremiumEmptyState(
              icon: Icons.groups_2_rounded,
              title: 'Customer detail unavailable',
              message:
                  'Customer $customerId is ready for the backend detail endpoint. Service history, contacts, and documents will appear once data is available.',
            );
          }

          return _CustomerDetailBody(customer: customer);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.groups_2_rounded,
          title: 'Customer detail unavailable',
          message:
              'Customer $customerId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
}

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _customerStatusLabel(customer.status);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DetailHeaderCard(
          icon: Icons.groups_2_rounded,
          title: customer.name,
          subtitle: customer.companyName ?? customer.city ?? 'Customer profile',
          statusLabel: statusLabel,
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Contact',
          rows: [
            _InfoRow(label: 'Email', value: customer.email ?? '-'),
            _InfoRow(label: 'Phone', value: customer.phone ?? '-'),
            _InfoRow(label: 'City', value: customer.city ?? '-'),
            _InfoRow(
              label: 'Activity',
              value: customer.lastActivityLabel ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Relationship',
          rows: const [
            _InfoRow(label: 'Services', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Documents', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Payments', value: 'Backend-ready placeholder'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Customer ID: ${customer.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(label: Text(statusLabel)),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
