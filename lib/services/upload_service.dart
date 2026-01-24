import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/photo_metadata.dart';
import 'database_service.dart';
import 'google_drive_service.dart';

class UploadService {
  final DatabaseService _dbService;
  final GoogleDriveService _driveService;
  final Connectivity _connectivity = Connectivity();
  
  final Map<String, StreamController<PhotoUploadStatus>> _statusControllers = {};
  final Set<String> _uploadingIds = {};

  UploadService(this._dbService, this._driveService);

  /// Get status stream for a photo
  Stream<PhotoUploadStatus> getStatusStream(String photoId) {
    _statusControllers[photoId] ??= StreamController<PhotoUploadStatus>.broadcast();
    return _statusControllers[photoId]!.stream;
  }

  /// Upload a photo to Google Drive
  Future<PhotoMetadata> uploadPhoto(
    PhotoMetadata photo,
    String driveFolderId,
  ) async {
    // Check if already uploading
    if (_uploadingIds.contains(photo.id)) {
      return photo;
    }

    // Check network connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception('No network connection');
    }

    // Check if local file exists
    if (photo.localPath == null || !File(photo.localPath!).existsSync()) {
      throw Exception('Local file not found');
    }

    _uploadingIds.add(photo.id);
    
    try {
      // Update status to uploading
      await _updatePhotoStatus(photo.id, PhotoUploadStatus.uploading);

      // Upload to Google Drive
      final file = File(photo.localPath!);
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await _driveService.uploadFile(
        file,
        driveFolderId,
        fileName,
      );

      // Update photo with Drive info
      final updatedPhoto = photo.copyWith(
        driveFileId: result.fileId,
        driveWebLink: result.webLink,
        uploadStatus: PhotoUploadStatus.completed,
        uploadTime: DateTime.now(),
      );

      await _dbService.updatePhoto(photo.id, {
        'driveFileId': result.fileId,
        'driveWebLink': result.webLink,
        'uploadStatus': PhotoUploadStatus.completed.name,
        'uploadTime': DateTime.now(),
      });

      await _updatePhotoStatus(photo.id, PhotoUploadStatus.completed);
      
      return updatedPhoto;
    } catch (e) {
      await _updatePhotoStatus(photo.id, PhotoUploadStatus.failed);
      rethrow;
    } finally {
      _uploadingIds.remove(photo.id);
    }
  }

  /// Update photo status and notify listeners
  Future<void> _updatePhotoStatus(
    String photoId,
    PhotoUploadStatus status,
  ) async {
    await _dbService.updatePhoto(photoId, {
      'uploadStatus': status.name,
    });
    
    _statusControllers[photoId]?.add(status);
  }

  /// Retry failed uploads
  Future<void> retryFailedUploads(
    String userId,
    Map<String, String> folderMap, // eventId+folderId -> driveFolderId
  ) async {
    final pendingPhotos = await _dbService.getPendingUploads(userId);
    
    for (final photo in pendingPhotos) {
      final key = '${photo.eventId}_${photo.folderId}';
      final driveFolderId = folderMap[key];
      
      if (driveFolderId != null && photo.isFailed) {
        try {
          await uploadPhoto(photo, driveFolderId);
        } catch (e) {
          // Continue with next photo
        }
      }
    }
  }

  /// Cancel upload
  void cancelUpload(String photoId) {
    _uploadingIds.remove(photoId);
    _statusControllers[photoId]?.close();
    _statusControllers.remove(photoId);
  }

  /// Dispose resources
  void dispose() {
    for (final controller in _statusControllers.values) {
      controller.close();
    }
    _statusControllers.clear();
    _uploadingIds.clear();
  }
}
