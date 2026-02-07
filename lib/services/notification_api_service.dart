import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationApiService {
  static const _baseUrl = String.fromEnvironment(
    'NOTIFY_API_URL',
    defaultValue: 'https://nudge-notify-api.vercel.app',
  );

  final FirebaseAuth _auth;

  NotificationApiService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Send a push notification for a ping/nudge
  Future<void> sendPingNotification({
    required String toUid,
    required String spaceId,
    required String itemId,
    required String itemTitle,
    required String spaceName,
  }) async {
    if (_baseUrl.isEmpty) {
      debugPrint('NotificationApiService: No API URL configured, skipping push');
      return;
    }

    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('NotificationApiService: No ID token, skipping push');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-ping'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'toUid': toUid,
          'spaceId': spaceId,
          'itemId': itemId,
          'itemTitle': itemTitle,
          'spaceName': spaceName,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Push notification sent successfully');
      } else {
        debugPrint('Push notification failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Don't crash the app if push notification fails
      debugPrint('Push notification error: $e');
    }
  }
}
