import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
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
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  color: AppTheme.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Documents unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
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
    final sections = _documentSections(documents);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _DocumentsHeader(documents: documents),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          _DocumentSection(section: section),
          if (section != sections.last) const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<_DocumentSectionData> _documentSections(List<DocumentItem> documents) {
    final missing = documents
        .where(
          (item) =>
              item.status == DocumentStatus.missing ||
              item.status == DocumentStatus.rejected,
        )
        .toList(growable: false);
    final submitted = documents
        .where(
          (item) =>
              item.status == DocumentStatus.uploaded ||
              item.status == DocumentStatus.pendingReview,
        )
        .toList(growable: false);
    final approved = documents
        .where((item) => item.status == DocumentStatus.approved)
        .toList(growable: false);

    return [
      if (missing.isNotEmpty)
        _DocumentSectionData(
          title: 'Action needed',
          subtitle: 'Missing or rejected documents to upload again.',
          icon: Icons.priority_high_rounded,
          documents: missing,
        ),
      if (submitted.isNotEmpty)
        _DocumentSectionData(
          title: 'Submitted',
          subtitle: 'Uploaded documents waiting for OMC review.',
          icon: Icons.upload_file_rounded,
          documents: submitted,
        ),
      if (approved.isNotEmpty)
        _DocumentSectionData(
          title: 'Approved',
          subtitle: 'Documents verified by OMC.',
          icon: Icons.verified_rounded,
          documents: approved,
        ),
    ];
  }
}

class _DocumentSectionData {
  const _DocumentSectionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.documents,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<DocumentItem> documents;
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.section});

  final _DocumentSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(section.icon, color: AppTheme.primaryRed, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PremiumInfoChip(label: section.documents.length.toString()),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < section.documents.length; index++) ...[
          _DocumentCard(document: section.documents[index]),
          if (index != section.documents.length - 1) const SizedBox(height: 10),
        ],
      ],
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
        PremiumListHeader(
          icon: Icons.folder_copy_outlined,
          title: 'Documents',
          subtitle:
              'Track required, submitted and reviewed documents for OMC services.',
          metaLabel: '${documents.length} total',
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
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
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
                border: Border.all(color: statusColor.withValues(alpha: 0.10)),
              ),
              child: Icon(
                _statusIcon(document.status),
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (document.subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      document.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                      PremiumInfoChip(
                        label: document.status.label,
                        color: statusColor,
                      ),
                      if (document.serviceReference != null)
                        PremiumInfoChip(label: document.serviceReference!),
                      if (document.updatedAtLabel != null)
                        PremiumInfoChip(label: document.updatedAtLabel!),
                    ],
                  ),
                  if (document.fileName != null ||
                      document.fileUrl != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      document.fileName ?? 'File link available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (document.remarks != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        document.status == DocumentStatus.rejected
                            ? 'Rejected: ${document.remarks!}'
                            : document.remarks!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: document.status == DocumentStatus.rejected
                              ? Colors.red.shade800
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
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
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Required and submitted documents will appear here when records are available.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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

class _DocumentsLoadingRow extends StatelessWidget {
  const _DocumentsLoadingRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DocumentsLoadingBlock(width: 48, height: 48, radius: 16, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentsLoadingBlock(
                width: double.infinity,
                height: 14,
                radius: 999,
                color: color,
              ),
              const SizedBox(height: 10),
              _DocumentsLoadingBlock(
                width: 170,
                height: 11,
                radius: 999,
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentsLoadingBlock extends StatelessWidget {
  const _DocumentsLoadingBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
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

        return PremiumCard(
          padding: const EdgeInsets.all(18),
          child: _DocumentsLoadingRow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: 4,
    );
  }
}
