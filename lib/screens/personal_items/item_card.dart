import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';

class ItemCard extends ConsumerWidget {
  final ReminderItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool enableSwipe;
  final String? assigneeName; // Display name of assigned user
  final int pingCount;
  final VoidCallback? onPing;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.enableSwipe = true,
    this.assigneeName,
    this.pingCount = 0,
    this.onPing,
  });

  bool get _isOverdue =>
      !item.isCompleted &&
      item.remindAt != null &&
      item.remindAt!.isBefore(DateTime.now());

  Color _getPriorityColor(ItemPriority priority, ColorScheme colorScheme) {
    switch (priority) {
      case ItemPriority.high:
        return colorScheme.error;
      case ItemPriority.medium:
        return Colors.orange;
      case ItemPriority.low:
        return colorScheme.primary;
      case ItemPriority.none:
        return colorScheme.outline;
    }
  }

  IconData _getPriorityIcon(ItemPriority priority) {
    switch (priority) {
      case ItemPriority.high:
        return Icons.priority_high_rounded;
      case ItemPriority.medium:
        return Icons.remove_rounded;
      case ItemPriority.low:
        return Icons.arrow_downward_rounded;
      case ItemPriority.none:
        return Icons.horizontal_rule_rounded;
    }
  }

  String _formatRemindAt(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.MMMd();

    if (date == today) {
      return 'Today ${timeFormat.format(dateTime)}';
    } else if (date == tomorrow) {
      return 'Tomorrow ${timeFormat.format(dateTime)}';
    } else if (date.isBefore(today.add(const Duration(days: 7)))) {
      return '${DateFormat.EEEE().format(dateTime)} ${timeFormat.format(dateTime)}';
    } else {
      return '${dateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
    }
  }

  void _handleComplete(WidgetRef ref, bool value) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    HapticFeedback.mediumImpact();

    final itemService = ref.read(itemServiceProvider);
    final notificationService = ref.read(localNotificationServiceProvider);

    // Fire-and-forget for optimistic UI — Firestore stream updates the list
    itemService.toggleComplete(
      itemId: item.itemId,
      updatedByUid: user.uid,
      isCompleted: value,
      spaceId: item.spaceId,
      itemTitle: item.title,
    );

    // Best-effort notification management
    if (value) {
      notificationService.cancelItemNotification(item.itemId);
    } else if (item.remindAt != null && item.remindAt!.isAfter(DateTime.now())) {
      notificationService.scheduleItemNotification(
        item.copyWith(isCompleted: false),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    HapticFeedback.mediumImpact();

    final itemService = ref.read(itemServiceProvider);
    final notificationService = ref.read(localNotificationServiceProvider);

    // Store item for undo
    final deletedItem = item;

    // Show snackbar FIRST (before deleting)
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    bool undoPressed = false;
    final snackbarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${item.title}"'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            undoPressed = true;
            // Restore the item
            final restored = await itemService.restoreItem(
              deletedItem,
              actorUid: user.uid,
            );
            if (restored) {
              // Reschedule notification if needed
              if (deletedItem.remindAt != null &&
                  deletedItem.remindAt!.isAfter(DateTime.now()) &&
                  !deletedItem.isCompleted) {
                await notificationService.scheduleItemNotification(deletedItem);
              }
            }
          },
        ),
      ),
    );

    // Small delay to ensure snackbar is mounted, then delete from Firestore
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await notificationService.cancelItemNotification(item.itemId);
      await itemService.deleteItem(
        item.itemId,
        spaceId: item.spaceId,
        actorUid: user.uid,
        itemTitle: item.title,
      );

      // Wait for snackbar to close, if undo was pressed, restore
      final reason = await snackbarController.closed;
      if (undoPressed && reason == SnackBarClosedReason.action) {
        // Already handled in onPressed
        return;
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete item'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _isUnread(String? currentUserUid) {
    if (currentUserUid == null) return false;
    if (item.type == ItemType.personal) return false; // Personal items don't need unread
    return !item.viewedBy.contains(currentUserUid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = _getPriorityColor(item.priority, colorScheme);
    final currentUser = ref.watch(currentUserProvider);
    final isUnread = _isUnread(currentUser?.uid);

    Widget cardContent = Semantics(
      label: '${item.isCompleted ? "Completed: " : ""}${item.title}${_isOverdue ? ", overdue" : ""}',
      child: Card(
        margin: enableSwipe ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _isOverdue
          ? colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              _CompletionCheckbox(
                isCompleted: item.isCompleted,
                priorityColor: _isOverdue ? colorScheme.error : priorityColor,
                onChanged: (value) => _handleComplete(ref, value),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : _isOverdue
                                ? colorScheme.error
                                : null,
                      ),
                    ),

                    // Details
                    if (item.details != null && item.details!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.details!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Remind at, repeat, assignee, and nudge
                    if (item.remindAt != null || item.repeatRule != null || item.assignedToUid != null || onPing != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (item.remindAt != null)
                            _InfoChip(
                              icon: _isOverdue
                                  ? Icons.warning_rounded
                                  : Icons.schedule_rounded,
                              label: _isOverdue
                                  ? 'Overdue - ${_formatRemindAt(item.remindAt!)}'
                                  : _formatRemindAt(item.remindAt!),
                              isOverdue: _isOverdue,
                            ),
                          if (item.repeatRule != null)
                            _InfoChip(
                              icon: Icons.repeat_rounded,
                              label: item.repeatRule == 'daily'
                                  ? 'Daily'
                                  : 'Weekly',
                            ),
                          if (item.assignedToUid != null && assigneeName != null)
                            _InfoChip(
                              icon: Icons.person_outline_rounded,
                              label: assigneeName!,
                              isAssignee: true,
                            ),
                          if (onPing != null)
                            GestureDetector(
                              onTap: onPing,
                              child: const _InfoChip(
                                icon: Icons.notifications_active_rounded,
                                label: 'Nudge',
                                isNudge: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Priority indicator, unread dot, and ping badge
              if (item.priority != ItemPriority.none || isUnread || pingCount > 0) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if ((isUnread || pingCount > 0) && item.priority != ItemPriority.none)
                      const SizedBox(height: 4),
                    if (item.priority != ItemPriority.none)
                      Icon(
                        _getPriorityIcon(item.priority),
                        size: 18,
                        color: priorityColor,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );

    if (!enableSwipe) return cardContent;

    // Wrap with Dismissible inside Padding+ClipRRect so backgrounds
    // are clipped to the card's rounded shape instead of going edge-to-edge.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey('dismissible_${item.itemId}'),
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.3,
            DismissDirection.endToStart: 0.3,
          },
          movementDuration: const Duration(milliseconds: 200),
          resizeDuration: const Duration(milliseconds: 300),
          background: Container(
            color: item.isCompleted ? Colors.orange : Colors.green,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.isCompleted ? Icons.undo_rounded : Icons.check_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(item.isCompleted ? 'Undo' : 'Complete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          secondaryBackground: Container(
            color: colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(width: 8),
                Icon(Icons.delete_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right to complete/uncomplete
              _handleComplete(ref, !item.isCompleted);
              return false; // Don't dismiss, just toggle
            } else {
              // Swipe left to delete - keep in UI, deletion will be handled by StreamProvider
              await _handleDelete(context, ref);
              return false; // Don't dismiss from UI, let Firestore deletion handle it
            }
          },
          onDismissed: (direction) {
            onDelete?.call();
          },
          child: cardContent,
        ),
      ),
    );
  }
}

class _CompletionCheckbox extends StatefulWidget {
  final bool isCompleted;
  final Color priorityColor;
  final ValueChanged<bool> onChanged;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.priorityColor,
    required this.onChanged,
  });

  @override
  State<_CompletionCheckbox> createState() => _CompletionCheckboxState();
}

class _CompletionCheckboxState extends State<_CompletionCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isCompleted ? 'Mark as incomplete' : 'Mark as complete',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.mediumImpact();
          await _controller.forward();
          await _controller.reverse();
          widget.onChanged(!widget.isCompleted);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isCompleted
                      ? widget.priorityColor
                      : widget.priorityColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                color: widget.isCompleted
                    ? widget.priorityColor
                    : Colors.transparent,
              ),
              child: widget.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOverdue;
  final bool isAssignee;
  final bool isNudge;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.isOverdue = false,
    this.isAssignee = false,
    this.isNudge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    Color fgColor;

    if (isOverdue) {
      bgColor = colorScheme.error.withValues(alpha: 0.1);
      fgColor = colorScheme.error;
    } else if (isAssignee) {
      bgColor = colorScheme.tertiary.withValues(alpha: 0.1);
      fgColor = colorScheme.tertiary;
    } else if (isNudge) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      fgColor = Colors.orange;
    } else {
      bgColor = colorScheme.primary.withValues(alpha: 0.1);
      fgColor = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: fgColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
