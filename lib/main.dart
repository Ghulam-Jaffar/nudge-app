import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/local_notification_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('Running in offline mode without Firebase');
  }

  // Set up FCM background handler before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  try {
    await LocalNotificationService().initialize();
  } catch (e) {
    debugPrint('Local notifications initialization failed: $e');
  }

  // Initialize FCM
  try {
    final fcmService = FCMService();
    await fcmService.initialize();
    await fcmService.requestPermission();
    debugPrint('FCM initialized successfully');
  } catch (e) {
    debugPrint('FCM initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: SharedReminderApp(),
    ),
  );
}
