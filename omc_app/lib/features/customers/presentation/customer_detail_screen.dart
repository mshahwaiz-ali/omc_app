import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        CrmDetailHeaderCard(
          icon: Icons.groups_2_rounded,
          title: customer.name,
          subtitle: customer.companyName ?? customer.city ?? 'Customer profile',
          statusLabel: statusLabel,
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Contact',
          rows: [
            CrmInfoRow(label: 'Email', value: customer.email ?? '-'),
            CrmInfoRow(label: 'Phone', value: customer.phone ?? '-'),
            CrmInfoRow(label: 'City', value: customer.city ?? '-'),
            CrmInfoRow(
              label: 'Activity',
              value: customer.lastActivityLabel ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Relationship timeline',
          emptyMessage:
              'No relationship activity yet. Services, documents, payments, and support events will appear here once backend activity data is available.',
        ),
        const SizedBox(height: 16),
        const CrmDetailInfoCard(
          title: 'Relationship',
          rows: [
            CrmInfoRow(label: 'Services', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Documents', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Payments', value: 'Backend-ready placeholder'),
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
