import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/space_model.dart';
import '../../providers/providers.dart';
import 'space_editor_sheet.dart';
import '../../widgets/skeleton_space_card.dart';
import '../../utils/error_messages.dart';
import '../../widgets/mascot_image.dart';

class SpacesListScreen extends ConsumerStatefulWidget {
  const SpacesListScreen({super.key});

  @override
  ConsumerState<SpacesListScreen> createState() => _SpacesListScreenState();
}

class _SpacesListScreenState extends ConsumerState<SpacesListScreen> {
  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(userSpacesProvider);
    ref.invalidate(pendingInvitesProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingCount = ref.watch(pendingInvitesCountProvider);
    final spacesAsync = ref.watch(userSpacesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Spaces'),
              actions: [
                if (pendingCount > 0)
                  Badge(
                    label: Text('$pendingCount'),
                    child: IconButton(
                      icon: const Icon(Icons.mail_outline_rounded),
                      onPressed: () => context.push('/invites'),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.mail_outline_rounded),
                    onPressed: () => context.push('/invites'),
                  ),
              ],
            ),
            spacesAsync.when(
              data: (spaces) {
                if (spaces.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(theme, colorScheme),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final space = spaces[index];
                        return _SpaceCard(space: space);
                      },
                      childCount: spaces.length,
                    ),
                  ),
                );
              },
              loading: () => const SkeletonSpaceList(),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MascotImage(
                        variant: MascotVariant.sad,
                        size: 100,
                        fallbackIcon: Icons.cloud_off_rounded,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        ErrorMessages.friendly(error),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          SpaceEditorSheet.show(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotImage(
            variant: MascotVariant.waving,
            size: 120,
            fallbackIcon: Icons.group_work_rounded,
          ),
          const SizedBox(height: 24),
          Text(
            'No spaces yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a space to share reminders\nwith friends and family',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              SpaceEditorSheet.show(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Space'),
          ),
        ],
      ),
    );
  }
}

class _SpaceCard extends ConsumerWidget {
  final Space space;

  const _SpaceCard({required this.space});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeCount = ref.watch(spaceActiveItemCountProvider(space.spaceId));
    final pingCount = ref.watch(spaceUnseenPingsCountProvider(space.spaceId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/spaces/${space.spaceId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji or icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: space.emoji != null
                      ? Text(
                          space.emoji!,
                          style: const TextStyle(fontSize: 24),
                        )
                      : Icon(
                          Icons.group_work_rounded,
                          color: colorScheme.primary,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and counts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${space.memberCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.check_box_outlined,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$activeCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: activeCount == 0
                                ? colorScheme.onSurface.withValues(alpha: 0.3)
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (pingCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pingCount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
