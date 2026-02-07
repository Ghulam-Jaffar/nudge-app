import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/ping_model.dart';

class PingService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  PingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pingsCollection =>
      _firestore.collection('pings');

  /// Create a ping (nudge). Returns null if rate-limited or error.
  Future<Ping?> createPing({
    required String spaceId,
    required String itemId,
    required String itemTitle,
    required String fromUid,
    required String toUid,
  }) async {
    try {
      // Rate-limit check: same sender + item within 1 hour
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final recentPings = await _pingsCollection
          .where('fromUid', isEqualTo: fromUid)
          .where('itemId', isEqualTo: itemId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .limit(1)
          .get();

      if (recentPings.docs.isNotEmpty) {
        debugPrint('Ping rate-limited: already pinged this item within 1 hour');
        return null;
      }

      final pingId = _uuid.v4();
      final now = DateTime.now();

      final ping = Ping(
        pingId: pingId,
        spaceId: spaceId,
        itemId: itemId,
        itemTitle: itemTitle,
        fromUid: fromUid,
        toUid: toUid,
        createdAt: now,
      );

      await _pingsCollection.doc(pingId).set(ping.toMap());
      return ping;
    } catch (e) {
      debugPrint('Error creating ping: $e');
      return null;
    }
  }

  /// Mark all unseen pings for a given item+user as seen
  Future<bool> markPingsAsSeen(String itemId, String toUid) async {
    try {
      final snapshot = await _pingsCollection
          .where('itemId', isEqualTo: itemId)
          .where('toUid', isEqualTo: toUid)
          .where('seenAt', isNull: true)
          .get();

      if (snapshot.docs.isEmpty) return true;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'seenAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error marking pings as seen: $e');
      return false;
    }
  }

  /// Stream all unseen pings for a user
  Stream<List<Ping>> streamUnseenPings(String toUid) {
    return _pingsCollection
        .where('toUid', isEqualTo: toUid)
        .where('seenAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Ping.fromFirestore(doc)).toList());
  }

  /// Stream unseen pings for a specific item + user
  Stream<List<Ping>> streamItemPings(String itemId, String toUid) {
    return _pingsCollection
        .where('itemId', isEqualTo: itemId)
        .where('toUid', isEqualTo: toUid)
        .where('seenAt', isNull: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Ping.fromFirestore(doc)).toList());
  }
}
