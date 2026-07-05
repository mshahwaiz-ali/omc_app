import 'package:flutter/material.dart';

class CrmDetailHeaderCard extends StatelessWidget {
  const CrmDetailHeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 26, child: Icon(icon)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(label: Text(statusLabel)),
          ],
        ),
      ),
    );
  }
}

class CrmDetailInfoCard extends StatelessWidget {
  const CrmDetailInfoCard({required this.title, required this.rows, super.key});

  final String title;
  final List<CrmInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrmInfoRow extends StatelessWidget {
  const CrmInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class CrmActivityTimelineCard extends StatelessWidget {
  const CrmActivityTimelineCard({
    required this.title,
    required this.emptyMessage,
    this.items = const [],
    super.key,
  });

  final String title;
  final String emptyMessage;
  final List<CrmTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            if (items.isEmpty)
              _TimelineEmptyMessage(message: emptyMessage)
            else
              ...items.map((item) => _TimelineItemTile(item: item)),
          ],
        ),
      ),
    );
  }
}

class CrmTimelineItem {
  const CrmTimelineItem({
    required this.title,
    required this.description,
    this.timeLabel,
    this.icon = Icons.circle_rounded,
  });

  final String title;
  final String description;
  final String? timeLabel;
  final IconData icon;
}

class _TimelineEmptyMessage extends StatelessWidget {
  const _TimelineEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TimelineItemTile extends StatelessWidget {
  const _TimelineItemTile({required this.item});

  final CrmTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 15, child: Icon(item.icon, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.timeLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.timeLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
