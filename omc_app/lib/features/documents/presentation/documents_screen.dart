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
              return _DocumentsWorkspace(
                documents: documents,
                assisted: widget.assisted,
                customerName: widget.customerName,
                hasMore: _hasMore,
                loadingMore: _loadingMore,
                onLoadMore: _loadMore,
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
    required this.customerName,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  final List<DocumentItem> documents;
  final bool assisted;
  final String? customerName;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        _Header(
          documents: widget.documents,
          assisted: widget.assisted,
          customerName: widget.customerName,
        ),
        const SizedBox(height: 18),
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
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Service requests',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${groups.length} ${groups.length == 1 ? 'request' : 'requests'}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        if (widget.hasMore) ...[
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: widget.loadingMore ? null : widget.onLoadMore,
            icon: widget.loadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(
              widget.loadingMore ? 'Loading documents' : 'Load more documents',
            ),
          ),
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
    final title = assisted && customerName?.trim().isNotEmpty == true
        ? '${customerName!.trim()}\'s documents'
        : 'My documents';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: OmcPremium.documents.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OmcPremium.documents.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(
                Icons.folder_copy_outlined,
                color: OmcPremium.documents,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    documents.isEmpty
                        ? 'Required and submitted files will appear here.'
                        : 'Loaded: $active active · $action need action · $review under review',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search document, service or request ID',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _DocumentFilter.values)
          ChoiceChip(
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            label: Text('${filter.label} ${_countFor(filter)}'),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
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
    final (statusLabel, statusColor) = _groupStatus(group);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.requestTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${group.reference} · ${group.serviceTitle}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final badge = OmcStatusBadge(
                label: statusLabel,
                color: statusColor,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 10), badge],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '${group.approvedCount} of $total documents approved',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE8EDF0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${group.approvedCount}/$total approved',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < group.documents.length; index++) ...[
            _DocumentRow(
              document: group.documents[index],
              assisted: assisted,
              customerName: customerName,
            ),
            if (index != group.documents.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  (String, Color) _groupStatus(_DocumentRequestGroup group) {
    if (group.actionCount > 0) {
      return ('${group.actionCount} need action', OmcPremium.danger);
    }
    if (group.reviewCount > 0) {
      return ('${group.reviewCount} under review', OmcPremium.review);
    }
    if (group.isArchived) return ('Completed', OmcPremium.system);
    if (group.isFullyApproved) return ('Approved', OmcPremium.success);
    return ('Up to date', OmcPremium.success);
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
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
    final route = assisted
        ? '/documents/${Uri.encodeComponent(document.id)}'
              '?assisted=1'
              '&customer_name=${Uri.encodeQueryComponent(customerName ?? '')}'
        : '/documents/${Uri.encodeComponent(document.id)}';

    return Semantics(
      button: true,
      label: '${document.title}, ${document.statusLabel}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(document), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (document.documentType?.trim().isNotEmpty == true)
                          document.documentType!.trim(),
                        document.statusLabel,
                      ].join(' · '),
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (document.remarks?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        document.remarks!.trim(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
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

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.hasQuery, required this.filter});

  final bool hasQuery;
  final _DocumentFilter filter;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another search or document filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
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
          const Icon(
            Icons.folder_copy_outlined,
            color: OmcPremium.documents,
            size: 40,
          ),
          const SizedBox(height: 14),
          const Text(
            'No documents yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Required and submitted documents will appear here when you start a service request.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 132),
      itemBuilder: (context, index) => PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: index == 0 ? 76 : 108,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: 6,
    );
  }
}
