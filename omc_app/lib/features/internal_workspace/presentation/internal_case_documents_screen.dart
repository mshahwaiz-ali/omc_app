import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../../documents/data/document_item.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/presentation/document_preview_screen.dart';

class InternalCaseDocumentsScreen extends ConsumerStatefulWidget {
  const InternalCaseDocumentsScreen({
    required this.serviceRequest,
    required this.customerName,
    super.key,
  });

  final String serviceRequest;
  final String customerName;

  @override
  ConsumerState<InternalCaseDocumentsScreen> createState() =>
      _InternalCaseDocumentsScreenState();
}

class _InternalCaseDocumentsScreenState
    extends ConsumerState<InternalCaseDocumentsScreen> {
  final List<DocumentItem> _documents = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextStart;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _documents.clear();
        _nextStart = null;
        _hasMore = false;
      });
    } else {
      if (_loadingMore || !_hasMore || _nextStart == null) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ref.read(documentsRepositoryProvider).fetchDocumentPage(
        serviceRequest: widget.serviceRequest,
        start: reset ? 0 : _nextStart!,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        final known = _documents.map((item) => item.id).toSet();
        _documents.addAll(page.items.where((item) => known.add(item.id)));
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackHeader(
        title: 'Case documents',
        subtitle: widget.customerName,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Text(
              widget.serviceRequest,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Read-only evidence for this service request. Review authority remains in the document review workspace.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              AppErrorState.fromError(
                error: _error!,
                fallbackTitle: 'Case documents unavailable',
                fallbackMessage:
                    'The scoped document evidence could not be loaded.',
                onRetry: () => _load(reset: true),
              )
            else if (_documents.isEmpty)
              const AppEmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No case documents',
                message: 'No document evidence is available for this request.',
              )
            else
              for (final document in _documents) ...[
                _CaseDocumentCard(
                  document: document,
                  onOpen: document.hasFile ? () => _open(document) : null,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            if (_hasMore) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingMore ? 'Loading' : 'Load more'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(DocumentItem document) async {
    try {
      final file = await ref
          .read(documentsRepositoryProvider)
          .downloadDocument(document);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            fileName: file.name,
            bytes: file.bytes,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Document unavailable',
        fallbackMessage: 'This document could not be opened right now.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _CaseDocumentCard extends StatelessWidget {
  const _CaseDocumentCard({required this.document, required this.onOpen});

  final DocumentItem document;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (document.updatedAtLabel?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Updated ${document.updatedAtLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(onOpen == null ? 'No file attached' : 'Open document'),
            ),
          ),
        ],
      ),
    );
  }
}
