import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/item_service.dart';
import '../services/local_notification_service.dart';
import '../services/fcm_service.dart';
import '../services/space_service.dart';
import '../services/invite_service.dart';
import '../services/activity_service.dart';
import '../services/ping_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService();
});

final itemServiceProvider = Provider<ItemService>((ref) {
  final activityService = ref.watch(activityServiceProvider);
  return ItemService(activityService: activityService);
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

final spaceServiceProvider = Provider<SpaceService>((ref) {
  final activityService = ref.watch(activityServiceProvider);
  return SpaceService(activityService: activityService);
});

final inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService();
});

final pingServiceProvider = Provider<PingService>((ref) {
  return PingService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
