import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_model.dart';
import '../models/space_model.dart';
import 'activity_service.dart';

class SpaceService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();
  final ActivityService? _activityService;

  SpaceService({
    FirebaseFirestore? firestore,
    ActivityService? activityService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _activityService = activityService;

  CollectionReference<Map<String, dynamic>> get _spacesCollection =>
      _firestore.collection('spaces');

  /// Create a new space
  Future<Space?> createSpace({
    required String ownerUid,
    required String name,
    String? emoji,
  }) async {
    try {
      final now = DateTime.now();
      final spaceId = _uuid.v4();

      final ownerMember = SpaceMember(
        uid: ownerUid,
        role: MemberRole.owner,
        joinedAt: now,
      );

      final space = Space(
        spaceId: spaceId,
        name: name,
        emoji: emoji,
        ownerUid: ownerUid,
        createdAt: now,
        updatedAt: now,
        memberCount: 1,
        members: {ownerUid: ownerMember},
      );

      await _spacesCollection.doc(spaceId).set(space.toMap());
      return space;
    } catch (e) {
      debugPrint('Error creating space: $e');
      return null;
    }
  }

  /// Update space details
  Future<bool> updateSpace({
    required String spaceId,
    String? name,
    String? emoji,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (emoji != null) updates['emoji'] = emoji;

      await _spacesCollection.doc(spaceId).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error updating space: $e');
      return false;
    }
  }

  /// Delete a space (only owner can do this)
  Future<bool> deleteSpace(String spaceId) async {
    try {
      // Best-effort: revoke pending invites (separate batch so rule
      // failures on invites sent by other admins don't block deletion)
      try {
        final invitesSnapshot = await _firestore
            .collection('spaceInvites')
            .where('spaceId', isEqualTo: spaceId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (invitesSnapshot.docs.isNotEmpty) {
          final inviteBatch = _firestore.batch();
          for (final doc in invitesSnapshot.docs) {
            inviteBatch.update(doc.reference, {'status': 'revoked'});
          }
          await inviteBatch.commit();
        }
      } catch (e) {
        debugPrint('Warning: Could not revoke pending invites: $e');
      }

      // Delete all space items and the space itself
      final itemsSnapshot = await _firestore
          .collection('items')
          .where('spaceId', isEqualTo: spaceId)
          .where('type', isEqualTo: 'space')
          .get();

      final batch = _firestore.batch();

      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_spacesCollection.doc(spaceId));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting space: $e');
      return false;
    }
  }

  /// Add a member to a space
  Future<bool> addMember({
    required String spaceId,
    required String uid,
    MemberRole role = MemberRole.member,
  }) async {
    try {
      final now = DateTime.now();
      final memberData = SpaceMember(
        uid: uid,
        role: role,
        joinedAt: now,
      );

      await _spacesCollection.doc(spaceId).update({
        'members.$uid': memberData.toMap(),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding member: $e');
      return false;
    }
  }

  /// Remove a member from a space
  Future<bool> removeMember({
    required String spaceId,
    required String uid,
  }) async {
    try {
      await _spacesCollection.doc(spaceId).update({
        'members.$uid': FieldValue.delete(),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  /// Update a member's role
  Future<bool> updateMemberRole({
    required String spaceId,
    required String uid,
    required MemberRole role,
    String? actorUid,
  }) async {
    try {
      await _spacesCollection.doc(spaceId).update({
        'members.$uid.role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Best-effort activity logging
      if (actorUid != null) {
        try {
          await _activityService?.createActivity(
            spaceId: spaceId,
            actorUid: actorUid,
            type: ActivityType.memberRoleChanged,
            targetUid: uid,
            metadata: {'newRole': role.name},
          );
        } catch (e) {
          debugPrint('Error logging memberRoleChanged activity: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating member role: $e');
      return false;
    }
  }

  /// Leave a space (member removes themselves)
  Future<bool> leaveSpace({
    required String spaceId,
    required String uid,
  }) async {
    try {
      // Get the space to check if user is owner
      final spaceDoc = await _spacesCollection.doc(spaceId).get();
      if (!spaceDoc.exists) return false;

      final space = Space.fromFirestore(spaceDoc);

      // Owner cannot leave, must transfer ownership or delete space
      if (space.ownerUid == uid) {
        return false;
      }

      return await removeMember(spaceId: spaceId, uid: uid);
    } catch (e) {
      debugPrint('Error leaving space: $e');
      return false;
    }
  }

  /// Get a single space
  Future<Space?> getSpace(String spaceId) async {
    try {
      final doc = await _spacesCollection.doc(spaceId).get();
      if (!doc.exists) return null;
      return Space.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting space: $e');
      return null;
    }
  }

  /// Stream a single space for real-time updates
  Stream<Space?> streamSpace(String spaceId) {
    return _spacesCollection.doc(spaceId).snapshots().map(
          (doc) => doc.exists ? Space.fromFirestore(doc) : null,
        );
  }

  /// Stream spaces for a user
  Stream<List<Space>> streamUserSpaces(String uid) {
    // Query spaces where user is a member
    // Note: Firestore doesn't support direct map key queries efficiently
    // We store the member UID as a key in the members map
    return _spacesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Space.fromFirestore(doc))
            .where((space) => space.members.containsKey(uid))
            .toList());
  }

  /// Check if a user is a member of a space
  Future<bool> isMember(String spaceId, String uid) async {
    try {
      final space = await getSpace(spaceId);
      return space?.members.containsKey(uid) ?? false;
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  /// Check if a user is an admin or owner of a space
  Future<bool> isAdmin(String spaceId, String uid) async {
    try {
      final space = await getSpace(spaceId);
      if (space == null) return false;

      final member = space.members[uid];
      if (member == null) return false;

      return member.role == MemberRole.admin || member.role == MemberRole.owner;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }
}
