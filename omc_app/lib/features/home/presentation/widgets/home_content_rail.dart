import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../data/home_content.dart';

class HomeContentRail extends StatelessWidget {
  const HomeContentRail({
    required this.items,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final List<HomeContentCard> items;
  final ValueChanged<HomeContentCard> onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardWidth = textScale >= 1.5 ? 330.0 : 304.0;

    if (textScale >= 1.5) {
      return Padding(
        padding: padding,
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _HomeContentCardView(
                item: items[index],
                onTap: () => onTap(items[index]),
              ),
              if (index != items.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            SizedBox(
              width: cardWidth,
              child: _HomeContentCardView(
                item: items[index],
                onTap: () => onTap(items[index]),
              ),
            ),
            if (index != items.length - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HomeContentCardView extends StatelessWidget {
  const _HomeContentCardView({required this.item, required this.onTap});

  final HomeContentCard item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackImage = textScale >= 1.45;
    final secondary = _secondaryLabel(item);

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: item.imageUrl == null
          ? const _ImageFallback()
          : Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _ImageFallback(),
            ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (item.category.trim().isNotEmpty)
              Text(
                item.category.trim(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (item.urgency?.trim().isNotEmpty == true)
              _MetadataBadge(label: item.urgency!.trim()),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.title,
          softWrap: true,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        if (item.summary.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.summary.trim(),
            maxLines: textScale >= 1.5 ? null : 3,
            overflow: textScale >= 1.5
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (secondary.isNotEmpty)
              Expanded(
                child: Text(
                  secondary,
                  maxLines: textScale >= 1.5 ? null : 2,
                  overflow: textScale >= 1.5
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ],
    );

    return Semantics(
      button: true,
      label: item.title,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: stackImage
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 112, child: image),
                      const SizedBox(height: AppSpacing.sm),
                      content,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 86, height: 96, child: image),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: content),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Center(
        child: Icon(
          Icons.article_outlined,
          color: AppTheme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}

String _secondaryLabel(HomeContentCard item) {
  final values = <String>[
    if (item.contentType.trim().isNotEmpty) item.contentType.trim(),
    if (item.publishedOn?.trim().isNotEmpty == true) item.publishedOn!.trim(),
    if (item.effectiveDate?.trim().isNotEmpty == true &&
        item.effectiveDate!.trim() != item.publishedOn?.trim())
      item.effectiveDate!.trim(),
    if (item.readTimeMinutes > 0) '${item.readTimeMinutes} min read',
  ];
  return values.join(' · ');
}
