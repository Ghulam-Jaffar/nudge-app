import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MemberRole { owner, admin, member }

class SpaceMember extends Equatable {
  final String uid;
  final MemberRole role;
  final DateTime joinedAt;

  const SpaceMember({
    required this.uid,
    required this.role,
    required this.joinedAt,
  });

  factory SpaceMember.fromMap(String uid, Map<String, dynamic> map) {
    return SpaceMember(
      uid: uid,
      role: MemberRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => MemberRole.member,
      ),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  SpaceMember copyWith({
    String? uid,
    MemberRole? role,
    DateTime? joinedAt,
  }) {
    return SpaceMember(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [uid, role, joinedAt];
}

class Space extends Equatable {
  final String spaceId;
  final String name;
  final String? emoji;
  final String ownerUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;
  final Map<String, SpaceMember> members;

  const Space({
    required this.spaceId,
    required this.name,
    this.emoji,
    required this.ownerUid,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 1,
    this.members = const {},
  });

  factory Space.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final membersData = data['members'] as Map<String, dynamic>? ?? {};
    final members = membersData.map((uid, memberData) => MapEntry(
      uid,
      SpaceMember.fromMap(uid, memberData as Map<String, dynamic>),
    ));

    return Space(
      spaceId: doc.id,
      name: data['name'] as String? ?? '',
      emoji: data['emoji'] as String?,
      ownerUid: data['ownerUid'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: data['memberCount'] as int? ?? 1,
      members: members,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spaceId': spaceId,
      'name': name,
      if (emoji != null) 'emoji': emoji,
      'ownerUid': ownerUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'memberCount': memberCount,
      'members': members.map((uid, member) => MapEntry(uid, member.toMap())),
    };
  }

  Space copyWith({
    String? spaceId,
    String? name,
    String? emoji,
    String? ownerUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
    Map<String, SpaceMember>? members,
  }) {
    return Space(
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
    );
  }

  bool isMember(String uid) => members.containsKey(uid);

  bool isOwner(String uid) => ownerUid == uid;

  bool isAdmin(String uid) =>
      members[uid]?.role == MemberRole.admin ||
      members[uid]?.role == MemberRole.owner;

  @override
  List<Object?> get props => [
        spaceId,
        name,
        emoji,
        ownerUid,
        createdAt,
        updatedAt,
        memberCount,
        members,
      ];
}
