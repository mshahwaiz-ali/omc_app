import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({
    super.key,
    this.assisted = false,
    this.serviceRequest,
    this.customerName,
  });

  final bool assisted;
  final String? serviceRequest;
  final String? customerName;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final List<DocumentItem> _additionalDocuments = [];
  int? _nextStart;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _didSeedPage = false;

  bool get _isAssistedRequest =>
      widget.assisted && widget.serviceRequest?.trim().isNotEmpty == true;

  String get _serviceRequest => widget.serviceRequest?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final pageAsync = _isAssistedRequest
        ? ref.watch(assistedDocumentPageProvider(_serviceRequest))
        : ref.watch(documentPageProvider);

    return Scaffold(
      key: OmcWidgetKeys.documentsScreen,
      backgroundColor: OmcPremium.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: OmcPremium.documents,
          onRefresh: _refresh,
          child: pageAsync.when(
            data: (page) {
              if (!_didSeedPage) {
                _didSeedPage = true;
                _nextStart = page.nextStart;
                _hasMore = page.hasMore;
              }

              final documents = _mergeDocuments(
                page.items,
                _additionalDocuments,
              );
              return Stack(
                children: [
                  _DocumentsWorkspace(
                    documents: documents,
                    assisted: widget.assisted,
                    serviceRequest: widget.serviceRequest,
                    customerName: widget.customerName,
                  ),
                  if (_hasMore)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 88,
                      child: SafeArea(
                        top: false,
                        child: FilledButton.tonalIcon(
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            _loadingMore ? 'Loading documents' : 'Load more',
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const _DocumentsLoadingView(),
            error: (error, _) =>
                _DocumentsErrorView(error: error, onRetry: _retry),
          ),
        ),
      ),
    );
  }

  List<DocumentItem> _mergeDocuments(
    List<DocumentItem> firstPage,
    List<DocumentItem> additional,
  ) {
    final seen = <String>{};
    final result = <DocumentItem>[];
    for (final item in [...firstPage, ...additional]) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  void _resetPagingState() {
    _additionalDocuments.clear();
    _nextStart = null;
    _hasMore = false;
    _loadingMore = false;
    _didSeedPage = false;
  }

  Future<void> _refresh() async {
    setState(_resetPagingState);
    if (_isAssistedRequest) {
      final provider = assistedDocumentPageProvider(_serviceRequest);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } else {
      ref.invalidate(documentPageProvider);
      await ref.read(documentPageProvider.future);
    }
  }

  void _retry() {
    setState(_resetPagingState);
    if (_isAssistedRequest) {
      ref.invalidate(assistedDocumentPageProvider(_serviceRequest));
    } else {
      ref.invalidate(documentPageProvider);
    }
  }

  Future<void> _loadMore() async {
    final start = _nextStart;
    if (_loadingMore || !_hasMore || start == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(documentsRepositoryProvider)
          .fetchDocumentPage(
            start: start,
            serviceRequest: _isAssistedRequest ? _serviceRequest : null,
            assisted: _isAssistedRequest,
          );
      if (!mounted) return;

      setState(() {
        final knownIds = _additionalDocuments.map((item) => item.id).toSet();
        final firstPage = _isAssistedRequest
            ? ref.read(assistedDocumentPageProvider(_serviceRequest)).value
            : ref.read(documentPageProvider).value;
        knownIds.addAll(firstPage?.items.map((item) => item.id) ?? const []);
        _additionalDocuments.addAll(
          page.items.where((item) => knownIds.add(item.id)),
        );
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'More documents unavailable',
        fallbackMessage: 'The next document page could not be loaded.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

enum _DocumentFilter {
  all('All'),
  action('Action'),
  review('Review'),
  approved('Approved'),
  archived('Archive');

  const _DocumentFilter(this.label);

  final String label;
}

class _DocumentsWorkspace extends StatefulWidget {
  const _DocumentsWorkspace({
    required this.documents,
    required this.assisted,
    required this.serviceRequest,
    required this.customerName,
  });

  final List<DocumentItem> documents;
  final bool assisted;
  final String? serviceRequest;
  final String? customerName;

  @override
  State<_DocumentsWorkspace> createState() => _DocumentsWorkspaceState();
}

class _DocumentsWorkspaceState extends State<_DocumentsWorkspace> {
  final _searchController = TextEditingController();
  _DocumentFilter _selectedFilter = _DocumentFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredDocuments(widget.documents);
    final groups = _DocumentRequestGroup.fromDocuments(visible);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 164),
      children: [
        _Header(
          documents: widget.documents,
          assisted: widget.assisted,
          customerName: widget.customerName,
        ),
        const SizedBox(height: 16),
        _SearchField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: 12),
        _FilterBar(
          documents: widget.documents,
          selected: _selectedFilter,
          onSelected: (value) => setState(() => _selectedFilter = value),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Service requests',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Text(
              '${groups.length} ${groups.length == 1 ? 'request' : 'requests'}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.documents.isEmpty)
          const _EmptyDocumentsView()
        else if (groups.isEmpty)
          _FilteredEmptyView(
            hasQuery: _query.isNotEmpty,
            filter: _selectedFilter,
          )
        else
          for (var index = 0; index < groups.length; index++) ...[
            _RequestDocumentCard(
              group: groups[index],
              assisted: widget.assisted,
              customerName: widget.customerName,
            ),
            if (index != groups.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<DocumentItem> _filteredDocuments(List<DocumentItem> documents) {
    final filtered = documents
        .where((item) {
          final matchesFilter = switch (_selectedFilter) {
            _DocumentFilter.all => true,
            _DocumentFilter.action => item.requiresAction,
            _DocumentFilter.review => item.isUnderReview,
            _DocumentFilter.approved => item.isApproved,
            _DocumentFilter.archived => item.isArchived,
          };

          if (!matchesFilter) return false;
          if (_query.isEmpty) return true;

          final searchable = [
            item.title,
            item.documentType,
            item.requestTitle,
            item.serviceTitle,
            item.serviceReference,
            item.statusLabel,
          ].whereType<String>().join(' ').toLowerCase();

          return searchable.contains(_query);
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      final actionCompare = (b.requiresAction ? 1 : 0).compareTo(
        a.requiresAction ? 1 : 0,
      );
      if (actionCompare != 0) return actionCompare;

      final archivedCompare = (a.isArchived ? 1 : 0).compareTo(
        b.isArchived ? 1 : 0,
      );
      if (archivedCompare != 0) return archivedCompare;

      return (b.updatedAtLabel ?? '').compareTo(a.updatedAtLabel ?? '');
    });

    return filtered;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.documents,
    required this.assisted,
    required this.customerName,
  });

  final List<DocumentItem> documents;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final active = documents.where((item) => item.isActive).length;
    final action = documents.where((item) => item.requiresAction).length;
    final review = documents.where((item) => item.isUnderReview).length;
    final approved = documents.where((item) => item.isApproved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmcPremium.border),
              ),
              child: const Icon(
                Icons.folder_copy_outlined,
                color: OmcPremium.documents,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assisted && customerName?.trim().isNotEmpty == true
                          ? '${customerName!.trim()}\'s Documents'
                          : 'My Documents',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 27,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$active active  •  $action need action',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Action',
                  value: action,
                  icon: Icons.priority_high_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Review',
                  value: review,
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Approved',
                  value: approved,
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OmcPremium.documents.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: OmcPremium.documents, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OmcPremium.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search document, service or request ID',
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.documents,
    required this.selected,
    required this.onSelected,
  });

  final List<DocumentItem> documents;
  final _DocumentFilter selected;
  final ValueChanged<_DocumentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in _DocumentFilter.values) ...[
            _FilterChip(
              label: filter.label,
              count: _countFor(filter),
              selected: selected == filter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _DocumentFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  int _countFor(_DocumentFilter filter) {
    return switch (filter) {
      _DocumentFilter.all => documents.length,
      _DocumentFilter.action =>
        documents.where((item) => item.requiresAction).length,
      _DocumentFilter.review =>
        documents.where((item) => item.isUnderReview).length,
      _DocumentFilter.approved =>
        documents.where((item) => item.isApproved).length,
      _DocumentFilter.archived =>
        documents.where((item) => item.isArchived).length,
    };
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      label: Text('$label  $count'),
      selectedColor: OmcPremium.documents.withValues(alpha: 0.11),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? OmcPremium.documents.withValues(alpha: 0.24)
            : OmcPremium.border,
      ),
      labelStyle: TextStyle(
        color: selected ? OmcPremium.documents : AppTheme.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}

class _DocumentRequestGroup {
  const _DocumentRequestGroup({
    required this.reference,
    required this.requestTitle,
    required this.serviceTitle,
    required this.serviceStatus,
    required this.documents,
  });

  final String reference;
  final String requestTitle;
  final String serviceTitle;
  final String? serviceStatus;
  final List<DocumentItem> documents;

  int get actionCount => documents.where((item) => item.requiresAction).length;
  int get approvedCount => documents.where((item) => item.isApproved).length;
  int get reviewCount => documents.where((item) => item.isUnderReview).length;
  bool get isArchived => documents.every((item) => item.isArchived);
  bool get isFullyApproved =>
      documents.isNotEmpty && approvedCount == documents.length;

  static List<_DocumentRequestGroup> fromDocuments(
    List<DocumentItem> documents,
  ) {
    final grouped = <String, List<DocumentItem>>{};

    for (final document in documents) {
      final reference = document.serviceReference?.trim();
      final key = reference != null && reference.isNotEmpty
          ? reference
          : 'Unlinked request';
      grouped.putIfAbsent(key, () => <DocumentItem>[]).add(document);
    }

    final groups = grouped.entries.map((entry) {
      final first = entry.value.first;
      final requestTitle = first.requestTitle?.trim();
      final serviceTitle = first.serviceTitle?.trim();

      return _DocumentRequestGroup(
        reference: entry.key,
        requestTitle: requestTitle != null && requestTitle.isNotEmpty
            ? requestTitle
            : serviceTitle != null && serviceTitle.isNotEmpty
            ? serviceTitle
            : 'Service request',
        serviceTitle: serviceTitle != null && serviceTitle.isNotEmpty
            ? serviceTitle
            : 'OMC service',
        serviceStatus: first.serviceStatus,
        documents: entry.value,
      );
    }).toList();

    groups.sort((a, b) {
      final actionCompare = b.actionCount.compareTo(a.actionCount);
      if (actionCompare != 0) return actionCompare;

      final archivedCompare = (a.isArchived ? 1 : 0).compareTo(
        b.isArchived ? 1 : 0,
      );
      if (archivedCompare != 0) return archivedCompare;

      return a.reference.compareTo(b.reference);
    });

    return groups;
  }
}

class _RequestDocumentCard extends StatelessWidget {
  const _RequestDocumentCard({
    required this.group,
    required this.assisted,
    required this.customerName,
  });

  final _DocumentRequestGroup group;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final total = group.documents.length;
    final progress = total == 0 ? 0.0 : group.approvedCount / total;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: OmcPremium.documents.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: OmcPremium.documents,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.requestTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.reference}  •  ${group.serviceTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.actionCount > 0)
                _StatusPill(
                  label: '${group.actionCount} action',
                  color: OmcPremium.danger,
                )
              else if (group.reviewCount > 0)
                _StatusPill(
                  label: '${group.reviewCount} review',
                  color: OmcPremium.review,
                )
              else if (group.isArchived)
                const _StatusPill(label: 'Completed', color: OmcPremium.system)
              else if (group.isFullyApproved)
                const _StatusPill(label: 'Approved', color: OmcPremium.success)
              else
                const _StatusPill(
                  label: 'Up to date',
                  color: OmcPremium.success,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE8EDF0),
                    valueColor: const AlwaysStoppedAnimation(
                      OmcPremium.documents,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${group.approvedCount}/$total approved',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < group.documents.length; index++) ...[
            _CompactDocumentRow(
              document: group.documents[index],
              assisted: assisted,
              customerName: customerName,
            ),
            if (index != group.documents.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CompactDocumentRow extends StatelessWidget {
  const _CompactDocumentRow({
    required this.document,
    required this.assisted,
    required this.customerName,
  });

  final DocumentItem document;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(document);

    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => context.push(
          assisted
              ? '/documents/${Uri.encodeComponent(document.id)}'
                    '?assisted=1'
                    '&customer_name=${Uri.encodeQueryComponent(customerName ?? '')}'
              : '/documents/${Uri.encodeComponent(document.id)}',
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black.withValues(alpha: 0.055)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(document), color: color, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (document.documentType?.trim().isNotEmpty == true)
                          document.documentType!.trim(),
                        document.statusLabel,
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (document.remarks?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        document.remarks!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(DocumentItem document) {
    if (document.isArchived) return OmcPremium.system;

    return switch (document.status) {
      DocumentStatus.approved => OmcPremium.success,
      DocumentStatus.rejected => OmcPremium.danger,
      DocumentStatus.missing => OmcPremium.danger,
      DocumentStatus.pendingReview => OmcPremium.action,
      DocumentStatus.uploaded => OmcPremium.review,
    };
  }

  IconData _statusIcon(DocumentItem document) {
    if (document.isArchived) return Icons.archive_rounded;

    return switch (document.status) {
      DocumentStatus.approved => Icons.verified_rounded,
      DocumentStatus.rejected => Icons.error_outline_rounded,
      DocumentStatus.missing => Icons.upload_file_rounded,
      DocumentStatus.pendingReview => Icons.hourglass_top_rounded,
      DocumentStatus.uploaded => Icons.description_outlined,
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.hasQuery, required this.filter});

  final bool hasQuery;
  final _DocumentFilter filter;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: OmcPremium.documents,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? 'No matching documents'
                : 'No ${filter.label.toLowerCase()} documents',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another search or document filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _EmptyDocumentsView extends StatelessWidget {
  const _EmptyDocumentsView();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: OmcPremium.documents.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: OmcPremium.documents,
              size: 31,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No documents yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Required and submitted documents will appear here when you start a service request.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        child: Container(
          height: index == 0 ? 80 : 112,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: 6,
    );
  }
}
