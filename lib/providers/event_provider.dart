import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/event_model.dart';
import '../models/photo_metadata.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../services/upload_service.dart';
import '../services/qr_service.dart';
import 'auth_provider.dart';

class EventProvider extends ChangeNotifier {
  final DatabaseService _dbService;
  final GoogleDriveService _driveService;
  final UploadService _uploadService;
  final QRService _qrService;
  final AuthProvider _authProvider;

  final Uuid _uuid = const Uuid();

  // State
  List<EventModel> _userEvents = [];
  EventModel? _currentEvent;
  String? _currentFolderId;
  List<PhotoMetadata> _currentPhotos = [];
  List<PhotoMetadata> _pendingPhotos =
      []; // Local photos not yet in Firestore stream
  bool _isLoading = false;
  bool _isPhotosLoading = false; // Track if photos are being loaded
  String? _error;
  bool _isRefreshing = false;

  // Subscriptions
  StreamSubscription<List<EventModel>>? _eventsSubscription;
  StreamSubscription<List<PhotoMetadata>>? _photosSubscription;
  StreamSubscription<EventModel?>? _currentEventSubscription;

  // Debounce timer for notifications
  Timer? _notifyDebounce;

  EventProvider(
    this._dbService,
    this._driveService,
    this._uploadService,
    this._qrService,
    this._authProvider,
  ) {
    _init();
  }

  // Getters
  List<EventModel> get userEvents => _userEvents;
  EventModel? get currentEvent => _currentEvent;
  String? get currentFolderId => _currentFolderId;
  List<PhotoMetadata> get currentPhotos => [
    ..._pendingPhotos,
    ..._currentPhotos,
  ];
  bool get isLoading => _isLoading;
  bool get isPhotosLoading => _isPhotosLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  String? get _userId => _authProvider.userId;

