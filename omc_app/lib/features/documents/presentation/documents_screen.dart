import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(documentsProvider);
            await ref.read(documentsProvider.future);
          },
          child: documentsAsync.when(
            data: (documents) => documents.isEmpty
                ? const _EmptyDocumentsView()
                : _DocumentsList(documents: documents),
            loading: () => const _DocumentsLoadingView(),
            error: (error, _) =>
                _DocumentsErrorView(message: _documentsErrorMessage(error)),
          ),
        ),
      ),
    );
  }
}

class _DocumentsErrorView extends StatelessWidget {
  const _DocumentsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppTheme.primaryRed,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Documents unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _documentsErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Document records are unavailable right now. Please try again.';
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.documents});

  final List<DocumentItem> documents;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: documents.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _DocumentsHeader(documents: documents);

        return _DocumentCard(document: documents[index - 1]);
      },
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({required this.documents});

  final List<DocumentItem> documents;

  @override
  Widget build(BuildContext context) {
    final missingCount = documents
        .where((item) => item.status == DocumentStatus.missing)
        .length;
    final approvedCount = documents
        .where((item) => item.status == DocumentStatus.approved)
        .length;
    final reviewCount = documents
        .where((item) => item.status == DocumentStatus.pendingReview)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your document vault',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Track required, submitted and reviewed documents for OMC services.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.folder_copy_outlined,
                  label: 'Total',
                  value: documents.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.upload_file_rounded,
                  label: 'Missing',
                  value: missingCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Review',
                  value: reviewCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.verified_rounded,
                  label: 'Approved',
                  value: approvedCount.toString(),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 20),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(document.status);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () =>
          context.push('/documents/${Uri.encodeComponent(document.id)}'),
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_statusIcon(document.status), color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (document.subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      document.subtitle!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: document.status.label,
                        color: statusColor,
                      ),
                      if (document.serviceReference != null)
                        _InfoChip(label: document.serviceReference!),
                      if (document.updatedAtLabel != null)
                        _InfoChip(label: document.updatedAtLabel!),
                    ],
                  ),
                  if (document.fileName != null ||
                      document.fileUrl != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      document.fileName ?? 'File link available',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (document.remarks != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      document.remarks!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return Colors.green.shade700;
      case DocumentStatus.rejected:
      case DocumentStatus.missing:
        return Colors.red.shade700;
      case DocumentStatus.pendingReview:
        return Colors.orange.shade800;
      case DocumentStatus.uploaded:
        return AppTheme.primaryRed;
    }
  }

  IconData _statusIcon(DocumentStatus status) {
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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color = AppTheme.primaryRed});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyDocumentsView extends StatelessWidget {
  const _EmptyDocumentsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const _DocumentsHeader(documents: []),
        const SizedBox(height: 24),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: AppTheme.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No documents yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Required and submitted documents will appear here when records are available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
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

class _DocumentsLoadingView extends StatelessWidget {
  const _DocumentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemBuilder: (context, index) {
        if (index == 0) return const _DocumentsHeader(documents: []);

        return const PremiumCard(
          padding: EdgeInsets.all(18),
          child: SizedBox(height: 72),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: 4,
    );
  }
}
