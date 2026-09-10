import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/document_item.dart';
import '../data/documents_repository.dart';
import 'document_preview_screen.dart';

enum _ReviewFilter {
  all('All', null),
  needsReview('Needs review', 'needs_review'),
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
  final _searchController = TextEditingController();
  final List<DocumentItem> _additionalDocuments = [];
  _ReviewFilter _selectedFilter = _ReviewFilter.needsReview;
  late Future<DocumentPage> _documentsFuture;
  String _query = '';
  String? _selectedCustomerProfile;
  String? _selectedDocumentType;
  String? _selectedServiceReference;
  String? _busyDocumentId;
  int? _nextStart;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _didSeedPage = false;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<DocumentPage> _loadDocuments() {
    final repository = ref.read(documentsRepositoryProvider);
    return repository.fetchDocumentPage(
      queue: _selectedFilter.queue,
      customer: _selectedCustomerProfile,
    );
  }

  void _resetPagingState() {
    _additionalDocuments.clear();
    _nextStart = null;
    _hasMore = false;
    _loadingMore = false;
    _didSeedPage = false;
  }

  List<DocumentItem> _mergeDocuments(List<DocumentItem> firstPage) {
    final seen = <String>{};
    final result = <DocumentItem>[];
    for (final item in [...firstPage, ..._additionalDocuments]) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  Future<void> _refresh() async {
    setState(() {
      _resetPagingState();
      _documentsFuture = _loadDocuments();
    });
    await _documentsFuture;
  }

  void _selectFilter(_ReviewFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _selectedCustomerProfile = null;
      _selectedDocumentType = null;
      _selectedServiceReference = null;
      _resetPagingState();
      _documentsFuture = _loadDocuments();
    });
  }

  Future<void> _loadMore() async {
    final start = _nextStart;
    if (_loadingMore || !_hasMore || start == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(documentsRepositoryProvider)
          .fetchDocumentPage(
            queue: _selectedFilter.queue,
            customer: _selectedCustomerProfile,
            start: start,
          );
      if (!mounted) return;

      final firstPage = await _documentsFuture;
      if (!mounted) return;
      setState(() {
        final knownIds = <String>{
          ...firstPage.items.map((item) => item.id),
          ..._additionalDocuments.map((item) => item.id),
        };
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
        fallbackMessage: 'The next review queue page could not be loaded.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectCustomer(String? customerProfile) {
    if (_selectedCustomerProfile == customerProfile) return;
    setState(() {
      _selectedCustomerProfile = customerProfile;
      _selectedDocumentType = null;
      _selectedServiceReference = null;
      _resetPagingState();
      _documentsFuture = _loadDocuments();
    });
  }

  void _selectDocumentType(String? documentType) {
    setState(() {
      _selectedDocumentType = documentType;
      _selectedServiceReference = null;
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
    final dirtyFormController = DirtyFormController();

    void markDirty() => dirtyFormController.markDirty();

    controller.addListener(markDirty);

    final remarks = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirtyFormController,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Reject document'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason / reupload instruction',
                hintText:
                    'Example: CNIC image is unclear. Please upload again.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () {
                        final value = controller.text.trim();
                        dirtyFormController.submissionSucceeded();
                        Navigator.of(dialogContext).pop(value);
                      },
                child: const Text('Reject document'),
              ),
            ],
          ),
        ),
      ),
    );

    controller.removeListener(markDirty);
    dirtyFormController.dispose();
    controller.dispose();

    if (!mounted || _busyDocumentId != null) return;
    if (remarks == null || remarks.isEmpty) return;
    await _reviewDocument(document, 'Rejected', remarks: remarks);
  }

  Future<void> _openDocumentPreview(DocumentItem document) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final file = await ref
          .read(documentsRepositoryProvider)
          .downloadDocument(document);

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              DocumentPreviewScreen(fileName: file.name, bytes: file.bytes),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Preview unavailable',
        fallbackMessage:
            'The authenticated document could not be opened right now.',
      );

      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
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
          child: FutureBuilder<DocumentPage>(
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

              final page = snapshot.data ?? const DocumentPage.empty();
              if (!_didSeedPage) {
                _didSeedPage = true;
                _nextStart = page.nextStart;
                _hasMore = page.hasMore;
              }
              final documents = _mergeDocuments(page.items);

              return _ReviewContent(
                documents: documents,
                searchController: _searchController,
                query: _query,
                selectedFilter: _selectedFilter,
                selectedCustomerProfile: _selectedCustomerProfile,
                selectedDocumentType: _selectedDocumentType,
                selectedServiceReference: _selectedServiceReference,
                busyDocumentId: _busyDocumentId,
                canReviewDocuments: canReviewDocuments,
                hasMore: _hasMore,
                loadingMore: _loadingMore,
                onLoadMore: _loadMore,
                onQueryChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                onClearQuery: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onFilterSelected: _selectFilter,
                onCustomerSelected: _selectCustomer,
                onDocumentTypeSelected: _selectDocumentType,
                onServiceSelected: _selectService,
                onPreview: _openDocumentPreview,
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
    required this.searchController,
    required this.query,
    required this.selectedFilter,
    required this.selectedCustomerProfile,
    required this.selectedDocumentType,
    required this.selectedServiceReference,
    required this.busyDocumentId,
    required this.canReviewDocuments,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onFilterSelected,
    required this.onCustomerSelected,
    required this.onDocumentTypeSelected,
    required this.onServiceSelected,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
  });

  final List<DocumentItem> documents;
  final TextEditingController searchController;
  final String query;
  final _ReviewFilter selectedFilter;
  final String? selectedCustomerProfile;
  final String? selectedDocumentType;
  final String? selectedServiceReference;
  final String? busyDocumentId;
  final bool canReviewDocuments;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<_ReviewFilter> onFilterSelected;
  final ValueChanged<String?> onCustomerSelected;
  final ValueChanged<String?> onDocumentTypeSelected;
  final ValueChanged<String?> onServiceSelected;
  final ValueChanged<DocumentItem> onPreview;
  final ValueChanged<DocumentItem> onApprove;
  final ValueChanged<DocumentItem> onReject;

  @override
  Widget build(BuildContext context) {
    final customerOptions = _customerOptions(documents);
    final documentTypeOptions = _documentTypeOptions(documents);
    final filteredDocuments = documents
        .where((document) {
          final matchesCustomer =
              selectedCustomerProfile == null ||
              document.customerProfile == selectedCustomerProfile;
          if (!matchesCustomer) return false;

          final matchesDocumentType =
              selectedDocumentType == null ||
              document.documentType?.trim() == selectedDocumentType;
          if (!matchesDocumentType) return false;

          if (query.isEmpty) return true;

          final searchable = [
            document.title,
            document.documentType,
            document.requestTitle,
            document.serviceTitle,
            document.serviceReference,
            document.displayCustomerName,
            document.customerEmail,
            document.customerPhone,
            document.companyName,
            document.statusLabel,
          ].whereType<String>().join(' ').toLowerCase();

          return searchable.contains(query);
        })
        .toList(growable: false);

    final reviewCount = filteredDocuments
        .where((item) => item.isUnderReview)
        .length;
    final groups = _ServiceDocumentGroup.fromDocuments(filteredDocuments);
    final selectedGroup = _selectedGroup(groups, selectedServiceReference);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
      children: [
        PremiumListHeader(
          icon: Icons.fact_check_outlined,
          title: 'Document review',
          subtitle:
              'Review customer evidence by service request and keep decisions explicit.',
          metaLabel: hasMore
              ? '$reviewCount awaiting review in loaded results · more available'
              : '$reviewCount awaiting review in loaded results',
        ),
        const SizedBox(height: 16),
        _ReviewFilterBar(
          selectedFilter: selectedFilter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search loaded request, service or document',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClearQuery,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasMore)
          Text(
            'Search, document type and available customer choices are based on loaded results. After you select a customer, that customer filter is applied by the server before paging.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        const SizedBox(height: 12),
        _AdvancedFilterPanel(
          customerOptions: customerOptions,
          selectedCustomerProfile: selectedCustomerProfile,
          documentTypeOptions: documentTypeOptions,
          selectedDocumentType: selectedDocumentType,
          onCustomerSelected: onCustomerSelected,
          onDocumentTypeSelected: onDocumentTypeSelected,
        ),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          PremiumEmptyState(
            icon: query.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.task_alt_rounded,
            title: query.isNotEmpty
                ? 'No matching documents'
                : 'No documents in this queue',
            message: query.isNotEmpty
                ? 'Try another customer, search term, or queue filter.'
                : 'Switch filters or refresh when new customer uploads arrive.',
          )
        else ...[
          _ServiceContextCard(
            groups: groups,
            selectedGroup: selectedGroup,
            onSelected: onServiceSelected,
          ),
          const SizedBox(height: 14),
          for (final document in selectedGroup.documents) ...[
            _ReviewDocumentCard(
              document: document,
              isBusy: busyDocumentId == document.id,
              canReviewDocuments: canReviewDocuments,
              onPreview: () => onPreview(document),
              onApprove: () => onApprove(document),
              onReject: () => onReject(document),
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (hasMore) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: loadingMore ? null : onLoadMore,
            icon: loadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(
              loadingMore ? 'Loading review queue' : 'Load more documents',
            ),
          ),
        ],
      ],
    );
  }

  List<String> _documentTypeOptions(List<DocumentItem> documents) {
    final values = documents
        .map((document) => document.documentType?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    values.sort();
    return values;
  }

  List<_CustomerFilterOption> _customerOptions(List<DocumentItem> documents) {
    final options = <String, _CustomerFilterOption>{};

    for (final document in documents) {
      final profile = document.customerProfile?.trim();
      if (profile == null || profile.isEmpty) continue;

      options.putIfAbsent(
        profile,
        () => _CustomerFilterOption(
          profile: profile,
          label: document.displayCustomerName,
          email: document.customerEmail,
        ),
      );
    }

    final values = options.values.toList(growable: false);
    values.sort((a, b) => a.label.compareTo(b.label));
    return values;
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

class _CustomerFilterOption {
  const _CustomerFilterOption({
    required this.profile,
    required this.label,
    required this.email,
  });

  final String profile;
  final String label;
  final String? email;
}

class _AdvancedFilterPanel extends StatelessWidget {
  const _AdvancedFilterPanel({
    required this.customerOptions,
    required this.selectedCustomerProfile,
    required this.documentTypeOptions,
    required this.selectedDocumentType,
    required this.onCustomerSelected,
    required this.onDocumentTypeSelected,
  });

  final List<_CustomerFilterOption> customerOptions;
  final String? selectedCustomerProfile;
  final List<String> documentTypeOptions;
  final String? selectedDocumentType;
  final ValueChanged<String?> onCustomerSelected;
  final ValueChanged<String?> onDocumentTypeSelected;

  @override
  Widget build(BuildContext context) {
    final activeCount = [
      selectedCustomerProfile,
      selectedDocumentType,
    ].where((value) => value != null && value.trim().isNotEmpty).length;

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.tune_rounded),
        title: const Text(
          'Advanced filters',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          activeCount == 0
              ? 'Loaded choices · server-applied customer'
              : '$activeCount active',
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedCustomerProfile ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Customer',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All customers'),
              ),
              for (final option in customerOptions)
                DropdownMenuItem<String>(
                  value: option.profile,
                  child: Text(
                    [
                      option.label,
                      if (option.email?.trim().isNotEmpty == true)
                        option.email!.trim(),
                    ].join(' · '),
                  ),
                ),
            ],
            onChanged: (value) => onCustomerSelected(
              value == null || value.isEmpty ? null : value,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedDocumentType ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Document type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All document types'),
              ),
              for (final option in documentTypeOptions)
                DropdownMenuItem<String>(value: option, child: Text(option)),
            ],
            onChanged: (value) => onDocumentTypeSelected(
              value == null || value.isEmpty ? null : value,
            ),
          ),
        ],
      ),
    );
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

