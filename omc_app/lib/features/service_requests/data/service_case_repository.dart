import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_case.dart';

final serviceCasesProvider = Provider<List<ServiceCase>>((ref) {
  return const [
    ServiceCase(
      id: 'case-001',
      reference: 'OMC-2026-001',
      title: 'Annual Income Tax Filing - Salaried',
      category: 'Income Tax Return',
      status: 'In Review',
      createdAtLabel: 'Today',
      updatedAtLabel: 'Just now',
      progress: 0.35,
      nextStep: 'OMC team is reviewing your salary and tax documents.',
      remarks: 'Upload any missing withholding certificates if available.',
    ),
    ServiceCase(
      id: 'case-002',
      reference: 'OMC-2026-002',
      title: 'NTN Registration',
      category: 'NTN Registration',
      status: 'Documents Required',
      createdAtLabel: 'Yesterday',
      updatedAtLabel: '2 hours ago',
      progress: 0.55,
      nextStep: 'CNIC back image is required to continue.',
      remarks: 'Please upload a clear CNIC back image.',
    ),
    ServiceCase(
      id: 'case-003',
      reference: 'OMC-2026-003',
      title: 'IRIS Profile Update',
      category: 'IRIS Profile',
      status: 'Completed',
      createdAtLabel: 'Last week',
      updatedAtLabel: 'Completed',
      progress: 1,
      nextStep: 'No action required.',
      remarks: 'Your IRIS profile update has been completed.',
    ),
  ];
});
