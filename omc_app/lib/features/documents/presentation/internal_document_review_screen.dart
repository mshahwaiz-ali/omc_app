import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
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
import 'document_preview_screen.dart';

const _documentIndigo = Color(0xFF4F46E5);
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
    return repository.fetchDocumentPage(queue: _selectedFilter.queue);
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
          .fetchDocumentPage(queue: _selectedFilter.queue, start: start);
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
    setState(() {
      _selectedCustomerProfile = customerProfile;
      _selectedServiceReference = null;
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
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () {
                        final value = controller.text.trim();
                        dirtyFormController.submissionSucceeded();
                        Navigator.of(dialogContext).pop(value);
                      },
                child: const Text('Reject'),
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

              return Stack(
                children: [
                  _ReviewContent(
                    documents: documents,
                    searchController: _searchController,
                    query: _query,
                    selectedFilter: _selectedFilter,
                    selectedCustomerProfile: _selectedCustomerProfile,
                    selectedDocumentType: _selectedDocumentType,
                    selectedServiceReference: _selectedServiceReference,
                    busyDocumentId: _busyDocumentId,
                    canReviewDocuments: canReviewDocuments,
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
                    onApprove: (document) =>
                        _reviewDocument(document, 'Approved'),
                    onReject: _rejectWithRemarks,
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
                            _loadingMore
                                ? 'Loading review queue'
                                : 'Load more documents',
                          ),
                        ),
                      ),
                    ),
                ],
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

    final needsReview = filteredDocuments
        .where((item) => item.isUnderReview)
        .length;
    final rejected = filteredDocuments
        .where((item) => item.status == DocumentStatus.rejected)
        .length;
    final approved = filteredDocuments
        .where((item) => item.status == DocumentStatus.approved)
        .length;
    final archived = filteredDocuments.where((item) => item.isArchived).length;
    final groups = _ServiceDocumentGroup.fromDocuments(filteredDocuments);
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
        _CompactMetricsStrip(
          needsReview: needsReview,
          rejected: rejected,
          approved: approved,
          archived: archived,
        ),
        const SizedBox(height: 12),
        _InternalDocumentSearchField(
          controller: searchController,
          onChanged: onQueryChanged,
          onClear: onClearQuery,
        ),
        const SizedBox(height: 10),
        _CompactFilterPanel(
          customerOptions: customerOptions,
          selectedCustomerProfile: selectedCustomerProfile,
          documentTypeOptions: documentTypeOptions,
          selectedDocumentType: selectedDocumentType,
          onCustomerSelected: onCustomerSelected,
          onDocumentTypeSelected: onDocumentTypeSelected,
        ),
        const SizedBox(height: 10),
        _ReviewFilterBar(
          selectedFilter: selectedFilter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 12),
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
          _ServiceWorkspaceHeader(
            groups: groups,
            selectedGroup: selectedGroup,
            onSelected: onServiceSelected,
          ),
          const SizedBox(height: 12),
          for (final document in selectedGroup.documents) ...[
            _ReviewDocumentCard(
              document: document,
              isBusy: busyDocumentId == document.id,
              canReviewDocuments: canReviewDocuments,
              onPreview: () => onPreview(document),
              onApprove: () => onApprove(document),
              onReject: () => onReject(document),
            ),
            const SizedBox(height: 10),
          ],
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

class _InternalDocumentSearchField extends StatelessWidget {
  const _InternalDocumentSearchField({
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
        border: Border.all(color: AppTheme.border),
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
          hintText: 'Search customer, request, service or document',
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

class _CompactFilterPanel extends StatelessWidget {
  const _CompactFilterPanel({
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

    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      leading: const Icon(Icons.tune_rounded, color: _documentIndigo),
      title: const Text(
        'Filters',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        activeCount == 0 ? 'Customer and document type' : '$activeCount active',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        _CustomerFilterField(
          options: customerOptions,
          selectedCustomerProfile: selectedCustomerProfile,
          onSelected: onCustomerSelected,
        ),
        const SizedBox(height: 10),
        _DocumentTypeFilterField(
          options: documentTypeOptions,
          selectedDocumentType: selectedDocumentType,
          onSelected: onDocumentTypeSelected,
        ),
      ],
    );
  }
}

class _CustomerFilterField extends StatelessWidget {
  const _CustomerFilterField({
    required this.options,
    required this.selectedCustomerProfile,
    required this.onSelected,
  });

  final List<_CustomerFilterOption> options;
  final String? selectedCustomerProfile;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCustomerProfile ?? '',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Customer',
        prefixIcon: Icon(Icons.person_search_rounded, color: _documentIndigo),
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('All customers')),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option.profile,
            child: Text(
              [
                option.label,
                if (option.email?.trim().isNotEmpty == true)
                  option.email!.trim(),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) =>
          onSelected(value == null || value.isEmpty ? null : value),
    );
  }
}

class _DocumentTypeFilterField extends StatelessWidget {
  const _DocumentTypeFilterField({
    required this.options,
    required this.selectedDocumentType,
    required this.onSelected,
  });

