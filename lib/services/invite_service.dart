import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/invite_model.dart';
import '../models/space_model.dart';
import 'space_service.dart';

class InviteService {
  final FirebaseFirestore _firestore;
  final SpaceService _spaceService;
  final Uuid _uuid = const Uuid();

  InviteService({
    FirebaseFirestore? firestore,
    SpaceService? spaceService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _spaceService = spaceService ?? SpaceService();

  CollectionReference<Map<String, dynamic>> get _invitesCollection =>
      _firestore.collection('spaceInvites');

  /// Create a new invitation
  Future<SpaceInvite?> createInvite({
    required String spaceId,
    required String spaceName,
    required String fromUid,
    required String toUid,
  }) async {
    try {
      // Check if there's already a pending invite for this user to this space
      // Query includes spaceId + toUid + status (uses composite index)
      final existingInvite = await _invitesCollection
          .where('spaceId', isEqualTo: spaceId)
          .where('toUid', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingInvite.docs.isNotEmpty) {
        debugPrint('Pending invite already exists');
        return null;
      }

      // Check if user is already a member
      final isMember = await _spaceService.isMember(spaceId, toUid);
      if (isMember) {
        debugPrint('User is already a member');
        return null;
      }

      final now = DateTime.now();
      final inviteId = _uuid.v4();

      final invite = SpaceInvite(
        inviteId: inviteId,
        spaceId: spaceId,
        spaceNameSnapshot: spaceName,
        fromUid: fromUid,
        toUid: toUid,
        status: InviteStatus.pending,
        createdAt: now,
      );

      await _invitesCollection.doc(inviteId).set(invite.toMap());
      return invite;
    } catch (e) {
      debugPrint('Error creating invite: $e');
      return null;
    }
  }

  /// Accept an invitation
  Future<bool> acceptInvite(String inviteId) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final inviteDoc = await transaction.get(_invitesCollection.doc(inviteId));

        if (!inviteDoc.exists) {
          debugPrint('Invite not found');
          return false;
        }

        final invite = SpaceInvite.fromFirestore(inviteDoc);

        if (invite.status != InviteStatus.pending) {
          debugPrint('Invite is not pending');
          return false;
        }

        // Update invite status
        transaction.update(_invitesCollection.doc(inviteId), {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        // Add user to space
        final spaceRef = _firestore.collection('spaces').doc(invite.spaceId);
        final now = DateTime.now();
        final memberData = SpaceMember(
          uid: invite.toUid,
          role: MemberRole.member,
          joinedAt: now,
        );

        transaction.update(spaceRef, {
          'members.${invite.toUid}': memberData.toMap(),
          'memberCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error accepting invite: $e');
      return false;
    }
  }

  /// Decline an invitation
  Future<bool> declineInvite(String inviteId) async {
    try {
      final inviteDoc = await _invitesCollection.doc(inviteId).get();

      if (!inviteDoc.exists) {
        debugPrint('Invite not found');
        return false;
      }

      final invite = SpaceInvite.fromFirestore(inviteDoc);

      if (invite.status != InviteStatus.pending) {
        debugPrint('Invite is not pending');
        return false;
      }

      await _invitesCollection.doc(inviteId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error declining invite: $e');
      return false;
    }
  }

  /// Revoke an invitation (by the sender)
  Future<bool> revokeInvite(String inviteId) async {
    try {
      final inviteDoc = await _invitesCollection.doc(inviteId).get();

      if (!inviteDoc.exists) {
        debugPrint('Invite not found');
        return false;
      }

      final invite = SpaceInvite.fromFirestore(inviteDoc);

      if (invite.status != InviteStatus.pending) {
        debugPrint('Invite is not pending');
        return false;
      }

      await _invitesCollection.doc(inviteId).update({
        'status': 'revoked',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error revoking invite: $e');
      return false;
    }
  }

  /// Get pending invites for a user
  Stream<List<SpaceInvite>> streamPendingInvites(String uid) {
    return _invitesCollection
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpaceInvite.fromFirestore(doc)).toList());
  }

  /// Get pending invites for a space (for admins to see who's invited)
  Stream<List<SpaceInvite>> streamSpaceInvites(String spaceId) {
    return _invitesCollection
        .where('spaceId', isEqualTo: spaceId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpaceInvite.fromFirestore(doc)).toList());
  }

  /// Get invite count for a user
  Future<int> getPendingInviteCount(String uid) async {
    try {
      final snapshot = await _invitesCollection
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting invite count: $e');
      return 0;
    }
  }
}
