import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/service_request_repository.dart';

class AssistedCustomerDraftSelection {
  const AssistedCustomerDraftSelection({
    required this.mode,
    this.customer,
    this.consentReference = '',
    this.city = '',
    this.address = '',
  });

  final String mode;
  final AssistedCustomerOption? customer;
  final String consentReference;
  final String city;
  final String address;

  String? get customerId {
    if (mode == 'Walk-in Customer') return null;
    return customer?.id;
  }
}

class AssistedCustomerCard extends ConsumerStatefulWidget {
  const AssistedCustomerCard({super.key, required this.onChanged});

  final ValueChanged<AssistedCustomerDraftSelection?> onChanged;

  @override
  ConsumerState<AssistedCustomerCard> createState() =>
      _AssistedCustomerCardState();
}

class _AssistedCustomerCardState extends ConsumerState<AssistedCustomerCard> {
  final _searchController = TextEditingController();
  final _consentController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

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
    _cityController.addListener(_emit);
    _addressController.addListener(_emit);
    Future<void>.microtask(_loadModes);
  }

  @override
  void dispose() {
    _consentController.removeListener(_emit);
    _cityController.removeListener(_emit);
    _addressController.removeListener(_emit);
    _searchController.dispose();
    _consentController.dispose();
    _cityController.dispose();
    _addressController.dispose();
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
          .getAssistedCustomerSelection();
      if (!mounted) return;
      final firstMode = selection.modes.isEmpty ? null : selection.modes.first;
      setState(() {
        _modes = selection.modes;
        _selectedMode = firstMode;
        _loading = false;
      });
      if (firstMode != null) {
        await _loadItems();
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

  Future<void> _loadItems() async {
    final mode = _selectedMode;
    if (mode == null || mode == 'Walk-in Customer') {
      setState(() {
        _items = const [];
        _selectedCustomer = null;
        _loading = false;
      });
      _emit();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedCustomer = null;
    });
    widget.onChanged(null);

    try {
      final selection = await ref
          .read(serviceRequestRepositoryProvider)
          .getAssistedCustomerSelection(
            customerMode: mode,
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() {
        _items = selection.items;
        _loading = false;
      });
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
    if (mode == null) {
      widget.onChanged(null);
      return;
    }
    if (mode != 'Walk-in Customer' && _selectedCustomer == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      AssistedCustomerDraftSelection(
        mode: mode,
        customer: _selectedCustomer,
        consentReference: _consentController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_outlined, size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose who this request is being created for.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && _modes.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && _modes.isEmpty) ...[
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadModes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedMode,
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
                _consentController.clear();
                _loadItems();
              },
              decoration: const InputDecoration(
                labelText: 'Customer mode',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedMode == 'Walk-in Customer') ...[
              TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'City (optional)',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  prefixIcon: Icon(Icons.home_outlined),
                  alignLabelWithHint: true,
                ),
              ),
            ] else ...[
              if (_selectedCustomer != null)
                _SelectedCustomerCard(
                  customer: _selectedCustomer!,
                  onChange: () {
                    setState(() {
                      _selectedCustomer = null;
                      _items = const [];
                      _error = null;
                    });
                    widget.onChanged(null);
                  },
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _loadItems(),
                        decoration: const InputDecoration(
                          labelText: 'Search and select customer',
                          hintText: 'Name, phone, email or customer ID',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _loading ? null : _loadItems,
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Search',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const LinearProgressIndicator()
                else if (_error != null)
                  Text(_error!)
                else if (_items.isEmpty)
                  const Text('No eligible customers found.')
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CustomerSearchResult(
                        customer: item,
                        onTap: () {
                          setState(() => _selectedCustomer = item);
                          _emit();
                        },
                      ),
                    ),
                  ),
              ],
              if (_selectedMode == 'Existing Customer') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _consentController,
                  decoration: const InputDecoration(
                    labelText: 'Consent reference',
                    helperText:
                        'Add a call, message, visit, or written-consent reference.',
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
        ],
      ),
    );
  }
}

class _CustomerSearchResult extends StatelessWidget {
  const _CustomerSearchResult({required this.customer, required this.onTap});

  final AssistedCustomerOption customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (customer.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard({required this.customer, required this.onChange});

  final AssistedCustomerOption customer;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected customer',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (customer.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    customer.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}
