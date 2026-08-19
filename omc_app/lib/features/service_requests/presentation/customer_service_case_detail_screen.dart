import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../../support/application/support_launcher.dart';
import '../data/customer_service_case_repository.dart';
import '../data/service_case_repository.dart';

part 'customer_service_case_detail_evidence.dart';
part 'customer_service_case_detail_sections.dart';
part 'customer_service_case_detail_support.dart';

class CustomerServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const CustomerServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<CustomerServiceCaseDetailScreen> createState() =>
      _CustomerServiceCaseDetailScreenState();
}

class _CustomerServiceCaseDetailScreenState
    extends ConsumerState<CustomerServiceCaseDetailScreen> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(customerServiceCaseDetailProvider(widget.caseId));
    final capabilities = ref.watch(effectiveCapabilitiesProvider);

    Future<void> refresh() async {
      ref.invalidate(customerServiceCaseDetailProvider(widget.caseId));
      await ref.read(customerServiceCaseDetailProvider(widget.caseId).future);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Request',
            subtitle: 'Current stage, requirements and next step',
            actionIcon: Icons.support_agent_rounded,
            actionTooltip: 'Contact support',
            onAction: () => SupportLauncher.openWhatsApp(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: detailAsync.when(
                loading: () => const _LoadingView(),
                error: (error, _) {
                  final failure = AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Service request unavailable',
                    fallbackMessage:
                        'This service request could not be loaded right now.',
                  );
                  return _ErrorView(
                    title: failure.title,
                    message: failure.message,
                    onRetry: failure.canRetry
                        ? () => ref.invalidate(
                            customerServiceCaseDetailProvider(widget.caseId),
                          )
                        : null,
                  );
                },
                data: (detail) {
                  if (detail == null) {
                    return _ErrorView(
                      title: 'Service request not found',
                      message:
                          'This service request is unavailable or is no longer accessible to your account.',
                      onRetry: () => ref.invalidate(
                        customerServiceCaseDetailProvider(widget.caseId),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                      children: [
                        _ServiceHero(detail: detail),
                        const SizedBox(height: 14),
                        _LifecycleCard(detail: detail),
                        const SizedBox(height: 14),
                        _NextStepCard(
                          detail: detail,
                          canViewDocuments: capabilities.canViewDocuments,
                          canViewPayments: capabilities.canViewPayments,
                        ),
                        const SizedBox(height: 14),
                        _DocumentsCard(
                          detail: detail,
                          canViewDocuments: capabilities.canViewDocuments,
                        ),
                        const SizedBox(height: 14),
                        _PaymentCard(
                          detail: detail,
                          canViewPayments: capabilities.canViewPayments,
                        ),
                        if (detail.activities.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _RecentActivityCard(activities: detail.activities),
                        ],
                        if (detail.canCancel && capabilities.canTrackRequests) ...[
                          const SizedBox(height: 14),
                          _CancelRequestCard(
                            busy: _isCancelling,
                            onCancel: () => _confirmCancel(detail),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(CustomerServiceCaseDetail detail) async {
    if (_isCancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel service request?'),
        content: const Text(
          'This will cancel this request. Existing submitted documents and payment proof are not deleted, and you can start a new request later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(customerServiceCaseRepositoryProvider)
          .cancelRequest(detail.id.isEmpty ? widget.caseId : detail.id);
      if (!mounted) return;
      ref.invalidate(customerServiceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);
      ref.invalidate(homeDashboardSummaryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service request cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackMessage: 'Service request could not be cancelled right now.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}
