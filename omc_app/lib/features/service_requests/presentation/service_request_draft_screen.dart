import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../service_catalogue/application/service_catalogue_controller.dart';
import '../../service_catalogue/data/service_item.dart';
import '../../service_templates/data/service_template.dart';
import '../data/service_request_repository.dart';

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
  final Map<String, TextEditingController> _dynamicControllers = {};
  final Map<String, String?> _selectValues = {};
  final Map<String, bool> _checkValues = {};
  final List<DocumentAttachment> _attachments = [];

  bool _prefilledEmail = false;
  bool _isPickingDocuments = false;
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
    ]) {
      controller.addListener(_refresh);
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
    ]) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _prefillEmail();

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

        final completedFields = _completedFieldCount(fields);
        final totalFields = fields.length + 4;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFD),
          appBar: const AppBackHeader(title: 'Start Request'),
          bottomNavigationBar: _SubmitRequestBar(
            service: service,
            completedFields: completedFields,
            totalFields: totalFields,
            attachmentCount: _attachments.length,
            isSubmitting: _isSubmitting,
            onSubmit: () => _submit(service, fields),
          ),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: Stack(
                children: [
                  const Positioned.fill(child: _RequestBackdrop()),
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                    children: [
                      const _RequestIntro(),
                      const SizedBox(height: 14),
                      _RequestProgress(
                        completedFields: completedFields,
                        totalFields: totalFields,
                        attachmentCount: _attachments.length,
                      ),
                      const SizedBox(height: 14),
                      _SelectedServiceCard(
                        service: service,
                        onChange: () => context.go('/services'),
                      ),
                      const SizedBox(height: 18),
                      _ContactDetailsCard(
                        nameController: _nameController,
                        phoneController: _phoneController,
                        emailController: _emailController,
                        taxIdController: _taxIdController,
                        requiredValidator: _required,
                        emailValidator: _validateEmail,
                        taxIdValidator: _validateOptionalCnicOrNtn,
                      ),
                      const SizedBox(height: 16),
                      _DynamicFormCard(
                        fields: fields,
                        remarksController: _remarksController,
                        controllerFor: _controllerFor,
                        selectValueFor: (field) =>
                            _selectValues[field.fieldname],
                        checkedValueFor: (field) =>
                            _checkValues[field.fieldname] ??
                            _boolDefault(field),
                        onSelectChanged: (field, value) {
                          setState(
                            () => _selectValues[field.fieldname] = value,
                          );
                        },
                        onCheckChanged: (field, value) {
                          setState(
                            () =>
                                _checkValues[field.fieldname] = value ?? false,
                          );
                        },
                        requiredValidator: _required,
                      ),
                      const SizedBox(height: 16),
                      _RequiredDocumentsCard(
                        documents: service.requiredDocuments,
                        attachments: _attachments,
                        isPickingDocuments: _isPickingDocuments,
                        onPickDocuments: _pickDocuments,
                        onRemoveDocument: _removeDocument,
                        formatFileSize: ref
                            .read(documentAttachmentControllerProvider)
                            .formatFileSize,
                      ),
                      if (service.stages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _StagesCard(stages: service.stages),
                      ],
                      const SizedBox(height: 16),
                      _SubmissionSummaryCard(
                        service: service,
                        completedFields: completedFields,
                        totalFields: totalFields,
                        attachmentCount: _attachments.length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _prefillEmail() {
    if (_prefilledEmail) return;
    final userId = ref.read(authControllerProvider).userId;
    if (userId != null && userId.contains('@')) {
      _emailController.text = userId;
    }
    _prefilledEmail = true;
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
      controller.addListener(_refresh);
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

  Future<void> _pickDocuments() async {
    if (_isPickingDocuments || _isSubmitting) return;

    setState(() => _isPickingDocuments = true);
    try {
      final result = await ref
          .read(documentAttachmentControllerProvider)
          .pickDocuments(existingAttachments: _attachments);
      if (!mounted) return;
      setState(() => _attachments.addAll(result.accepted));
      for (final message in result.rejectedMessages) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Documents unavailable',
        fallbackMessage:
            'Documents could not be selected right now. Your form was retained.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isPickingDocuments = false);
    }
  }

  void _removeDocument(DocumentAttachment attachment) {
    setState(
      () => _attachments.removeWhere((item) => item.id == attachment.id),
    );
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

    final repository = ref.read(serviceRequestRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final dynamicDetails = _dynamicValues(fields);
    final additionalDetails = <String, String>{
      ...dynamicDetails,
      if (dynamicDetails.isNotEmpty)
        'form_data_json': jsonEncode(dynamicDetails),
    };

    setState(() => _isSubmitting = true);
    try {
      final result = await repository.createServiceRequest(
        ServiceRequestPayload(
          service: service,
          fullName: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          taxId: _taxIdController.text,
          remarks: _remarksController.text,
          additionalDetails: additionalDetails,
          attachments: _attachments,
        ),
      );

      final requestId = result.requestId?.trim();
      if (requestId != null &&
          requestId.isNotEmpty &&
          _attachments.isNotEmpty) {
        try {
          await repository.uploadRequestAttachments(
            requestId: requestId,
            attachments: _attachments,
          );
        } catch (error) {
          if (!mounted) return;
          final failure = AppFailureClassifier.classify(
            error,
            fallbackTitle: 'Documents not uploaded',
            fallbackMessage:
                'Your service request was submitted, but its documents could not be uploaded. Open the request and retry the document upload.',
          );
          messenger.showSnackBar(SnackBar(content: Text(failure.message)));
          context.go('/my-services/${Uri.encodeComponent(requestId)}');
          return;
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Service request submitted to OMC.')),
      );
      context.go('/my-services');
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Request not submitted',
        fallbackMessage:
            'Request could not be submitted right now. Your entered information was retained.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

class _RequestBackdrop extends StatelessWidget {
  const _RequestBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FC), Color(0xFFFAFBFD)],
        ),
      ),
    );
  }
}

class _RequestIntro extends StatelessWidget {
  const _RequestIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Let’s get you started',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Complete the details below and OMC will review your request.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RequestProgress extends StatelessWidget {
  const _RequestProgress({
    required this.completedFields,
    required this.totalFields,
    required this.attachmentCount,
  });

  final int completedFields;
  final int totalFields;
  final int attachmentCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalFields == 0
        ? 0.0
        : (completedFields / totalFields).clamp(0.0, 1.0);

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Request progress',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$completedFields of $totalFields details',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE9EDF3),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C3AED),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const _ProgressStep(
                icon: Icons.person_outline_rounded,
                label: 'Details',
              ),
              const _ProgressDivider(),
              const _ProgressStep(icon: Icons.tune_rounded, label: 'Service'),
              const _ProgressDivider(),
              _ProgressStep(
                icon: Icons.attach_file_rounded,
                label: attachmentCount == 0
                    ? 'Documents'
                    : '$attachmentCount attached',
              ),
              const _ProgressDivider(),
              const _ProgressStep(
                icon: Icons.check_circle_outline_rounded,
                label: 'Submit',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppTheme.textSecondary),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDivider extends StatelessWidget {
  const _ProgressDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 13, height: 1, color: const Color(0xFFDDE3EB));
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service, required this.onChange});

  final ServiceItem service;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tone = _serviceTone(service.colorFamily);
    final description = service.shortDescription?.trim() ?? '';

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _serviceIcon(service.iconKey),
                  color: tone,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8ECF2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ServiceMeta(
                  icon: Icons.schedule_rounded,
                  label: 'Timeline',
                  value: service.completionTime.trim().isEmpty
                      ? 'To be confirmed'
                      : service.completionTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceMeta(
                  icon: Icons.payments_outlined,
                  label: 'Service fee',
                  value: service.priceLabel.trim().isEmpty
                      ? 'To be confirmed'
                      : service.priceLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceMeta extends StatelessWidget {
  const _ServiceMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Your details',
            subtitle: 'Tell us who this request is for.',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
  const _RequiredDocumentsCard({
    required this.documents,
    required this.attachments,
    required this.isPickingDocuments,
    required this.onPickDocuments,
    required this.onRemoveDocument,
    required this.formatFileSize,
  });

  final List<String> documents;
  final List<DocumentAttachment> attachments;
  final bool isPickingDocuments;
  final VoidCallback onPickDocuments;
  final ValueChanged<DocumentAttachment> onRemoveDocument;
  final String Function(int bytes) formatFileSize;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            title: 'Documents',
            subtitle: documents.isEmpty
                ? 'You can attach supporting files now or provide them later.'
                : '${documents.length} document${documents.length == 1 ? '' : 's'} may be needed for this service.',
            icon: Icons.folder_copy_outlined,
          ),
          if (documents.isNotEmpty) ...[
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
          const SizedBox(height: 14),
          InkWell(
            onTap: isPickingDocuments ? null : onPickDocuments,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8DEE8), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: isPickingDocuments
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.upload_file_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPickingDocuments
                              ? 'Opening file picker...'
                              : 'Attach documents',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Add clear PDF or image files.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_rounded, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${attachments.length} attached',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(11, 9, 5, 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE5EAF1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Color(0xFF2563EB),
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatFileSize(attachment.sizeInBytes),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => onRemoveDocument(attachment),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SubmissionSummaryCard extends StatelessWidget {
  const _SubmissionSummaryCard({
    required this.service,
    required this.completedFields,
    required this.totalFields,
    required this.attachmentCount,
  });

  final ServiceItem service;
  final int completedFields;
  final int totalFields;
  final int attachmentCount;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF16A34A),
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completedFields of $totalFields details completed'
                  ' · $attachmentCount file${attachmentCount == 1 ? '' : 's'} attached',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
    return Material(
      color: Colors.white,
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.priceLabel.trim().isEmpty
                          ? service.title
                          : service.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedFields/$totalFields details'
                      ' · $attachmentCount attachment${attachmentCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 158,
                child: AppButton(
                  label: 'Submit request',
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF7C3AED), size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
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

Color _serviceTone(String? family) {
  return switch ((family ?? '').trim().toLowerCase()) {
    'orange' => const Color(0xFFF97316),
    'green' => const Color(0xFF16A34A),
    'purple' => const Color(0xFF7C3AED),
    'blue' => const Color(0xFF2563EB),
    'teal' => const Color(0xFF0F9F8F),
    'rose' || 'red' => const Color(0xFFE11D48),
    _ => const Color(0xFF7C3AED),
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
