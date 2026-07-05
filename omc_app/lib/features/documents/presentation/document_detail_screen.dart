import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../application/document_attachment_controller.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';
import 'widgets/document_action_card.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(documentDetailProvider(documentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Document Details')),
      body: documentAsync.when(
        data: (document) {
          if (document == null) {
            return PremiumEmptyState(
              icon: Icons.description_rounded,
              title: 'Document detail unavailable',
              message:
                  'Document $documentId is ready for the backend detail endpoint. File status, remarks, and service links will appear once data is available.',
            );
          }

          return _DocumentDetailBody(document: document);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load document',
          message: _cleanError(error),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Document details could not be loaded right now. Please try again.';
  }
  return message;
}

class _DocumentDetailBody extends ConsumerStatefulWidget {
  const _DocumentDetailBody({required this.document});

  final DocumentItem document;

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
      padding: const EdgeInsets.all(20),
      children: [
        CrmDetailHeaderCard(
          icon: Icons.description_rounded,
          title: document.title,
          subtitle: document.subtitle ?? document.fileName ?? 'Document record',
          statusLabel: document.status.label,
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Document',
          rows: [
            CrmInfoRow(label: 'File', value: document.fileName ?? '-'),
            CrmInfoRow(
              label: 'File Link',
              value: document.fileUrl == null ? '-' : 'Available',
            ),
            CrmInfoRow(
              label: 'Service',
              value: document.serviceReference ?? '-',
            ),
            CrmInfoRow(label: 'Updated', value: document.updatedAtLabel ?? '-'),
            CrmInfoRow(label: 'Remarks', value: document.remarks ?? '-'),
          ],
        ),
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Document timeline',
          emptyMessage:
              'No document timeline yet. Uploads, review updates, approvals, and rejection notes will appear here once backend activity data is available.',
        ),
        const SizedBox(height: 16),
        DocumentActionCard(
          document: document,
          onPreview: () => _openDocumentUrl(
            context,
            document.previewUrl ?? document.fileUrl,
            fallbackMessage: 'Document preview URL is not available yet.',
          ),
          isUploading: _isUploading,
          onUpload: _isUploading ? null : () => _pickAndStageUpload(context),
          onDownload: () => _openDocumentUrl(
            context,
            document.downloadUrl ?? document.fileUrl,
            fallbackMessage: 'Document download URL is not available yet.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Document ID: ${document.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndStageUpload(BuildContext context) async {
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
      final uploadedFiles = await repository.uploadDocumentAttachments(
        documentId: document.id,
        attachments: result.accepted,
      );

      if (!context.mounted) return;

      final uploadedCount = uploadedFiles.length;
      final skippedCount = result.accepted.length - uploadedCount;
      final message = skippedCount > 0
          ? 'Uploaded $uploadedCount document(s). $skippedCount file(s) were skipped because their local path was unavailable.'
          : 'Uploaded $uploadedCount document(s).';

      messenger.showSnackBar(SnackBar(content: Text(message)));

      ref.invalidate(documentDetailProvider(document.id));
      ref.invalidate(documentsProvider);
    } on ApiError catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to upload document right now. Please try again.',
          ),
        ),
      );
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
      _showSnack(context, 'Invalid document URL received from backend.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    if (!opened) {
      _showSnack(context, 'Unable to open document link right now.');
    }
  }

  Uri? _documentUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return uri;
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
