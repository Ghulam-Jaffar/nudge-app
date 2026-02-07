import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_model.dart';
import '../../models/item_model.dart';
import '../../models/space_model.dart';
import '../../providers/providers.dart';
import '../personal_items/item_card.dart';
import '../personal_items/item_editor_sheet.dart';
import 'invite_user_sheet.dart';
import 'space_activity_screen.dart';
import 'space_editor_sheet.dart';
import 'space_members_sheet.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  final String spaceId;

  const SpaceDetailScreen({
    super.key,
    required this.spaceId,
  });

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  int _selectedFilter = 0; // 0=All, 1=Incomplete, 2=Completed

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(spaceProvider(widget.spaceId));
    ref.invalidate(spaceItemsProvider(widget.spaceId));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _editItem(ReminderItem item) async {
    await ItemEditorSheet.show(
      context,
      item: item,
      spaceId: widget.spaceId,
    );
  }

  Future<void> _addItem(Space space) async {
    await ItemEditorSheet.show(
      context,
      spaceId: space.spaceId,
    );
  }

  void _showActivityScreen(Space space) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpaceActivityScreen(spaceId: space.spaceId),
      ),
    );
  }

  void _showMembersSheet(Space space) {
    SpaceMembersSheet.show(context, space: space);
  }

  void _showInviteSheet(Space space) {
    InviteUserSheet.show(context, space: space);
  }

  void _showEditSheet(Space space) {
    SpaceEditorSheet.show(context, space: space);
  }

  void _showSpaceMenu(Space space) {
    final currentUser = ref.read(currentUserProvider);
    final isOwner = space.ownerUid == currentUser?.uid;
    final member = currentUser != null ? space.members[currentUser.uid] : null;
    final isAdmin = member?.role == MemberRole.admin || isOwner;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Activity'),
              onTap: () {
                Navigator.pop(context);
                _showActivityScreen(space);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: const Text('Members'),
              subtitle: Text('${space.memberCount} members'),
              onTap: () {
                Navigator.pop(context);
                _showMembersSheet(space);
              },
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Invite'),
                onTap: () {
                  Navigator.pop(context);
                  _showInviteSheet(space);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Space'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSheet(space);
                },
              ),
            ],
            if (!isOwner)
              ListTile(
                leading: Icon(
                  Icons.exit_to_app_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Leave Space',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveSpace(space);
                },
              ),
            if (isOwner)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Space',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSpace(space);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSpace(Space space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Space'),
        content: Text(
          'Are you sure you want to delete "${space.name}"? '
          'This will permanently delete all items in this space. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final spaceService = ref.read(spaceServiceProvider);

    bool success = false;
    try {
      success = await spaceService.deleteSpace(space.spaceId);
    } catch (e) {
      debugPrint('Error deleting space: $e');
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${space.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete space'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmLeaveSpace(Space space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Space'),
        content: Text(
          'Are you sure you want to leave "${space.name}"? '
          'You will no longer have access to items in this space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final spaceService = ref.read(spaceServiceProvider);
    final success = await spaceService.removeMember(
      spaceId: space.spaceId,
      uid: currentUser.uid,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${space.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to leave space'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  bool _canPing(ReminderItem item) {
    final currentUser = ref.read(currentUserProvider);
    return item.assignedToUid != null &&
        item.assignedToUid != currentUser?.uid &&
        !item.isCompleted;
  }

  Future<void> _sendPing(ReminderItem item, Space space) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || item.assignedToUid == null) return;

    HapticFeedback.lightImpact();

    final pingService = ref.read(pingServiceProvider);
    final activityService = ref.read(activityServiceProvider);

    final ping = await pingService.createPing(
      spaceId: space.spaceId,
      itemId: item.itemId,
      itemTitle: item.title,
      fromUid: currentUser.uid,
      toUid: item.assignedToUid!,
    );

    if (!mounted) return;

    if (ping != null) {
      // Log activity with visibleTo (private to sender + receiver)
      try {
        await activityService.createActivity(
          spaceId: space.spaceId,
          actorUid: currentUser.uid,
          type: ActivityType.ping,
          targetUid: item.assignedToUid,
          itemId: item.itemId,
          itemTitle: item.title,
          visibleTo: [currentUser.uid, item.assignedToUid!],
        );
      } catch (e) {
        debugPrint('Error logging ping activity: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nudged about "${item.title}"!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send nudge. Try again.'),
          ),
        );
      }
    }
  }

  List<ReminderItem> _filterItems(List<ReminderItem> items) {
    switch (_selectedFilter) {
      case 1:
        return items.where((item) => !item.isCompleted).toList();
      case 2:
        return items.where((item) => item.isCompleted).toList();
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spaceAsync = ref.watch(spaceProvider(widget.spaceId));
    final itemsAsync = ref.watch(spaceItemsProvider(widget.spaceId));

    return spaceAsync.when(
      data: (space) {
        if (space == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Space not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (space.emoji != null) ...[
                  Text(space.emoji!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(space.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.group_add_outlined),
                onPressed: () => _showInviteSheet(space),
                tooltip: 'Invite',
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showSpaceMenu(space),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Filter chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedFilter == 0,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = 0);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'To Do',
                          isSelected: _selectedFilter == 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = 1);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Done',
                          isSelected: _selectedFilter == 2,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = 2);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Swipe hint
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Swipe right to complete, left to delete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Items list
                itemsAsync.when(
                  data: (items) {
                    final filteredItems = _filterItems(items);

                    if (filteredItems.isEmpty) {
                      return SliverFillRemaining(
                        child: _buildEmptyState(theme, colorScheme, items.isEmpty, space),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredItems[index];
                            final canPing = _canPing(item);
                            final pingCount = ref.watch(
                              itemUnseenPingsCountProvider(item.itemId),
                            );
                            return ItemCard(
                              key: ValueKey(item.itemId),
                              item: item,
                              onTap: () => _editItem(item),
                              pingCount: pingCount,
                              onPing: canPing
                                  ? () => _sendPing(item, space)
                                  : null,
                            );
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => SliverFillRemaining(
                    child: _buildErrorState(theme, colorScheme),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.lightImpact();
              _addItem(space);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('New'),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: _buildErrorState(theme, colorScheme),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 50,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to try again',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme, bool noItems, Space space) {
    final message = noItems
        ? 'No items yet'
        : _selectedFilter == 1
            ? 'All done!'
            : 'No completed items';
    final subtitle = noItems
        ? 'Add items for everyone in this space to see'
        : _selectedFilter == 1
            ? 'Great teamwork!'
            : 'Complete items to see them here';
    final icon = noItems
        ? Icons.checklist_rounded
        : _selectedFilter == 1
            ? Icons.celebration_rounded
            : Icons.check_circle_outline_rounded;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (noItems || _selectedFilter == 2)
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _addItem(space);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
