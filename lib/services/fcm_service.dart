import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // The notification will be displayed automatically by the system
  // We just need to handle any data processing here if needed
}

class FCMService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final UserService _userService;

  String? _currentToken;
  String? _currentUid;

  FCMService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    UserService? userService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _userService = userService ?? UserService();

  String? get currentToken => _currentToken;

  /// Initialize FCM and set up handlers
  Future<void> initialize() async {
    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up foreground notification presentation
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up local notifications for foreground messages
    await _initializeLocalNotifications();

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen for notification taps (when app is in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM token refreshed');
      if (_currentUid != null) {
        _updateToken(_currentUid!, token);
      }
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );

    // Create notification channels for Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const spaceChannel = AndroidNotificationChannel(
        'space_reminders',
        'Space Reminders',
        description: 'Notifications for shared space reminders',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(spaceChannel);

      const remindersChannel = AndroidNotificationChannel(
        'reminders',
        'Reminders',
        description: 'General reminder notifications',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(remindersChannel);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('FCM permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      debugPrint('FCM token: $_currentToken');
      return _currentToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Register token for a user (call on login)
  Future<void> registerToken(String uid) async {
    _currentUid = uid;

    final token = await getToken();
    if (token != null) {
      await _updateToken(uid, token);
    }
  }

  Future<void> _updateToken(String uid, String token) async {
    _currentToken = token;
    await _userService.updateFcmToken(uid, token);
    debugPrint('FCM token registered for user $uid');
  }

  /// Unregister token for a user (call on logout)
  Future<void> unregisterToken(String uid) async {
    if (_currentToken != null) {
      await _userService.removeFcmToken(uid, _currentToken!);
      debugPrint('FCM token unregistered for user $uid');
    }
    _currentUid = null;
    _currentToken = null;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');

    final notification = message.notification;
    final android = message.notification?.android;

    // Show local notification for foreground messages
    if (notification != null) {
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'space_reminders',
            'Space Reminders',
            channelDescription: 'Notifications for shared space reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap (background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    _navigateToItem(message.data);
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateToItem(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Navigate to the relevant item/space
  void _navigateToItem(Map<String, dynamic> data) {
    final itemId = data['itemId'] as String?;
    final spaceId = data['spaceId'] as String?;
    final type = data['type'] as String?;

    debugPrint('Navigate to: itemId=$itemId, spaceId=$spaceId, type=$type');

    // Navigation will be handled by the app through a callback
    // This is set up in the app initialization
    _onNotificationTap?.call(data);
  }

  // Callback for notification taps
  static void Function(Map<String, dynamic> data)? _onNotificationTap;

  /// Set callback for notification taps
  static void setOnNotificationTap(void Function(Map<String, dynamic> data) callback) {
    _onNotificationTap = callback;
  }

  /// Subscribe to a topic (e.g., for space notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
}
