import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';

class ItemEditorSheet extends ConsumerStatefulWidget {
  final ReminderItem? item; // null for new item
  final String? spaceId; // null for personal item

  const ItemEditorSheet({
    super.key,
    this.item,
    this.spaceId,
  });

  static Future<bool?> show(
    BuildContext context, {
    ReminderItem? item,
    String? spaceId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ItemEditorSheet(
        item: item,
        spaceId: spaceId,
      ),
    );
  }

  @override
  ConsumerState<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends ConsumerState<ItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime? _remindAt;
  TimeOfDay? _remindTime;
  ItemPriority _priority = ItemPriority.none;
  String? _repeatRule;
  bool _isLoading = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.item!.title;
      _detailsController.text = widget.item!.details ?? '';
      _remindAt = widget.item!.remindAt;
      if (_remindAt != null) {
        _remindTime = TimeOfDay.fromDateTime(_remindAt!);
      }
      _priority = widget.item!.priority;
      _repeatRule = widget.item!.repeatRule;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  DateTime? _combineDateAndTime() {
    if (_remindAt == null) return null;

    final time = _remindTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      _remindAt!.year,
      _remindAt!.month,
      _remindAt!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remindAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (date != null && mounted) {
      setState(() => _remindAt = date);

      // If no time set, prompt for time
      if (_remindTime == null) {
        _selectTime();
      }
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _remindTime ?? TimeOfDay.now(),
    );

    if (time != null && mounted) {
      setState(() => _remindTime = time);
    }
  }

  void _clearReminder() {
    setState(() {
      _remindAt = null;
      _remindTime = null;
      _repeatRule = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    final itemService = ref.read(itemServiceProvider);
    final notificationService = ref.read(localNotificationServiceProvider);
    final combinedDateTime = _combineDateAndTime();

    bool success = false;
    ReminderItem? resultItem;

    if (_isEditing) {
      // Update existing item
      success = await itemService.updateItem(
        itemId: widget.item!.itemId,
        updatedByUid: user.uid,
        title: _titleController.text.trim(),
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
        remindAt: combinedDateTime,
        clearRemindAt: combinedDateTime == null && widget.item!.remindAt != null,
        priority: _priority,
        repeatRule: _repeatRule,
        clearRepeatRule: _repeatRule == null && widget.item!.repeatRule != null,
      );

      if (success) {
        // Update notification
        await notificationService.cancelItemNotification(widget.item!.itemId);
        if (combinedDateTime != null) {
          final updatedItem = widget.item!.copyWith(
            title: _titleController.text.trim(),
            remindAt: combinedDateTime,
            priority: _priority,
            repeatRule: _repeatRule,
          );
          await notificationService.scheduleItemNotification(updatedItem);
        }
      }
    } else {
      // Create new item
      if (widget.spaceId != null) {
        resultItem = await itemService.createSpaceItem(
          spaceId: widget.spaceId!,
          createdByUid: user.uid,
          title: _titleController.text.trim(),
          details: _detailsController.text.trim().isEmpty
              ? null
              : _detailsController.text.trim(),
          remindAt: combinedDateTime,
          priority: _priority,
          repeatRule: _repeatRule,
        );
      } else {
        resultItem = await itemService.createPersonalItem(
          ownerUid: user.uid,
          title: _titleController.text.trim(),
          details: _detailsController.text.trim().isEmpty
              ? null
              : _detailsController.text.trim(),
          remindAt: combinedDateTime,
          priority: _priority,
          repeatRule: _repeatRule,
        );
      }

      success = resultItem != null;

      // Schedule notification for new item
      if (resultItem != null && combinedDateTime != null) {
        await notificationService.scheduleItemNotification(resultItem);
      }
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Failed to update item' : 'Failed to create item'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
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

    setState(() => _isLoading = true);

    final itemService = ref.read(itemServiceProvider);
    final notificationService = ref.read(localNotificationServiceProvider);

    await notificationService.cancelItemNotification(widget.item!.itemId);
    final success = await itemService.deleteItem(widget.item!.itemId);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete item'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat.MMMd();
    final timeFormat = DateFormat.jm();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Text(
                    _isEditing ? 'Edit Reminder' : 'New Reminder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'What do you need to remember?',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                        autofocus: !_isEditing,
                      ),

                      const SizedBox(height: 16),

                      // Details
                      TextFormField(
                        controller: _detailsController,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Details (optional)',
                          hintText: 'Add any additional notes',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Remind At section
                      Text(
                        'Reminder',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _selectDate,
                              icon: const Icon(Icons.calendar_today_rounded),
                              label: Text(
                                _remindAt != null
                                    ? dateFormat.format(_remindAt!)
                                    : 'Set date',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading || _remindAt == null
                                  ? null
                                  : _selectTime,
                              icon: const Icon(Icons.access_time_rounded),
                              label: Text(
                                _remindTime != null
                                    ? timeFormat.format(DateTime(
                                        2000, 1, 1, _remindTime!.hour, _remindTime!.minute))
                                    : 'Set time',
                              ),
                            ),
                          ),
                          if (_remindAt != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isLoading ? null : _clearReminder,
                              icon: const Icon(Icons.clear_rounded),
                              tooltip: 'Clear reminder',
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Repeat
                      if (_remindAt != null) ...[
                        Text(
                          'Repeat',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String?>(
                          segments: const [
                            ButtonSegment(
                              value: null,
                              label: Text('Never'),
                            ),
                            ButtonSegment(
                              value: 'daily',
                              label: Text('Daily'),
                            ),
                            ButtonSegment(
                              value: 'weekly',
                              label: Text('Weekly'),
                            ),
                          ],
                          selected: {_repeatRule},
                          onSelectionChanged: _isLoading
                              ? null
                              : (selection) {
                                  setState(() => _repeatRule = selection.first);
                                },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Priority
                      Text(
                        'Priority',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ItemPriority>(
                        segments: const [
                          ButtonSegment(
                            value: ItemPriority.none,
                            label: Text('None'),
                          ),
                          ButtonSegment(
                            value: ItemPriority.low,
                            label: Text('Low'),
                          ),
                          ButtonSegment(
                            value: ItemPriority.medium,
                            label: Text('Med'),
                          ),
                          ButtonSegment(
                            value: ItemPriority.high,
                            label: Text('High'),
                          ),
                        ],
                        selected: {_priority},
                        onSelectionChanged: _isLoading
                            ? null
                            : (selection) {
                                setState(() => _priority = selection.first);
                              },
                      ),

                      // Delete button (only for editing)
                      if (_isEditing) ...[
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _delete,
                          icon: Icon(Icons.delete_outline_rounded,
                              color: colorScheme.error),
                          label: Text(
                            'Delete Reminder',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.error),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
