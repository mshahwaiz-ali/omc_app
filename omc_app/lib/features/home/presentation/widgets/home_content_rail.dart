import 'package:flutter/material.dart';

import '../../data/home_content.dart';

class HomeContentRail extends StatelessWidget {
  const HomeContentRail({required this.items, required this.onTap, super.key});

  final List<HomeContentCard> items;
  final ValueChanged<HomeContentCard> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _HomeContentCardView(
            item: items[index],
            onTap: () => onTap(items[index]),
          );
        },
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
    return SizedBox(
      width: 280,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8EAF0)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A111827),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.imageUrl != null)
                  SizedBox(
                    width: 92,
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImageFallback(),
                    ),
                  )
                else
                  const SizedBox(width: 92, child: _ImageFallback()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.category.trim().isNotEmpty)
                              Expanded(
                                child: Text(
                                  item.category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFDA1735),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.55,
                                  ),
                                ),
                              ),
                            if (item.urgency?.trim().isNotEmpty == true)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2F4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.urgency!,
                                  style: const TextStyle(
                                    color: Color(0xFFDA1735),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 15.5,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Text(
                            item.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (item.readTimeMinutes > 0) ...[
                              const Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.readTimeMinutes} min',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: Color(0xFF111827),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.article_outlined, color: Color(0xFF9CA3AF), size: 28),
      ),
    );
  }
}
