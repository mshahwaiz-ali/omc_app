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
  final _searchController = TextEditingController();
  _ReviewFilter _selectedFilter = _ReviewFilter.needsReview;
  late Future<List<DocumentItem>> _documentsFuture;
  String _query = '';
  String? _selectedCustomerProfile;
  String? _selectedDocumentType;
  String? _selectedServiceReference;
  String? _busyDocumentId;

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
      _selectedCustomerProfile = null;
      _selectedDocumentType = null;
      _selectedServiceReference = null;
      _documentsFuture = _loadDocuments();
    });
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

    if (!mounted || _busyDocumentId != null) return;
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
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onFilterSelected,
    required this.onCustomerSelected,
    required this.onDocumentTypeSelected,
    required this.onServiceSelected,
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
        _WorkspaceFilterRow(
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

class _WorkspaceFilterRow extends StatelessWidget {
  const _WorkspaceFilterRow({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

        final customerField = _CustomerFilterField(
          options: customerOptions,
          selectedCustomerProfile: selectedCustomerProfile,
          onSelected: onCustomerSelected,
        );

        final typeField = _DocumentTypeFilterField(
          options: documentTypeOptions,
          selectedDocumentType: selectedDocumentType,
          onSelected: onDocumentTypeSelected,
        );

        if (compact) {
          return Column(
            children: [customerField, const SizedBox(height: 10), typeField],
          );
        }

        return Row(
          children: [
            Expanded(child: customerField),
            const SizedBox(width: 10),
            Expanded(child: typeField),
          ],
        );
      },
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
          const SizedBox(height: 10),
          _CompactCustomerMeta(group: selectedGroup),
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
    final statusColor = _statusColor(document);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () =>
          context.push('/documents/${Uri.encodeComponent(document.id)}'),
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
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: canOpenCase
                      ? () => context.push(
                          '/my-services/${Uri.encodeComponent(serviceReference)}',
                        )
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Case'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: _documentNavy,
                    side: const BorderSide(color: Color(0xFFD8DFEC)),
                  ),
                ),
                FilledButton.icon(
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: _approvedGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: canReview ? onReject : null,
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: _rejectedRed,
                    side: BorderSide(
                      color: _rejectedRed.withValues(alpha: 0.34),
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
