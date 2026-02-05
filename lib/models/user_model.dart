import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserThemeSettings extends Equatable {
  final String mode; // 'light', 'dark', 'system'
  final String packId;
  final String? accent;

  const UserThemeSettings({
    this.mode = 'system',
    this.packId = 'candy',
    this.accent,
  });

  factory UserThemeSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserThemeSettings();
    return UserThemeSettings(
      mode: map['mode'] as String? ?? 'system',
      packId: map['packId'] as String? ?? 'candy',
      accent: map['accent'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'packId': packId,
      if (accent != null) 'accent': accent,
    };
  }

  UserThemeSettings copyWith({
    String? mode,
    String? packId,
    String? accent,
  }) {
    return UserThemeSettings(
      mode: mode ?? this.mode,
      packId: packId ?? this.packId,
      accent: accent ?? this.accent,
    );
  }

  @override
  List<Object?> get props => [mode, packId, accent];
}

class AppUser extends Equatable {
  final String uid;
  final String handle;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final Map<String, bool> fcmTokens;
  final UserThemeSettings theme;

  const AppUser({
    required this.uid,
    required this.handle,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.fcmTokens = const {},
    this.theme = const UserThemeSettings(),
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      handle: data['handle'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmTokens: Map<String, bool>.from(data['fcmTokens'] as Map? ?? {}),
      theme: UserThemeSettings.fromMap(data['theme'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'handle': handle,
      'handle_lower': handle.toLowerCase(),
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmTokens': fcmTokens,
      'theme': theme.toMap(),
    };
  }

  AppUser copyWith({
    String? uid,
    String? handle,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    Map<String, bool>? fcmTokens,
    UserThemeSettings? theme,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      theme: theme ?? this.theme,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        handle,
        displayName,
        photoUrl,
        createdAt,
        fcmTokens,
        theme,
      ];
}
