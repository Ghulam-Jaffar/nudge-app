import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userDocProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
});

final appUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(userDocProvider).value;
});

final hasCompletedProfileProvider = Provider<bool>((ref) {
  final appUser = ref.watch(appUserProvider);
  return appUser != null && appUser.handle.isNotEmpty;
});
