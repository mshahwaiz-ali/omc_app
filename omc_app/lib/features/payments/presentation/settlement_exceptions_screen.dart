import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: const Text('Settlement Exceptions'),
        actions: [
          IconButton(
            tooltip: 'Refresh exceptions',
            onPressed: () =>
                ref.invalidate(financeReconciliationPageProvider(query)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeReconciliationPageProvider(query));
          await ref.read(financeReconciliationPageProvider(query).future);
        },
        child: pageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(financeReconciliationPageProvider(query)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
          data: (page) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              const _InfoBanner(
                icon: Icons.fact_check_outlined,
                title: 'Human finance review only',
                message:
                    'Resolve or Ignore records the review disposition only. It does not create Journal Entries, post ERP accounting, or retry technical quarantine. Make accounting corrections in the authoritative ERP workflow first.',
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              if (page.items.isEmpty)
                const PremiumCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 34),
                        SizedBox(height: 10),
                        Text(
                          'No settlement exceptions in this view.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final item in page.items) ...[
                  _ReviewCard(
                    item: item,
                    busy: _mutatingReview == item.id,
                    onOpenCase: item.hasServiceRequest
                        ? () => context.push(
                            '/internal-workspace/service-cases/${Uri.encodeComponent(item.serviceRequest)}',
                          )
                        : null,
                    onResolve: item.canResolve
                        ? () => _decide(
                            item,
                            FinanceReconciliationDecision.resolve,
                          )
                        : null,
                    onIgnore: item.canIgnore
                        ? () => _decide(
                            item,
                            FinanceReconciliationDecision.ignore,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 6),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              decision == FinanceReconciliationDecision.resolve
                  ? 'Confirm the accounting evidence was corrected or independently verified before resolving this review.'
                  : 'Use Ignore only for an intentional exception that should remain documented without mobile accounting changes.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Finance review note',
                hintText: 'Required: what was verified and where',
              ),
            ),
          ],
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
                  ? 'Resolve'
                  : 'Ignore',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _mutatingReview = null);
    }
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: status,
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
    final subtitle = [
      item.customerName,
      item.serviceRequest,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.reasonLabel.isEmpty ? item.reasonCode : item.reasonLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (item.requestState.isNotEmpty ||
              item.serviceStatus.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                item.requestState,
                item.serviceStatus,
              ].where((value) => value.isNotEmpty).join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Redacted evidence',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final entry in item.evidence.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${_humanize(entry.key)}: ${entry.value}'),
              ),
          ],
          if (item.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Resolution: ${item.resolutionNote}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                  label: const Text('Ignore'),
                ),
              if (onResolve != null)
                FilledButton.icon(
                  onPressed: busy ? null : onResolve,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Resolve'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.isEmpty ? 'Unknown' : status),
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
            style: Theme.of(context).textTheme.bodySmall,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(message),
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
