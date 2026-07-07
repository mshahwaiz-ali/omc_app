import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
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
        body: EmptyState(
          title: 'Request form unavailable',
          message: _serviceRequestDraftErrorMessage(error),
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
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

        return Scaffold(
          appBar: const AppBackHeader(title: 'Start Request'),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _SelectedServiceCard(service: service),
                  const SizedBox(height: 16),
                  _BackendTemplateStatusCard(
                    service: service,
                    fieldCount: fields.length,
                  ),
                  const SizedBox(height: 16),
                  if (service.stages.isNotEmpty) ...[
                    _StagesCard(stages: service.stages),
                    const SizedBox(height: 16),
                  ],
                  _ContactDetailsCard(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                    taxIdController: _taxIdController,
                    remarksController: _remarksController,
                    requiredValidator: _required,
                    emailValidator: _validateEmail,
                    taxIdValidator: _validateOptionalCnicOrNtn,
                  ),
                  const SizedBox(height: 16),
                  _DynamicFormCard(
                    fields: fields,
                    controllerFor: _controllerFor,
                    selectValueFor: (field) => _selectValues[field.fieldname],
                    checkedValueFor: (field) =>
                        _checkValues[field.fieldname] ?? _boolDefault(field),
                    onSelectChanged: (field, value) {
                      setState(() => _selectValues[field.fieldname] = value);
                    },
                    onCheckChanged: (field, value) {
                      setState(
                        () => _checkValues[field.fieldname] = value ?? false,
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
                  const SizedBox(height: 16),
                  _ReviewCard(
                    service: service,
                    formValues: _dynamicValues(fields),
                    fullName: _nameController.text,
                    phone: _phoneController.text,
                    email: _emailController.text,
                    attachments: _attachments,
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Submit request',
                    icon: Icons.send_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : () => _submit(service, fields),
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
      return ((_checkValues[field.fieldname] ?? _boolDefault(field)) ? 'Yes' : 'No');
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
    setState(() => _isPickingDocuments = true);
    try {
      final result = await ref
          .read(documentAttachmentControllerProvider)
          .pickDocuments(existingAttachments: _attachments);
      if (!mounted) return;
      setState(() => _attachments.addAll(result.accepted));
      for (final message in result.rejectedMessages) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isPickingDocuments = false);
    }
  }

  void _removeDocument(DocumentAttachment attachment) {
    setState(() => _attachments.removeWhere((item) => item.id == attachment.id));
  }

  Future<void> _submit(ServiceItem service, List<ServiceTemplateField> fields) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final missingRequired = fields
        .where((field) => field.isRequired && _fieldValue(field).trim().isEmpty)
        .map((field) => field.label.isNotEmpty ? field.label : field.fieldname)
        .toList(growable: false);

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete: ${missingRequired.join(', ')}')),
      );
      return;
    }

    final repository = ref.read(serviceRequestRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final dynamicDetails = _dynamicValues(fields);
    final additionalDetails = <String, String>{
      ...dynamicDetails,
      if (dynamicDetails.isNotEmpty) 'form_data_json': jsonEncode(dynamicDetails),
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

      final requestId = result.requestId;
      if (requestId != null && requestId.trim().isNotEmpty && _attachments.isNotEmpty) {
        await repository.uploadRequestAttachments(
          requestId: requestId,
          attachments: _attachments,
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Service request submitted to OMC.')),
      );
      context.go('/my-services');
    } on ApiError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Request could not be submitted right now.')),
      );
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

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.category,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            service.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          if (service.shortDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              service.shortDescription.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackendTemplateStatusCard extends StatelessWidget {
  const _BackendTemplateStatusCard({required this.service, required this.fieldCount});

  final ServiceItem service;
  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    final hasTemplate = service.hasBackendTemplate;
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(
            hasTemplate ? Icons.cloud_done_rounded : Icons.edit_note_rounded,
            color: AppTheme.primaryRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasTemplate
                  ? 'Backend configured form loaded with $fieldCount fields.'
                  : 'Using safe fallback form until backend fields are configured.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    required this.remarksController,
    required this.requiredValidator,
    required this.emailValidator,
    required this.taxIdValidator,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final TextEditingController remarksController;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) taxIdValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Contact details'),
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
              helperText: 'CNIC must be 13 digits. NTN should be 7-9 digits if provided.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: taxIdValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: remarksController,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Remarks (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicFormCard extends StatelessWidget {
  const _DynamicFormCard({
    required this.fields,
    required this.controllerFor,
    required this.selectValueFor,
    required this.checkedValueFor,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final List<ServiceTemplateField> fields;
  final TextEditingController Function(ServiceTemplateField field) controllerFor;
  final String? Function(ServiceTemplateField field) selectValueFor;
  final bool Function(ServiceTemplateField field) checkedValueFor;
  final void Function(ServiceTemplateField field, String? value) onSelectChanged;
  final void Function(ServiceTemplateField field, bool? value) onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Service form'),
          const SizedBox(height: 6),
          const Text(
            'These fields are driven by OMC backend service configuration.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
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
    final label = field.label.trim().isEmpty ? field.fieldname : field.label.trim();
    final helperText = field.description.trim().isEmpty ? null : field.description.trim();

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
        value: selected,
        items: field.options
            .map((option) => DropdownMenuItem(value: option, child: Text(option)))
            .toList(growable: false),
        onChanged: onSelectChanged,
        decoration: InputDecoration(
          labelText: field.isRequired ? '$label *' : label,
          helperText: helperText,
          prefixIcon: const Icon(Icons.list_alt_outlined),
        ),
        validator: field.isRequired ? (value) => requiredValidator(value, label) : null,
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
        hintText: field.placeholder.trim().isEmpty ? null : field.placeholder.trim(),
        helperText: helperText,
        alignLabelWithHint: _isLongTextField(field),
        prefixIcon: Icon(_iconFor(field)),
      ),
      validator: field.isRequired ? (value) => requiredValidator(value, label) : null,
    );
  }
}

class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.stages});

  final List<ServiceStageTemplate> stages;

  @override
  Widget build(BuildContext context) {
    final visibleStages = stages.where((stage) => stage.isCustomerVisible).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visibleStages.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Expected stages'),
          const SizedBox(height: 14),
          for (var index = 0; index < visibleStages.length; index++) ...[
            _StageRow(number: index + 1, stage: visibleStages[index]),
            if (index != visibleStages.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.number, required this.stage});

  final int number;
  final ServiceStageTemplate stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stage.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (stage.description.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  stage.description.trim(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Required documents'),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            const Text(
              'OMC will confirm required documents after reviewing your case.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppTheme.primaryRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(document)),
                  ],
                ),
              ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isPickingDocuments ? null : onPickDocuments,
            icon: isPickingDocuments
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(isPickingDocuments ? 'Opening picker...' : 'Attach documents'),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final attachment in attachments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(attachment.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatFileSize(attachment.sizeInBytes)),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onRemoveDocument(attachment),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.service,
    required this.formValues,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.attachments,
  });

  final ServiceItem service;
  final Map<String, String> formValues;
  final String fullName;
  final String phone;
  final String email;
  final List<DocumentAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Review'),
          const SizedBox(height: 12),
          _ReviewRow(label: 'Service', value: service.title),
          _ReviewRow(label: 'Name', value: fullName.trim().isEmpty ? 'Not entered' : fullName.trim()),
          _ReviewRow(label: 'Phone', value: phone.trim().isEmpty ? 'Not entered' : phone.trim()),
          _ReviewRow(label: 'Email', value: email.trim().isEmpty ? 'Not entered' : email.trim()),
          _ReviewRow(label: 'Form fields', value: formValues.length.toString()),
          _ReviewRow(label: 'Attachments', value: attachments.length.toString()),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
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
  return type.contains('text') || type == 'textarea' || type == 'long text' || type == 'small text';
}

TextInputType _keyboardTypeFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('email') || name.contains('email')) return TextInputType.emailAddress;
  if (type.contains('phone') || name.contains('phone') || name.contains('mobile')) return TextInputType.phone;
  if (type.contains('int') || type.contains('currency') || type.contains('float') || type.contains('number')) {
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
  if (type.contains('date') || name.contains('date')) return Icons.event_outlined;
  if (type.contains('email') || name.contains('email')) return Icons.email_outlined;
  if (type.contains('phone') || name.contains('phone')) return Icons.phone_outlined;
  if (type.contains('currency') || name.contains('amount') || name.contains('fee')) return Icons.payments_outlined;
  if (type.contains('int') || type.contains('number')) return Icons.numbers_outlined;
  if (_isLongTextField(field)) return Icons.notes_outlined;
  return Icons.edit_outlined;
}

String _serviceRequestDraftErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return 'OMC service request form could not be loaded right now. Please try again.';
}
