import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/space_model.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final userSpacesProvider = StreamProvider<List<Space>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  // Query all spaces and filter client-side for membership
  // Firestore doesn't support direct map key existence queries reliably
  return firestore
      .collection('spaces')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Space.fromFirestore(doc))
          .where((space) => space.members.containsKey(user.uid))
          .toList());
});

final spaceProvider = StreamProvider.family<Space?, String>((ref, spaceId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('spaces').doc(spaceId).snapshots().map(
        (doc) => doc.exists ? Space.fromFirestore(doc) : null,
      );
});
