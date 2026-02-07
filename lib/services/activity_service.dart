import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_model.dart';

class ActivityService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ActivityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _activitiesCollection =>
      _firestore.collection('spaceActivities');

  /// Create an activity
  Future<SpaceActivity?> createActivity({
    required String spaceId,
    required String actorUid,
    required ActivityType type,
    String? targetUid,
    String? itemId,
    String? itemTitle,
    Map<String, dynamic>? metadata,
    List<String>? visibleTo,
  }) async {
    try {
      final activityId = _uuid.v4();
      final now = DateTime.now();

      final activity = SpaceActivity(
        activityId: activityId,
        spaceId: spaceId,
        actorUid: actorUid,
        type: type,
        targetUid: targetUid,
        itemId: itemId,
        itemTitle: itemTitle,
        createdAt: now,
        metadata: metadata,
        visibleTo: visibleTo,
      );

      await _activitiesCollection.doc(activityId).set(activity.toMap());
      return activity;
    } catch (e) {
      debugPrint('Error creating activity: $e');
      return null;
    }
  }

  /// Stream activities for a space
  Stream<List<SpaceActivity>> streamSpaceActivities(String spaceId) {
    return _activitiesCollection
        .where('spaceId', isEqualTo: spaceId)
        .orderBy('createdAt', descending: true)
        .limit(100) // Limit to last 100 activities
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpaceActivity.fromFirestore(doc)).toList());
  }

  /// Get recent activities for a space
  Future<List<SpaceActivity>> getRecentActivities(String spaceId, {int limit = 20}) async {
    try {
      final snapshot = await _activitiesCollection
          .where('spaceId', isEqualTo: spaceId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => SpaceActivity.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting recent activities: $e');
      return [];
    }
  }

  /// Delete all activities for a space (called when space is deleted)
  Future<bool> deleteSpaceActivities(String spaceId) async {
    try {
      final snapshot = await _activitiesCollection
          .where('spaceId', isEqualTo: spaceId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting space activities: $e');
      return false;
    }
  }
}
