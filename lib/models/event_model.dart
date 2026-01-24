import 'package:cloud_firestore/cloud_firestore.dart';

class EventFolder {
  final String id;
  final String name;
  final String driveFolderId;

  EventFolder({
    required this.id,
    required this.name,
    required this.driveFolderId,
  });

  factory EventFolder.fromMap(Map<String, dynamic> map) {
    return EventFolder(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      driveFolderId: map['driveFolderId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'driveFolderId': driveFolderId,
    };
  }

  EventFolder copyWith({
    String? id,
    String? name,
    String? driveFolderId,
  }) {
    return EventFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      driveFolderId: driveFolderId ?? this.driveFolderId,
    );
  }

  @override
  String toString() {
    return 'EventFolder(id: $id, name: $name, driveFolderId: $driveFolderId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class EventModel {
  final String id;
  final String name;
  final String creatorId;
  final String eventCode;
  final String driveRootFolderId;
  final String? publicDriveLink;
  final List<EventFolder> folders;
  final List<String> memberIds;
  final List<String> pendingMemberIds;
  final DateTime? createdAt;

  EventModel({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.eventCode,
    required this.driveRootFolderId,
    this.publicDriveLink,
    required this.folders,
    required this.memberIds,
    required this.pendingMemberIds,
    this.createdAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    return EventModel(
      id: id,
      name: map['name'] ?? '',
      creatorId: map['creatorId'] ?? '',
      eventCode: map['eventCode'] ?? '',
      driveRootFolderId: map['driveRootFolderId'] ?? '',
      publicDriveLink: map['publicDriveLink'],
      folders: (map['folders'] as List<dynamic>?)
              ?.map((f) => EventFolder.fromMap(f as Map<String, dynamic>))
              .toList() ??
          [],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      pendingMemberIds: List<String>.from(map['pendingMemberIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'creatorId': creatorId,
      'eventCode': eventCode,
      'driveRootFolderId': driveRootFolderId,
      'publicDriveLink': publicDriveLink,
      'folders': folders.map((f) => f.toMap()).toList(),
      'memberIds': memberIds,
      'pendingMemberIds': pendingMemberIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  EventModel copyWith({
    String? id,
    String? name,
    String? creatorId,
    String? eventCode,
    String? driveRootFolderId,
    String? publicDriveLink,
    List<EventFolder>? folders,
    List<String>? memberIds,
    List<String>? pendingMemberIds,
    DateTime? createdAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      eventCode: eventCode ?? this.eventCode,
      driveRootFolderId: driveRootFolderId ?? this.driveRootFolderId,
      publicDriveLink: publicDriveLink ?? this.publicDriveLink,
      folders: folders ?? this.folders,
      memberIds: memberIds ?? this.memberIds,
      pendingMemberIds: pendingMemberIds ?? this.pendingMemberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool isCreator(String userId) => creatorId == userId;
  
  bool isMember(String userId) => memberIds.contains(userId) || creatorId == userId;
  
  bool isPending(String userId) => pendingMemberIds.contains(userId);

  EventFolder? get defaultFolder => folders.isNotEmpty ? folders.first : null;

  @override
  String toString() {
    return 'EventModel(id: $id, name: $name, eventCode: $eventCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
