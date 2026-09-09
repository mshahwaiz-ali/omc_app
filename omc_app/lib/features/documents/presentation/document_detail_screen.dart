import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/mutation_invalidation.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../application/document_attachment_controller.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';
import 'widgets/document_action_card.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({
    required this.documentId,
    this.assisted = false,
    this.customerName,
    super.key,
  });

  final String documentId;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = assisted
        ? ref.watch(assistedDocumentDetailProvider(documentId))
        : ref.watch(documentDetailProvider(documentId));
    final assistedCustomer = customerName?.trim();

    return Scaffold(
      appBar: AppBackHeader(
        title: 'Document details',
        subtitle:
            assisted && assistedCustomer != null && assistedCustomer.isNotEmpty
            ? assistedCustomer
            : null,
      ),
      body: documentAsync.when(
        data: (document) {
          if (document == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppEmptyState(
                icon: Icons.description_outlined,
                title: 'Document unavailable',
                message:
                    'This document may have been removed or is no longer available.',
              ),
            );
          }

          return _DocumentDetailBody(
            document: document,
            customerName: assisted ? assistedCustomer : null,
          );
        },
        loading: () => const _DetailLoadingView(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: AppErrorState.fromError(
            error: error,
            fallbackTitle: 'Document unavailable',
            fallbackMessage:
                'Document details could not be loaded right now. Please try again.',
            onRetry: () => assisted
                ? ref.invalidate(assistedDocumentDetailProvider(documentId))
                : ref.invalidate(documentDetailProvider(documentId)),
          ),
        ),
      ),
    );
  }
}

