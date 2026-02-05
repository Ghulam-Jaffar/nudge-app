import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum InviteStatus { pending, accepted, declined, revoked }

class SpaceInvite extends Equatable {
  final String inviteId;
  final String spaceId;
  final String spaceNameSnapshot;
  final String fromUid;
  final String toUid;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const SpaceInvite({
    required this.inviteId,
    required this.spaceId,
    required this.spaceNameSnapshot,
    required this.fromUid,
    required this.toUid,
    this.status = InviteStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  factory SpaceInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpaceInvite(
      inviteId: doc.id,
      spaceId: data['spaceId'] as String? ?? '',
      spaceNameSnapshot: data['spaceNameSnapshot'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      status: InviteStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => InviteStatus.pending,
      ),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteId': inviteId,
      'spaceId': spaceId,
      'spaceNameSnapshot': spaceNameSnapshot,
      'fromUid': fromUid,
      'toUid': toUid,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
    };
  }

  SpaceInvite copyWith({
    String? inviteId,
    String? spaceId,
    String? spaceNameSnapshot,
    String? fromUid,
    String? toUid,
    InviteStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return SpaceInvite(
      inviteId: inviteId ?? this.inviteId,
      spaceId: spaceId ?? this.spaceId,
      spaceNameSnapshot: spaceNameSnapshot ?? this.spaceNameSnapshot,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  @override
  List<Object?> get props => [
        inviteId,
        spaceId,
        spaceNameSnapshot,
        fromUid,
        toUid,
        status,
        createdAt,
        respondedAt,
      ];
}