  final List<String> options;
  final String? selectedDocumentType;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedDocumentType ?? '',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Document type',
        prefixIcon: Icon(Icons.category_outlined, color: _documentIndigo),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('All document types'),
        ),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option,
            child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) =>
          onSelected(value == null || value.isEmpty ? null : value),
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

class _ServiceWorkspaceHeader extends StatelessWidget {
  const _ServiceWorkspaceHeader({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<_ServiceDocumentGroup> groups;
  final _ServiceDocumentGroup selectedGroup;
  final ValueChanged<String?> onSelected;

  bool _hasCustomerMeta(_ServiceDocumentGroup group) {
    return [
      group.customerEmail,
      group.customerPhone,
      group.companyName,
      group.customerNtn,
      group.customerCnic,
    ].any((value) => value != null && value.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedGroup.reference,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Service request',
              prefixIcon: Icon(
                Icons.folder_open_rounded,
                color: _documentIndigo,
              ),
            ),
            items: groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group.reference,
                    child: Text(
                      '${group.customerName} · ${group.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSelected,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _documentIndigo.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  color: _documentIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedGroup.customerName,
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
                      selectedGroup.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (selectedGroup.status != null)
                          PremiumInfoChip(label: selectedGroup.status!),
                        PremiumInfoChip(
                          label: '${selectedGroup.documents.length} docs',
                        ),
                        if (selectedGroup.needsReview > 0)
                          PremiumInfoChip(
                            label: '${selectedGroup.needsReview} review',
                            color: _reviewTeal,
                          ),
                        if (selectedGroup.rejected > 0)
                          PremiumInfoChip(
                            label: '${selectedGroup.rejected} rejected',
                            color: _rejectedRed,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasCustomerMeta(selectedGroup)) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text(
                'Customer details',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CompactCustomerMeta(group: selectedGroup),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactCustomerMeta extends StatelessWidget {
  const _CompactCustomerMeta({required this.group});

  final _ServiceDocumentGroup group;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (group.customerEmail?.trim().isNotEmpty == true)
        group.customerEmail!.trim(),
      if (group.customerPhone?.trim().isNotEmpty == true)
        group.customerPhone!.trim(),
      if (group.companyName?.trim().isNotEmpty == true)
        group.companyName!.trim(),
      if (group.customerNtn?.trim().isNotEmpty == true)
        'NTN ${group.customerNtn!.trim()}',
      if (group.customerCnic?.trim().isNotEmpty == true)
        'CNIC ${group.customerCnic!.trim()}',
    ];

    if (values.isEmpty) return const SizedBox.shrink();

    return Text(
      values.join('  •  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: document.hasFile ? onPreview : null,
      child: PremiumCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    document.isArchived
                        ? Icons.archive_rounded
                        : Icons.description_outlined,
                    color: statusColor,
                    size: 19,
                  ),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (document.documentType?.trim().isNotEmpty == true)
                            document.documentType!.trim(),
                          document.statusLabel,
                          if (document.updatedAtLabel?.trim().isNotEmpty ==
                              true)
                            document.updatedAtLabel!.trim(),
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  document.hasFile
                      ? Icons.visibility_outlined
                      : Icons.insert_drive_file_outlined,
                  color: document.hasFile
                      ? _documentIndigo
                      : AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
            if (document.remarks?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  document.remarks!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: document.hasFile ? onPreview : null,
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      foregroundColor: _documentIndigo,
                      side: BorderSide(
                        color: _documentIndigo.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Document details',
                  onPressed: () => context.push(
                    '/documents/${Uri.encodeComponent(document.id)}',
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Open case',
                  onPressed: canOpenCase
                      ? () => context.push(
                          '/internal-workspace/service-cases/'
                          '${Uri.encodeComponent(serviceReference)}',
                        )
                      : null,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                ),
              ],
            ),
            if (canReviewDocuments && !document.isArchived) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canReview ? onApprove : null,
                      icon: isBusy
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        backgroundColor: _approvedGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canReview ? onReject : null,
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
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

class _CompactMetricsStrip extends StatelessWidget {
  const _CompactMetricsStrip({
    required this.needsReview,
    required this.rejected,
    required this.approved,
    required this.archived,
  });

  final int needsReview;
  final int rejected;
  final int approved;
  final int archived;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CompactMetric(
            icon: Icons.hourglass_top_rounded,
            label: 'Review',
            value: needsReview,
            color: _reviewTeal,
          ),
          _CompactMetric(
            icon: Icons.error_outline_rounded,
            label: 'Rejected',
            value: rejected,
            color: _rejectedRed,
          ),
          _CompactMetric(
            icon: Icons.verified_rounded,
            label: 'Approved',
            value: approved,
            color: _approvedGreen,
          ),
          _CompactMetric(
            icon: Icons.archive_rounded,
            label: 'Archive',
            value: archived,
            color: _archivedSlate,
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
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
