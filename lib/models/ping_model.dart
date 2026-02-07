import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Ping extends Equatable {
  final String pingId;
  final String spaceId;
  final String itemId;
  final String itemTitle;
  final String fromUid;
  final String toUid;
  final DateTime createdAt;
  final DateTime? seenAt;

  const Ping({
    required this.pingId,
    required this.spaceId,
    required this.itemId,
    required this.itemTitle,
    required this.fromUid,
    required this.toUid,
    required this.createdAt,
    this.seenAt,
  });

  bool get isSeen => seenAt != null;

  factory Ping.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Ping(
      pingId: doc.id,
      spaceId: data['spaceId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      itemTitle: data['itemTitle'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seenAt: (data['seenAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pingId': pingId,
      'spaceId': spaceId,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'fromUid': fromUid,
      'toUid': toUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'seenAt': seenAt != null ? Timestamp.fromDate(seenAt!) : null,
    };
  }

  Ping copyWith({
    String? pingId,
    String? spaceId,
    String? itemId,
    String? itemTitle,
    String? fromUid,
    String? toUid,
    DateTime? createdAt,
    DateTime? seenAt,
  }) {
    return Ping(
      pingId: pingId ?? this.pingId,
      spaceId: spaceId ?? this.spaceId,
      itemId: itemId ?? this.itemId,
      itemTitle: itemTitle ?? this.itemTitle,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      createdAt: createdAt ?? this.createdAt,
      seenAt: seenAt ?? this.seenAt,
    );
  }

  @override
  List<Object?> get props => [
        pingId,
        spaceId,
        itemId,
        itemTitle,
        fromUid,
        toUid,
        createdAt,
        seenAt,
      ];
}