  /// Debounced notify to prevent excessive rebuilds
  void _debouncedNotify() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
  }

  /// Immediate notify for critical updates
  void _immediateNotify() {
    _notifyDebounce?.cancel();
    notifyListeners();
  }

  /// Initialize event subscriptions
  void _init() {
    if (_userId != null) {
      _subscribeToEvents();
    }

    // Listen for auth changes
    _authProvider.addListener(_onAuthChanged);
  }

  /// Handle auth state changes
  void _onAuthChanged() {
    if (_authProvider.isAuthenticated && _userId != null) {
      _subscribeToEvents();
    } else {
      _clearState();
    }
  }

  /// Subscribe to user's events
  void _subscribeToEvents() {
    _eventsSubscription?.cancel();
    if (_userId == null) return;

    _eventsSubscription = _dbService
        .getUserEvents(_userId!)
        .listen(
          (events) {
            _userEvents = events;
            _immediateNotify(); // Fast update for event list
          },
          onError: (e) {
            _error = e.toString();
            _immediateNotify();
          },
        );
  }

  /// Subscribe to current event (for real-time member updates)
  void _subscribeToCurrentEvent(String eventId) {
    _currentEventSubscription?.cancel();

    _currentEventSubscription = _dbService
        .getEventStream(eventId)
        .listen(
          (event) {
            if (event != null) {
              final hadPendingChanges =
                  _currentEvent?.pendingMemberIds.length !=
                  event.pendingMemberIds.length;
              final hadMemberChanges =
                  _currentEvent?.memberIds.length != event.memberIds.length;

              _currentEvent = event;

              // Use immediate notify for member changes (join requests)
              if (hadPendingChanges || hadMemberChanges) {
                _immediateNotify();
              } else {
                _debouncedNotify();
              }
            }
          },
          onError: (e) {
            _error = e.toString();
            _immediateNotify();
          },
        );
  }

  /// Subscribe to photos in current folder (null = all photos)
  void _subscribeToPhotos() {
    _photosSubscription?.cancel();
    if (_currentEvent == null) {
      _isPhotosLoading = false;
      return;
    }

    _isPhotosLoading = true; // Set loading when starting subscription
    
    // If folderId is null, subscribe to all photos in the event
    final Stream<List<PhotoMetadata>> photoStream;
    if (_currentFolderId == null) {
      photoStream = _dbService.getEventPhotos(_currentEvent!.id);
    } else {
      photoStream = _dbService.getEventFolderPhotos(
        _currentEvent!.id,
        _currentFolderId!,
      );
    }

    _photosSubscription = photoStream.listen(
      (photos) {
        final hadNewPhotos = photos.length != _currentPhotos.length;
        _currentPhotos = photos;
        _isPhotosLoading = false; // Photos loaded
        
        // Remove photos from pending that are now in the stream
        _pendingPhotos.removeWhere(
          (p) => photos.any((photo) => photo.id == p.id),
        );

        // Use immediate notify for new photos
        if (hadNewPhotos) {
          _immediateNotify();
        } else {
          _debouncedNotify();
        }
      },
      onError: (e) {
        _error = e.toString();
        _isPhotosLoading = false; // Stop loading on error
        _immediateNotify();
      },
    );
  }

  /// Force refresh all data
  Future<void> refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _immediateNotify();

    try {
      // Re-subscribe to get fresh data
      _subscribeToEvents();
      if (_currentEvent != null) {
        _subscribeToCurrentEvent(_currentEvent!.id);
        if (_currentFolderId != null) {
          _subscribeToPhotos();
        }
      }

      // Small delay to let subscriptions fire
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      _isRefreshing = false;
      _immediateNotify();
    }
  }

  /// Clear all state
  void _clearState() {
    _eventsSubscription?.cancel();
    _photosSubscription?.cancel();
    _currentEventSubscription?.cancel();
    _notifyDebounce?.cancel();
    _userEvents = [];
    _currentEvent = null;
    _currentFolderId = null;
    _currentPhotos = [];
    _pendingPhotos = [];
    notifyListeners();
  }

  /// Create a new event
  Future<EventModel?> createEvent(String name, String initialFolderName) async {
    if (_userId == null) return null;

    try {
      _setLoading(true);

      // Generate unique event code
      String eventCode;
      do {
        eventCode = _qrService.generateEventCode();
      } while (await _dbService.eventCodeExists(eventCode));

      // Create Google Drive folders
      final driveResult = await _driveService.createEventFolder(
        name,
        initialFolderName,
      );

      // Create event model
      final folderId = _uuid.v4();
      final event = EventModel(
        id: '', // Will be set by Firestore
        name: name,
        creatorId: _userId!,
        eventCode: eventCode,
        driveRootFolderId: driveResult.rootFolderId,
        publicDriveLink: driveResult.rootFolderLink,
        folders: [
          EventFolder(
            id: folderId,
            name: initialFolderName,
            driveFolderId: driveResult.subFolderId,
          ),
        ],
        memberIds: [_userId!],
        pendingMemberIds: [],
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      final eventId = await _dbService.createEvent(event);

      _setLoading(false);
      return event.copyWith(id: eventId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Join an event by code
  Future<bool> joinEvent(String eventCode) async {
    if (_userId == null) return false;

    try {
      _setLoading(true);

      final event = await _dbService.getEventByCode(eventCode);

      if (event == null) {
        throw Exception('Event not found');
      }

      if (event.isMember(_userId!)) {
        throw Exception('You are already a member of this event');
      }

      if (event.isPending(_userId!)) {
        throw Exception('Your join request is pending approval');
      }

      // Add to pending members
      await _dbService.requestJoinEvent(event.id, _userId!);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Approve a join request
  Future<bool> approveJoinRequest(String eventId, String userId) async {
    try {
      await _dbService.approveJoinRequest(eventId, userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Reject a join request
  Future<bool> rejectJoinRequest(String eventId, String userId) async {
    try {
      await _dbService.rejectJoinRequest(eventId, userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Add a new folder to event
  Future<bool> addFolder(String eventId, String folderName) async {
    if (_currentEvent == null) return false;

    try {
      _setLoading(true);

      // Create folder in Google Drive
      final driveFolderId = await _driveService.createSubFolder(
        _currentEvent!.driveRootFolderId,
        folderName,
      );

      // Create folder model
      final folder = EventFolder(
        id: _uuid.v4(),
        name: folderName,
        driveFolderId: driveFolderId,
      );

      // Add to Firestore
      await _dbService.addEventFolder(eventId, folder);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Set current event and folder (null folderId = show all photos)
  void setCurrentEvent(EventModel event, {String? folderId}) {
    // Clear old data IMMEDIATELY to prevent showing previous event's data
    _currentPhotos = [];
    _pendingPhotos = [];
    _isPhotosLoading = true; // Set loading state
    
    _currentEvent = event;
    // Start with "All" view (null) by default
    _currentFolderId = folderId;

    _subscribeToCurrentEvent(event.id);
    _subscribeToPhotos();
    notifyListeners();
  }

  /// Change current folder (null = show all photos)
  void setCurrentFolder(String? folderId) {
    _currentFolderId = folderId;
    _pendingPhotos = [];
    _subscribeToPhotos();
    notifyListeners();
  }

  /// Clear current event
  void clearCurrentEvent() {
    _currentEventSubscription?.cancel();
    _photosSubscription?.cancel();
    _currentEvent = null;
    _currentFolderId = null;
    _currentPhotos = [];
    _pendingPhotos = [];
    notifyListeners();
  }

  /// Capture and upload photo
  Future<PhotoMetadata?> capturePhoto(
    File file,
    PhotoStorageType storageType,
  ) async {
    if (_userId == null || _currentEvent == null || _currentFolderId == null) {
      return null;
    }

    try {
      // Create photo metadata with temp ID
      final tempId = _uuid.v4();
      var photo = PhotoMetadata(
        id: tempId,
        eventId: _currentEvent!.id,
        folderId: _currentFolderId!,
        ownerId: _userId!,
        localPath: file.path,
        uploadStatus: PhotoUploadStatus.pending,
        storageType: storageType,
        uploadTime: DateTime.now(),
      );

      // Add to pending photos for immediate display
      _pendingPhotos.insert(0, photo);
      notifyListeners();

      // Save to Firestore and get the actual document ID
      final firestoreId = await _dbService.createPhoto(photo);

      // Update photo with Firestore document ID
      photo = photo.copyWith(id: firestoreId);

      // Update pending photo with correct ID
      final pendingIndex = _pendingPhotos.indexWhere((p) => p.id == tempId);
      if (pendingIndex >= 0) {
        _pendingPhotos[pendingIndex] = photo;
      }

      // If shared, start upload
      if (storageType == PhotoStorageType.shared) {
        // Get drive folder ID
        final folder = _currentEvent!.folders.firstWhere(
          (f) => f.id == _currentFolderId,
        );

        // Upload in background with correct Firestore ID
        _uploadPhotoAsync(photo, folder.driveFolderId);
      }

      return photo;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Upload photo asynchronously
  Future<void> _uploadPhotoAsync(
    PhotoMetadata photo,
    String driveFolderId,
  ) async {
    try {
      await _uploadService.uploadPhoto(photo, driveFolderId);
    } catch (e) {
      // Error is handled by upload service
      debugPrint('Upload failed: $e');
    }
  }

  /// Retry failed photo upload
  Future<bool> retryUpload(PhotoMetadata photo) async {
    if (_currentEvent == null) return false;

    try {
      final folder = _currentEvent!.folders.firstWhere(
        (f) => f.id == photo.folderId,
      );

      await _uploadService.uploadPhoto(photo, folder.driveFolderId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Get event by code (for QR scanning)
  Future<EventModel?> getEventByCode(String code) async {
    return await _dbService.getEventByCode(code);
  }

  /// Get users for an event
  Future<List<dynamic>> getEventMembers(List<String> userIds) async {
    return await _dbService.getUsers(userIds);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _eventsSubscription?.cancel();
    _photosSubscription?.cancel();
    _currentEventSubscription?.cancel();
    _uploadService.dispose();
    super.dispose();
  }
}
