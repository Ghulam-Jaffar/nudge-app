import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';
import 'item_card.dart';
import 'item_editor_sheet.dart';
import '../../widgets/skeleton_item_card.dart';
import '../../utils/error_messages.dart';
import '../../widgets/mascot_image.dart';

enum PersonalItemsFilter { today, upcoming, completed }

class PersonalItemsScreen extends ConsumerStatefulWidget {
  const PersonalItemsScreen({super.key});

  @override
  ConsumerState<PersonalItemsScreen> createState() =>
      _PersonalItemsScreenState();
}

class _PersonalItemsScreenState extends ConsumerState<PersonalItemsScreen> {
  PersonalItemsFilter _currentFilter = PersonalItemsFilter.today;

  List<ReminderItem> _filterItems(List<ReminderItem> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    switch (_currentFilter) {
      case PersonalItemsFilter.today:
        return items.where((item) {
          if (item.isCompleted) return false;
          // Items due today OR overdue items OR items without a date
          if (item.remindAt == null) return false;
          return item.remindAt!.isBefore(todayEnd);
        }).toList()
          ..sort((a, b) {
            // Sort by remind time, putting overdue first
            if (a.remindAt == null) return 1;
            if (b.remindAt == null) return -1;
            return a.remindAt!.compareTo(b.remindAt!);
          });

      case PersonalItemsFilter.upcoming:
        return items.where((item) {
          if (item.isCompleted) return false;
          // Items without date OR future items
          if (item.remindAt == null) return true;
          return item.remindAt!.isAfter(todayEnd) ||
              item.remindAt!.isAtSameMomentAs(todayEnd);
        }).toList()
          ..sort((a, b) {
            // Sort by remind time, items without date at end
            if (a.remindAt == null && b.remindAt == null) {
              return a.createdAt.compareTo(b.createdAt);
            }
            if (a.remindAt == null) return 1;
            if (b.remindAt == null) return -1;
            return a.remindAt!.compareTo(b.remindAt!);
          });

      case PersonalItemsFilter.completed:
        return items.where((item) => item.isCompleted).toList()
          ..sort((a, b) {
            // Sort by completion time, most recent first
            final aTime = a.completedAt ?? a.updatedAt;
            final bTime = b.completedAt ?? b.updatedAt;
            return bTime.compareTo(aTime);
          });
    }
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case PersonalItemsFilter.today:
        return 'All clear for today!';
      case PersonalItemsFilter.upcoming:
        return 'Nothing scheduled';
      case PersonalItemsFilter.completed:
        return 'No completed tasks yet';
    }
  }

  String _getEmptySubtitle() {
    switch (_currentFilter) {
      case PersonalItemsFilter.today:
        return 'Enjoy your day or add a new reminder';
      case PersonalItemsFilter.upcoming:
        return 'Plan ahead by scheduling future reminders';
      case PersonalItemsFilter.completed:
        return 'Complete tasks to see them here';
    }
  }

  IconData _getEmptyIcon() {
    switch (_currentFilter) {
      case PersonalItemsFilter.today:
        return Icons.wb_sunny_rounded;
      case PersonalItemsFilter.upcoming:
        return Icons.event_note_rounded;
      case PersonalItemsFilter.completed:
        return Icons.celebration_rounded;
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(personalItemsProvider);
    // Wait a bit for the stream to refresh
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _createItem() async {
    final result = await ItemEditorSheet.show(context);
    if (result == true) {
      // Item created, Firestore will update the list automatically
    }
  }

  Future<void> _editItem(ReminderItem item) async {
    final result = await ItemEditorSheet.show(context, item: item);
    if (result == true) {
      // Item updated/deleted, Firestore will update the list automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemsAsync = ref.watch(personalItemsProvider);
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: Row(
                children: [
                  Text('Hey${appUser != null ? ", ${appUser.displayName.split(' ').first}" : ""}!'),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<PersonalItemsFilter>(
                  segments: const [
                    ButtonSegment(
                      value: PersonalItemsFilter.today,
                      label: Text('Today'),
                      icon: Icon(Icons.today_rounded),
                    ),
                    ButtonSegment(
                      value: PersonalItemsFilter.upcoming,
                      label: Text('Later'),
                      icon: Icon(Icons.schedule_rounded),
                    ),
                    ButtonSegment(
                      value: PersonalItemsFilter.completed,
                      label: Text('Done'),
                      icon: Icon(Icons.check_circle_outline_rounded),
                    ),
                  ],
                  selected: {_currentFilter},
                  onSelectionChanged: (Set<PersonalItemsFilter> selection) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentFilter = selection.first;
                    });
                  },
                ),
              ),
            ),
            // Swipe hint for first-time users
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
            itemsAsync.when(
              data: (items) {
                final filteredItems = _filterItems(items);

                if (filteredItems.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MascotImage(
                            variant: _currentFilter == PersonalItemsFilter.completed
                                ? MascotVariant.celebrating
                                : MascotVariant.happy,
                            size: 120,
                            fallbackIcon: _getEmptyIcon(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _getEmptyMessage(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getEmptySubtitle(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (_currentFilter != PersonalItemsFilter.completed)
                            FilledButton.icon(
                              onPressed: _createItem,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Reminder'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredItems[index];
                        return ItemCard(
                          item: item,
                          onTap: () => _editItem(item),
                        );
                      },
                      childCount: filteredItems.length,
                    ),
                  ),
                );
              },
              loading: () => const SkeletonItemList(),
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
          _createItem();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
    );
  }
}