class _DetailLoadingView extends StatelessWidget {
  const _DetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox.square(
                dimension: 48,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loading document',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fetching file status, remarks and linked service details.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentHeroCard extends StatelessWidget {
  const _DocumentHeroCard({
    required this.document,
    this.customerName,
  });

  final DocumentItem document;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final statusColor = _documentStatusColor(document.status);
    final subtitle = (document.subtitle ?? document.fileName)?.trim();
    final rejectionNote = document.status == DocumentStatus.rejected
        ? document.remarks?.trim()
        : null;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(
                  _documentStatusIcon(document.status),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: 'Status: ${document.status.label}',
                      child: Text(
                        document.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        document.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 21,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (customerName?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            _ContextLine(
              icon: Icons.person_outline_rounded,
              text: 'Customer: ${customerName!}',
            ),
          ],
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (rejectionNote != null && rejectionNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Correction required',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rejectionNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  const _ContextLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentInfoCard extends StatelessWidget {
  const _DocumentInfoCard({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Semantics(
            header: true,
            child: Text(
              'Document information',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DocumentInfoRow(label: 'File', value: document.fileName ?? '-'),
          _DocumentInfoRow(
            label: 'Service',
            value: document.serviceReference ?? '-',
          ),
          _DocumentInfoRow(
            label: 'Updated',
            value: document.updatedAtLabel ?? '-',
          ),
          if (document.status != DocumentStatus.rejected)
            _DocumentInfoRow(label: 'Remarks', value: document.remarks ?? '-'),
          _DocumentInfoRow(
            label: 'File access',
            value: document.fileUrl == null ? 'Not available' : 'Available',
          ),
        ],
      ),
    );
  }
}

class _DocumentInfoRow extends StatelessWidget {
  const _DocumentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;

          final labelText = Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
          final valueText = Text(
            cleanValue,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelText,
                const SizedBox(height: 4),
                valueText,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: labelText),
              const SizedBox(width: 12),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

Color _documentStatusColor(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return AppTheme.success;
    case DocumentStatus.rejected:
    case DocumentStatus.missing:
      return AppTheme.danger;
    case DocumentStatus.pendingReview:
      return AppTheme.warning;
    case DocumentStatus.uploaded:
      return AppTheme.info;
  }
}

IconData _documentStatusIcon(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return Icons.verified_rounded;
    case DocumentStatus.rejected:
      return Icons.error_outline_rounded;
    case DocumentStatus.missing:
      return Icons.upload_file_rounded;
    case DocumentStatus.pendingReview:
      return Icons.hourglass_top_rounded;
    case DocumentStatus.uploaded:
      return Icons.description_outlined;
  }
}

class _DocumentDetailBody extends ConsumerStatefulWidget {
  const _DocumentDetailBody({
    required this.document,
    this.customerName,
  });

  final DocumentItem document;
  final String? customerName;

  @override
  ConsumerState<_DocumentDetailBody> createState() =>
      _DocumentDetailBodyState();
}

class _DocumentDetailBodyState extends ConsumerState<_DocumentDetailBody> {
  bool _isUploading = false;

  DocumentItem get document => widget.document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _DocumentHeroCard(
          document: document,
          customerName: widget.customerName,
        ),
        const SizedBox(height: 12),
        DocumentActionCard(
          document: document,
          onPreview: () => _openDocumentUrl(
            context,
            document.previewUrl ?? document.fileUrl,
            fallbackMessage:
                'Document preview link is not available for this record.',
          ),
          isUploading: _isUploading,
          onUpload: _isUploading ? null : () => _pickAndStageUpload(context),
          onDownload: () => _openDocumentUrl(
            context,
            document.downloadUrl ?? document.fileUrl,
            fallbackMessage:
                'Document download link is not available for this record.',
          ),
        ),
        const SizedBox(height: 12),
        _DocumentInfoCard(document: document),
        const SizedBox(height: 14),
        SelectableText(
          'Document ID: ${document.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndStageUpload(BuildContext context) async {
    if (_isUploading) return;

    final controller = ref.read(documentAttachmentControllerProvider);
    final result = await controller.pickDocuments();

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    for (final message in result.rejectedMessages) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    if (!result.hasAcceptedFiles) {
      return;
    }

    final repository = ref.read(documentsRepositoryProvider);

    setState(() => _isUploading = true);

    try {
      final serviceRequestId = document.serviceReference?.trim();

      if (serviceRequestId == null || serviceRequestId.isEmpty) {
        throw const ApiError(
          message:
              'This document is not linked to a service request, so upload cannot continue.',
        );
      }

      final uploadedFiles = await repository.uploadDocumentAttachments(
        serviceRequestId: serviceRequestId,
        attachments: result.accepted,
      );

      if (!context.mounted) return;

      final uploadedCount = uploadedFiles.length;
      final skippedCount = result.accepted.length - uploadedCount;
      final message = skippedCount > 0
          ? 'Uploaded $uploadedCount document(s). $skippedCount file(s) were skipped because their local path was unavailable.'
          : 'Uploaded $uploadedCount document(s).';

      messenger.showSnackBar(SnackBar(content: Text(message)));

      invalidateDocumentMutation(
        ref,
        documentId: document.id,
        caseId: serviceRequestId,
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Document upload failed',
        fallbackMessage:
            'Document upload could not be completed right now. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openDocumentUrl(
    BuildContext context,
    String? url, {
    required String fallbackMessage,
  }) async {
    final cleanUrl = url?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      _showSnack(context, fallbackMessage);
      return;
    }

    final uri = _documentUri(cleanUrl);
    if (uri == null) {
      _showSnack(context, 'Invalid document link received.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;

      if (!opened) {
        _showSnack(context, 'Document link could not be opened right now.');
      }
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Document link unavailable',
        fallbackMessage: 'Document link could not be opened right now.',
      );
      _showSnack(context, failure.message);
    }
  }

  Uri? _documentUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return _isAllowedWebScheme(uri.scheme) ? uri : null;
    }

    if (!url.startsWith('/')) {
      return null;
    }

    final baseUri = Uri.tryParse(ApiConfig.baseUrl);
    if (baseUri == null || !baseUri.hasScheme) {
      return null;
    }

    return baseUri.resolve(url);
  }

  bool _isAllowedWebScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'https' || normalized == 'http';
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
