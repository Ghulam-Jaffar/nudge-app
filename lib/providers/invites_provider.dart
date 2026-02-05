import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invite_model.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final pendingInvitesProvider = StreamProvider<List<SpaceInvite>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('spaceInvites')
      .where('toUid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => SpaceInvite.fromFirestore(doc)).toList());
});

final pendingInvitesCountProvider = Provider<int>((ref) {
  final invites = ref.watch(pendingInvitesProvider).value ?? [];
  return invites.length;
});

/// Provider for streaming all invites for a specific space (for activity view)
final spaceInvitesProvider = StreamProvider.family<List<SpaceInvite>, String>((ref, spaceId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('spaceInvites')
      .where('spaceId', isEqualTo: spaceId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => SpaceInvite.fromFirestore(doc)).toList());
});
