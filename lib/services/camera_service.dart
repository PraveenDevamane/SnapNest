import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.auto;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null;
  FlashMode get flashMode => _flashMode;
  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  bool get hasFrontCamera => _cameras.length > 1;
  bool get isBackCamera =>
      _cameras.isNotEmpty &&
      _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.back;

  /// Initialize camera
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      // Start with back camera if available
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex < 0) _currentCameraIndex = 0;
      
      await _initializeController();
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Initialize the camera controller
  Future<void> _initializeController() async {
    await _controller?.dispose();
    
    _controller = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    
    // Get zoom limits
    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _currentZoom = _minZoom;
    
    // Set flash mode
    await _controller!.setFlashMode(_flashMode);
    
    _isInitialized = true;
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initializeController();
  }

  /// Set flash mode
  Future<void> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return;
    
    _flashMode = mode;
    await _controller!.setFlashMode(mode);
  }

  /// Cycle through flash modes
  Future<FlashMode> cycleFlashMode() async {
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      default:
        nextMode = FlashMode.auto;
    }
    await setFlashMode(nextMode);
    return nextMode;
  }

  /// Set zoom level
  Future<void> setZoom(double zoom) async {
    if (!isInitialized) return;
    
    _currentZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(_currentZoom);
  }

  /// Capture a photo
  Future<File?> capturePhoto() async {
    if (!isInitialized || _controller!.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'IMG_$timestamp.jpg';
      final filePath = path.join(photosDir.path, fileName);
      
      // Copy to permanent location
      final file = File(image.path);
      final savedFile = await file.copy(filePath);
      
      // Delete temporary file
      await file.delete();
      
      return savedFile;
    } catch (e) {
      rethrow;
    }
  }

  /// Focus on a point
  Future<void> focusOnPoint(Offset point, Size previewSize) async {
    if (!isInitialized) return;
    
    try {
      final x = point.dx / previewSize.width;
      final y = point.dy / previewSize.height;
      
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
    } catch (e) {
      // Focus not supported on this device
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isInitialized = false;
    await _controller?.dispose();
    _controller = null;
  }
}
