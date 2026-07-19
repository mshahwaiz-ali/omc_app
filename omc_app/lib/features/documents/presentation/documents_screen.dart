import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
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
            error: (error, _) => _DocumentsErrorView(
              error: error,
              onRetry: () => ref.invalidate(documentsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DocumentFilter {
  active('Active'),
  needsAction('Needs Action'),
  approved('Approved'),
  archived('Archived');

  const _DocumentFilter(this.label);

  final String label;
}

class _DocumentsList extends StatefulWidget {
  const _DocumentsList({required this.documents});

  final List<DocumentItem> documents;

  @override
  State<_DocumentsList> createState() => _DocumentsListState();
}

class _DocumentsListState extends State<_DocumentsList> {
  _DocumentFilter _selectedFilter = _DocumentFilter.active;

  @override
  Widget build(BuildContext context) {
    final filteredDocuments = _filteredDocuments(widget.documents);
    final sections = _documentSections(filteredDocuments);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _DocumentsHeader(documents: widget.documents),
        const SizedBox(height: 12),
        _DocumentFilterBar(
          documents: widget.documents,
          selectedFilter: _selectedFilter,
          onSelected: (filter) => setState(() => _selectedFilter = filter),
        ),
        const SizedBox(height: 16),
        if (filteredDocuments.isEmpty)
          _DocumentsFilteredEmptyState(filter: _selectedFilter)
        else
          for (final section in sections) ...[
            _DocumentSection(section: section),
            if (section != sections.last) const SizedBox(height: 16),
          ],
      ],
    );
  }

  List<DocumentItem> _filteredDocuments(List<DocumentItem> documents) {
    switch (_selectedFilter) {
      case _DocumentFilter.active:
        return documents.where((item) => item.isActive).toList(growable: false);
      case _DocumentFilter.needsAction:
        return documents
            .where((item) => item.requiresAction)
            .toList(growable: false);
      case _DocumentFilter.approved:
        return documents
            .where((item) => item.isApproved)
            .toList(growable: false);
      case _DocumentFilter.archived:
        return documents
            .where((item) => item.isArchived)
            .toList(growable: false);
    }
  }

  List<_DocumentSectionData> _documentSections(List<DocumentItem> documents) {
    final actionNeeded = documents
        .where((item) => item.requiresAction)
        .toList(growable: false);
    final submitted = documents
        .where((item) => item.isUnderReview)
        .toList(growable: false);
    final approved = documents
        .where((item) => item.isApproved)
        .toList(growable: false);
    final archived = documents
        .where((item) => item.isArchived)
        .toList(growable: false);

    return [
      if (actionNeeded.isNotEmpty)
        _DocumentSectionData(
          title: 'Action needed',
          subtitle: 'Missing or rejected documents to upload again.',
          icon: Icons.priority_high_rounded,
          documents: actionNeeded,
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
          subtitle: 'Documents verified by OMC for active services.',
          icon: Icons.verified_rounded,
          documents: approved,
        ),
      if (archived.isNotEmpty)
        _DocumentSectionData(
          title: 'Archived',
          subtitle: 'Documents from completed or cancelled services.',
          icon: Icons.archive_rounded,
          documents: archived,
        ),
    ];
  }
}

class _DocumentFilterBar extends StatelessWidget {
  const _DocumentFilterBar({
    required this.documents,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<DocumentItem> documents;
  final _DocumentFilter selectedFilter;
  final ValueChanged<_DocumentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Documents',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_countFor(selectedFilter)} shown',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final filter in _DocumentFilter.values) ...[
                  _DocumentFilterChip(
                    label: filter.label,
                    count: _countFor(filter),
                    selected: selectedFilter == filter,
                    onTap: () => onSelected(filter),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countFor(_DocumentFilter filter) {
    switch (filter) {
      case _DocumentFilter.active:
        return documents.where((item) => item.isActive).length;
      case _DocumentFilter.needsAction:
        return documents.where((item) => item.requiresAction).length;
      case _DocumentFilter.approved:
        return documents.where((item) => item.isApproved).length;
      case _DocumentFilter.archived:
        return documents.where((item) => item.isArchived).length;
    }
  }
}

class _DocumentFilterChip extends StatelessWidget {
  const _DocumentFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label $count'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: OmcPremium.documents.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? OmcPremium.documents.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.08),
      ),
      labelStyle: TextStyle(
        color: selected ? OmcPremium.documents : AppTheme.textSecondary,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );
  }
}

class _DocumentsFilteredEmptyState extends StatelessWidget {
  const _DocumentsFilteredEmptyState({required this.filter});

