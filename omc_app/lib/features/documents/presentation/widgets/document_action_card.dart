import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../data/document_item.dart';

class DocumentActionCard extends StatelessWidget {
  const DocumentActionCard({
    required this.document,
    required this.onPreview,
    required this.onUpload,
    required this.onDownload,
    this.isUploading = false,
    super.key,
  });

  final DocumentItem document;
  final VoidCallback onPreview;
  final VoidCallback? onUpload;
  final VoidCallback onDownload;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final canPreview = document.previewUrl != null || document.fileUrl != null;
    final canDownload =
        document.downloadUrl != null || document.fileUrl != null;
    final requiresAction = document.requiresAction;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              requiresAction ? 'Action required' : 'File actions',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            requiresAction
                ? 'Upload the requested document before continuing with this service.'
                : 'Preview, download, or replace the latest submitted file.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (requiresAction) ...[
            FilledButton.icon(
              onPressed: isUploading ? null : onUpload,
              icon: isUploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                isUploading ? 'Uploading document' : 'Upload document',
              ),
            ),
            if (canPreview) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview current file'),
              ),
            ],
          ] else ...[
            if (canPreview)
              FilledButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview document'),
              )
            else
              const _UnavailableAction(
                icon: Icons.visibility_off_outlined,
                label: 'Preview will be available after a file is uploaded.',
              ),
            if (canDownload) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download document'),
              ),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isUploading ? null : onUpload,
              icon: isUploading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                isUploading ? 'Uploading document' : 'Replace document',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableAction extends StatelessWidget {
  const _UnavailableAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
