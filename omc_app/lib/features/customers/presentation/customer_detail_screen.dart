import 'package:flutter/material.dart';

import '../../../core/widgets/premium_empty_state.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: PremiumEmptyState(
        icon: Icons.groups_2_rounded,
        title: 'Customer detail foundation',
        message:
            'Customer $customerId is ready for a backend detail endpoint. Service history, contacts, and documents will be connected next.',
      ),
    );
  }
}
