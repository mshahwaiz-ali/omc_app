import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';

const _documentIndigo = Color(0xFF4F46E5);
const _documentNavy = Color(0xFF0B1F4D);
const _reviewTeal = Color(0xFF0F9F8F);
const _approvedGreen = Color(0xFF159A62);
const _actionAmber = Color(0xFFF59E0B);
const _rejectedRed = Color(0xFFE5484D);
const _archivedSlate = Color(0xFF64748B);

enum _ReviewFilter {
  all('All', null),
  needsReview('Needs Review', 'needs_review'),
  rejected('Rejected', 'rejected'),
  approved('Approved', 'approved'),
  archived('Archived', 'archived');

  const _ReviewFilter(this.label, this.queue);

  final String label;
  final String? queue;
}

class InternalDocumentReviewScreen extends ConsumerStatefulWidget {
  const InternalDocumentReviewScreen({super.key});

  @override
  ConsumerState<InternalDocumentReviewScreen> createState() =>
      _InternalDocumentReviewScreenState();
}

class _InternalDocumentReviewScreenState
    extends ConsumerState<InternalDocumentReviewScreen> {
  _ReviewFilter _selectedFilter = _ReviewFilter.needsReview;
  late Future<List<DocumentItem>> _documentsFuture;
  String? _selectedServiceReference;
  String? _busyDocumentId;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _loadDocuments();
  }

  Future<List<DocumentItem>> _loadDocuments() {
    final repository = ref.read(documentsRepositoryProvider);
    return repository.fetchDocuments(queue: _selectedFilter.queue);
  }

  Future<void> _refresh() async {
    setState(() => _documentsFuture = _loadDocuments());
    await _documentsFuture;
  }

  void _selectFilter(_ReviewFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _selectedServiceReference = null;
      _documentsFuture = _loadDocuments();
    });
  }

  void _selectService(String? serviceReference) {
    setState(() => _selectedServiceReference = serviceReference);
  }

  Future<void> _reviewDocument(
    DocumentItem document,
    String status, {
    String? remarks,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final canReview = ref
        .read(authControllerProvider)
        .capabilities
        .canReviewDocuments;

    if (!canReview) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your role cannot review customer documents.'),
        ),
      );
      return;
    }

    setState(() => _busyDocumentId = document.id);

    try {
      await ref
          .read(documentsRepositoryProvider)
          .updateServiceDocumentStatus(
            documentId: document.id,
            status: status,
            remarks: remarks,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${document.title} marked as $status.')),
      );
      await _refresh();
    } on ApiError catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(error);
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Document review failed',
        fallbackMessage:
            'The document review action could not be completed. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busyDocumentId = null);
    }
  }

  Future<void> _rejectWithRemarks(DocumentItem document) async {
    final controller = TextEditingController(text: document.remarks ?? '');
    final remarks = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject document'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason / reupload instruction',
            hintText: 'Example: CNIC image is unclear. Please upload again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (remarks == null) return;
    await _reviewDocument(document, 'Rejected', remarks: remarks);
  }

  @override
  Widget build(BuildContext context) {
    final canReviewDocuments = ref
        .watch(authControllerProvider)
        .capabilities
        .canReviewDocuments;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<DocumentItem>>(
            future: _documentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ReviewLoadingView();
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    AppErrorState.fromError(
                      error: snapshot.error!,
                      onRetry: _refresh,
                      fallbackTitle: 'Review queue unavailable',
                      fallbackMessage:
                          'Customer documents could not be loaded. Please try again.',
                    ),
                  ],
                );
              }

              final documents = snapshot.data ?? const <DocumentItem>[];
              return _ReviewContent(
                documents: documents,
                selectedFilter: _selectedFilter,
                selectedServiceReference: _selectedServiceReference,
                busyDocumentId: _busyDocumentId,
                canReviewDocuments: canReviewDocuments,
                onFilterSelected: _selectFilter,
                onServiceSelected: _selectService,
                onApprove: (document) => _reviewDocument(document, 'Approved'),
                onReject: _rejectWithRemarks,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({
    required this.documents,
    required this.selectedFilter,
    required this.selectedServiceReference,
    required this.busyDocumentId,
    required this.canReviewDocuments,
    required this.onFilterSelected,
    required this.onServiceSelected,
    required this.onApprove,
    required this.onReject,
  });

  final List<DocumentItem> documents;
  final _ReviewFilter selectedFilter;
  final String? selectedServiceReference;
  final String? busyDocumentId;
  final bool canReviewDocuments;
  final ValueChanged<_ReviewFilter> onFilterSelected;
  final ValueChanged<String?> onServiceSelected;
  final ValueChanged<DocumentItem> onApprove;
  final ValueChanged<DocumentItem> onReject;

  @override
  Widget build(BuildContext context) {
    final needsReview = documents.where((item) => item.isUnderReview).length;
    final rejected = documents
        .where((item) => item.status == DocumentStatus.rejected)
        .length;
    final approved = documents
        .where((item) => item.status == DocumentStatus.approved)
        .length;
    final archived = documents.where((item) => item.isArchived).length;
    final groups = _ServiceDocumentGroup.fromDocuments(documents);
    final selectedGroup = _selectedGroup(groups, selectedServiceReference);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        PremiumListHeader(
          icon: Icons.folder_copy_outlined,
          title: 'Document Review',
          subtitle:
              'Review customer files by service request and keep every case moving.',
          metaLabel: '${documents.length} docs',
          accentColor: _documentIndigo,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.hourglass_top_rounded,
                label: 'Review',
                value: needsReview.toString(),
                color: _reviewTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.error_outline_rounded,
                label: 'Rejected',
                value: rejected.toString(),
                color: _rejectedRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.verified_rounded,
                label: 'Approved',
                value: approved.toString(),
                color: _approvedGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.archive_rounded,
                label: 'Archive',
                value: archived.toString(),
                color: _archivedSlate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewFilterBar(
          selectedFilter: selectedFilter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          PremiumEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No documents in this queue',
            message:
                'Switch filters or refresh when new customer uploads arrive.',
          )
        else ...[
          _ServiceSelectorCard(
            groups: groups,
            selectedReference: selectedGroup.reference,
            onSelected: onServiceSelected,
          ),
          const SizedBox(height: 12),
          _ServiceSummaryCard(group: selectedGroup),
          const SizedBox(height: 12),
          PremiumListHeader(
            icon: Icons.folder_copy_outlined,
            title: 'Documents',
            subtitle: selectedGroup.serviceTitle,
            metaLabel: '${selectedGroup.documents.length} files',
            accentColor: _documentIndigo,
          ),
          const SizedBox(height: 12),
          for (final document in selectedGroup.documents) ...[
            _ReviewDocumentCard(
              document: document,
              isBusy: busyDocumentId == document.id,
              canReviewDocuments: canReviewDocuments,
              onApprove: () => onApprove(document),
              onReject: () => onReject(document),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  _ServiceDocumentGroup _selectedGroup(
    List<_ServiceDocumentGroup> groups,
    String? selectedReference,
  ) {
    if (groups.isEmpty) return _ServiceDocumentGroup.empty();

    for (final group in groups) {
      if (group.reference == selectedReference) return group;
    }

    return groups.first;
  }
}

class _ServiceDocumentGroup {
  const _ServiceDocumentGroup({
    required this.reference,
    required this.serviceTitle,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerNtn,
    required this.customerCnic,
    required this.companyName,
    required this.status,
    required this.documents,
  });

  factory _ServiceDocumentGroup.empty() {
    return const _ServiceDocumentGroup(
      reference: '-',
      serviceTitle: 'Service request',
      customerName: 'Customer',
      customerEmail: null,
      customerPhone: null,
      customerNtn: null,
      customerCnic: null,
      companyName: null,
      status: null,
      documents: <DocumentItem>[],
    );
  }

  final String reference;
  final String serviceTitle;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerNtn;
  final String? customerCnic;
  final String? companyName;
  final String? status;
  final List<DocumentItem> documents;

  int get needsReview => documents.where((item) => item.isUnderReview).length;

  int get approved =>
      documents.where((item) => item.status == DocumentStatus.approved).length;

  int get rejected =>
      documents.where((item) => item.status == DocumentStatus.rejected).length;

  static List<_ServiceDocumentGroup> fromDocuments(
    List<DocumentItem> documents,
  ) {
    final grouped = <String, List<DocumentItem>>{};
    for (final document in documents) {
      final key = document.serviceReference?.trim().isNotEmpty == true
          ? document.serviceReference!.trim()
          : 'Unlinked Service';
      grouped.putIfAbsent(key, () => <DocumentItem>[]).add(document);
    }

    final groups = grouped.entries.map((entry) {
      final docs = entry.value;
      final first = docs.first;
      return _ServiceDocumentGroup(
        reference: entry.key,
        serviceTitle: first.serviceTitle ?? 'Service request',
        customerName: first.displayCustomerName,
        customerEmail: first.customerEmail,
        customerPhone: first.customerPhone,
        customerNtn: first.customerNtn,
        customerCnic: first.customerCnic,
        companyName: first.companyName,
        status: first.serviceStatus,
        documents: docs,
      );
    }).toList();

    groups.sort((a, b) {
      final reviewCompare = b.needsReview.compareTo(a.needsReview);
      if (reviewCompare != 0) return reviewCompare;
      return a.reference.compareTo(b.reference);
    });

    return groups;
  }
}

class _ServiceSelectorCard extends StatelessWidget {
  const _ServiceSelectorCard({
    required this.groups,
    required this.selectedReference,
    required this.onSelected,
  });

  final List<_ServiceDocumentGroup> groups;
  final String selectedReference;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: DropdownButtonFormField<String>(
        initialValue: selectedReference,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Service request',
          prefixIcon: Icon(Icons.folder_open_rounded, color: _documentIndigo),
        ),
        items: groups
            .map(
              (group) => DropdownMenuItem<String>(
                value: group.reference,
                child: Text(
                  '${group.reference} · ${group.customerName} · ${group.documents.length} docs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onSelected,
      ),
    );
  }
}

class _ServiceSummaryCard extends StatelessWidget {
  const _ServiceSummaryCard({required this.group});

  final _ServiceDocumentGroup group;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
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
                  color: _documentIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  color: _documentIndigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.customerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.serviceTitle} · ${group.reference}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (group.status != null) PremiumInfoChip(label: group.status!),
              PremiumInfoChip(label: '${group.documents.length} documents'),
              if (group.needsReview > 0)
                PremiumInfoChip(
                  label: '${group.needsReview} needs review',
                  color: _reviewTeal,
                ),
              if (group.approved > 0)
                PremiumInfoChip(
                  label: '${group.approved} approved',
                  color: _approvedGreen,
                ),
              if (group.rejected > 0)
                PremiumInfoChip(
                  label: '${group.rejected} rejected',
                  color: _rejectedRed,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoGrid(
            items: [
              _InfoItem('Phone', group.customerPhone),
              _InfoItem('Email', group.customerEmail),
              _InfoItem('NTN', group.customerNtn),
              _InfoItem('CNIC', group.customerCnic),
              _InfoItem('Company', group.companyName),
              _InfoItem('Request ID', group.reference),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => item.value != null && item.value!.trim().isNotEmpty)
        .toList(growable: false);

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in visibleItems)
          SizedBox(
            width: 145,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);

  final String label;
  final String? value;
}

class _ReviewFilterBar extends StatelessWidget {
  const _ReviewFilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final _ReviewFilter selectedFilter;
  final ValueChanged<_ReviewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final filter in _ReviewFilter.values) ...[
              Builder(
                builder: (context) {
                  final selected = selectedFilter == filter;
                  final accent = Theme.of(context).colorScheme.primary;
                  return ChoiceChip(
                    avatar: Icon(
                      _reviewFilterIcon(filter),
                      size: 16,
                      color: selected ? accent : AppTheme.textMuted,
                    ),
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) => onSelected(filter),
                    selectedColor: accent.withValues(alpha: 0.08),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? accent.withValues(alpha: 0.22)
                          : AppTheme.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? accent : AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewDocumentCard extends StatelessWidget {
  const _ReviewDocumentCard({
    required this.document,
    required this.isBusy,
    required this.canReviewDocuments,
    required this.onApprove,
    required this.onReject,
  });

  final DocumentItem document;
  final bool isBusy;
  final bool canReviewDocuments;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final canReview =
        canReviewDocuments &&
        !document.isArchived &&
        document.status != DocumentStatus.approved &&
        !isBusy;
    final serviceReference = document.serviceReference?.trim() ?? '';
    final canOpenCase = serviceReference.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () =>
          context.push('/documents/${Uri.encodeComponent(document.id)}'),
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _statusColor(document).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _statusColor(document).withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    document.isArchived
                        ? Icons.archive_rounded
                        : Icons.description_rounded,
                    color: _statusColor(document),
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumInfoChip(
                  label: document.statusLabel,
                  color: _statusColor(document),
                ),
                if (document.source != null)
                  PremiumInfoChip(label: document.source!),
                if (document.updatedAtLabel != null)
                  PremiumInfoChip(
                    label: 'Uploaded ${document.updatedAtLabel!}',
                  ),
              ],
            ),
            if (document.remarks != null) ...[
              const SizedBox(height: 10),
              Text(
                document.remarks!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canOpenCase
                        ? () => context.push(
                            '/my-services/${Uri.encodeComponent(serviceReference)}',
                          )
                        : null,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Case'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _documentNavy,
                      side: const BorderSide(color: Color(0xFFD8DFEC)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canReview ? onApprove : null,
                    icon: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _approvedGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canReview ? onReject : null,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _rejectedRed,
                      side: BorderSide(
                        color: _rejectedRed.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DocumentItem document) {
    if (document.isArchived) return _archivedSlate;

    switch (document.status) {
      case DocumentStatus.approved:
        return _approvedGreen;
      case DocumentStatus.rejected:
        return _rejectedRed;
      case DocumentStatus.missing:
        return _actionAmber;
      case DocumentStatus.pendingReview:
        return _reviewTeal;
      case DocumentStatus.uploaded:
        return _documentIndigo;
    }
  }
}

IconData _reviewFilterIcon(_ReviewFilter filter) {
  switch (filter) {
    case _ReviewFilter.all:
      return Icons.folder_copy_outlined;
    case _ReviewFilter.needsReview:
      return Icons.fact_check_outlined;
    case _ReviewFilter.rejected:
      return Icons.cancel_outlined;
    case _ReviewFilter.approved:
      return Icons.check_circle_outline_rounded;
    case _ReviewFilter.archived:
      return Icons.archive_outlined;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
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

class _ReviewLoadingView extends StatelessWidget {
  const _ReviewLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: const [
        PremiumListHeader(
          icon: Icons.fact_check_outlined,
          title: 'Document Review',
          subtitle: 'Loading customer document queue from backend.',
          metaLabel: 'Loading',
          accentColor: _documentIndigo,
        ),
        SizedBox(height: 16),
        PremiumCard(
          padding: EdgeInsets.all(22),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}
