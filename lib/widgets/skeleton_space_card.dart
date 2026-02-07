import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SkeletonSpaceCard extends StatelessWidget {
  const SkeletonSpaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.onSurface.withValues(alpha: 0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Emoji placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name placeholder
                  Container(
                    height: 14,
                    width: 160,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Stats placeholder
                  Container(
                    height: 10,
                    width: 100,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow placeholder
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 0.ms)
        .then()
        .fade(
          begin: 1.0,
          end: 0.4,
          duration: 800.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .fade(
          begin: 0.4,
          end: 1.0,
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class SkeletonSpaceList extends StatelessWidget {
  final int count;
  const SkeletonSpaceList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SkeletonSpaceCard(),
          childCount: count,
        ),
      ),
    );
  }
}
