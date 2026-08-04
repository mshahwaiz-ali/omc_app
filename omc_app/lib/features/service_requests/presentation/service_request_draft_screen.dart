import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/network/mutation_intent.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_summary.dart';
import '../../internal_workspace/presentation/internal_workspace_providers.dart';
import '../data/service_case_repository.dart';
import '../../service_catalogue/application/service_catalogue_controller.dart';
import '../../service_catalogue/data/service_item.dart';
import '../../service_templates/data/service_template.dart';
import '../data/service_request_repository.dart';
import 'assisted_customer_card.dart';

class ServiceRequestDraftScreen extends ConsumerStatefulWidget {
  const ServiceRequestDraftScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceRequestDraftScreen> createState() =>
      _ServiceRequestDraftScreenState();
}

class _ServiceRequestDraftScreenState
    extends ConsumerState<ServiceRequestDraftScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _remarksController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _discountReasonController = TextEditingController();
  final Map<String, TextEditingController> _dynamicControllers = {};
  final Map<String, String?> _selectValues = {};
  final Map<String, bool> _checkValues = {};
  final _dirtyFormController = DirtyFormController();
  final _submissionIntent = MutationIntent();

  bool _customerProfilePrefillScheduled = false;
  bool _customerProfilePrefilled = false;
  AssistedCustomerDraftSelection? _assistedSelection;
  String _discountType = 'Percentage';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _nameController,
      _phoneController,
      _emailController,
      _taxIdController,
      _remarksController,
      _discountValueController,
      _discountReasonController,
    ]) {
      controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _phoneController,
      _emailController,
      _taxIdController,
      _remarksController,
      _discountValueController,
      _discountReasonController,
    ]) {
      controller.removeListener(_onTextChanged);
      controller.dispose();
    }
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    _dirtyFormController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _dirtyFormController.markDirty();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileAsync = authState.capabilities.isInternal
        ? null
        : ref.watch(profileSummaryProvider);
    final customerProfile = profileAsync?.asData?.value;

    final servicesAsync = ref.watch(serviceCatalogueProvider);

    return servicesAsync.when(
      loading: () => const Scaffold(
        appBar: AppBackHeader(title: 'Start Request'),
        body: LoadingView(message: 'Preparing request form...'),
      ),
      error: (error, _) => Scaffold(
        appBar: const AppBackHeader(title: 'Start Request'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: AppErrorState.fromError(
            error: error,
            fallbackTitle: 'Request form unavailable',
            fallbackMessage:
                'The request form could not be prepared right now.',
            onRetry: () => ref.invalidate(serviceCatalogueProvider),
          ),
        ),
      ),
      data: (services) {
        final service = _findService(services);
        if (service == null) {
          return const Scaffold(
            appBar: AppBackHeader(title: 'Start Request'),
            body: EmptyState(
              title: 'Service not found',
              message: 'Select the service again from the catalogue.',
              icon: Icons.search_off_rounded,
            ),
          );
        }

        final fields = _templateFields(service);
        _scheduleCustomerProfilePrefill(customerProfile, fields);

        final completedFields = _completedFieldCount(fields);
        final totalFields = fields.length + 4;

        return UnsavedChangesGuard(
          controller: _dirtyFormController,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: const AppBackHeader(title: 'Start Request'),
            bottomNavigationBar: _SubmitRequestBar(
              service: service,
              completedFields: completedFields,
              totalFields: totalFields,
              attachmentCount: 0,
              isSubmitting: _isSubmitting,
              onSubmit: () => _submit(service, fields),
            ),
            body: SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
                  children: [
                    _SelectedServiceCard(
                      service: service,
                      onChange: () => context.go('/services'),
                    ),
                    if (ref
                        .watch(authControllerProvider)
                        .capabilities
                        .isInternal) ...[
                      const SizedBox(height: 12),
                      AssistedCustomerCard(
                        onChanged: _onAssistedSelectionChanged,
                      ),
                      const SizedBox(height: 12),
                      _InternalDiscountCard(
                        service: service,
                        discountType: _discountType,
                        discountValueController: _discountValueController,
                        discountReasonController: _discountReasonController,
                        onDiscountTypeChanged: (value) {
                          if (value == null || value == _discountType) {
                            return;
                          }
                          _dirtyFormController.markDirty();
                          setState(() => _discountType = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ContactDetailsCard(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      emailController: _emailController,
                      taxIdController: _taxIdController,
                      requiredValidator: _required,
                      emailValidator: _validateEmail,
                      taxIdValidator: _validateOptionalCnicOrNtn,
                    ),
                    const SizedBox(height: 12),
                    _DynamicFormCard(
                      fields: fields,
                      remarksController: _remarksController,
                      controllerFor: _controllerFor,
                      selectValueFor: (field) => _selectValues[field.fieldname],
                      checkedValueFor: (field) =>
                          _checkValues[field.fieldname] ?? _boolDefault(field),
                      onSelectChanged: (field, value) {
                        _dirtyFormController.markDirty();
                        setState(() => _selectValues[field.fieldname] = value);
                      },
                      onCheckChanged: (field, value) {
                        _dirtyFormController.markDirty();
                        setState(
                          () => _checkValues[field.fieldname] = value ?? false,
                        );
                      },
                      requiredValidator: _required,
                    ),
                    const SizedBox(height: 12),
                    _RequiredDocumentsCard(
                      documents: service.requiredDocuments,
                    ),
                    if (service.stages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _StagesCard(stages: service.stages),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleCustomerProfilePrefill(
    ProfileSummary? profile,
    List<ServiceTemplateField> fields,
  ) {
    if (_customerProfilePrefilled ||
        _customerProfilePrefillScheduled ||
        profile == null) {
      return;
    }

    _customerProfilePrefillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _customerProfilePrefillScheduled = false;
      if (!mounted || _customerProfilePrefilled) return;
      if (ref.read(authControllerProvider).capabilities.isInternal) return;
      final wasDirty = _dirtyFormController.isDirty;

      _setIfEmpty(_nameController, profile.displayName);
      _setIfEmpty(_phoneController, profile.phone);
      _setIfEmpty(_emailController, profile.email);
      _setIfEmpty(_taxIdController, profile.cnic ?? profile.ntn);

      final profileValues = <String, String?>{
        'full_name': profile.displayName,
        'customer_name': profile.displayName,
        'email': profile.email,
        'email_id': profile.email,
        'phone': profile.phone,
        'mobile': profile.phone,
        'mobile_no': profile.phone,
        'whatsapp': profile.whatsappNo,
        'whatsapp_no': profile.whatsappNo,
        'cnic': profile.cnic,
        'ntn': profile.ntn,
        'tax_id': profile.cnic ?? profile.ntn,
        'address': profile.address,
        'company': profile.companyName,
        'company_name': profile.companyName,
      };

      for (final field in fields) {
        final key = field.fieldname.trim().toLowerCase();
        final value = profileValues[key]?.trim();
        if (value == null || value.isEmpty) continue;
        if (_isCheckField(field) || _isSelectField(field)) continue;
        _setIfEmpty(_controllerFor(field), value);
      }

      _customerProfilePrefilled = true;
      if (!wasDirty) {
        _dirtyFormController.markPristine();
      }
      setState(() {});
    });
  }

  void _setIfEmpty(TextEditingController controller, String? value) {
    final cleanValue = value?.trim();
    if (controller.text.trim().isNotEmpty ||
        cleanValue == null ||
        cleanValue.isEmpty ||
        cleanValue == 'Not available') {
      return;
    }
    controller.text = cleanValue;
  }

  void _onAssistedSelectionChanged(AssistedCustomerDraftSelection? selection) {
    _dirtyFormController.markDirty();
    _assistedSelection = selection;
    final customer = selection?.customer;
    if (customer != null) {
      _nameController.text = customer.fullName;
      _phoneController.text = customer.phone;
      _emailController.text = customer.email;
      if (customer.cnic.isNotEmpty) {
        _taxIdController.text = customer.cnic;
      }
    }
    if (mounted) setState(() {});
  }

  ServiceItem? _findService(List<ServiceItem> services) {
    for (final service in services) {
      if (service.id == widget.serviceId) return service;
    }
    return null;
  }

  List<ServiceTemplateField> _templateFields(ServiceItem service) {
    if (service.formSchema.isNotEmpty) {
      final fields = [...service.formSchema];
      fields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return fields;
    }

    return const [
      ServiceTemplateField(
        fieldname: 'request_context',
        label: 'Request details',
        fieldtype: 'Small Text',
        description: 'Tell OMC what you need for this service.',
        isRequired: true,
      ),
    ];
  }

  TextEditingController _controllerFor(ServiceTemplateField field) {
    return _dynamicControllers.putIfAbsent(field.fieldname, () {
      final controller = TextEditingController(text: field.defaultValue);
      controller.addListener(_onTextChanged);
      return controller;
    });
  }

  Map<String, String> _dynamicValues(List<ServiceTemplateField> fields) {
    final values = <String, String>{};
    for (final field in fields) {
      final fieldname = field.fieldname.trim();
      if (fieldname.isEmpty) continue;
      final value = _fieldValue(field).trim();
      if (value.isNotEmpty) values[fieldname] = value;
    }
    return values;
  }

  String _fieldValue(ServiceTemplateField field) {
    if (_isCheckField(field)) {
      return ((_checkValues[field.fieldname] ?? _boolDefault(field))
          ? 'Yes'
          : 'No');
    }
    if (_isSelectField(field)) {
      return _selectValues[field.fieldname] ?? field.defaultValue;
    }
    return _controllerFor(field).text;
  }

  bool _boolDefault(ServiceTemplateField field) {
    final text = field.defaultValue.trim().toLowerCase();
    return const ['1', 'true', 'yes', 'y'].contains(text);
  }

  int _completedFieldCount(List<ServiceTemplateField> fields) {
    var count = 0;
    for (final value in [
      _nameController.text,
      _phoneController.text,
      _emailController.text,
      _taxIdController.text,
    ]) {
      if (value.trim().isNotEmpty) {
        count++;
      }
    }
    for (final field in fields) {
      if (_fieldValue(field).trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  double _parseDiscountValue() {
    final normalized = _discountValueController.text.trim().replaceAll(',', '');
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _submit(
    ServiceItem service,
    List<ServiceTemplateField> fields,
  ) async {
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final missingRequired = fields
        .where((field) => field.isRequired && _fieldValue(field).trim().isEmpty)
        .map((field) => field.label.isNotEmpty ? field.label : field.fieldname)
        .toList(growable: false);

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete: ${missingRequired.join(', ')}'),
        ),
      );
      return;
    }

    final capabilities = ref.read(authControllerProvider).capabilities;
    if (capabilities.isInternal && _assistedSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the request customer first.')),
      );
      return;
    }

    final discountValue = _parseDiscountValue();
    if (capabilities.isInternal && discountValue > 0) {
      final originalPrice = service.basePrice;
      if (originalPrice == null || originalPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A catalogue base price is required before applying a discount.',
            ),
          ),
        );
        return;
      }
      if (_discountType == 'Percentage' && discountValue > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Percentage discount cannot exceed 100%.'),
          ),
        );
        return;
      }
      if (_discountType == 'Fixed Amount' && discountValue > originalPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fixed discount cannot exceed the service price.'),
          ),
        );
        return;
      }
      if (_discountReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a reason for the customer discount.'),
          ),
        );
        return;
      }
    }

    final repository = ref.read(serviceRequestRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final dynamicDetails = _dynamicValues(fields);
    final additionalDetails = <String, String>{...dynamicDetails};

    _dirtyFormController.beginSubmitting();
    final payload = ServiceRequestPayload(
      service: service,
      fullName: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      taxId: _taxIdController.text,
      remarks: _remarksController.text,
      additionalDetails: additionalDetails,
      attachments: const [],
      customerId: _assistedSelection?.customerId,
      customerName: _assistedSelection?.customer?.fullName,
      customerMode: _assistedSelection?.mode,
      customerConsentReference: _assistedSelection?.consentReference,
      city: _assistedSelection?.city,
      address: _assistedSelection?.address,
      discountType: capabilities.isInternal && discountValue > 0
          ? _discountType
          : null,
      discountValue: capabilities.isInternal && discountValue > 0
          ? discountValue
          : null,
      discountReason: capabilities.isInternal && discountValue > 0
          ? _discountReasonController.text
          : null,
    );
    final idempotencyKey = _submissionIntent.keyFor(payload.toJson());

    setState(() => _isSubmitting = true);
    try {
      final result = await repository.createServiceRequest(
        payload,
        idempotencyKey: idempotencyKey,
      );

      final requestId = result.requestId?.trim();

      if (!mounted) return;
      _submissionIntent.complete();
      _dirtyFormController.submissionSucceeded();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'Your existing active request is ready to continue.'
                : 'Service request submitted to OMC.',
          ),
        ),
      );
      if (requestId != null && requestId.isNotEmpty) {
        await _refreshRequestTracking(requestId);
        if (!mounted) return;
        _openSubmittedRequest(requestId);
      } else {
        context.go(_requestHomeRoute());
      }
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Request not submitted',
        fallbackMessage:
            'Request could not be submitted right now. Your entered information was retained.',
      );
      _dirtyFormController.submissionFailed();
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) {
        if (_dirtyFormController.isSubmitting) {
          _dirtyFormController.submissionFailed();
        }
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _refreshRequestTracking(String requestId) async {
    final capabilities = ref.read(authControllerProvider).capabilities;

    ref.invalidate(serviceCasesProvider);
    ref.invalidate(serviceCaseDetailProvider(requestId));

    if (capabilities.isInternal) {
      ref.invalidate(internalServiceCasesProvider);
      ref.invalidate(internalWorkspaceSummaryProvider);

      try {
        await Future.wait([
          ref.read(internalServiceCasesProvider.future),
          ref.read(internalWorkspaceSummaryProvider.future),
        ]);
      } catch (_) {
        // Destination screens keep their own loading and retry behaviour.
      }
      return;
    }

    try {
      await Future.wait([
        ref.read(serviceCasesProvider.future),
        ref.read(serviceCaseDetailProvider(requestId).future),
      ]);
    } catch (_) {
      // Destination screens keep their own loading and retry behaviour.
    }
  }

  void _openSubmittedRequest(String requestId) {
    final encodedRequestId = Uri.encodeComponent(requestId);
    final capabilities = ref.read(authControllerProvider).capabilities;
    if (capabilities.isInternal) {
      context.go('/my-services/$encodedRequestId');
      return;
    }
    context.go('/my-services/$encodedRequestId');
  }

  String _requestHomeRoute() {
    final capabilities = ref.read(authControllerProvider).capabilities;
    return capabilities.isInternal
        ? '/internal-workspace/service-cases'
        : '/my-services';
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredMessage = _required(value, 'Email');
    if (requiredMessage != null) return requiredMessage;
    final email = value!.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validateOptionalCnicOrNtn(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) return null;
    final digits = normalizedValue.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13) return null;
    if (digits.length >= 7 && digits.length <= 9) return null;
    return 'Enter a valid CNIC or NTN.';
  }
}

