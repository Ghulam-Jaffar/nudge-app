import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';
import 'providers.dart';

/// Provider for activity service
final activityServiceProvider = Provider<ActivityService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ActivityService(firestore: firestore);
});

/// Provider for streaming space activities
final spaceActivitiesProvider = StreamProvider.family<List<SpaceActivity>, String>((ref, spaceId) {
  final activityService = ref.watch(activityServiceProvider);
  return activityService.streamSpaceActivities(spaceId);
});
