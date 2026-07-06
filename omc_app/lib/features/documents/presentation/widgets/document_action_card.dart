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

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload, preview, and download actions are available when file links are provided.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.visibility_outlined,
              title: 'Preview document',
              subtitle: canPreview
                  ? 'Open the uploaded file preview.'
                  : 'Preview will be available after upload.',
              enabled: canPreview,
              onTap: onPreview,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: isUploading
                  ? Icons.hourglass_top_rounded
                  : Icons.upload_file_rounded,
              title: isUploading
                  ? 'Uploading document'
                  : document.requiresAction
                  ? 'Upload document'
                  : 'Replace document',
              subtitle: isUploading
                  ? 'Please wait while the file is uploaded.'
                  : 'Attach a new file for upload.',
              enabled: !isUploading,
              onTap: onUpload,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.download_rounded,
              title: 'Download document',
              subtitle: canDownload
                  ? 'Download the latest submitted file.'
                  : 'Download will be available after upload.',
              enabled: canDownload,
              onTap: onDownload,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primaryRed : AppTheme.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.primaryRed.withValues(alpha: 0.035)
              : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? AppTheme.primaryRed.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
