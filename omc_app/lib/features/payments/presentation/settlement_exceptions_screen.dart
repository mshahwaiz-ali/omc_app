import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/finance_reconciliation_repository.dart';

class SettlementExceptionsScreen extends ConsumerStatefulWidget {
  const SettlementExceptionsScreen({super.key});

  @override
  ConsumerState<SettlementExceptionsScreen> createState() =>
      _SettlementExceptionsScreenState();
}

class _SettlementExceptionsScreenState
    extends ConsumerState<SettlementExceptionsScreen> {
  static const _pageLength = 20;
  final _searchController = TextEditingController();
  String _search = '';
  String _status = 'Open';
  int _start = 0;
  String? _mutatingReview;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FinanceReconciliationQuery get _query => FinanceReconciliationQuery(
        start: _start,
        pageLength: _pageLength,
        search: _search,
        status: _status,
      );

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final pageAsync = ref.watch(financeReconciliationPageProvider(query));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settlement exceptions'),
        actions: [
          IconButton(
            tooltip: 'Refresh exceptions',
            onPressed: () =>
                ref.invalidate(financeReconciliationPageProvider(query)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(financeReconciliationPageProvider(query));
          await ref.read(financeReconciliationPageProvider(query).future);
        },
        child: pageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ResponsiveList(
            children: [
              _InfoBanner(
                icon: Icons.cloud_off_rounded,
                title: 'Settlement exceptions unavailable',
                message: AppFailureClassifier.classify(
                  error,
                  fallbackTitle: 'Settlement exceptions unavailable',
                  fallbackMessage:
                      'The finance reconciliation queue could not be loaded.',
                ).message,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(financeReconciliationPageProvider(query)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
          data: (page) => _ResponsiveList(
            children: [
              const _InfoBanner(
                icon: Icons.fact_check_outlined,
                title: 'Human finance review only',
                message:
                    'Resolve or Ignore records only the review disposition. It does not create Journal Entries, post ERP accounting, repair a payment, execute settlement, or retry technical quarantine.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _Filters(
                searchController: _searchController,
                status: _status,
                onSearch: () => setState(() {
                  _search = _searchController.text.trim();
                  _start = 0;
                }),
                onClearSearch: () => setState(() {
                  _searchController.clear();
                  _search = '';
                  _start = 0;
                }),
                onStatusChanged: (value) => setState(() {
                  _status = value;
                  _start = 0;
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Review queue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (page.items.isEmpty)
                const PremiumCard(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No settlement exceptions in this view.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (var index = 0; index < page.items.length; index++) ...[
                  _ReviewCard(
                    item: page.items[index],
                    busy: _mutatingReview == page.items[index].id,
                    onOpenCase: page.items[index].hasServiceRequest
                        ? () => context.push(
                              '/internal-workspace/service-cases/${Uri.encodeComponent(page.items[index].serviceRequest)}',
                            )
                        : null,
                    onResolve: page.items[index].canResolve
                        ? () => _decide(
                              page.items[index],
                              FinanceReconciliationDecision.resolve,
                            )
                        : null,
                    onIgnore: page.items[index].canIgnore
                        ? () => _decide(
                              page.items[index],
                              FinanceReconciliationDecision.ignore,
                            )
                        : null,
                  ),
                  if (index != page.items.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.md),
              _Pager(
                start: page.start,
                shown: page.items.length,
                hasMore: page.hasMore,
                onPrevious: page.start == 0
                    ? null
                    : () => setState(() {
                          _start = (_start - _pageLength)
                              .clamp(0, 1 << 30)
                              .toInt();
                        }),
                onNext: page.hasMore
                    ? () => setState(() {
                          _start = page.nextStart ?? _start + _pageLength;
                        })
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _decide(
    FinanceReconciliationItem item,
    FinanceReconciliationDecision decision,
  ) async {
    final noteController = TextEditingController();
    final decisionLabel = decision == FinanceReconciliationDecision.resolve
        ? 'Resolve review'
        : 'Ignore exception';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(decisionLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                decision == FinanceReconciliationDecision.resolve
                    ? 'Confirm the accounting evidence was corrected or independently verified before recording this review as resolved. This does not repair or settle the payment.'
                    : 'Use Ignore only for an intentional exception that should remain documented. This does not make accounting changes.',
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: noteController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Finance review note',
                  hintText: 'Required: what was verified and where',
                ),
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
            onPressed: () {
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(
              decision == FinanceReconciliationDecision.resolve
                  ? 'Resolve review'
                  : 'Ignore exception',
            ),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || note.isEmpty || !mounted) return;

    setState(() => _mutatingReview = item.id);
    try {
      await ref
          .read(financeReconciliationRepositoryProvider)
          .decide(review: item.id, decision: decision, note: note);
      if (!mounted) return;
      ref.invalidate(financeReconciliationPageProvider(_query));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == FinanceReconciliationDecision.resolve
                ? 'Settlement review resolved.'
                : 'Settlement exception ignored with note.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Review not updated',
        fallbackMessage: 'The settlement review could not be updated.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } finally {
      if (mounted) setState(() => _mutatingReview = null);
    }
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
        final horizontal = constraints.maxWidth >
                AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 100),
          children: children,
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.status,
    required this.onSearch,
    required this.onClearSearch,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String status;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              labelText: 'Search request or reason',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.trim().isEmpty
                  ? IconButton(
                      tooltip: 'Search',
                      onPressed: onSearch,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    )
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Review status',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Open', child: Text('Open')),
              DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
              DropdownMenuItem(value: 'Ignored', child: Text('Ignored')),
              DropdownMenuItem(value: 'All', child: Text('All')),
            ],
            onChanged: (value) {
              if (value != null) onStatusChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.busy,
    required this.onOpenCase,
    required this.onResolve,
    required this.onIgnore,
  });

  final FinanceReconciliationItem item;
  final bool busy;
  final VoidCallback? onOpenCase;
  final VoidCallback? onResolve;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final title = item.serviceTitle.isNotEmpty
        ? item.serviceTitle
        : item.requestTitle.isNotEmpty
        ? item.requestTitle
        : item.serviceRequest.isNotEmpty
        ? item.serviceRequest
        : item.sourceName;
    final reason = item.reasonLabel.isEmpty ? item.reasonCode : item.reasonLabel;
    final contextLine = [
      item.customerName,
      item.serviceRequest,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (contextLine.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        contextLine,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Exception reason',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(reason, style: Theme.of(context).textTheme.bodyLarge),
          if (item.requestState.isNotEmpty || item.serviceStatus.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [item.requestState, item.serviceStatus]
                  .where((value) => value.isNotEmpty)
                  .join(' • '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (onResolve != null || onIgnore != null || onOpenCase != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Review decision',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (onOpenCase != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onOpenCase,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open case'),
                  ),
                if (onIgnore != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onIgnore,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Ignore review'),
                  ),
                if (onResolve != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onResolve,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Resolve review'),
                  ),
              ],
            ),
          ],
          if (item.evidence.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1),
            ),
            Text(
              'Redacted evidence metadata',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final entry in item.evidence.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  '${_humanize(entry.key)}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
          if (item.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Resolution note: ${item.resolutionNote}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final (color, background) = switch (normalized) {
      'resolved' => (AppTheme.success, AppTheme.successSoft),
      'ignored' => (AppTheme.processing, AppTheme.processingSoft),
      _ => (AppTheme.warning, AppTheme.warningSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        status.isEmpty ? 'Unknown' : status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.start,
    required this.shown,
    required this.hasMore,
    required this.onPrevious,
    required this.onNext,
  });

  final int start;
  final int shown;
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
            shown == 0 ? 'No records' : 'Showing $first-$last',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
