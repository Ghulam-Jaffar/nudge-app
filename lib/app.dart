import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

class SharedReminderApp extends ConsumerStatefulWidget {
  const SharedReminderApp({super.key});

  @override
  ConsumerState<SharedReminderApp> createState() => _SharedReminderAppState();
}

class _SharedReminderAppState extends ConsumerState<SharedReminderApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationHandler();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request local notification permissions
    final notificationService = LocalNotificationService();
    await notificationService.requestPermissions();
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
