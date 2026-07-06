import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/domain/customer_item.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../service_catalogue/application/service_catalogue_controller.dart';
import '../../service_catalogue/data/service_item.dart';

import '../../../core/network/api_error.dart';
import '../data/service_case_repository.dart';
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
  final _cnicController = TextEditingController();
  final _occupationController = TextEditingController();
  final _sourceOfIncomeController = TextEditingController();
  final _gstBusinessTypeController = TextEditingController();
  final _gstBusinessNatureController = TextEditingController();
  final _consumerNumberController = TextEditingController();
  final _businessContextController = TextEditingController();
  final _remarksController = TextEditingController();

  final List<DocumentAttachment> _attachments = [];

  CustomerItem? _selectedCustomer;
  String? _irisIncomeSource;
  String? _businessOption;

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
      _cnicController,
      _occupationController,
      _sourceOfIncomeController,
      _gstBusinessTypeController,
      _gstBusinessNatureController,
      _consumerNumberController,
      _businessContextController,
      _remarksController,
    ]) {
      controller.addListener(_refreshReviewSummary);
    }
  }

  void _refreshReviewSummary() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _phoneController,
      _emailController,
      _taxIdController,
      _cnicController,
      _occupationController,
      _sourceOfIncomeController,
      _gstBusinessTypeController,
      _gstBusinessNatureController,
      _consumerNumberController,
      _businessContextController,
      _remarksController,
    ]) {
      controller.removeListener(_refreshReviewSummary);
    }

    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxIdController.dispose();
    _cnicController.dispose();
    _occupationController.dispose();
    _sourceOfIncomeController.dispose();
    _gstBusinessTypeController.dispose();
    _gstBusinessNatureController.dispose();
    _consumerNumberController.dispose();
    _businessContextController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _prefillEmail();

    final servicesAsync = ref.watch(serviceCatalogueProvider);
    final customersAsync = ref.watch(customersProvider);

    return servicesAsync.when(
      loading: () => const Scaffold(
        body: SafeArea(
          child: LoadingView(message: 'Preparing request form...'),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
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
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Service not found',
              message: 'Select the service again from the catalogue.',
              icon: Icons.search_off_rounded,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Start Request')),
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
                  _DraftOverviewCard(
                    service: service,
                    attachments: _attachments,
                    selectedCustomer: _selectedCustomer,
                  ),
                  const SizedBox(height: 16),
                  customersAsync.when(
                    data: (customers) {
                      if (customers.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CustomerPickerCard(
                          customers: customers,
                          selectedCustomer: _selectedCustomer,
                          onChanged: (customer) {
                            setState(() {
                              _selectedCustomer = customer;
                            });
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  _WizardProgressCard(service: service),
                  const SizedBox(height: 16),
                  _WizardFoundationCard(service: service),
                  _WizardSpecificFieldsCard(
                    service: service,
                    cnicController: _cnicController,
                    occupationController: _occupationController,
                    sourceOfIncomeController: _sourceOfIncomeController,
                    gstBusinessTypeController: _gstBusinessTypeController,
                    gstBusinessNatureController: _gstBusinessNatureController,
                    consumerNumberController: _consumerNumberController,
                    businessContextController: _businessContextController,
                    irisIncomeSource: _irisIncomeSource,
                    businessOption: _businessOption,
                    onIrisIncomeSourceChanged: (value) {
                      setState(() {
                        _irisIncomeSource = value;
                      });
                    },
                    onBusinessOptionChanged: (value) {
                      setState(() {
                        _businessOption = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Contact details',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) => _required(value, 'Full name'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Phone or WhatsApp number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) =>
                              _required(value, 'Phone number'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _taxIdController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'CNIC / NTN (optional)',
                            helperText:
                                'CNIC must be 13 digits. NTN should be 7-9 digits if provided.',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: _validateOptionalCnicOrNtn,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _remarksController,
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
                  ),
                  const SizedBox(height: 18),
                  _DocumentHintCard(
                    service: service,
                    attachments: _attachments,
                    isPickingDocuments: _isPickingDocuments,
                    onPickDocuments: _pickDocuments,
                    onRemoveDocument: _removeDocument,
                    formatFileSize: ref
                        .read(documentAttachmentControllerProvider)
                        .formatFileSize,
                  ),
                  const SizedBox(height: 18),
                  _ReviewSummaryCard(
                    service: service,
                    fullNameController: _nameController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                    taxIdController: _taxIdController,
                    selectedCustomer: _selectedCustomer,
                    remarksController: _remarksController,
                    additionalDetails: _wizardDetailsFor(service),
                    attachments: _attachments,
                    formatFileSize: ref
                        .read(documentAttachmentControllerProvider)
                        .formatFileSize,
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Submit request',
                    icon: Icons.send_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : () => _submit(service),
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

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }

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

  Map<String, String> _wizardDetailsFor(ServiceItem service) {
    final details = <String, String>{};

    if (_isNtnService(service)) {
      _putIfNotEmpty(details, 'ntn_cnic', _cnicController.text);
      _putIfNotEmpty(details, 'occupation', _occupationController.text);
      _putIfNotEmpty(
        details,
        'source_of_income',
        _sourceOfIncomeController.text,
      );
    }

    if (_isIrisService(service)) {
      _putIfNotEmpty(details, 'iris_income_source', _irisIncomeSource);
    }

    if (_isGstService(service)) {
      _putIfNotEmpty(
        details,
        'gst_business_type',
        _gstBusinessTypeController.text,
      );
      _putIfNotEmpty(
        details,
        'gst_business_nature',
        _gstBusinessNatureController.text,
      );
      _putIfNotEmpty(
        details,
        'consumer_number',
        _consumerNumberController.text,
      );
    }

    if (_isBusinessService(service)) {
      _putIfNotEmpty(details, 'business_option', _businessOption);
      _putIfNotEmpty(
        details,
        'business_context',
        _businessContextController.text,
      );
    }

    return details;
  }

  void _putIfNotEmpty(Map<String, String> details, String key, String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) return;

    details[key] = normalizedValue;
  }

  Future<void> _pickDocuments() async {
    setState(() {
      _isPickingDocuments = true;
    });

    try {
      final result = await ref
          .read(documentAttachmentControllerProvider)
          .pickDocuments(existingAttachments: _attachments);

      if (!mounted) return;

      if (result.hasAcceptedFiles) {
        setState(() {
          _attachments.addAll(result.accepted);
        });
      }

      if (result.hasRejectedFiles) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.rejectedMessages.join('\n'))),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document picker could not be opened right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingDocuments = false;
        });
      }
    }
  }

  void _removeDocument(DocumentAttachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.id == attachment.id);
    });
  }

  Future<void> _submit(ServiceItem service) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (service.requiredDocuments.isNotEmpty && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach at least one document before submitting.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(serviceRequestRepositoryProvider);
      final result = await repository.createServiceRequest(
        ServiceRequestPayload(
          service: service,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          taxId: _taxIdController.text.trim(),
          remarks: _remarksController.text.trim(),
          additionalDetails: _wizardDetailsFor(service),
          attachments: List<DocumentAttachment>.unmodifiable(_attachments),
          customerId: _selectedCustomer?.id,
          customerName: _selectedCustomer?.name,
        ),
      );

      if (!mounted) return;

      final requestId = result.requestId;
      var uploadedCount = 0;
      String? uploadWarning;

      if (_attachments.isNotEmpty) {
        if (requestId == null || requestId.isEmpty) {
          uploadWarning =
              'Documents could not be uploaded automatically because the server did not return a request reference.';
        } else {
          try {
            final uploadedFiles = await repository.uploadRequestAttachments(
              requestId: requestId,
              attachments: _attachments,
            );

            uploadedCount = uploadedFiles.length;

            if (uploadedCount < _attachments.length) {
              uploadWarning =
                  'Some documents were skipped because their local file paths were unavailable.';
            }
          } on ApiError catch (error) {
            uploadWarning = error.message;
          } catch (_) {
            uploadWarning =
                'The request was created, but documents could not be uploaded right now.';
          }
        }
      }

      if (!mounted) return;

      ref.invalidate(serviceCasesProvider);

      final nextRoute = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final referenceLine = requestId == null || requestId.isEmpty
              ? 'OMC will confirm your reference after submission.'
              : 'Reference: $requestId';

          final uploadLine = _attachments.isEmpty
              ? 'No documents were attached with this request.'
              : uploadWarning == null
              ? 'Uploaded $uploadedCount document(s).'
              : 'Document upload note: $uploadWarning';

          return AlertDialog(
            title: const Text('Request submitted'),
            content: Text(
              'Your request has been sent to OMC.\n\n'
              '$referenceLine\n'
              '$uploadLine\n\n'
              'You can track updates from My Services once tracking data is available.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('/services'),
                child: const Text('Back to services'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(dialogContext).pop('/my-services'),
                icon: const Icon(Icons.track_changes_rounded),
                label: const Text('Track request'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (nextRoute == null || nextRoute.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      context.go(nextRoute);
    } on ApiError catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request could not be submitted right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _WizardProgressCard extends StatelessWidget {
  const _WizardProgressCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    if (_normalizedWizardType(service).isEmpty) {
      return const SizedBox.shrink();
    }

    final steps = _stepsFor(service);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(service),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Complete each section, attach documents, review, then submit to OMC.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final isLast = index == steps.length - 1;

            return _WizardProgressStepRow(
              number: index + 1,
              title: steps[index],
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  static String _titleFor(ServiceItem service) {
    switch (_normalizedWizardType(service)) {
      case 'ntn':
        return 'NTN registration wizard';
      case 'iris':
        return 'IRIS profile wizard';
      case 'gst':
        return 'GST registration wizard';
      case 'business':
        return 'Business incorporation wizard';
      default:
        return 'Guided request wizard';
    }
  }

  static List<String> _stepsFor(ServiceItem service) {
    switch (_normalizedWizardType(service)) {
      case 'ntn':
        return const [
          'CNIC and income details',
          'Contact information',
          'Required documents',
          'Review and submit',
        ];
      case 'iris':
        return const [
          'Income source selection',
          'Contact information',
          'Required documents',
          'Review and submit',
        ];
      case 'gst':
        return const [
          'Business information',
          'Contact information',
          'Required documents',
          'Review and submit',
        ];
      case 'business':
        return const [
          'Business option',
          'Contact information',
          'Required documents',
          'Review and submit',
        ];
      default:
        return const [
          'Service details',
          'Contact information',
          'Documents',
          'Review and submit',
        ];
    }
  }
}

class _WizardProgressStepRow extends StatelessWidget {
  const _WizardProgressStepRow({
    required this.number,
    required this.title,
    required this.isLast,
  });

  final int number;
  final String title;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.primaryRed.withValues(alpha: 0.16),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 14),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_add, color: Colors.white, size: 30),
            const SizedBox(height: 14),
            Text(
              service.category,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              service.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(
                  icon: Icons.payments_outlined,
                  label: service.feeLabel,
                ),
                _HeroPill(
                  icon: Icons.schedule_rounded,
                  label: service.completionTime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftOverviewCard extends StatelessWidget {
  const _DraftOverviewCard({
    required this.service,
    required this.attachments,
    required this.selectedCustomer,
  });

  final ServiceItem service;
  final List<DocumentAttachment> attachments;
  final CustomerItem? selectedCustomer;

  @override
  Widget build(BuildContext context) {
    final documents = _wizardDocumentsFor(service);
    final wizardType = _normalizedWizardType(service);
    final wizardLabel = wizardType.isEmpty
        ? 'Standard'
        : '${wizardType[0].toUpperCase()}${wizardType.substring(1)}';

    return Row(
      children: [
        Expanded(
          child: _DraftOverviewTile(
            icon: Icons.route_rounded,
            label: 'Flow',
            value: wizardLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DraftOverviewTile(
            icon: Icons.description_outlined,
            label: 'Docs',
            value: documents.length.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DraftOverviewTile(
            icon: Icons.attach_file_rounded,
            label: 'Attached',
            value: attachments.length.toString(),
          ),
        ),
        if (selectedCustomer != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _DraftOverviewTile(
              icon: Icons.people_outline_rounded,
              label: 'Customer',
              value: 'Linked',
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftOverviewTile extends StatelessWidget {
  const _DraftOverviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPickerCard extends StatelessWidget {
  const _CustomerPickerCard({
    required this.customers,
    required this.selectedCustomer,
    required this.onChanged,
  });

  final List<CustomerItem> customers;
  final CustomerItem? selectedCustomer;
  final ValueChanged<CustomerItem?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For internal users, link this request to an existing customer before submission.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedCustomer?.id ?? 'no-customer'),
            initialValue: selectedCustomer?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select customer (optional)',
              prefixIcon: Icon(Icons.people_outline_rounded),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('No customer selected'),
              ),
              ...customers.map(
                (customer) => DropdownMenuItem<String>(
                  value: customer.id,
                  child: Text(customer.name),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null || value.isEmpty) {
                onChanged(null);
                return;
              }

              for (final customer in customers) {
                if (customer.id == value) {
                  onChanged(customer);
                  return;
                }
              }

              onChanged(null);
            },
          ),
          if (selectedCustomer != null) ...[
            const SizedBox(height: 12),
            _CustomerSelectionSummary(customer: selectedCustomer!),
          ],
        ],
      ),
    );
  }
}

class _CustomerSelectionSummary extends StatelessWidget {
  const _CustomerSelectionSummary({required this.customer});

  final CustomerItem customer;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (customer.email != null) customer.email!,
      if (customer.phone != null) customer.phone!,
      if (customer.city != null) customer.city!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              details.join(' • '),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WizardSpecificFieldsCard extends StatelessWidget {
  const _WizardSpecificFieldsCard({
    required this.service,
    required this.cnicController,
    required this.occupationController,
    required this.sourceOfIncomeController,
    required this.gstBusinessTypeController,
    required this.gstBusinessNatureController,
    required this.consumerNumberController,
    required this.businessContextController,
    required this.irisIncomeSource,
    required this.businessOption,
    required this.onIrisIncomeSourceChanged,
    required this.onBusinessOptionChanged,
  });

  final ServiceItem service;
  final TextEditingController cnicController;
  final TextEditingController occupationController;
  final TextEditingController sourceOfIncomeController;
  final TextEditingController gstBusinessTypeController;
  final TextEditingController gstBusinessNatureController;
  final TextEditingController consumerNumberController;
  final TextEditingController businessContextController;
  final String? irisIncomeSource;
  final String? businessOption;
  final ValueChanged<String?> onIrisIncomeSourceChanged;
  final ValueChanged<String?> onBusinessOptionChanged;

  @override
  Widget build(BuildContext context) {
    final showNtnFields = _isNtnService(service);
    final showIrisFields = _isIrisService(service);
    final showGstFields = _isGstService(service);
    final showBusinessFields = _isBusinessService(service);

    if (!showNtnFields &&
        !showIrisFields &&
        !showGstFields &&
        !showBusinessFields) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Service-specific details',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These fields help OMC route the request correctly.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showNtnFields) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: cnicController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: const InputDecoration(
                  labelText: 'CNIC',
                  helperText: 'Enter 13 digits without dashes.',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _validateRequiredCnic,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: occupationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Occupation',
                  helperText: 'Example: salaried, business owner, freelancer.',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                validator: (value) => _requiredWizardField(
                  value,
                  'Occupation is required for NTN registration.',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: sourceOfIncomeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Source of income',
                  helperText:
                      'Mention the primary income source for NTN setup.',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (value) => _requiredWizardField(
                  value,
                  'Source of income is required for NTN registration.',
                ),
              ),
            ],
            if (showIrisFields) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(irisIncomeSource ?? 'no-iris-income-source'),
                initialValue: irisIncomeSource,
                decoration: const InputDecoration(
                  labelText: 'Income source',
                  helperText: 'Select the source to update in IRIS profile.',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                  DropdownMenuItem(value: 'Business', child: Text('Business')),
                  DropdownMenuItem(
                    value: 'Freelance',
                    child: Text('Freelance'),
                  ),
                  DropdownMenuItem(value: 'Property', child: Text('Property')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Select an income source.'
                    : null,
                onChanged: onIrisIncomeSourceChanged,
              ),
            ],
            if (showGstFields) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: gstBusinessTypeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Business type',
                  helperText: 'Example: retail, services, manufacturing.',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) => _requiredWizardField(
                  value,
                  'Business type is required for GST registration.',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: gstBusinessNatureController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Business nature',
                  helperText: 'Briefly describe what the business does.',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (value) => _requiredWizardField(
                  value,
                  'Business nature is required for GST registration.',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: consumerNumberController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Consumer number',
                  helperText: 'Utility bill consumer number if available.',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
            ],
            if (showBusinessFields) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(businessOption ?? 'no-business-option'),
                initialValue: businessOption,
                decoration: const InputDecoration(
                  labelText: 'Business option',
                  helperText: 'Choose the closest business structure.',
                  prefixIcon: Icon(Icons.business_center_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sole Proprietor',
                    child: Text('Sole Proprietor'),
                  ),
                  DropdownMenuItem(
                    value: 'Partnership',
                    child: Text('Partnership'),
                  ),
                  DropdownMenuItem(
                    value: 'Private Limited Company',
                    child: Text('Private Limited Company'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Select a business option.'
                    : null,
                onChanged: onBusinessOptionChanged,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: businessContextController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Business context',
                  helperText: 'Add any registration, change, or setup context.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (value) => _requiredWizardField(
                  value,
                  'Business context is required.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _requiredWizardField(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String _serviceSearchText(ServiceItem service) {
  return '${service.id} ${service.title} ${service.category}'.toLowerCase();
}

String _normalizedWizardType(ServiceItem service) {
  return service.wizardType?.trim().toLowerCase() ?? '';
}

bool _hasWizardType(ServiceItem service, String type) {
  return _normalizedWizardType(service) == type;
}

String? _validateRequiredCnic(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.isEmpty) return 'CNIC is required.';
  if (digits.length != 13) return 'CNIC must be exactly 13 digits.';
  return null;
}

bool _isNtnService(ServiceItem service) {
  if (_hasWizardType(service, 'ntn')) return true;

  return _serviceSearchText(service).contains('ntn');
}

bool _isIrisService(ServiceItem service) {
  if (_hasWizardType(service, 'iris')) return true;

  return _serviceSearchText(service).contains('iris');
}

bool _isGstService(ServiceItem service) {
  if (_hasWizardType(service, 'gst')) return true;

  final text = _serviceSearchText(service);
  return text.contains('gst') || text.contains('sales tax');
}

bool _isBusinessService(ServiceItem service) {
  if (_hasWizardType(service, 'business')) return true;

  final text = _serviceSearchText(service);
  return text.contains('business') ||
      text.contains('company registration') ||
      text.contains('sole proprietor');
}

String _detailLabel(String key) {
  switch (key) {
    case 'ntn_cnic':
      return 'CNIC';
    case 'occupation':
      return 'Occupation';
    case 'source_of_income':
      return 'Income source';
    case 'iris_income_source':
      return 'IRIS income';
    case 'gst_business_type':
      return 'Business type';
    case 'gst_business_nature':
      return 'Business nature';
    case 'consumer_number':
      return 'Consumer no.';
    case 'business_option':
      return 'Business option';
    case 'business_context':
      return 'Business context';
    default:
      return key;
  }
}

List<String> _wizardDocumentsFor(ServiceItem service) {
  final documents = <String>[
    ...service.requiredDocuments,
    ..._extraWizardDocumentsFor(service),
  ];

  final seen = <String>{};
  return documents
      .where((document) {
        final normalized = document.trim();
        if (normalized.isEmpty) return false;

        final key = normalized.toLowerCase();
        if (seen.contains(key)) return false;

        seen.add(key);
        return true;
      })
      .toList(growable: false);
}

List<String> _extraWizardDocumentsFor(ServiceItem service) {
  if (_isNtnService(service)) {
    return const [
      'Clear CNIC front image',
      'Clear CNIC back image',
      'Residential address details',
      'Occupation / income source details',
    ];
  }

  if (_isIrisService(service)) {
    return const [
      'CNIC front and back',
      'Current IRIS login details if available',
      'Income source proof if available',
      'Updated contact details',
    ];
  }

  if (_isGstService(service)) {
    return const [
      'CNIC front and back',
      'NTN certificate if available',
      'Utility bill with consumer number',
      'Business address proof',
      'Bank account proof',
    ];
  }

  if (_isBusinessService(service)) {
    return const [
      'Owner / partner / director CNIC copies',
      'Proposed business names',
      'Business address proof',
      'Business nature details',
      'Authorization documents if required',
    ];
  }

  return const [];
}

class _DocumentHintCard extends StatelessWidget {
  const _DocumentHintCard({
    required this.service,
    required this.attachments,
    required this.isPickingDocuments,
    required this.onPickDocuments,
    required this.onRemoveDocument,
    required this.formatFileSize,
  });

  final ServiceItem service;
  final List<DocumentAttachment> attachments;
  final bool isPickingDocuments;
  final VoidCallback onPickDocuments;
  final ValueChanged<DocumentAttachment> onRemoveDocument;
  final String Function(int bytes) formatFileSize;

  @override
  Widget build(BuildContext context) {
    final documents = _wizardDocumentsFor(service);
    final visibleDocuments = documents.take(6).toList();
    final remainingCount = documents.length - visibleDocuments.length;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required documents',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            documents.isEmpty
                ? 'Attach any helpful files for OMC review.'
                : 'Attach at least one relevant file now. ERP upload starts after the request is created.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (visibleDocuments.isEmpty)
            const Text(
              'OMC will confirm documents after reviewing your draft.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            for (final document in visibleDocuments)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _RequirementRow(label: document),
              ),
            if (remainingCount > 0)
              Text(
                '+$remainingCount more on the detail page',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: attachments.isEmpty ? 'Attach documents' : 'Add more files',
            icon: Icons.attach_file_rounded,
            isLoading: isPickingDocuments,
            onPressed: isPickingDocuments ? null : onPickDocuments,
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AttachedDocumentTile(
                  attachment: attachment,
                  sizeLabel: formatFileSize(attachment.sizeInBytes),
                  onRemove: () => onRemoveDocument(attachment),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.service,
    required this.fullNameController,
    required this.phoneController,
    required this.emailController,
    required this.taxIdController,
    required this.selectedCustomer,
    required this.remarksController,
    required this.additionalDetails,
    required this.attachments,
    required this.formatFileSize,
  });

  final ServiceItem service;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final CustomerItem? selectedCustomer;
  final TextEditingController remarksController;
  final Map<String, String> additionalDetails;
  final List<DocumentAttachment> attachments;
  final String Function(int bytes) formatFileSize;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review before submit',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirm these details before sending the request to OMC.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _ReviewRow(label: 'Service', value: service.title),
          _ReviewRow(label: 'Category', value: service.category),
          _ReviewRow(label: 'Name', value: fullNameController.text),
          _ReviewRow(label: 'Phone', value: phoneController.text),
          _ReviewRow(label: 'Email', value: emailController.text),
          if (selectedCustomer != null)
            _ReviewRow(label: 'Customer', value: selectedCustomer!.name),
          if (taxIdController.text.trim().isNotEmpty)
            _ReviewRow(label: 'CNIC / NTN', value: taxIdController.text),
          for (final detail in _orderedDetails(additionalDetails))
            _ReviewRow(label: _detailLabel(detail.key), value: detail.value),
          if (remarksController.text.trim().isNotEmpty)
            _ReviewRow(label: 'Remarks', value: remarksController.text),
          const Divider(height: 22),
          Text(
            attachments.isEmpty
                ? 'No documents attached yet.'
                : '${attachments.length} document(s) attached',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final attachment in attachments.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${attachment.name} • ${formatFileSize(attachment.sizeInBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (attachments.length > 3)
              Text(
                '+${attachments.length - 3} more',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _orderedDetails(Map<String, String> details) {
  const preferredOrder = [
    'ntn_cnic',
    'occupation',
    'source_of_income',
    'iris_income_source',
    'gst_business_type',
    'gst_business_nature',
    'consumer_number',
    'business_option',
    'business_context',
  ];

  final ordered = <MapEntry<String, String>>[];

  for (final key in preferredOrder) {
    final value = details[key];
    if (value != null && value.trim().isNotEmpty) {
      ordered.add(MapEntry(key, value));
    }
  }

  for (final detail in details.entries) {
    final value = detail.value.trim();
    if (preferredOrder.contains(detail.key) || value.isEmpty) continue;

    ordered.add(MapEntry(detail.key, value));
  }

  return ordered;
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? 'Not added yet' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              safeValue,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedDocumentTile extends StatelessWidget {
  const _AttachedDocumentTile({
    required this.attachment,
    required this.sizeLabel,
    required this.onRemove,
  });

  final DocumentAttachment attachment;
  final String sizeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppTheme.primaryRed,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sizeLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove document',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppTheme.primaryRed,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardFoundationCard extends StatelessWidget {
  const _WizardFoundationCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final blueprint = _WizardBlueprint.fromService(service);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(blueprint.icon, color: AppTheme.primaryRed),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blueprint.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      blueprint.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final step in blueprint.steps) ...[
            _WizardStepRow(label: step),
            if (step != blueprint.steps.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Text(
            'This guided flow collects service-specific details, documents and review data for secure submission.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardStepRow extends StatelessWidget {
  const _WizardStepRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppTheme.primaryRed,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardBlueprint {
  const _WizardBlueprint({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> steps;

  factory _WizardBlueprint.fromService(ServiceItem service) {
    final text = '${service.id} ${service.title} ${service.category}'
        .toLowerCase();

    if (text.contains('ntn')) {
      return const _WizardBlueprint(
        title: 'NTN registration wizard',
        subtitle:
            'Guided flow for personal details, CNIC/NTN data, documents and review.',
        icon: Icons.badge_outlined,
        steps: [
          'Confirm personal and contact details',
          'Add CNIC / NTN information',
          'Attach required identity documents',
          'Review and submit to OMC',
        ],
      );
    }

    if (text.contains('iris')) {
      return const _WizardBlueprint(
        title: 'IRIS profile wizard',
        subtitle:
            'Guided flow for profile update requests and income-source context.',
        icon: Icons.account_tree_outlined,
        steps: [
          'Confirm personal and login/profile details',
          'Select income-source update context',
          'Attach supporting documents',
          'Review and submit to OMC',
        ],
      );
    }

    if (text.contains('gst') || text.contains('sales tax')) {
      return const _WizardBlueprint(
        title: 'GST registration wizard',
        subtitle:
            'Guided flow for business information, tax details, documents and review.',
        icon: Icons.storefront_outlined,
        steps: [
          'Confirm business and owner details',
          'Add activity and address information',
          'Attach utility, bank and business proof',
          'Review and submit to OMC',
        ],
      );
    }

    if (text.contains('business') ||
        text.contains('incorporation') ||
        text.contains('company') ||
        text.contains('aop') ||
        text.contains('sole')) {
      return const _WizardBlueprint(
        title: 'Business service wizard',
        subtitle:
            'Guided flow for business setup, incorporation or NTN business changes.',
        icon: Icons.business_center_outlined,
        steps: [
          'Select business service context',
          'Confirm owner / partner information',
          'Attach business supporting documents',
          'Review and submit to OMC',
        ],
      );
    }

    return const _WizardBlueprint(
      title: 'Service request wizard',
      subtitle:
          'Guided request flow with contact details, documents, review and secure submission.',
      icon: Icons.assignment_outlined,
      steps: [
        'Confirm contact details',
        'Attach required documents',
        'Review request summary',
        'Submit to OMC',
      ],
    );
  }
}

String _serviceRequestDraftErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Service request form is unavailable right now. Please try again.';
}
