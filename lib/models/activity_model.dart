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
  itemDeleted,
  itemUncompleted,
  itemUpdated,
  itemRestored,
  memberRoleChanged,
  ping,
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
  final Map<String, dynamic>? metadata;
  final List<String>? visibleTo;

  const SpaceActivity({
    required this.activityId,
    required this.spaceId,
    required this.actorUid,
    required this.type,
    this.targetUid,
    this.itemId,
    this.itemTitle,
    required this.createdAt,
    this.metadata,
    this.visibleTo,
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
      metadata: (data['metadata'] as Map<String, dynamic>?),
      visibleTo: (data['visibleTo'] as List<dynamic>?)?.cast<String>(),
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
      if (metadata != null) 'metadata': metadata,
      if (visibleTo != null) 'visibleTo': visibleTo,
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
    Map<String, dynamic>? metadata,
    List<String>? visibleTo,
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
      metadata: metadata ?? this.metadata,
      visibleTo: visibleTo ?? this.visibleTo,
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
      case ActivityType.itemDeleted:
        return '$actor deleted "${itemTitle ?? 'a reminder'}"';
      case ActivityType.itemUncompleted:
        return '$actor uncompleted "${itemTitle ?? 'a reminder'}"';
      case ActivityType.itemUpdated:
        return _getUpdateDescription(actor);
      case ActivityType.itemRestored:
        return '$actor restored "${itemTitle ?? 'a reminder'}"';
      case ActivityType.memberRoleChanged:
        final newRole = metadata?['newRole'] as String? ?? 'member';
        return '$actor changed $target\'s role to $newRole';
      case ActivityType.ping:
        return '$actor nudged $target about "${itemTitle ?? 'a reminder'}"';
    }
  }

  String _getUpdateDescription(String actor) {
    final title = itemTitle ?? 'a reminder';
    if (metadata == null) return '$actor updated "$title"';

    final changedFields = (metadata!['changedFields'] as List<dynamic>?)?.cast<String>() ?? [];
    if (changedFields.isEmpty) return '$actor updated "$title"';

    final descriptions = <String>[];
    for (final field in changedFields) {
      switch (field) {
        case 'title':
          final from = metadata!['titleFrom'] as String?;
          final to = metadata!['titleTo'] as String?;
          if (from != null && to != null) {
            descriptions.add('renamed "$from" to "$to"');
          }
        case 'priority':
          final from = metadata!['priorityFrom'] as String?;
          final to = metadata!['priorityTo'] as String?;
          if (from != null && to != null) {
            descriptions.add('changed priority from $from to $to');
          }
        case 'assigned':
          descriptions.add('changed assignment');
        case 'remindAt':
          descriptions.add('changed reminder time');
        case 'details':
          descriptions.add('updated details');
        case 'repeatRule':
          descriptions.add('changed repeat rule');
      }
    }

    if (descriptions.isEmpty) return '$actor updated "$title"';
    return '$actor ${descriptions.first}';
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
        metadata,
        visibleTo,
      ];
}