class _ServiceContextCard extends StatelessWidget {
  const _ServiceContextCard({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<_ServiceDocumentGroup> groups;
  final _ServiceDocumentGroup selectedGroup;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (selectedGroup.customerEmail?.trim().isNotEmpty == true)
        selectedGroup.customerEmail!.trim(),
      if (selectedGroup.customerPhone?.trim().isNotEmpty == true)
        selectedGroup.customerPhone!.trim(),
      if (selectedGroup.companyName?.trim().isNotEmpty == true)
        selectedGroup.companyName!.trim(),
      if (selectedGroup.customerNtn?.trim().isNotEmpty == true)
        'NTN ${selectedGroup.customerNtn!.trim()}',
      if (selectedGroup.customerCnic?.trim().isNotEmpty == true)
        'CNIC ${selectedGroup.customerCnic!.trim()}',
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedGroup.reference,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Service request',
              prefixIcon: Icon(Icons.folder_open_rounded),
            ),
            items: groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group.reference,
                    child: Text('${group.customerName} · ${group.reference}'),
                  ),
                )
                .toList(),
            onChanged: onSelected,
          ),
          const SizedBox(height: 16),
          Text(
            selectedGroup.customerName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedGroup.serviceTitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (selectedGroup.status?.trim().isNotEmpty == true)
                OmcStatusBadge(label: selectedGroup.status!),
              OmcStatusBadge(
                label: '${selectedGroup.documents.length} documents',
                color: AppTheme.textSecondary,
              ),
              if (selectedGroup.needsReview > 0)
                OmcStatusBadge(
                  label: '${selectedGroup.needsReview} need review',
                  color: AppTheme.warning,
                ),
              if (selectedGroup.rejected > 0)
                OmcStatusBadge(
                  label: '${selectedGroup.rejected} rejected',
                  color: AppTheme.danger,
                ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text(
                'Customer details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    meta.join(' · '),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _ReviewFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: selectedFilter == filter,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _ReviewDocumentCard extends StatelessWidget {
  const _ReviewDocumentCard({
    required this.document,
    required this.isBusy,
    required this.canReviewDocuments,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
  });

  final DocumentItem document;
  final bool isBusy;
  final bool canReviewDocuments;
  final VoidCallback onPreview;
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
    final statusColor = _statusColor(document);
    final remarks = document.remarks?.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (document.documentType?.trim().isNotEmpty == true)
                        document.documentType!.trim(),
                      if (document.updatedAtLabel?.trim().isNotEmpty == true)
                        document.updatedAtLabel!.trim(),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              );
              final badge = OmcStatusBadge(
                label: document.statusLabel,
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
          if (remarks != null && remarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                remarks,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: document.hasFile ? onPreview : null,
            icon: const Icon(Icons.visibility_outlined),
            label: Text(
              document.hasFile ? 'Preview document' : 'No file available',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => context.push(
                  '/documents/${Uri.encodeComponent(document.id)}',
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Document details'),
              ),
              TextButton.icon(
                onPressed: canOpenCase
                    ? () => context.push(
                        '/internal-workspace/service-cases/'
                        '${Uri.encodeComponent(serviceReference)}',
                      )
                    : null,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open case'),
              ),
            ],
          ),
          if (canReviewDocuments && !document.isArchived) ...[
            const Divider(height: 28),
            const Text(
              'Review decision',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                final approve = FilledButton.icon(
                  onPressed: canReview ? onApprove : null,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(isBusy ? 'Reviewing' : 'Approve'),
                );
                final reject = OutlinedButton.icon(
                  onPressed: canReview ? onReject : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                );

                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [approve, const SizedBox(height: 8), reject],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: approve),
                    const SizedBox(width: 10),
                    Expanded(child: reject),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(DocumentItem document) {
    if (document.isArchived) return AppTheme.textSecondary;

    switch (document.status) {
      case DocumentStatus.approved:
        return AppTheme.success;
      case DocumentStatus.rejected:
        return AppTheme.danger;
      case DocumentStatus.missing:
        return AppTheme.warning;
      case DocumentStatus.pendingReview:
        return AppTheme.warning;
      case DocumentStatus.uploaded:
        return AppTheme.info;
    }
  }
}

class _ReviewLoadingView extends StatelessWidget {
  const _ReviewLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
      children: const [
        PremiumListHeader(
          icon: Icons.fact_check_outlined,
          title: 'Document review',
          subtitle: 'Loading customer document queue from backend.',
          metaLabel: 'Loading',
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
