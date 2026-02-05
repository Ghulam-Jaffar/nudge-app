import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/item_model.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // The payload contains the item ID which can be used to navigate
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation would be handled by the app's navigation system
  }

  /// Request notification permissions (especially for iOS/Android 13+)
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  /// Schedule a notification for a reminder item
  Future<void> scheduleItemNotification(ReminderItem item) async {
    if (item.remindAt == null) return;
    if (item.remindAt!.isBefore(DateTime.now())) return;
    if (item.isCompleted) return;

    await _notifications.zonedSchedule(
      _generateNotificationId(item.itemId),
      'Reminder',
      item.title,
      tz.TZDateTime.from(item.remindAt!, tz.local),
      _buildNotificationDetails(item),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: item.itemId,
      matchDateTimeComponents: _getDateTimeComponents(item.repeatRule),
    );

    debugPrint('Scheduled notification for item ${item.itemId} at ${item.remindAt}');
  }

  /// Cancel a notification for an item
  Future<void> cancelItemNotification(String itemId) async {
    await _notifications.cancel(_generateNotificationId(itemId));
    debugPrint('Cancelled notification for item $itemId');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Cancelled all notifications');
  }

  /// Reschedule all notifications for a list of items
  Future<void> rescheduleAllNotifications(List<ReminderItem> items) async {
    await cancelAllNotifications();

    for (final item in items) {
      if (item.remindAt != null && !item.isCompleted) {
        await scheduleItemNotification(item);
      }
    }
  }

  /// Show an immediate notification (for testing or instant reminders)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _buildNotificationDetails(null),
      payload: payload,
    );
  }

  NotificationDetails _buildNotificationDetails(ReminderItem? item) {
    // Customize notification appearance based on priority
    String channelId = 'reminders';
    String channelName = 'Reminders';
    Importance importance = Importance.high;
    Priority priority = Priority.high;

    if (item != null) {
      switch (item.priority) {
        case ItemPriority.high:
          channelId = 'reminders_high';
          channelName = 'High Priority Reminders';
          importance = Importance.max;
          priority = Priority.max;
          break;
        case ItemPriority.medium:
          channelId = 'reminders_medium';
          channelName = 'Medium Priority Reminders';
          importance = Importance.high;
          priority = Priority.high;
          break;
        case ItemPriority.low:
          channelId = 'reminders_low';
          channelName = 'Low Priority Reminders';
          importance = Importance.defaultImportance;
          priority = Priority.defaultPriority;
          break;
        case ItemPriority.none:
          break;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Reminder notifications',
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  DateTimeComponents? _getDateTimeComponents(String? repeatRule) {
    if (repeatRule == null) return null;

    switch (repeatRule) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      default:
        return null;
    }
  }

  /// Generate a consistent notification ID from item ID
  int _generateNotificationId(String itemId) {
    // Use hashCode to convert string to int for notification ID
    return itemId.hashCode.abs() % 2147483647; // Max int32
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
    }
    // iOS doesn't have a direct way to check, assume enabled
    return true;
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    final pending = await _notifications.pendingNotificationRequests();
    return pending.length;
  }
}
