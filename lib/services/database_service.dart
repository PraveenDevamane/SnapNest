import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/event_model.dart';
import '../models/photo_metadata.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');
  
  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');
  
  CollectionReference<Map<String, dynamic>> get _photosRef =>
      _firestore.collection('photos');

  // ==================== USER OPERATIONS ====================

  /// Create or update user profile
  Future<void> saveUser(AppUser user) async {
    await _usersRef.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  /// Get user by ID
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  /// Get user stream
  Stream<AppUser?> getUserStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!, doc.id);
    });
  }

  /// Get multiple users by IDs
  Future<List<AppUser>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    final results = await Future.wait(
      uids.map((uid) => _usersRef.doc(uid).get()),
    );
    
    return results
        .where((doc) => doc.exists)
        .map((doc) => AppUser.fromMap(doc.data()!, doc.id))
        .toList();
  }

  // ==================== EVENT OPERATIONS ====================

  /// Create a new event
  Future<String> createEvent(EventModel event) async {
    final docRef = await _eventsRef.add(event.toMap());
    return docRef.id;
  }

  /// Update event
  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _eventsRef.doc(eventId).update(data);
  }

  /// Get event by ID
  Future<EventModel?> getEvent(String eventId) async {
    final doc = await _eventsRef.doc(eventId).get();
    if (!doc.exists) return null;
    return EventModel.fromMap(doc.data()!, doc.id);
  }

  /// Get event by code
  Future<EventModel?> getEventByCode(String eventCode) async {
    final query = await _eventsRef
        .where('eventCode', isEqualTo: eventCode.toUpperCase())
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    return EventModel.fromMap(query.docs.first.data(), query.docs.first.id);
  }

  /// Get events where user is a member
  Stream<List<EventModel>> getUserEvents(String userId) {
    return _eventsRef
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get events created by user
  Stream<List<EventModel>> getCreatedEvents(String userId) {
    return _eventsRef
        .where('creatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get event stream
  Stream<EventModel?> getEventStream(String eventId) {
    return _eventsRef.doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Add user to pending members
  Future<void> requestJoinEvent(String eventId, String userId) async {
    await _eventsRef.doc(eventId).update({
      'pendingMemberIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Approve join request
  Future<void> approveJoinRequest(String eventId, String userId) async {
    await _eventsRef.doc(eventId).update({
      'pendingMemberIds': FieldValue.arrayRemove([userId]),
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Reject join request
  Future<void> rejectJoinRequest(String eventId, String userId) async {
    await _eventsRef.doc(eventId).update({
      'pendingMemberIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Add folder to event
  Future<void> addEventFolder(String eventId, EventFolder folder) async {
    await _eventsRef.doc(eventId).update({
      'folders': FieldValue.arrayUnion([folder.toMap()]),
    });
  }

  /// Check if event code exists
  Future<bool> eventCodeExists(String code) async {
    final query = await _eventsRef
        .where('eventCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ==================== PHOTO OPERATIONS ====================

  /// Create photo metadata
  Future<String> createPhoto(PhotoMetadata photo) async {
    final docRef = await _photosRef.add(photo.toMap());
    return docRef.id;
  }

  /// Update photo metadata
  Future<void> updatePhoto(String photoId, Map<String, dynamic> data) async {
    await _photosRef.doc(photoId).update(data);
  }

  /// Get photo by ID
  Future<PhotoMetadata?> getPhoto(String photoId) async {
    final doc = await _photosRef.doc(photoId).get();
    if (!doc.exists) return null;
    return PhotoMetadata.fromMap(doc.data()!, doc.id);
  }

  /// Get photos for event folder
  Stream<List<PhotoMetadata>> getEventFolderPhotos(
    String eventId,
    String folderId,
  ) {
    debugPrint('🔍 Querying photos: eventId=$eventId, folderId=$folderId');
    
    // Simplified query without orderBy to avoid index requirement
    return _photosRef
        .where('eventId', isEqualTo: eventId)
        .where('folderId', isEqualTo: folderId)
        .snapshots()
        .map((snapshot) {
          debugPrint('🔍 Query returned ${snapshot.docs.length} documents');
          final photos = snapshot.docs
              .map((doc) => PhotoMetadata.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort in memory instead
          photos.sort((a, b) {
            final aTime = a.uploadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.uploadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // descending
          });
          
          return photos;
        });
  }

  /// Get all photos for event
  Stream<List<PhotoMetadata>> getEventPhotos(String eventId) {
    return _photosRef
        .where('eventId', isEqualTo: eventId)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotoMetadata.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get user's photos in event
  Stream<List<PhotoMetadata>> getUserEventPhotos(
    String eventId,
    String userId,
  ) {
    return _photosRef
        .where('eventId', isEqualTo: eventId)
        .where('ownerId', isEqualTo: userId)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotoMetadata.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Delete photo
  Future<void> deletePhoto(String photoId) async {
    await _photosRef.doc(photoId).delete();
  }

  /// Get set of Drive file IDs already tracked in Firestore for an event
  Future<Set<String>> getTrackedDriveFileIds(String eventId) async {
    final query = await _photosRef
        .where('eventId', isEqualTo: eventId)
        .where('driveFileId', isNull: false)
        .get();
    
    return query.docs
        .map((doc) => doc.data()['driveFileId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  /// Batch-create multiple photo metadata docs
  Future<void> createPhotoBatch(List<PhotoMetadata> photos) async {
    if (photos.isEmpty) return;
    
    final batch = _firestore.batch();
    for (final photo in photos) {
      final docRef = _photosRef.doc();
      batch.set(docRef, photo.toMap());
    }
    await batch.commit();
  }

  /// Get pending uploads for user
  Future<List<PhotoMetadata>> getPendingUploads(String userId) async {
    final query = await _photosRef
        .where('ownerId', isEqualTo: userId)
        .where('uploadStatus', whereIn: ['pending', 'uploading'])
        .get();
    
    return query.docs
        .map((doc) => PhotoMetadata.fromMap(doc.data(), doc.id))
        .toList();
  }
}
