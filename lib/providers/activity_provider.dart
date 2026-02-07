import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import 'auth_provider.dart';

/// Provider for streaming space activities
final spaceActivitiesProvider = StreamProvider.family<List<SpaceActivity>, String>((ref, spaceId) {
  final activityService = ref.watch(activityServiceProvider);
  return activityService.streamSpaceActivities(spaceId).transform(
    StreamTransformer.fromHandlers(
      handleError: (error, stackTrace, sink) {
        debugPrint('Activity stream error for space $spaceId: $error');
        sink.add(<SpaceActivity>[]); // Emit empty list instead of crashing
      },
    ),
  );
});
