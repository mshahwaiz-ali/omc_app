import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_empty_state.dart';
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
      appBar: const AppBackHeader(title: 'Document Details'),
      body: documentAsync.when(
        data: (document) {
          if (document == null) {
            return PremiumEmptyState(
              icon: Icons.description_rounded,
              title: 'Document details unavailable',
              message:
                  'Document $documentId could not be loaded right now. File status, remarks, and service links will appear when data is available.',
            );
          }

          return _DocumentDetailBody(document: document);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Document unavailable',
          message: _cleanError(error),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Document details could not be loaded right now. Please try again.';
  }
  return message;
}

class _DocumentHeroCard extends StatelessWidget {
  const _DocumentHeroCard({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    final statusColor = _documentStatusColor(document.status);

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.description_rounded, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              document.status.label,
              style: TextStyle(
                color: statusColor == AppTheme.primaryRed
                    ? Colors.white70
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              document.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ((document.subtitle ?? document.fileName)?.trim().isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              Text(
                document.subtitle ?? document.fileName!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentQuickStats extends StatelessWidget {
  const _DocumentQuickStats({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DocumentStatTile(
            icon: _documentStatusIcon(document.status),
            label: 'Status',
            value: document.status.label,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DocumentStatTile(
            icon: Icons.link_rounded,
            label: 'File link',
            value: document.fileUrl == null ? 'No' : 'Yes',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DocumentStatTile(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: document.updatedAtLabel ?? '-',
          ),
        ),
      ],
    );
  }
}

class _DocumentStatTile extends StatelessWidget {
  const _DocumentStatTile({
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
            value.trim().isEmpty ? '-' : value.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
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

class _DocumentInfoCard extends StatelessWidget {
  const _DocumentInfoCard({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document information',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _DocumentInfoRow(label: 'File', value: document.fileName ?? '-'),
          _DocumentInfoRow(
            label: 'File link',
            value: document.fileUrl == null ? '-' : 'Available',
          ),
          _DocumentInfoRow(
            label: 'Service',
            value: document.serviceReference ?? '-',
          ),
          _DocumentInfoRow(
            label: 'Updated',
            value: document.updatedAtLabel ?? '-',
          ),
          _DocumentInfoRow(label: 'Remarks', value: document.remarks ?? '-'),
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
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
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
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTimelinePlaceholder extends StatelessWidget {
  const _DocumentTimelinePlaceholder();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document timeline',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Uploads, review updates, approvals and rejection notes will appear here when activity data is available.',
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
    );
  }
}

Color _documentStatusColor(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return const Color(0xFF18864B);
    case DocumentStatus.rejected:
    case DocumentStatus.missing:
      return const Color(0xFFC62828);
    case DocumentStatus.pendingReview:
      return const Color(0xFFB25E00);
    case DocumentStatus.uploaded:
      return AppTheme.primaryRed;
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
      return Icons.description_rounded;
  }
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
        _DocumentHeroCard(document: document),
        const SizedBox(height: 16),
        _DocumentQuickStats(document: document),
        const SizedBox(height: 16),
        _DocumentInfoCard(document: document),
        const SizedBox(height: 16),
        const _DocumentTimelinePlaceholder(),
        const SizedBox(height: 16),
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
            'Document upload could not be completed right now. Please try again.',
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
      _showSnack(context, 'Invalid document link received.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    if (!opened) {
      _showSnack(context, 'Document link could not be opened right now.');
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
