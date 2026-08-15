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

class _AssistedCustomerCardState extends ConsumerState<AssistedCustomerCard> {
  final _customerController = TextEditingController();
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
    _customerController.dispose();
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

      if (firstMode != null) await _loadItems();
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
          const Text(
            'Request customer',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text(
            'Choose who this request is being created for.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownMenu<AssistedCustomerOption>(
                    controller: _customerController,
                    width: constraints.maxWidth,
                    enableFilter: true,
                    enableSearch: true,
                    requestFocusOnTap: true,
                    leadingIcon: const Icon(Icons.search_rounded),
                    label: const Text('Search and select customer'),
                    hintText: 'Type name, phone, email or customer ID',
                    dropdownMenuEntries: _items
                        .map(
                          (
                            customer,
                          ) => DropdownMenuEntry<AssistedCustomerOption>(
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
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[const SizedBox(height: 8), Text(_error!)],
              if (!_loading && _error == null && _items.isEmpty) ...[
                const SizedBox(height: 8),
                const Text('No eligible customers found.'),
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
