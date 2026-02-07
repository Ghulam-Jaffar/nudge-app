import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final personalItemsProvider = StreamProvider<List<ReminderItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('items')
      .where('ownerUid', isEqualTo: user.uid)
      .where('type', isEqualTo: 'personal')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList());
});

final todayItemsProvider = Provider<List<ReminderItem>>((ref) {
  final items = ref.watch(personalItemsProvider).value ?? [];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  return items.where((item) {
    if (item.isCompleted) return false;
    if (item.remindAt == null) return false;
    return item.remindAt!.isAfter(todayStart) &&
        item.remindAt!.isBefore(todayEnd);
  }).toList();
});

final upcomingItemsProvider = Provider<List<ReminderItem>>((ref) {
  final items = ref.watch(personalItemsProvider).value ?? [];
  final now = DateTime.now();
  final todayEnd = DateTime(now.year, now.month, now.day + 1);

  return items.where((item) {
    if (item.isCompleted) return false;
    if (item.remindAt == null) return true; // No date = upcoming
    return item.remindAt!.isAfter(todayEnd);
  }).toList();
});

final completedItemsProvider = Provider<List<ReminderItem>>((ref) {
  final items = ref.watch(personalItemsProvider).value ?? [];
  return items.where((item) => item.isCompleted).toList();
});

final spaceItemsProvider =
    StreamProvider.family<List<ReminderItem>, String>((ref, spaceId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('items')
      .where('spaceId', isEqualTo: spaceId)
      .where('type', isEqualTo: 'space')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList());
});

/// Count of active (incomplete) items in a space
final spaceActiveItemCountProvider = Provider.family<int, String>((ref, spaceId) {
  final items = ref.watch(spaceItemsProvider(spaceId)).value ?? [];
  return items.where((item) => !item.isCompleted).length;
});
