import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _handlesCollection =>
      _firestore.collection('handles');

  /// Get a user by their UID
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Stream a user's profile for realtime updates
  Stream<AppUser?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromFirestore(doc) : null,
        );
  }

  /// Check if a user document exists
  Future<bool> userExists(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.exists;
  }

  /// Check if a user has completed their profile (has a handle)
  Future<bool> hasCompletedProfile(String uid) async {
    final user = await getUser(uid);
    return user != null && user.handle.isNotEmpty;
  }

  /// Create a new user document
  Future<bool> createUser(AppUser user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
      return true;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return false;
    }
  }

  /// Update user profile fields
  Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(uid).update(data);
      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return false;
    }
  }

  /// Check if a handle is available
  /// Returns: true = available, false = taken, null = error occurred
  Future<bool?> isHandleAvailable(String handle) async {
    try {
      final handleLower = handle.toLowerCase();

      // Check reserved words
      if (_isReservedHandle(handleLower)) {
        debugPrint('Handle "$handle" is reserved');
        return false;
      }

      debugPrint('Checking handle availability: $handleLower');
      final doc = await _handlesCollection.doc(handleLower).get();
      final isAvailable = !doc.exists;
      debugPrint('Handle "$handleLower" available: $isAvailable');
      return isAvailable;
    } catch (e) {
      debugPrint('Error checking handle availability: $e');
      // Return null to indicate an error occurred (different from "taken")
      return null;
    }
  }

  /// Reserve a handle for a user using a transaction
  /// This ensures atomic operation to prevent race conditions
  Future<bool> reserveHandle({
    required String uid,
    required String handle,
    required String displayName,
    String? photoUrl,
  }) async {
    final handleLower = handle.toLowerCase();

    if (_isReservedHandle(handleLower)) {
      return false;
    }

    try {
      debugPrint('Attempting to reserve handle: $handle for uid: $uid');
      
      return await _firestore.runTransaction<bool>((transaction) async {
        // Check if handle is taken
        final handleDoc = await transaction.get(_handlesCollection.doc(handleLower));
        debugPrint('Handle doc exists: ${handleDoc.exists}');
        
        if (handleDoc.exists) {
          final existingUid = handleDoc.data()?['uid'];
          debugPrint('Handle already taken by uid: $existingUid');
          
          // If the handle is already owned by this user, allow it (re-setup case)
          if (existingUid == uid) {
            debugPrint('Handle is owned by same user, allowing re-setup');
          } else {
            // Handle is taken by someone else
            debugPrint('Handle is taken by different user');
            return false;
          }
        }

        // Check if user already has a handle
        final userDoc = await transaction.get(_usersCollection.doc(uid));
        debugPrint('User doc exists: ${userDoc.exists}');

        if (userDoc.exists) {
          final existingHandle = userDoc.data()?['handle'] as String?;
          debugPrint('User existing handle: $existingHandle');
          
          if (existingHandle != null && existingHandle.isNotEmpty) {
            final oldHandleLower = existingHandle.toLowerCase();
            // Only delete old handle if it's different from the new one
            if (oldHandleLower != handleLower) {
              debugPrint('Releasing old handle: $oldHandleLower');
              transaction.delete(_handlesCollection.doc(oldHandleLower));
            }
          }
        }

        // Reserve the new handle
        debugPrint('Reserving handle: $handleLower');
        transaction.set(_handlesCollection.doc(handleLower), {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create or update user document
        final now = DateTime.now();
        final userData = AppUser(
          uid: uid,
          handle: handle,
          displayName: displayName,
          photoUrl: photoUrl,
          createdAt: now,
        ).toMap();

        if (userDoc.exists) {
          debugPrint('Updating existing user document');
          transaction.update(_usersCollection.doc(uid), {
            'handle': handle,
            'handle_lower': handleLower,
            'displayName': displayName,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          debugPrint('Creating new user document');
          transaction.set(_usersCollection.doc(uid), userData);
        }

        debugPrint('Handle reservation successful');
        return true;
      });
    } catch (e) {
      debugPrint('Error reserving handle: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Search users by handle (for inviting to spaces)
  Future<List<AppUser>> searchUsersByHandle(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();

      // Search for handles starting with the query
      final snapshot = await _usersCollection
          .where('handle_lower', isGreaterThanOrEqualTo: queryLower)
          .where('handle_lower', isLessThan: '${queryLower}z')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Get user by handle
  Future<AppUser?> getUserByHandle(String handle) async {
    try {
      final handleLower = handle.toLowerCase();
      final snapshot = await _usersCollection
          .where('handle_lower', isEqualTo: handleLower)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return AppUser.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting user by handle: $e');
      return null;
    }
  }

  /// Update FCM token for push notifications
  Future<bool> updateFcmToken(String uid, String token) async {
    try {
      await _usersCollection.doc(uid).update({
        'fcmTokens.$token': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      return false;
    }
  }

  /// Remove FCM token
  Future<bool> removeFcmToken(String uid, String token) async {
    try {
      await _usersCollection.doc(uid).update({
        'fcmTokens.$token': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
      return false;
    }
  }

  /// Update user theme settings
  Future<bool> updateThemeSettings(String uid, UserThemeSettings settings) async {
    try {
      await _usersCollection.doc(uid).update({
        'theme': settings.toMap(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating theme settings: $e');
      return false;
    }
  }

  bool _isReservedHandle(String handle) {
    const reservedHandles = {
      'admin',
      'administrator',
      'support',
      'help',
      'system',
      'official',
      'nudge',
      'app',
      'api',
      'www',
      'mail',
      'email',
      'info',
      'contact',
      'root',
      'user',
      'users',
      'account',
      'accounts',
      'settings',
      'profile',
      'null',
      'undefined',
      'test',
      'demo',
    };
    return reservedHandles.contains(handle);
  }
}
