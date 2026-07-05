import 'package:flutter/material.dart';

import '../../../core/widgets/premium_empty_state.dart';

class LeadDetailScreen extends StatelessWidget {
  const LeadDetailScreen({required this.leadId, super.key});

  final String leadId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lead Details')),
      body: PremiumEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'Lead detail foundation',
        message:
            'Lead $leadId is ready for a backend detail endpoint. Timeline, notes, and conversion actions will be connected next.',
      ),
    );
  }
}