class _InternalDiscountCard extends StatelessWidget {
  const _InternalDiscountCard({
    required this.service,
    required this.discountType,
    required this.discountValueController,
    required this.discountReasonController,
    required this.onDiscountTypeChanged,
  });

  final ServiceItem service;
  final String discountType;
  final TextEditingController discountValueController;
  final TextEditingController discountReasonController;
  final ValueChanged<String?> onDiscountTypeChanged;

  @override
  Widget build(BuildContext context) {
    final originalPrice = service.basePrice;
    final value =
        double.tryParse(discountValueController.text.replaceAll(',', '')) ?? 0;
    final discountAmount = originalPrice == null || originalPrice <= 0
        ? 0.0
        : discountType == 'Percentage'
        ? originalPrice * (value.clamp(0, 100) / 100)
        : value.clamp(0, originalPrice).toDouble();
    final finalPrice = originalPrice == null
        ? null
        : (originalPrice - discountAmount).clamp(0, double.infinity).toDouble();
    final currency = (service.currency ?? '').trim();

    String money(double amount) {
      final formatted = amount % 1 == 0
          ? amount.toInt().toString()
          : amount.toStringAsFixed(2);
      return currency.isEmpty ? formatted : '$currency $formatted';
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer discount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional. Available only for internal assisted requests.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: discountType,
            decoration: const InputDecoration(labelText: 'Discount type'),
            items: const [
              DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
              DropdownMenuItem(
                value: 'Fixed Amount',
                child: Text('Fixed amount'),
              ),
            ],
            onChanged: onDiscountTypeChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: discountValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: discountType == 'Percentage'
                  ? 'Discount percentage'
                  : 'Discount amount',
              suffixText: discountType == 'Percentage' ? '%' : currency,
            ),
            validator: (value) {
              final clean = (value ?? '').trim().replaceAll(',', '');
              if (clean.isEmpty) {
                return null;
              }
              final parsed = double.tryParse(clean);
              if (parsed == null || parsed < 0) {
                return 'Enter a valid non-negative discount.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: discountReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Discount reason',
              hintText: 'Required when a discount is applied',
            ),
          ),
          if (originalPrice != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DiscountSummaryRow(
              label: 'Original price',
              value: money(originalPrice),
            ),
            const SizedBox(height: 6),
            _DiscountSummaryRow(
              label: 'Discount',
              value: '- ${money(discountAmount)}',
            ),
            const SizedBox(height: 6),
            _DiscountSummaryRow(
              label: 'Final price',
              value: money(finalPrice ?? originalPrice),
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscountSummaryRow extends StatelessWidget {
  const _DiscountSummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? const TextStyle(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service, required this.onChange});

  final ServiceItem service;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final timeline = service.completionTime.trim().isEmpty
        ? 'Timeline to be confirmed'
        : service.completionTime.trim();
    final price = service.priceLabel.trim().isEmpty
        ? 'Fee to be confirmed'
        : service.priceLabel.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _serviceIcon(service.iconKey),
              color: AppTheme.textPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$price  •  $timeline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.taxIdController,
    required this.requiredValidator,
    required this.emailValidator,
    required this.taxIdValidator,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) taxIdValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Client details',
            subtitle:
                'Enter the details of the person or business receiving this service.',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => requiredValidator(value, 'Full name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone or WhatsApp number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Phone number'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: emailValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: taxIdController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'CNIC / NTN (optional)',
              helperText:
                  'CNIC must be 13 digits. NTN should be 7-9 digits if provided.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: taxIdValidator,
          ),
        ],
      ),
    );
  }
}

