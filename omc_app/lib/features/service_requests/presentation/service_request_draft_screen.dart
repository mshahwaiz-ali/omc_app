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

part 'service_request_draft_form_sections.dart';
part 'service_request_draft_service_sections.dart';

class ServiceRequestDraftScreen extends ConsumerStatefulWidget {
  const ServiceRequestDraftScreen({
    super.key,
    required this.serviceId,
    this.assisted = false,
    this.customerProfile,
    this.customerName,
  });

  final String serviceId;
  final bool assisted;
  final String? customerProfile;
  final String? customerName;

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
          final catalogueIsEmpty = services.isEmpty;

          return Scaffold(
            appBar: const AppBackHeader(title: 'Start Request'),
            body: EmptyState(
              title: catalogueIsEmpty
                  ? 'No services available'
                  : 'Service unavailable',
              message: catalogueIsEmpty
                  ? 'OMC has not published any mobile services yet. Please check again later.'
                  : 'This service is no longer available. Select another service from the catalogue.',
              icon: catalogueIsEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              actionLabel: 'Back to services',
              onAction: () => context.go('/services'),
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
                        initialMode: widget.assisted ? 'My Referral' : null,
                        initialCustomerId: widget.assisted
                            ? widget.customerProfile
                            : null,
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
                ? 'An active request already exists for this customer and service.'
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
      context.go('/internal-workspace/service-cases/$encodedRequestId');
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
