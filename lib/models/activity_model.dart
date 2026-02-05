import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ActivityType {
  inviteSent,
  inviteAccepted,
  inviteDeclined,
  memberJoined,
  memberLeft,
  itemCreated,
  itemCompleted,
  itemAssigned,
}

class SpaceActivity extends Equatable {
  final String activityId;
  final String spaceId;
  final String actorUid;
  final ActivityType type;
  final String? targetUid;
  final String? itemId;
  final String? itemTitle;
  final DateTime createdAt;

  const SpaceActivity({
    required this.activityId,
    required this.spaceId,
    required this.actorUid,
    required this.type,
    this.targetUid,
    this.itemId,
    this.itemTitle,
    required this.createdAt,
  });

  factory SpaceActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpaceActivity(
      activityId: doc.id,
      spaceId: data['spaceId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ActivityType.itemCreated,
      ),
      targetUid: data['targetUid'] as String?,
      itemId: data['itemId'] as String?,
      itemTitle: data['itemTitle'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'spaceId': spaceId,
      'actorUid': actorUid,
      'type': type.name,
      if (targetUid != null) 'targetUid': targetUid,
      if (itemId != null) 'itemId': itemId,
      if (itemTitle != null) 'itemTitle': itemTitle,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SpaceActivity copyWith({
    String? activityId,
    String? spaceId,
    String? actorUid,
    ActivityType? type,
    String? targetUid,
    String? itemId,
    String? itemTitle,
    DateTime? createdAt,
  }) {
    return SpaceActivity(
      activityId: activityId ?? this.activityId,
      spaceId: spaceId ?? this.spaceId,
      actorUid: actorUid ?? this.actorUid,
      type: type ?? this.type,
      targetUid: targetUid ?? this.targetUid,
      itemId: itemId ?? this.itemId,
      itemTitle: itemTitle ?? this.itemTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String getDescription({
    String? actorName,
    String? targetName,
  }) {
    final actor = actorName ?? 'Someone';
    final target = targetName ?? 'someone';

    switch (type) {
      case ActivityType.inviteSent:
        return '$actor invited $target';
      case ActivityType.inviteAccepted:
        return '$actor accepted the invite';
      case ActivityType.inviteDeclined:
        return '$actor declined the invite';
      case ActivityType.memberJoined:
        return '$actor joined the space';
      case ActivityType.memberLeft:
        return '$actor left the space';
      case ActivityType.itemCreated:
        return '$actor created "${itemTitle ?? 'a reminder'}"';
      case ActivityType.itemCompleted:
        return '$actor completed "${itemTitle ?? 'a reminder'}"';
      case ActivityType.itemAssigned:
        return '$actor assigned "${itemTitle ?? 'a reminder'}" to $target';
    }
  }

  @override
  List<Object?> get props => [
        activityId,
        spaceId,
        actorUid,
        type,
        targetUid,
        itemId,
        itemTitle,
        createdAt,
      ];
}
