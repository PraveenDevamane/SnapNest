import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

enum PhotoUploadStatus { pending, uploading, completed, failed }

enum PhotoStorageType { localOnly, shared }

class PhotoMetadata {
  final String id;
  final String eventId;
  final String folderId;
  final String ownerId;
  final String? localPath;
  final String? driveFileId;
  final String? driveWebLink;
  final DateTime? uploadTime;
  final PhotoUploadStatus uploadStatus;
  final PhotoStorageType storageType;

  PhotoMetadata({
    required this.id,
    required this.eventId,
    required this.folderId,
    required this.ownerId,
    this.localPath,
    this.driveFileId,
    this.driveWebLink,
    this.uploadTime,
    this.uploadStatus = PhotoUploadStatus.pending,
    this.storageType = PhotoStorageType.shared,
  });

  factory PhotoMetadata.fromMap(Map<String, dynamic> map, String id) {
    return PhotoMetadata(
      id: id,
      eventId: map['eventId'] ?? '',
      folderId: map['folderId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      localPath: map['localPath'],
      driveFileId: map['driveFileId'],
      driveWebLink: map['driveWebLink'],
      uploadTime: map['uploadTime'] != null
          ? (map['uploadTime'] as Timestamp).toDate()
          : null,
      uploadStatus: PhotoUploadStatus.values.firstWhere(
        (e) => e.name == map['uploadStatus'],
        orElse: () => PhotoUploadStatus.pending,
      ),
      storageType: PhotoStorageType.values.firstWhere(
        (e) => e.name == map['storageType'],
        orElse: () => PhotoStorageType.shared,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'folderId': folderId,
      'ownerId': ownerId,
      'localPath': localPath,
      'driveFileId': driveFileId,
      'driveWebLink': driveWebLink,
      'uploadTime': uploadTime != null 
          ? Timestamp.fromDate(uploadTime!) 
          : FieldValue.serverTimestamp(),
      'uploadStatus': uploadStatus.name,
      'storageType': storageType.name,
    };
  }

  PhotoMetadata copyWith({
    String? id,
    String? eventId,
    String? folderId,
    String? ownerId,
    String? localPath,
    String? driveFileId,
    String? driveWebLink,
    DateTime? uploadTime,
    PhotoUploadStatus? uploadStatus,
    PhotoStorageType? storageType,
  }) {
    return PhotoMetadata(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      folderId: folderId ?? this.folderId,
      ownerId: ownerId ?? this.ownerId,
      localPath: localPath ?? this.localPath,
      driveFileId: driveFileId ?? this.driveFileId,
      driveWebLink: driveWebLink ?? this.driveWebLink,
      uploadTime: uploadTime ?? this.uploadTime,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      storageType: storageType ?? this.storageType,
    );
  }

  /// Get the URL for displaying this photo
  String? get displayUrl {
    if (driveFileId != null) {
      return DriveConfig.getViewUrl(driveFileId!);
    }
    return null;
  }

  /// Get the thumbnail URL for this photo
  String? get thumbnailUrl {
    if (driveFileId != null) {
      return DriveConfig.getThumbnailUrl(driveFileId!);
    }
    return null;
  }

  /// Get the download URL for this photo
  String? get downloadUrl {
    if (driveFileId != null) {
      return DriveConfig.getDownloadUrl(driveFileId!);
    }
    return null;
  }

  bool get isUploaded => uploadStatus == PhotoUploadStatus.completed;
  bool get isPending => uploadStatus == PhotoUploadStatus.pending;
  bool get isUploading => uploadStatus == PhotoUploadStatus.uploading;
  bool get isFailed => uploadStatus == PhotoUploadStatus.failed;
  bool get isLocalOnly => storageType == PhotoStorageType.localOnly;
  bool get isShared => storageType == PhotoStorageType.shared;

  @override
  String toString() {
    return 'PhotoMetadata(id: $id, eventId: $eventId, status: $uploadStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotoMetadata && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
