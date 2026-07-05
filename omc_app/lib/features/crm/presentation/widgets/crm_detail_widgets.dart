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
