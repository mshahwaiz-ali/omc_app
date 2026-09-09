import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/mutation_invalidation.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/admin_control_repository.dart';

class AdminOperationsScreen extends ConsumerStatefulWidget {
  const AdminOperationsScreen({super.key});

  @override
  ConsumerState<AdminOperationsScreen> createState() =>
      _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends ConsumerState<AdminOperationsScreen> {
  static const _pageLength = 20;

  final _search = TextEditingController();
  final _busy = <String>{};
  AdminOperationQueue? _queue;
  int _start = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final allowed = <AdminOperationQueue>[
      if (capabilities.canReassignServiceCases)
        AdminOperationQueue.reassignment,
      if (capabilities.canRetrySync) AdminOperationQueue.sync,
      if (capabilities.canManageBusinessSettings) AdminOperationQueue.discount,
    ];

    if (allowed.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBackHeader(title: 'Operational controls'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'This account has no operational control capability.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final queue = allowed.contains(_queue) ? _queue! : allowed.first;
    final query = AdminOperationsQuery(
      queue: queue,
      search: _search.text,
      start: _start,
      pageLength: _pageLength,
    );
    final page = ref.watch(adminOperationsProvider(query));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(
        title: 'Operational controls',
        subtitle: 'Authorized case operations only',
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(adminOperationsProvider(query));
          await ref.read(adminOperationsProvider(query).future);
        },
        child: _ResponsiveList(
          children: [
            Text(
              'Operation type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in allowed)
                  ChoiceChip(
                    label: Text(item.label),
                    selected: item == queue,
                    onSelected: (_) => setState(() {
                      _queue = item;
                      _start = 0;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search case, customer or service',
              ),
              onChanged: (_) => setState(() => _start = 0),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    queue.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _QueueScopeBadge(queue: queue),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _queueDescription(queue),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            page.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queue unavailable',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppFailureClassifier.classify(
                        error,
                        fallbackTitle: 'Queue unavailable',
                        fallbackMessage:
                            'The operational queue could not be loaded.',
                      ).message,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(adminOperationsProvider(query)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.items.isEmpty)
                    const PremiumCard(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('No records currently require this action.'),
                    )
                  else
                    for (var index = 0; index < data.items.length; index++) ...[
                      _OperationCard(
                        item: data.items[index],
                        queue: queue,
                        busy: _busy.contains(data.items[index].id),
                        onAction: () => _act(query, data.items[index], queue),
                      ),
                      if (index != data.items.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  const SizedBox(height: AppSpacing.md),
                  _Pager(
                    start: data.start,
                    shown: data.items.length,
                    total: data.total,
                    hasMore: data.hasMore,
                    onPrevious: data.start == 0
                        ? null
                        : () => setState(() {
                            _start = (_start - _pageLength)
                                .clamp(0, 1 << 30)
                                .toInt();
                          }),
                    onNext: data.hasMore
                        ? () => setState(() => _start += _pageLength)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(
    AdminOperationsQuery query,
    AdminOperationItem item,
    AdminOperationQueue queue,
  ) async {
    if (_busy.contains(item.id)) return;
    setState(() => _busy.add(item.id));
    try {
      final options = await ref.read(adminCaseOptionsProvider(item.id).future);
      if (!mounted) return;
      final changed = switch (queue) {
        AdminOperationQueue.reassignment => await _reassign(item, options),
        AdminOperationQueue.sync => await _retrySync(item, options),
        AdminOperationQueue.discount => await _reviewDiscount(item, options),
      };
      if (changed) {
        invalidateAdministrativeCaseMutation(ref, caseId: item.id);
        ref.invalidate(adminOperationsProvider(query));
      }
    } catch (error) {
      if (mounted) {
        _message(
          context,
          AppFailureClassifier.classify(
            error,
            fallbackTitle: 'Action failed',
            fallbackMessage: 'The operation could not be completed.',
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<bool> _reassign(
    AdminOperationItem item,
    AdminCaseOptions options,
  ) async {
    final reason = TextEditingController();
    final dirtyFormController = DirtyFormController();
    void markDirty() => dirtyFormController.markDirty();
    reason.addListener(markDirty);

    var candidates = options.candidates;
    AdminAssignmentCandidate? selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirtyFormController,
          child: AlertDialog(
            title: Text('Reassign ${item.id}'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DecisionContext(
                      title: item.title.isEmpty ? item.id : item.title,
                      rows: [
                        (
                          'Current assignee',
                          options.text('assigned_staff').isEmpty
                              ? 'Unassigned'
                              : options.text('assigned_staff'),
                        ),
                        (
                          'Customer',
                          item.customer.isEmpty
                              ? 'Not available'
                              : item.customer,
                        ),
                        (
                          'Service',
                          item.service.isEmpty ? 'Not available' : item.service,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search eligible staff',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setDialogState(() {
                        final query = value.trim().toLowerCase();
                        candidates = options.candidates
                            .where(
                              (candidate) =>
                                  '${candidate.fullName} ${candidate.userId}'
                                      .toLowerCase()
                                      .contains(query),
                            )
                            .toList();
                        if (selected != null &&
                            !candidates.contains(selected)) {
                          selected = null;
                        }
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<AdminAssignmentCandidate>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Eligible assignee',
                      ),
                      items: [
                        for (final candidate in candidates)
                          DropdownMenuItem(
                            value: candidate,
                            child: Text(
                              '${candidate.fullName} (${candidate.userId})',
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        dirtyFormController.markDirty();
                        setDialogState(() => selected = value);
                      },
                    ),
                    if (candidates.isEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No eligible staff match this search.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: reason,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        dirtyFormController.submissionSucceeded();
                        Navigator.pop(dialogContext, true);
                      },
                child: const Text('Confirm reassignment'),
              ),
            ],
          ),
        ),
      ),
    );

    reason.removeListener(markDirty);
    dirtyFormController.dispose();

    if (confirmed != true || selected == null) {
      reason.dispose();
      return false;
    }
    await ref
        .read(adminControlRepositoryProvider)
        .reassignCase(item.id, selected!.userId, reason: reason.text);
    reason.dispose();
    if (mounted) {
      _message(context, 'Case reassigned and audit feedback recorded.');
    }
    return true;
  }

  Future<bool> _retrySync(
    AdminOperationItem item,
    AdminCaseOptions options,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Retry exhausted sync for ${item.id}?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DecisionNotice(
                    icon: Icons.sync_problem_rounded,
                    message:
                        'This explicitly retries the existing exhausted ERP sync. Review the recorded technical context before continuing.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DecisionContext(
                    title: item.title.isEmpty ? item.id : item.title,
                    rows: [
                      (
                        'ERP Task',
                        options.text('erp_task').isEmpty
                            ? 'Not available'
                            : options.text('erp_task'),
                      ),
                      ('Retry count', '${options.integer('erp_retry_count')}'),
                      (
                        'Last attempt',
                        options.text('erp_last_attempt_at').isEmpty
                            ? 'Not available'
                            : options.text('erp_last_attempt_at'),
                      ),
                      (
                        'Next attempt',
                        options.text('erp_next_attempt_at').isEmpty
                            ? 'Not available'
                            : options.text('erp_next_attempt_at'),
                      ),
                      (
                        'Last error',
                        options.text('erp_sync_error').isEmpty
                            ? 'Not available'
                            : options.text('erp_sync_error'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry sync'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return false;
    await ref.read(adminControlRepositoryProvider).retrySync(item.id);
    if (mounted) {
      _message(context, 'Controlled ERP sync retry completed.');
    }
    return true;
  }

  Future<bool> _reviewDiscount(
    AdminOperationItem item,
    AdminCaseOptions options,
  ) async {
    final remarks = TextEditingController();
    final dirtyFormController = DirtyFormController();
    void markDirty() => dirtyFormController.markDirty();
    remarks.addListener(markDirty);

    bool? approve;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirtyFormController,
          child: AlertDialog(
            title: Text('Discount review ${item.id}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DecisionContext(
                    title: item.title.isEmpty ? item.id : item.title,
                    rows: [
                      ('Customer', options.text('customer_name')),
                      ('Service', options.text('service_title')),
                      ('Base price', 'PKR ${options.number('original_price')}'),
                      (
                        'Discount',
                        '${options.text('discount_type')} ${options.number('discount_value')}',
                      ),
                      (
                        'Discount amount',
                        'PKR ${options.number('discount_amount')}',
                      ),
                      (
                        'Final price',
                        'PKR ${options.number('proposed_final_price')}',
                      ),
                      ('Requested by', options.text('discount_requested_by')),
                      ('Reason', options.text('discount_reason')),
                      (
                        'Auto threshold',
                        '${options.number('discount_auto_approval_percent')}%',
                      ),
                      (
                        'Minimum floor',
                        'PKR ${options.number('minimum_service_price')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Decision',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Approve')),
                      ButtonSegment(value: false, label: Text('Reject')),
                    ],
                    selected: approve == null ? const {} : {approve!},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (value) {
                      dirtyFormController.markDirty();
                      setDialogState(() => approve = value.firstOrNull);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: remarks,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: approve == false
                          ? 'Review remarks (required)'
                          : 'Review remarks (optional)',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    approve == null ||
                        (approve == false && remarks.text.trim().isEmpty)
                    ? null
                    : () {
                        dirtyFormController.submissionSucceeded();
                        Navigator.pop(dialogContext, true);
                      },
                child: const Text('Confirm decision'),
              ),
            ],
          ),
        ),
      ),
    );

    remarks.removeListener(markDirty);
    dirtyFormController.dispose();

    if (confirmed != true || approve == null) {
      remarks.dispose();
      return false;
    }
    await ref
        .read(adminControlRepositoryProvider)
        .reviewDiscount(item.id, approve: approve!, reason: remarks.text);
    remarks.dispose();
    if (mounted) {
      _message(context, 'Discount decision recorded.');
    }
    return true;
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ResponsiveList extends StatelessWidget {
  const _ResponsiveList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 100),
          children: children,
        );
      },
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.item,
    required this.queue,
    required this.busy,
    required this.onAction,
  });

  final AdminOperationItem item;
  final AdminOperationQueue queue;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final title = item.title.isEmpty ? item.id : item.title;
    final contextLine = [
      if (item.customer.isNotEmpty) item.customer,
      if (item.service.isNotEmpty) item.service,
    ].join(' · ');
    final blocker = switch (queue) {
      AdminOperationQueue.reassignment =>
        'Current assignee: ${item.assignedStaff.isEmpty ? 'Unassigned' : item.assignedStaff}',
      AdminOperationQueue.sync =>
        '${item.syncStatus.isEmpty ? 'Sync status unavailable' : item.syncStatus} · ${item.retryCount} retries${item.lastError.isEmpty ? '' : ' · ${item.lastError}'}',
      AdminOperationQueue.discount =>
        item.discountStatus.isEmpty
            ? 'Discount review status unavailable'
            : item.discountStatus,
    };
    final actionLabel = switch (queue) {
      AdminOperationQueue.reassignment => 'Review reassignment',
      AdminOperationQueue.sync => 'Review sync retry',
      AdminOperationQueue.discount => 'Review discount',
    };

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            item.id,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          if (contextLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(contextLine, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.cardSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current blocker / review context',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(blocker, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onAction,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(busy ? 'Working…' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueScopeBadge extends StatelessWidget {
  const _QueueScopeBadge({required this.queue});

  final AdminOperationQueue queue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Authorized',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppTheme.processing),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.start,
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.onPrevious,
    required this.onNext,
  });

  final int start;
  final int shown;
  final int total;
  final bool hasMore;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final first = shown == 0 ? 0 : start + 1;
    final last = start + shown;
    return Row(
      children: [
        Expanded(
          child: Text(
            shown == 0 ? 'No records' : '$first-$last of $total',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
        IconButton(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: hasMore ? 'Next page' : 'No more records',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DecisionContext extends StatelessWidget {
  const _DecisionContext({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (var index = 0; index < rows.length; index++) ...[
            _DecisionRow(label: rows[index].$1, value: rows[index].$2),
            if (index != rows.length - 1) const Divider(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? 'Not available' : value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SelectableText(cleanValue),
      ],
    );
  }
}

class _DecisionNotice extends StatelessWidget {
  const _DecisionNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.processing, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

String _queueDescription(AdminOperationQueue queue) => switch (queue) {
  AdminOperationQueue.reassignment =>
    'Review the current assignment, then choose only from backend-eligible staff.',
  AdminOperationQueue.sync =>
    'Review exhausted ERP sync context before explicitly retrying processing.',
  AdminOperationQueue.discount =>
    'Review pricing context and record an explicit approve or reject decision.',
};
