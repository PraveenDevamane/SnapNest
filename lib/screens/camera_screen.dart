import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../core/constants.dart';
import '../models/photo_metadata.dart';
import '../providers/event_provider.dart';
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _showFlash = false;
  String? _lastCapturedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _setImmersiveMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _resetSystemUI();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _setImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _resetSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      // Show flash effect
      setState(() => _showFlash = true);
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() => _showFlash = false);

      // Capture photo
      final file = await _cameraService.capturePhoto();

      if (file != null && mounted) {
        setState(() => _lastCapturedPath = file.path);

        // Upload to event
        final eventProvider = context.read<EventProvider>();
        await eventProvider.capturePhoto(file, PhotoStorageType.shared);

        _showSuccess('Photo captured!');
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _toggleFlash() async {
    final newMode = await _cameraService.cycleFlashMode();
    setState(() {});
    
    String message;
    switch (newMode) {
      case FlashMode.auto:
        message = 'Flash: Auto';
        break;
      case FlashMode.always:
        message = 'Flash: On';
        break;
      case FlashMode.off:
        message = 'Flash: Off';
        break;
      default:
        message = 'Flash: Auto';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (!_cameraService.hasFrontCamera) return;
    await _cameraService.switchCamera();
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _cameraService.controller != null)
            _buildCameraPreview()
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Flash overlay
          if (_showFlash)
            Container(
              color: Colors.white.withOpacity(0.8),
            ),

          // Controls
          if (_isInitialized) ...[
            // Top controls
            _buildTopControls(),

            // Bottom controls
            _buildBottomControls(),

            // Zoom indicator
            if (_cameraService.currentZoom > 1.0) _buildZoomIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller!;
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onScaleUpdate: (details) {
        final zoom = (_cameraService.currentZoom * details.scale).clamp(
          _cameraService.minZoom,
          _cameraService.maxZoom,
        );
        _cameraService.setZoom(zoom);
        setState(() {});
      },
      onTapDown: (details) {
        _cameraService.focusOnPoint(details.localPosition, size);
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: 1 / controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          _buildControlButton(
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Row(
            children: [
              // Flash toggle
              _buildControlButton(
                icon: _getFlashIcon(),
                onPressed: _toggleFlash,
              ),
              const SizedBox(width: 16),
              // Camera switch
              if (_cameraService.hasFrontCamera)
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  onPressed: _switchCamera,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery thumbnail
          _buildGalleryThumbnail(),

          // Capture button
          _buildCaptureButton(),

          // Placeholder for symmetry
          const SizedBox(width: 60, height: 60),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _capturePhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _isCapturing ? 55 : 65,
            height: _isCapturing ? 55 : 65,
            decoration: BoxDecoration(
              color: _isCapturing ? AppColors.primary : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryThumbnail() {
    if (_lastCapturedPath == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.photo, color: Colors.white54),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          _lastCapturedPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.photo,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomIndicator() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_cameraService.currentZoom.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_cameraService.flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      default:
        return Icons.flash_auto;
    }
  }
}
