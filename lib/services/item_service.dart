import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/item_model.dart';

class ItemService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ItemService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('items');

  /// Create a new personal item
  Future<ReminderItem?> createPersonalItem({
    required String ownerUid,
    required String title,
    String? details,
    DateTime? remindAt,
    String? timezone,
    ItemPriority priority = ItemPriority.none,
    String? repeatRule,
  }) async {
    try {
      final now = DateTime.now();
      final itemId = _uuid.v4();

      final item = ReminderItem(
        itemId: itemId,
        type: ItemType.personal,
        ownerUid: ownerUid,
        title: title,
        details: details,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
        createdByUid: ownerUid,
        updatedByUid: ownerUid,
        remindAt: remindAt,
        timezone: timezone,
        notifyStatus: remindAt != null ? NotifyStatus.scheduled : NotifyStatus.none,
        priority: priority,
        repeatRule: repeatRule,
      );

      await _itemsCollection.doc(itemId).set(item.toMap());
      return item;
    } catch (e) {
      debugPrint('Error creating personal item: $e');
      return null;
    }
  }

  /// Create a new space item
  Future<ReminderItem?> createSpaceItem({
    required String spaceId,
    required String createdByUid,
    required String title,
    String? details,
    DateTime? remindAt,
    String? timezone,
    ItemPriority priority = ItemPriority.none,
    String? repeatRule,
    String? assignedToUid,
  }) async {
    try {
      final now = DateTime.now();
      final itemId = _uuid.v4();

      final item = ReminderItem(
        itemId: itemId,
        type: ItemType.space,
        spaceId: spaceId,
        title: title,
        details: details,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
        createdByUid: createdByUid,
        updatedByUid: createdByUid,
        remindAt: remindAt,
        timezone: timezone,
        notifyStatus: remindAt != null ? NotifyStatus.scheduled : NotifyStatus.none,
        priority: priority,
        repeatRule: repeatRule,
        assignedToUid: assignedToUid,
        viewedBy: [createdByUid], // Creator has viewed it
      );

      // Use batch to create item and update space itemCount
      final batch = _firestore.batch();
      batch.set(_itemsCollection.doc(itemId), item.toMap());
      batch.update(_firestore.collection('spaces').doc(spaceId), {
        'itemCount': FieldValue.increment(1),
      });
      await batch.commit();

      return item;
    } catch (e) {
      debugPrint('Error creating space item: $e');
      return null;
    }
  }

  /// Update an item
  Future<bool> updateItem({
    required String itemId,
    required String updatedByUid,
    String? title,
    String? details,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? timezone,
    ItemPriority? priority,
    String? repeatRule,
    bool clearRepeatRule = false,
    String? assignedToUid,
    bool clearAssignedTo = false,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': updatedByUid,
      };

      if (title != null) updates['title'] = title;
      if (details != null) updates['details'] = details;
      if (priority != null) updates['priority'] = priority.name;

      if (clearRemindAt) {
        updates['remindAt'] = FieldValue.delete();
        updates['notifyStatus'] = NotifyStatus.cancelled.name;
      } else if (remindAt != null) {
        updates['remindAt'] = Timestamp.fromDate(remindAt);
        updates['notifyStatus'] = NotifyStatus.scheduled.name;
        if (timezone != null) updates['timezone'] = timezone;
      }

      if (clearRepeatRule) {
        updates['repeatRule'] = FieldValue.delete();
      } else if (repeatRule != null) {
        updates['repeatRule'] = repeatRule;
      }

      if (clearAssignedTo) {
        updates['assignedToUid'] = FieldValue.delete();
      } else if (assignedToUid != null) {
        updates['assignedToUid'] = assignedToUid;
      }

      await _itemsCollection.doc(itemId).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error updating item: $e');
      return false;
    }
  }

  /// Toggle item completion status
  Future<bool> toggleComplete({
    required String itemId,
    required String updatedByUid,
    required bool isCompleted,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'isCompleted': isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': updatedByUid,
      };

      if (isCompleted) {
        updates['completedAt'] = FieldValue.serverTimestamp();
      } else {
        updates['completedAt'] = FieldValue.delete();
      }

      await _itemsCollection.doc(itemId).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error toggling item completion: $e');
      return false;
    }
  }

  /// Delete an item
  Future<bool> deleteItem(String itemId, {String? spaceId}) async {
    try {
      if (spaceId != null) {
        // Use batch to delete item and decrement space itemCount
        final batch = _firestore.batch();
        batch.delete(_itemsCollection.doc(itemId));
        batch.update(_firestore.collection('spaces').doc(spaceId), {
          'itemCount': FieldValue.increment(-1),
        });
        await batch.commit();
      } else {
        await _itemsCollection.doc(itemId).delete();
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting item: $e');
      return false;
    }
  }

  /// Mark an item as viewed by a user
  Future<bool> markAsViewed(String itemId, String uid) async {
    try {
      await _itemsCollection.doc(itemId).update({
        'viewedBy': FieldValue.arrayUnion([uid]),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking item as viewed: $e');
      return false;
    }
  }

  /// Restore a deleted item (for undo)
  Future<bool> restoreItem(ReminderItem item) async {
    try {
      if (item.spaceId != null) {
        // Use batch to restore item and increment space itemCount
        final batch = _firestore.batch();
        batch.set(_itemsCollection.doc(item.itemId), item.toMap());
        batch.update(_firestore.collection('spaces').doc(item.spaceId!), {
          'itemCount': FieldValue.increment(1),
        });
        await batch.commit();
      } else {
        await _itemsCollection.doc(item.itemId).set(item.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('Error restoring item: $e');
      return false;
    }
  }

  /// Get a single item
  Future<ReminderItem?> getItem(String itemId) async {
    try {
      final doc = await _itemsCollection.doc(itemId).get();
      if (!doc.exists) return null;
      return ReminderItem.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting item: $e');
      return null;
    }
  }

  /// Stream personal items for a user
  Stream<List<ReminderItem>> streamPersonalItems(String ownerUid) {
    return _itemsCollection
        .where('ownerUid', isEqualTo: ownerUid)
        .where('type', isEqualTo: 'personal')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList());
  }

  /// Stream items for a space
  Stream<List<ReminderItem>> streamSpaceItems(String spaceId) {
    return _itemsCollection
        .where('spaceId', isEqualTo: spaceId)
        .where('type', isEqualTo: 'space')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList());
  }

  /// Get items due today for a user (for local notifications sync)
  Future<List<ReminderItem>> getItemsDueToday(String ownerUid) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final snapshot = await _itemsCollection
          .where('ownerUid', isEqualTo: ownerUid)
          .where('type', isEqualTo: 'personal')
          .where('remindAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('remindAt', isLessThan: Timestamp.fromDate(todayEnd))
          .where('isCompleted', isEqualTo: false)
          .get();

      return snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting items due today: $e');
      return [];
    }
  }

  /// Get all items with scheduled notifications (for syncing local notifications)
  Future<List<ReminderItem>> getItemsWithReminders(String ownerUid) async {
    try {
      final now = DateTime.now();

      final snapshot = await _itemsCollection
          .where('ownerUid', isEqualTo: ownerUid)
          .where('type', isEqualTo: 'personal')
          .where('remindAt', isGreaterThan: Timestamp.fromDate(now))
          .where('isCompleted', isEqualTo: false)
          .get();

      return snapshot.docs.map((doc) => ReminderItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting items with reminders: $e');
      return [];
    }
  }
}
