import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/service_request_repository.dart';

class AssistedCustomerDraftSelection {
  const AssistedCustomerDraftSelection({
    required this.mode,
    this.customer,
    this.consentReference = '',
  });

  final String mode;
  final AssistedCustomerOption? customer;
  final String consentReference;

  String? get customerId => customer?.id;
}

class AssistedCustomerCard extends ConsumerStatefulWidget {
  const AssistedCustomerCard({
    super.key,
    required this.onChanged,
    this.initialMode,
    this.initialCustomerId,
  });

  final ValueChanged<AssistedCustomerDraftSelection?> onChanged;
  final String? initialMode;
  final String? initialCustomerId;

  @override
  ConsumerState<AssistedCustomerCard> createState() =>
      _AssistedCustomerCardState();
}

class _AssistedCustomerCardState extends ConsumerState<AssistedCustomerCard>
    with AutomaticKeepAliveClientMixin<AssistedCustomerCard> {
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _consentController = TextEditingController();

  List<String> _modes = const [];
  List<AssistedCustomerOption> _items = const [];
  String? _selectedMode;
  AssistedCustomerOption? _selectedCustomer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _consentController.addListener(_emit);
    Future<void>.microtask(_loadModes);
  }

  @override
  void dispose() {
    _consentController.removeListener(_emit);
    _customerController.dispose();
    _searchController.dispose();
    _consentController.dispose();
    super.dispose();
  }

  Future<void> _loadModes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selection = await ref
          .read(serviceRequestRepositoryProvider)
          .getAssistedCustomerSelection(limitPageLength: 100);
      if (!mounted) return;
      final preferredMode = widget.initialMode?.trim();
      final firstMode =
          preferredMode != null &&
              preferredMode.isNotEmpty &&
              selection.modes.contains(preferredMode)
          ? preferredMode
          : (selection.modes.isEmpty ? null : selection.modes.first);

      setState(() {
        _modes = selection.modes;
        _selectedMode = firstMode;
        _loading = false;
      });

      if (firstMode != null) {
        final initialCustomerId = widget.initialCustomerId?.trim();
        await _loadItems(
          search: initialCustomerId != null && initialCustomerId.isNotEmpty
              ? initialCustomerId
              : null,
        );
      }
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Customer options unavailable',
        fallbackMessage:
            'Assisted customer options could not be loaded right now.',
      );
      setState(() {
        _loading = false;
        _error = failure.message;
      });
      widget.onChanged(null);
    }
  }

  Future<void> _loadItems({String? search}) async {
    final mode = _selectedMode;
    if (mode == null) {
      setState(() {
        _items = const [];
        _selectedCustomer = null;
        _customerController.clear();
        _loading = false;
      });
      _emit();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedCustomer = null;
      _customerController.clear();
    });
    widget.onChanged(null);

    try {
      final selection = await ref
          .read(serviceRequestRepositoryProvider)
          .getAssistedCustomerSelection(
            customerMode: mode,
            search: search,
            limitPageLength: 100,
          );
      if (!mounted) return;
      AssistedCustomerOption? initialCustomer;
      final initialCustomerId = widget.initialCustomerId?.trim();

      if (initialCustomerId != null && initialCustomerId.isNotEmpty) {
        for (final customer in selection.items) {
          if (customer.id == initialCustomerId) {
            initialCustomer = customer;
            break;
          }
        }
      }

      setState(() {
        _items = selection.items;
        _selectedCustomer = initialCustomer;
        _loading = false;

        if (initialCustomer != null) {
          _customerController.text = initialCustomer.fullName;
        }
      });

      _emit();
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Customers unavailable',
        fallbackMessage: 'Customers could not be loaded for this mode.',
      );
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  void _emit() {
    final mode = _selectedMode;
    if (mode == null || _selectedCustomer == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      AssistedCustomerDraftSelection(
        mode: mode,
        customer: _selectedCustomer,
        consentReference: _consentController.text.trim(),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final selectedCustomer = _selectedCustomer;

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Customer context',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose the registered customer this request is being created for. This selection controls the assisted request identity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading && _modes.isEmpty)
            const _AssistedLoadingState()
          else if (_error != null && _modes.isEmpty)
            _AssistedErrorState(message: _error!, onRetry: _loadModes)
          else ...[
            Text('Customer mode', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: _selectedMode,
              isExpanded: true,
              items: _modes
                  .map(
                    (mode) => DropdownMenuItem(value: mode, child: Text(mode)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _selectedMode = value;
                  _selectedCustomer = null;
                  _items = const [];
                  _error = null;
                });
                _searchController.clear();
                _consentController.clear();
                _loadItems();
              },
              decoration: const InputDecoration(
                hintText: 'Choose customer mode',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Search eligible customers',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) =>
                  _loading ? null : _loadItems(search: _searchController.text),
              decoration: InputDecoration(
                hintText: 'Name, phone, email or customer ID',
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search customers',
                  onPressed: _loading
                      ? null
                      : () => _loadItems(search: _searchController.text),
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Select customer', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<AssistedCustomerOption>(
                  controller: _customerController,
                  width: constraints.maxWidth,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.person_search_outlined),
                  hintText: 'Choose from the loaded results',
                  dropdownMenuEntries: _items
                      .map(
                        (customer) => DropdownMenuEntry<AssistedCustomerOption>(
                          value: customer,
                          label: customer.subtitle.isEmpty
                              ? customer.fullName
                              : '${customer.fullName} — ${customer.subtitle}',
                        ),
                      )
                      .toList(growable: false),
                  onSelected: (customer) {
                    setState(() => _selectedCustomer = customer);
                    _emit();
                  },
                );
              },
            ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Loading eligible customers…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _AssistedErrorState(
                message: _error!,
                onRetry: () => _loadItems(search: _searchController.text),
              ),
            ] else if (!_loading && _items.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'No eligible customers found for this mode and search.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
            if (selectedCustomer != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SelectedAssistedCustomer(customer: selectedCustomer),
            ],
            if (_selectedMode == 'Existing Customer' &&
                selectedCustomer != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Consent reference', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _consentController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Call, message, visit or written-consent reference',
                  helperText:
                      'Add the reference authorizing this assisted request.',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                validator: (value) {
                  if (_selectedMode != 'Existing Customer') return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Consent reference is required.';
                  }
                  return null;
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SelectedAssistedCustomer extends StatelessWidget {
  const _SelectedAssistedCustomer({required this.customer});

  final AssistedCustomerOption customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      container: true,
      label: 'Selected customer: ${customer.fullName}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppTouchTarget.minimum,
              height: AppTouchTarget.minimum,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_outline_rounded,
                color: accent,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected customer',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    customer.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (customer.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      customer.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistedLoadingState extends StatelessWidget {
  const _AssistedLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Loading assisted customer options…')),
        ],
      ),
    );
  }
}

class _AssistedErrorState extends StatelessWidget {
  const _AssistedErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
