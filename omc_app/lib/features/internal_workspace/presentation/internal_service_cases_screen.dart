import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/internal_service_case.dart';
import 'internal_workspace_providers.dart';

class InternalServiceCasesScreen extends ConsumerStatefulWidget {
  const InternalServiceCasesScreen({super.key});

  @override
  ConsumerState<InternalServiceCasesScreen> createState() =>
      _InternalServiceCasesScreenState();
}

class _InternalServiceCasesScreenState
    extends ConsumerState<InternalServiceCasesScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(internalServiceCaseFiltersProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilters(InternalServiceCaseFilters filters) {
    ref.read(internalServiceCaseFiltersProvider.notifier).state = filters;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(internalServiceCaseFiltersProvider);
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Cases',
            subtitle: 'Select a case before reviewing documents',
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Create service request',
            onAction: () => _showCreateRequestSheet(context),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                ref.invalidate(internalServiceCasesProvider);
                return ref.read(internalServiceCasesProvider.future);
              },
              child: queueAsync.when(
                loading: () => const _CasesLoadingView(),
                error: (error, _) => _CasesErrorView(
                  message: _cleanErrorMessage(error),
                  onRetry: () => ref.invalidate(internalServiceCasesProvider),
                ),
                data: (queue) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  children: [
                    _SearchAndFilters(
                      filters: filters,
                      controller: _searchController,
                      onChanged: _updateFilters,
                    ),
                    const SizedBox(height: 16),
                    _QueueSummary(queue: queue),
                    const SizedBox(height: 16),
                    if (queue.cases.isEmpty)
                      const _EmptyCasesView()
                    else
                      for (final serviceCase in queue.cases)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _InternalCaseCard(serviceCase: serviceCase),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateRequestSheet(BuildContext context) async {
    final customerController = TextEditingController();
    final serviceController = TextEditingController();
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              setSheetState(() => isSaving = true);
              try {
                final repository = ref.read(internalWorkspaceRepositoryProvider);
                final created = await repository.createServiceRequestForCustomer(
                  customerProfile: customerController.text,
                  serviceId: serviceController.text,
                  title: titleController.text,
                  note: noteController.text,
                );

                ref.invalidate(internalServiceCasesProvider);
                if (!mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Service request ${created.id} created.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(_cleanErrorMessage(error)),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              } finally {
                if (mounted) setSheetState(() => isSaving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create service request',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use exact backend IDs for now. Customer-facing request creation remains separate.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: customerController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Profile ID',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: serviceController,
                      decoration: const InputDecoration(
                        labelText: 'Service ID or name',
                        prefixIcon: Icon(Icons.design_services_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title optional',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Internal/customer note optional',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : submit,
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_task_rounded),
                        label: Text(isSaving ? 'Creating...' : 'Create request'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    customerController.dispose();
    serviceController.dispose();
    titleController.dispose();
    noteController.dispose();
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.filters,
    required this.controller,
    required this.onChanged,
  });

  final InternalServiceCaseFilters filters;
  final TextEditingController controller;
  final ValueChanged<InternalServiceCaseFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: (value) => onChanged(filters.copyWith(search: value)),
            decoration: const InputDecoration(
              hintText: 'Search customer name or case ID',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          _FilterRow(
            title: 'Case status',
            selected: filters.status,
            options: const [
              'Open',
              'In Progress',
              'Waiting for Customer',
              'Completed',
              'Cancelled',
            ],
            onSelected: (value) => onChanged(
              filters.copyWith(
                status: value,
                clearStatus: value == null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FilterRow(
            title: 'Document status',
            selected: filters.documentStatus,
            options: const ['uploaded', 'pending', 'approved', 'rejected'],
            labelBuilder: (value) => value[0].toUpperCase() + value.substring(1),
            onSelected: (value) => onChanged(
              filters.copyWith(
                documentStatus: value,
                clearDocumentStatus: value == null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.labelBuilder,
  });

  final String title;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onSelected;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                ),
              ),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labelBuilder?.call(option) ?? option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.queue});

  final InternalServiceCaseQueue queue;

  @override
  Widget build(BuildContext context) {
    final pendingDocuments = queue.summary['pending_documents'] ?? 0;
    final uploadedDocuments = queue.summary['uploaded_documents'] ?? 0;

    return Row(
      children: [
        Expanded(child: _SummaryPill(value: '${queue.cases.length}', label: 'Cases')),
        const SizedBox(width: 10),
        Expanded(child: _SummaryPill(value: '$uploadedDocuments', label: 'Uploaded')),
        const SizedBox(width: 10),
        Expanded(child: _SummaryPill(value: '$pendingDocuments', label: 'Pending')),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalCaseCard extends StatelessWidget {
  const _InternalCaseCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCase.displayCustomer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      serviceCase.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: serviceCase.status),
            ],
          ),
          const SizedBox(height: 14),
          _CaseInfoLine(
            icon: Icons.design_services_outlined,
            label: 'Service',
            value: serviceCase.displayService,
          ),
          _CaseInfoLine(
            icon: Icons.folder_copy_outlined,
            label: 'Documents',
            value: serviceCase.documentSummaryLabel,
          ),
          _CaseInfoLine(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAt,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Review case'),
                ),
              ),
              const SizedBox(width: 10),
              if (serviceCase.canReviewDocuments)
                _TinyCapability(label: 'Docs')
              else if (serviceCase.canUpdateStatus)
                _TinyCapability(label: 'Status'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaseInfoLine extends StatelessWidget {
  const _CaseInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value == '-') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.primaryRed),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryRed,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TinyCapability extends StatelessWidget {
  const _TinyCapability({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryRed,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CasesLoadingView extends StatelessWidget {
  const _CasesLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: const [
        _LoadingCard(),
        SizedBox(height: 14),
        _LoadingCard(),
        SizedBox(height: 14),
        _LoadingCard(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.75),
                SizedBox(height: 10),
                _LoadingBar(widthFactor: 0.50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CasesErrorView extends StatelessWidget {
  const _CasesErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        PremiumCard(
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppTheme.primaryRed, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Service cases unavailable',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCasesView extends StatelessWidget {
  const _EmptyCasesView();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: AppTheme.primaryRed, size: 34),
          SizedBox(height: 10),
          Text(
            'No matching service cases',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Adjust search or filters to find a customer case.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final raw = error.toString().replaceFirst('ApiError:', '').trim();
  return raw.isEmpty ? 'The internal workspace could not load this data.' : raw;
}
