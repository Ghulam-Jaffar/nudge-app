import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ItemType { personal, space }

enum NotifyStatus { none, scheduled, sent, cancelled }

enum ItemPriority { none, low, medium, high }

class ReminderItem extends Equatable {
  final String itemId;
  final ItemType type;
  final String? ownerUid;
  final String? spaceId;
  final String title;
  final String? details;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String updatedByUid;
  final DateTime? remindAt;
  final String? timezone;
  final NotifyStatus notifyStatus;
  final String? notifyJobId;
  final ItemPriority priority;
  final String? repeatRule; // 'none', 'daily', 'weekly'
  final String? assignedToUid; // User assigned to this item (for space items)
  final List<String> viewedBy; // UIDs of users who have viewed this item

  const ReminderItem({
    required this.itemId,
    required this.type,
    this.ownerUid,
    this.spaceId,
    required this.title,
    this.details,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
    this.remindAt,
    this.timezone,
    this.notifyStatus = NotifyStatus.none,
    this.notifyJobId,
    this.priority = ItemPriority.none,
    this.repeatRule,
    this.assignedToUid,
    this.viewedBy = const [],
  });

  factory ReminderItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReminderItem(
      itemId: doc.id,
      type: data['type'] == 'space' ? ItemType.space : ItemType.personal,
      ownerUid: data['ownerUid'] as String?,
      spaceId: data['spaceId'] as String?,
      title: data['title'] as String? ?? '',
      details: data['details'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUid: data['createdByUid'] as String? ?? '',
      updatedByUid: data['updatedByUid'] as String? ?? '',
      remindAt: (data['remindAt'] as Timestamp?)?.toDate(),
      timezone: data['timezone'] as String?,
      notifyStatus: NotifyStatus.values.firstWhere(
        (e) => e.name == data['notifyStatus'],
        orElse: () => NotifyStatus.none,
      ),
      notifyJobId: data['notifyJobId'] as String?,
      priority: ItemPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => ItemPriority.none,
      ),
      repeatRule: data['repeatRule'] as String?,
      assignedToUid: data['assignedToUid'] as String?,
      viewedBy: (data['viewedBy'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'type': type.name,
      if (ownerUid != null) 'ownerUid': ownerUid,
      if (spaceId != null) 'spaceId': spaceId,
      'title': title,
      if (details != null) 'details': details,
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
      if (remindAt != null) 'remindAt': Timestamp.fromDate(remindAt!),
      if (timezone != null) 'timezone': timezone,
      'notifyStatus': notifyStatus.name,
      if (notifyJobId != null) 'notifyJobId': notifyJobId,
      'priority': priority.name,
      if (repeatRule != null) 'repeatRule': repeatRule,
      if (assignedToUid != null) 'assignedToUid': assignedToUid,
      'viewedBy': viewedBy,
    };
  }

  ReminderItem copyWith({
    String? itemId,
    ItemType? type,
    String? ownerUid,
    String? spaceId,
    String? title,
    String? details,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
    DateTime? remindAt,
    String? timezone,
    NotifyStatus? notifyStatus,
    String? notifyJobId,
    ItemPriority? priority,
    String? repeatRule,
    String? assignedToUid,
    List<String>? viewedBy,
  }) {
    return ReminderItem(
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      ownerUid: ownerUid ?? this.ownerUid,
      spaceId: spaceId ?? this.spaceId,
      title: title ?? this.title,
      details: details ?? this.details,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      remindAt: remindAt ?? this.remindAt,
      timezone: timezone ?? this.timezone,
      notifyStatus: notifyStatus ?? this.notifyStatus,
      notifyJobId: notifyJobId ?? this.notifyJobId,
      priority: priority ?? this.priority,
      repeatRule: repeatRule ?? this.repeatRule,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      viewedBy: viewedBy ?? this.viewedBy,
    );
  }

  @override
  List<Object?> get props => [
        itemId,
        type,
        ownerUid,
        spaceId,
        title,
        details,
        isCompleted,
        completedAt,
        createdAt,
        updatedAt,
        createdByUid,
        updatedByUid,
        remindAt,
        timezone,
        notifyStatus,
        notifyJobId,
        priority,
        repeatRule,
        assignedToUid,
        viewedBy,
      ];
}