class _DynamicFormCard extends StatelessWidget {
  const _DynamicFormCard({
    required this.fields,
    required this.remarksController,
    required this.controllerFor,
    required this.selectValueFor,
    required this.checkedValueFor,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final List<ServiceTemplateField> fields;
  final TextEditingController remarksController;
  final TextEditingController Function(ServiceTemplateField field)
  controllerFor;
  final String? Function(ServiceTemplateField field) selectValueFor;
  final bool Function(ServiceTemplateField field) checkedValueFor;
  final void Function(ServiceTemplateField field, String? value)
  onSelectChanged;
  final void Function(ServiceTemplateField field, bool? value) onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Service information',
            subtitle: 'Add the information needed to prepare your case.',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 16),
          for (final field in fields) ...[
            _DynamicField(
              field: field,
              controller: controllerFor(field),
              selectValue: selectValueFor(field),
              checkedValue: checkedValueFor(field),
              onSelectChanged: (value) => onSelectChanged(field, value),
              onCheckChanged: (value) => onCheckChanged(field, value),
              requiredValidator: requiredValidator,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: remarksController,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Add anything else OMC should know.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({
    required this.field,
    required this.controller,
    required this.selectValue,
    required this.checkedValue,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final ServiceTemplateField field;
  final TextEditingController controller;
  final String? selectValue;
  final bool checkedValue;
  final ValueChanged<String?> onSelectChanged;
  final ValueChanged<bool?> onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    final label = field.label.trim().isEmpty
        ? field.fieldname
        : field.label.trim();
    final helperText = field.description.trim().isEmpty
        ? null
        : field.description.trim();

    if (_isCheckField(field)) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: checkedValue,
        onChanged: onCheckChanged,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: helperText == null ? null : Text(helperText),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    if (_isSelectField(field) && field.options.isNotEmpty) {
      final selected = field.options.contains(selectValue) ? selectValue : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        items: field.options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(growable: false),
        onChanged: onSelectChanged,
        decoration: InputDecoration(
          labelText: field.isRequired ? '$label *' : label,
          helperText: helperText,
          prefixIcon: const Icon(Icons.list_alt_outlined),
        ),
        validator: field.isRequired
            ? (value) => requiredValidator(value, label)
            : null,
      );
    }

    return TextFormField(
      controller: controller,
      minLines: _isLongTextField(field) ? 3 : 1,
      maxLines: _isLongTextField(field) ? 5 : 1,
      keyboardType: _keyboardTypeFor(field),
      inputFormatters: _inputFormattersFor(field),
      textInputAction: _isLongTextField(field)
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: field.isRequired ? '$label *' : label,
        hintText: field.placeholder.trim().isEmpty
            ? null
            : field.placeholder.trim(),
        helperText: helperText,
        alignLabelWithHint: _isLongTextField(field),
        prefixIcon: Icon(_iconFor(field)),
      ),
      validator: field.isRequired
          ? (value) => requiredValidator(value, label)
          : null,
    );
  }
}

class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.stages});

  final List<ServiceStageTemplate> stages;

  @override
  Widget build(BuildContext context) {
    final visibleStages =
        stages.where((stage) => stage.isCustomerVisible).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visibleStages.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.route_outlined,
            color: Color(0xFF7C3AED),
            size: 19,
          ),
        ),
        title: const Text(
          'What happens next',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${visibleStages.length} service stage${visibleStages.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          for (var index = 0; index < visibleStages.length; index++)
            _CompactStageRow(
              number: index + 1,
              stage: visibleStages[index],
              isLast: index == visibleStages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CompactStageRow extends StatelessWidget {
  const _CompactStageRow({
    required this.number,
    required this.stage,
    required this.isLast,
  });

  final int number;
  final ServiceStageTemplate stage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0ECFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFE2E6ED),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (stage.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      stage.description.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({required this.documents});

  final List<String> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Documents you may need',
            subtitle:
                'Submit the request now. OMC will ask for documents from the case screen when they are required.',
            icon: Icons.folder_copy_outlined,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < documents.length; index++) ...[
                  Row(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF16A34A),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          documents[index],
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index != documents.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE5E9EF)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitRequestBar extends StatelessWidget {
  const _SubmitRequestBar({
    required this.service,
    required this.completedFields,
    required this.totalFields,
    required this.attachmentCount,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final ServiceItem service;
  final int completedFields;
  final int totalFields;
  final int attachmentCount;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final _ = service;
    final remaining = (totalFields - completedFields).clamp(0, totalFields);

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  remaining == 0
                      ? attachmentCount == 0
                            ? 'Ready to submit'
                            : '$attachmentCount file${attachmentCount == 1 ? '' : 's'} attached'
                      : '$remaining detail${remaining == 1 ? '' : 's'} remaining',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 174,
                child: AppButton(
                  label: 'Submit',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: AppTheme.textSecondary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _serviceIcon(String? key) {
  return switch ((key ?? '').trim().toLowerCase()) {
    'business_setup' => Icons.domain_add_outlined,
    'company_registration' => Icons.apartment_outlined,
    'tax_filing' => Icons.receipt_long_outlined,
    'tax_registration' => Icons.how_to_reg_outlined,
    'gst' => Icons.request_quote_outlined,
    'accounting' => Icons.calculate_outlined,
    'audit' => Icons.fact_check_outlined,
    'payroll' => Icons.groups_outlined,
    'legal' => Icons.gavel_outlined,
    _ => Icons.work_outline_rounded,
  };
}

bool _isSelectField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'select' || type == 'autocomplete' || type == 'link';
}

bool _isCheckField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'check' || type == 'checkbox' || type == 'boolean';
}

bool _isLongTextField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type.contains('text') ||
      type == 'textarea' ||
      type == 'long text' ||
      type == 'small text';
}

TextInputType _keyboardTypeFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('email') || name.contains('email')) {
    return TextInputType.emailAddress;
  }
  if (type.contains('phone') ||
      name.contains('phone') ||
      name.contains('mobile')) {
    return TextInputType.phone;
  }
  if (type.contains('int') ||
      type.contains('currency') ||
      type.contains('float') ||
      type.contains('number')) {
    return TextInputType.number;
  }
  if (_isLongTextField(field)) return TextInputType.multiline;
  return TextInputType.text;
}

List<TextInputFormatter> _inputFormattersFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  if (type.contains('int') || type == 'number') {
    return [FilteringTextInputFormatter.digitsOnly];
  }
  return const [];
}

IconData _iconFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('date') || name.contains('date')) {
    return Icons.event_outlined;
  }
  if (type.contains('email') || name.contains('email')) {
    return Icons.email_outlined;
  }
  if (type.contains('phone') || name.contains('phone')) {
    return Icons.phone_outlined;
  }
  if (type.contains('currency') ||
      name.contains('amount') ||
      name.contains('fee')) {
    return Icons.payments_outlined;
  }
  if (type.contains('int') || type.contains('number')) {
    return Icons.numbers_outlined;
  }
  if (_isLongTextField(field)) return Icons.notes_outlined;
  return Icons.edit_outlined;
}