  final _DocumentFilter filter;

  @override
  Widget build(BuildContext context) {
    final isArchived = filter == _DocumentFilter.archived;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            isArchived ? Icons.archive_outlined : Icons.filter_alt_off_rounded,
            color: OmcPremium.documents,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            isArchived
                ? 'No archived documents'
                : 'No ${filter.label.toLowerCase()} documents',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArchived
                ? 'Completed and cancelled service documents will appear here.'
                : 'Try another document filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
                color: OmcPremium.documents.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(section.icon, color: OmcPremium.documents, size: 18),
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
    final activeCount = documents.where((item) => item.isActive).length;
    final actionCount = documents.where((item) => item.requiresAction).length;
    final approvedCount = documents.where((item) => item.isApproved).length;
    final archivedCount = documents.where((item) => item.isArchived).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.folder_copy_outlined,
          title: 'My Documents',
          subtitle:
              'Active service documents stay visible. Completed service documents move to archive.',
          metaLabel: '$activeCount active',
        ),
        if (documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.folder_copy_outlined,
                  label: 'Active',
                  value: activeCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.priority_high_rounded,
                  label: 'Action',
                  value: actionCount.toString(),
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
              const SizedBox(width: 10),
              Expanded(
                child: _DocumentStatTile(
                  icon: Icons.archive_rounded,
                  label: 'Archive',
                  value: archivedCount.toString(),
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
              color: OmcPremium.documents.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: OmcPremium.documents.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(icon, color: OmcPremium.documents, size: 17),
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
    final statusColor = _statusColor(document);

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
              child: Icon(_statusIcon(document), color: statusColor, size: 22),
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
                        label: document.statusLabel,
                        color: statusColor,
                      ),
                      if (document.serviceStatus != null)
                        PremiumInfoChip(label: document.serviceStatus!),
                      if (document.updatedAtLabel != null)
                        PremiumInfoChip(
                          label: 'Uploaded ${document.updatedAtLabel!}',
                        ),
                      if (document.archivedOnLabel != null)
                        PremiumInfoChip(
                          label: 'Archived ${document.archivedOnLabel!}',
                        ),
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
                              ? OmcPremium.danger
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

  Color _statusColor(DocumentItem document) {
    if (document.isArchived) return OmcPremium.system;

    switch (document.status) {
      case DocumentStatus.approved:
        return OmcPremium.success;
      case DocumentStatus.rejected:
      case DocumentStatus.missing:
        return OmcPremium.danger;
      case DocumentStatus.pendingReview:
        return OmcPremium.action;
      case DocumentStatus.uploaded:
        return OmcPremium.review;
    }
  }

  IconData _statusIcon(DocumentItem document) {
    if (document.isArchived) return Icons.archive_rounded;

    switch (document.status) {
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
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
                  color: OmcPremium.documents.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: OmcPremium.documents.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: OmcPremium.documents,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No active documents yet',
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
                'Required and submitted documents will appear here when active service records are available.',
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

class _DocumentsErrorView extends StatelessWidget {
  const _DocumentsErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        const _DocumentsHeader(documents: []),
        const SizedBox(height: 24),
        AppErrorState.fromError(
          error: error,
          onRetry: onRetry,
          fallbackTitle: 'Documents unavailable',
          fallbackMessage:
              'We could not load your document records. Please try again.',
          compact: true,
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 164),
      itemBuilder: (context, index) => PremiumCard(
        padding: const EdgeInsets.all(16),
        child: _DocumentsLoadingRow(
          color: Colors.black.withValues(alpha: 0.055 + (index % 2) * 0.015),
        ),
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: 7,
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
