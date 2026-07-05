import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        error: (_, _) => PremiumEmptyState(
          icon: Icons.description_rounded,
          title: 'Document detail unavailable',
          message:
              'Document $documentId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
}

class _DocumentDetailBody extends ConsumerWidget {
  const _DocumentDetailBody({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onPreview: () => _showBackendPendingSnack(
            context,
            'Document preview endpoint is not connected yet.',
          ),
          onUpload: () => _pickAndStageUpload(context, ref),
          onDownload: () => _showBackendPendingSnack(
            context,
            'Document download endpoint is not connected yet.',
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

  Future<void> _pickAndStageUpload(BuildContext context, WidgetRef ref) async {
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

    final count = result.accepted.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$count file${count == 1 ? '' : 's'} selected. Backend upload endpoint is not connected yet.',
        ),
      ),
    );
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
