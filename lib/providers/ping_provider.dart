import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ping_model.dart';
import 'auth_provider.dart';

/// Stream all unseen pings for the current user
final unseenPingsProvider = StreamProvider<List<Ping>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final pingService = ref.watch(pingServiceProvider);
  return pingService.streamUnseenPings(user.uid).transform(
    StreamTransformer.fromHandlers(
      handleError: (error, stackTrace, sink) {
        debugPrint('Pings stream error: $error');
        sink.add(<Ping>[]); // Emit empty list instead of crashing
      },
    ),
  );
});

/// Total count of unseen pings (for bottom nav badge)
final totalUnseenPingsCountProvider = Provider<int>((ref) {
  final pingsAsync = ref.watch(unseenPingsProvider);
  return pingsAsync.whenData((pings) => pings.length).value ?? 0;
});

/// Count of unseen pings per space
final spaceUnseenPingsCountProvider = Provider.family<int, String>((ref, spaceId) {
  final pings = ref.watch(unseenPingsProvider).value ?? [];
  return pings.where((p) => p.spaceId == spaceId).length;
});

/// Count of unseen pings per item
final itemUnseenPingsCountProvider = Provider.family<int, String>((ref, itemId) {
  final pings = ref.watch(unseenPingsProvider).value ?? [];
  return pings.where((p) => p.itemId == itemId).length;
});
