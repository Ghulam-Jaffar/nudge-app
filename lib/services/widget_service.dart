import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../models/item_model.dart';
import '../theme/theme_packs.dart';

/// Extension to convert Color to ARGB int32 for Android widgets
extension ColorToInt on Color {
  int toARGB32() {
    return ((a * 255).round() << 24) |
           ((r * 255).round() << 16) |
           ((g * 255).round() << 8) |
           ((b * 255).round());
  }
}

/// Service to sync reminder data and theme colors to the Android home screen widget.
class WidgetService {
  static const String _appGroupId = 'com.sharedreminder.shared_reminder_app';
  static const String _androidWidgetName = 'NudgeWidgetProviderSimple';

  /// Initialize home_widget with app group ID.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Update the widget with today's reminders and current theme.
  static Future<void> updateWidget({
    required List<ReminderItem> todayItems,
    required ThemePack themePack,
    required bool isDark,
  }) async {
    try {
      // Sort: incomplete first, then by remind time
      final sorted = List<ReminderItem>.from(todayItems)
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          if (a.remindAt == null && b.remindAt == null) return 0;
          if (a.remindAt == null) return 1;
          if (b.remindAt == null) return -1;
          return a.remindAt!.compareTo(b.remindAt!);
        });

      // Take up to 5 items for the widget (matches Android provider limit)
      final widgetItems = sorted.take(5).toList();

      // Serialize items as JSON array
      final itemsJson = jsonEncode(widgetItems.map((item) => {
        'title': item.title,
        'isCompleted': item.isCompleted,
        'remindAt': item.remindAt?.toIso8601String(),
        'priority': item.priority.name,
        'isOverdue': !item.isCompleted &&
            item.remindAt != null &&
            item.remindAt!.isBefore(DateTime.now()),
      }).toList());

      // Save data to shared storage
      await HomeWidget.saveWidgetData<bool>('signed_in', true);
      await HomeWidget.saveWidgetData<String>('items_json', itemsJson);
      await HomeWidget.saveWidgetData<int>('item_count', todayItems.length);
      await HomeWidget.saveWidgetData<int>('incomplete_count',
          todayItems.where((i) => !i.isCompleted).length);

      // Theme colors (as ARGB int values for Android)
      await HomeWidget.saveWidgetData<int>(
          'theme_primary', themePack.primaryColor.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_background',
          isDark
              ? themePack.backgroundColor.toARGB32()
              : Colors.white.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_card',
          isDark
              ? themePack.cardColor.toARGB32()
              : Colors.white.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_text',
          isDark ? Colors.white.toARGB32() : const Color(0xFF212121).toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_text_secondary',
          isDark
              ? const Color(0xB3FFFFFF).toARGB32()
              : const Color(0xFF757575).toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_surface', themePack.surfaceColor.toARGB32());
      await HomeWidget.saveWidgetData<bool>('is_dark', isDark);
      await HomeWidget.saveWidgetData<String>('theme_name', themePack.name);

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );

      debugPrint('Widget updated: ${widgetItems.length} items, theme: ${themePack.name}');
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Update just the theme (when user changes theme without data change).
  static Future<void> updateTheme({
    required ThemePack themePack,
    required bool isDark,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>(
          'theme_primary', themePack.primaryColor.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_background',
          isDark
              ? themePack.backgroundColor.toARGB32()
              : Colors.white.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_card',
          isDark
              ? themePack.cardColor.toARGB32()
              : Colors.white.toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_text',
          isDark ? Colors.white.toARGB32() : const Color(0xFF212121).toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_text_secondary',
          isDark
              ? const Color(0xB3FFFFFF).toARGB32()
              : const Color(0xFF757575).toARGB32());
      await HomeWidget.saveWidgetData<int>(
          'theme_surface', themePack.surfaceColor.toARGB32());
      await HomeWidget.saveWidgetData<bool>('is_dark', isDark);
      await HomeWidget.saveWidgetData<String>('theme_name', themePack.name);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
    } catch (e) {
      debugPrint('Error updating widget theme: $e');
    }
  }

  /// Clear widget data (e.g., on sign out).
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<bool>('signed_in', false);
      await HomeWidget.saveWidgetData<String>('items_json', '[]');
      await HomeWidget.saveWidgetData<int>('item_count', 0);
      await HomeWidget.saveWidgetData<int>('incomplete_count', 0);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
    } catch (e) {
      debugPrint('Error clearing widget: $e');
    }
  }
}
