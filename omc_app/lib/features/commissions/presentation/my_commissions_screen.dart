import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/commission_repository.dart';

class MyCommissionsScreen extends ConsumerStatefulWidget {
  const MyCommissionsScreen({super.key});
  @override
  ConsumerState<MyCommissionsScreen> createState() =>
      _MyCommissionsScreenState();
}

class _MyCommissionsScreenState extends ConsumerState<MyCommissionsScreen> {
  final _items = <CommissionEarning>[];
  final _periodController = TextEditingController();
  final _customerController = TextEditingController();
  final _serviceController = TextEditingController();
  List<CommissionSummary> _summaries = const [];
  String _status = '';
  bool _loading = true;
  bool _hasMore = false;
  int _nextStart = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _periodController.dispose();
    _customerController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _items.clear();
      _nextStart = 0;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (refresh) {
        _summaries = await ref.read(commissionSummaryLoaderProvider)(
          periodMonth: _periodController.text.trim(),
        );
      }
      final page = await ref.read(commissionPageLoaderProvider)(
        start: _nextStart,
        limit: 20,
        periodMonth: _periodController.text.trim(),
        status: _status,
        customerProfile: _customerController.text.trim(),
        service: _serviceController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My commissions')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._summaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TotalCard(
                      label: '${summary.currency} outstanding',
                      value: summary.outstanding,
                    ),
                    _TotalCard(
                      label: '${summary.currency} settled',
                      value: summary.settled,
                    ),
                  ],
                ),
              ),
            ),
            _CommissionFilters(
              periodController: _periodController,
              customerController: _customerController,
              serviceController: _serviceController,
              status: _status,
              onStatusChanged: (value) => setState(() => _status = value),
              apply: () => _load(refresh: true),
              clear: () {
                _periodController.clear();
                _customerController.clear();
                _serviceController.clear();
                setState(() => _status = '');
                _load(refresh: true);
              },
            ),
            const SizedBox(height: 16),
            if (_error != null)
              _ErrorCard(message: _error!, retry: () => _load(refresh: true)),
            if (!_loading && _items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('No commission earnings yet.')),
              ),
            ..._items.map(
              (item) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${item.currency} ${item.amount.toStringAsFixed(2)}',
                  ),
                  subtitle: Text(
                    '${item.service}\n${item.customer}\n${item.status} • ${item.earnedOn}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/my-commissions/${Uri.encodeComponent(item.id)}',
                  ),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && _hasMore)
              Center(
                child: OutlinedButton(
                  onPressed: _load,
                  child: const Text('Load more'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommissionFilters extends StatelessWidget {
  const _CommissionFilters({
    required this.periodController,
    required this.customerController,
    required this.serviceController,
    required this.status,
    required this.onStatusChanged,
    required this.apply,
    required this.clear,
  });

  final TextEditingController periodController;
  final TextEditingController customerController;
  final TextEditingController serviceController;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback apply;
  final VoidCallback clear;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Filters'),
    children: [
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: '', child: Text('All statuses')),
          DropdownMenuItem(value: 'Earned', child: Text('Outstanding')),
          DropdownMenuItem(value: 'Settled', child: Text('Settled')),
          DropdownMenuItem(value: 'Reversed', child: Text('Reversed')),
        ],
        onChanged: (value) => onStatusChanged(value ?? ''),
      ),
      TextField(
        controller: periodController,
        decoration: const InputDecoration(
          labelText: 'Earned month',
          hintText: 'YYYY-MM',
        ),
      ),
      TextField(
        controller: customerController,
        decoration: const InputDecoration(labelText: 'Customer profile'),
      ),
      TextField(
        controller: serviceController,
        decoration: const InputDecoration(labelText: 'Service'),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: clear, child: const Text('Clear')),
          const SizedBox(width: 8),
          FilledButton(onPressed: apply, child: const Text('Apply')),
        ],
      ),
    ],
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      title: Text(message),
      trailing: TextButton(onPressed: retry, child: const Text('Retry')),
    ),
  );
}
