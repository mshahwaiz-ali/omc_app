import 'package:flutter/material.dart';

import '../../data/document_item.dart';

class DocumentActionCard extends StatelessWidget {
  const DocumentActionCard({
    required this.document,
    required this.onPreview,
    required this.onUpload,
    required this.onDownload,
    super.key,
  });

  final DocumentItem document;
  final VoidCallback onPreview;
  final VoidCallback onUpload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPreview = document.fileName != null;
    final canDownload = document.fileName != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Upload, preview, and download actions are prepared for backend file endpoints.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
              icon: Icons.upload_file_rounded,
              title: document.requiresAction
                  ? 'Upload document'
                  : 'Replace document',
              subtitle: 'Attach a new file for backend upload.',
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
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.10),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
