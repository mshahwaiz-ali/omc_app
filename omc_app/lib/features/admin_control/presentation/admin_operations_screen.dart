import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/mutation_invalidation.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/forms/dirty_form_controller.dart';
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
  final _search = TextEditingController();
  final _busy = <String>{};
  AdminOperationQueue? _queue;
  int _start = 0;
  static const _pageLength = 20;

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
        appBar: AppBackHeader(title: 'Operational controls'),
        body: Center(
          child: Text('This account has no operational control capability.'),
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
      appBar: const AppBackHeader(
        title: 'Operational controls',
        subtitle: 'Reassignment, sync recovery and discount decisions',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminOperationsProvider(query));
          await ref.read(adminOperationsProvider(query).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search case, customer or service',
              ),
              onChanged: (_) => setState(() => _start = 0),
            ),
            const SizedBox(height: 16),
            page.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => PremiumCard(
                child: Column(
                  children: [
                    Text(
                      AppFailureClassifier.classify(
                        error,
                        fallbackTitle: 'Queue unavailable',
                        fallbackMessage:
                            'The operational queue could not be loaded.',
                      ).message,
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(adminOperationsProvider(query)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) => Column(
                children: [
                  if (data.items.isEmpty)
                    const PremiumCard(
                      child: Text('No records currently require this action.'),
                    )
                  else
                    for (final item in data.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OperationCard(
                          item: item,
                          queue: queue,
                          busy: _busy.contains(item.id),
                          onAction: () => _act(query, item, queue),
                        ),
                      ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${data.items.isEmpty ? 0 : data.start + 1}-${data.start + data.items.length} of ${data.total}',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous page',
                        onPressed: data.start == 0
                            ? null
                            : () => setState(() {
                                _start = (_start - _pageLength)
                                    .clamp(0, 1 << 30)
                                    .toInt();
                              }),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next page',
                        onPressed: data.hasMore
                            ? () => setState(() => _start += _pageLength)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
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
                  children: [
                    Text(
                      'Current assignee: ${options.text('assigned_staff').isEmpty ? 'Unassigned' : options.text('assigned_staff')}',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search eligible staff',
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
                    DropdownButtonFormField<AdminAssignmentCandidate>(
                      initialValue: selected,
                      decoration: const InputDecoration(
                        labelText: 'Eligible assignee',
                      ),
                      items: [
                        for (final candidate in candidates)
                          DropdownMenuItem(
                            value: candidate,
                            child: Text(
                              '${candidate.fullName} (${candidate.userId})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        dirtyFormController.markDirty();
                        setDialogState(() => selected = value);
                      },
                    ),
                    TextField(
                      controller: reason,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Retry exhausted sync for ${item.id}?'),
        content: Text(
          'ERP Task: ${options.text('erp_task').isEmpty ? '-' : options.text('erp_task')}\n'
          'Retry count: ${options.integer('erp_retry_count')}\n'
          'Last attempt: ${options.text('erp_last_attempt_at').isEmpty ? '-' : options.text('erp_last_attempt_at')}\n'
          'Next attempt: ${options.text('erp_next_attempt_at').isEmpty ? '-' : options.text('erp_next_attempt_at')}\n'
          'Last error: ${options.text('erp_sync_error').isEmpty ? '-' : options.text('erp_sync_error')}',
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
    );
    if (confirmed != true) return false;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${options.text('customer_name')}'),
                  Text('Service: ${options.text('service_title')}'),
                  Text('Base price: PKR ${options.number('original_price')}'),
                  Text(
                    'Discount: ${options.text('discount_type')} ${options.number('discount_value')}',
                  ),
                  Text(
                    'Discount amount: PKR ${options.number('discount_amount')}',
                  ),
                  Text(
                    'Final price: PKR ${options.number('proposed_final_price')}',
                  ),
                  Text(
                    'Requested by: ${options.text('discount_requested_by')}',
                  ),
                  Text('Reason: ${options.text('discount_reason')}'),
                  Text(
                    'Auto threshold: ${options.number('discount_auto_approval_percent')}%',
                  ),
                  Text(
                    'Minimum floor: PKR ${options.number('minimum_service_price')}',
                  ),
                  const SizedBox(height: 10),
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
                  TextField(
                    controller: remarks,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: approve == false
                          ? 'Review remarks (required)'
                          : 'Review remarks (optional)',
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
  Widget build(BuildContext context) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title.isEmpty ? item.id : item.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          '${item.customer.isEmpty ? 'Unknown customer' : item.customer} • ${item.service}',
        ),
        const SizedBox(height: 6),
        Text(switch (queue) {
          AdminOperationQueue.reassignment =>
            'Current assignee: ${item.assignedStaff.isEmpty ? 'Unassigned' : item.assignedStaff}',
          AdminOperationQueue.sync =>
            '${item.syncStatus} • ${item.retryCount} retries${item.lastError.isEmpty ? '' : ' • ${item.lastError}'}',
          AdminOperationQueue.discount => item.discountStatus,
        }),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: busy ? null : onAction,
            child: Text(
              busy
                  ? 'Working...'
                  : switch (queue) {
                      AdminOperationQueue.reassignment => 'Reassign',
                      AdminOperationQueue.sync => 'Review and retry',
                      AdminOperationQueue.discount => 'Review discount',
                    },
            ),
          ),
        ),
      ],
    ),
  );
}
