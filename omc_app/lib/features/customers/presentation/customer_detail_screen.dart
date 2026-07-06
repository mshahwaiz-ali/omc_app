import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/app_back_header.dart';
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
      appBar: const AppBackHeader(title: 'Customer Details'),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return PremiumEmptyState(
              icon: Icons.groups_2_rounded,
              title: 'Customer detail unavailable',
              message:
                  'Service history, contacts and documents will appear here when customer details are available.',
            );
          }

          return _CustomerDetailBody(customer: customer);
        },
        loading: () => const CrmDetailLoadingView(
          icon: Icons.groups_2_rounded,
          title: 'Loading customer',
          message: 'Fetching contact, relationship and service context.',
        ),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.groups_2_rounded,
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
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load customer details right now. Please try again.';
}

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
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
              'No relationship activity yet. Services, documents, payments, and support events will appear here when activity data is available.',
        ),
        const SizedBox(height: 16),
        const CrmDetailInfoCard(
          title: 'Relationship',
          rows: [
            CrmInfoRow(label: 'Services', value: 'No linked services yet'),
            CrmInfoRow(label: 'Documents', value: 'No documents linked yet'),
            CrmInfoRow(label: 'Payments', value: 'No payment summary yet'),
          ],
        ),
        const SizedBox(height: 8),
        CrmDetailMetaFooter(label: 'Customer ID', value: customer.id),
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
