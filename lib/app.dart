import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

class SharedReminderApp extends ConsumerStatefulWidget {
  const SharedReminderApp({super.key});

  @override
  ConsumerState<SharedReminderApp> createState() => _SharedReminderAppState();
}

class _SharedReminderAppState extends ConsumerState<SharedReminderApp>
    with WidgetsBindingObserver {
  String? _lastRegisteredUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationHandler();
    _requestNotificationPermissions();
    WidgetService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Update widget when app comes to foreground or goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _updateHomeWidget();
    }
  }

  void _updateHomeWidget() {
    final widgetItems = ref.read(widgetItemsProvider);
    final themeState = ref.read(themeProvider);
    // Use the pack directly since we can't access BuildContext reliably here
    final isDark = themeState.pack.isDarkPack;
    WidgetService.updateWidget(
      todayItems: widgetItems,
      themePack: themeState.pack,
      isDark: isDark,
    );
  }

  Future<void> _requestNotificationPermissions() async {
    // Request local notification permissions
    final notificationService = LocalNotificationService();
    await notificationService.requestPermissions();
  }

  /// Register FCM token whenever an authenticated user is detected
  void _registerFcmTokenIfNeeded() {
    final user = ref.read(currentUserProvider);
    if (user != null && user.uid != _lastRegisteredUid) {
      _lastRegisteredUid = user.uid;
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.registerToken(user.uid);
    }
  }

  void _setupNotificationHandler() {
    FCMService.setOnNotificationTap((data) {
      _handleNotificationNavigation(data);
    });
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final type = data['type'] as String?;
    final spaceId = data['spaceId'] as String?;
    final itemId = data['itemId'] as String?;

    debugPrint('Notification navigation: type=$type, spaceId=$spaceId, itemId=$itemId');

    if (type == 'space' && spaceId != null) {
      // Navigate to the space detail screen
      router.push('/spaces/$spaceId');
    } else if (type == 'personal') {
      // Navigate to personal items (home)
      router.go('/');
    } else {
      // Default: go to home
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state and register FCM token when user is authenticated
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        _registerFcmTokenIfNeeded();
      } else if (prev != null && next == null) {
        // User signed out — clear widget
        WidgetService.clearWidget();
      }
    });
    // Also check on first build
    _registerFcmTokenIfNeeded();

    // Update home screen widget when items change
    ref.listen(widgetItemsProvider, (prev, next) {
      _updateHomeWidget();
    });

    // Update home screen widget when theme changes
    ref.listen(themeProvider, (prev, next) {
      _updateHomeWidget();
    });

    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Nudge',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: themeState.getTheme(context),
      darkTheme: themeState.getTheme(context),
      themeMode: _mapThemeMode(themeState.mode),
    );
  }

  ThemeMode _mapThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
