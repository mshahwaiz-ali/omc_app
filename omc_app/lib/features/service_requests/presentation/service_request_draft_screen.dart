import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../service_catalogue/application/service_catalogue_controller.dart';
import '../../service_catalogue/data/service_item.dart';

import '../../../core/network/api_error.dart';
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
      _remarksController,
    ]) {
      controller.removeListener(_refreshReviewSummary);
    }

    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxIdController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _prefillEmail();

    final servicesAsync = ref.watch(serviceCatalogueProvider);

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
          message: error.toString(),
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
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
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
                    remarksController: _remarksController,
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
          content: Text('Unable to open the document picker right now.'),
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
        final result = await ref
            .read(serviceRequestRepositoryProvider)
            .createServiceRequest(
              ServiceRequestPayload(
                service: service,
                fullName: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                email: _emailController.text.trim(),
                taxId: _taxIdController.text.trim(),
                remarks: _remarksController.text.trim(),
                attachments: List<DocumentAttachment>.unmodifiable(_attachments),
              ),
            );

        if (!mounted) return;

        final requestId = result.requestId;
        var uploadedCount = 0;

        if (requestId != null &&
            requestId.isNotEmpty &&
            _attachments.isNotEmpty) {
          final uploadedFiles = await ref
              .read(serviceRequestRepositoryProvider)
              .uploadRequestAttachments(
                requestId: requestId,
                attachments: _attachments,
              );

          uploadedCount = uploadedFiles.length;
        }

        if (!mounted) return;

        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Request submitted'),
              content: Text(
                requestId == null
                    ? 'Your service request has been submitted successfully. OMC will confirm the reference and documents shortly.'
                    : 'Your service request has been submitted successfully. Reference: $requestId. Uploaded $uploadedCount attachment(s).',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        Navigator.of(context).pop();
      } on ApiError catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to submit request right now. Please try again.'),
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
    final visibleDocuments = service.requiredDocuments.take(4).toList();
    final remainingCount =
        service.requiredDocuments.length - visibleDocuments.length;

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
            service.requiredDocuments.isEmpty
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
                padding: const EdgeInsets.only(bottom: 8),
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
    required this.remarksController,
    required this.attachments,
    required this.formatFileSize,
  });

  final ServiceItem service;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final TextEditingController remarksController;
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
          if (taxIdController.text.trim().isNotEmpty)
            _ReviewRow(label: 'CNIC / NTN', value: taxIdController.text),
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
