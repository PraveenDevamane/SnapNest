import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import '../core/constants.dart';

/// Result returned from the photo preview screen
enum PhotoPreviewResult {
  /// Share photo with the event (upload to cloud)
  shareWithEvent,

  /// Save photo to device gallery only (don't share with event)
  saveLocally,

  /// Discard the photo (delete it)
  discard,
}

/// Full-screen preview of a captured photo with action options
/// Supports both single image mode (for new captures) and multi-image mode (for viewing)
class PhotoPreviewScreen extends StatefulWidget {
  /// Single image file (for capture mode)
  final File? imageFile;

  /// List of image files (for view-only mode with swipe support)
  final List<File>? imageFiles;

  /// Initial index when viewing multiple images
  final int initialIndex;

  /// If true, shows only a close button (for viewing previously captured photos)
  final bool isViewOnly;

  const PhotoPreviewScreen({
    super.key,
    this.imageFile,
    this.imageFiles,
    this.initialIndex = 0,
    this.isViewOnly = false,
  }) : assert(
         imageFile != null || imageFiles != null,
         'Either imageFile or imageFiles must be provided',
       );

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isProcessing = false;
  String? _processingMessage;
  late PageController _pageController;
  late int _currentIndex;

  /// Get the list of files (either single or multiple)
  List<File> get _files => widget.imageFiles ?? [widget.imageFile!];

  /// Get the current file being displayed
  File get _currentFile => _files[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _files.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _setImmersiveMode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resetSystemUI();
    super.dispose();
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

  Future<void> _shareWithEvent() async {
    if (_isProcessing) return;
    Navigator.of(context).pop(PhotoPreviewResult.shareWithEvent);
  }

  Future<void> _saveLocally() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Saving to gallery...';
    });

    try {
      // Save to device gallery
      await Gal.putImage(_currentFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved to gallery!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(PhotoPreviewResult.saveLocally);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _discard() async {
    if (_isProcessing) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard Photo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This photo will be deleted and cannot be recovered.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Delete the temp file
      try {
        await _currentFile.delete();
      } catch (_) {
        // Ignore delete errors
      }
      if (mounted) {
        Navigator.of(context).pop(PhotoPreviewResult.discard);
      }
    }
  }

  void _retake() {
    if (_isProcessing) return;
    // Delete the temp file and go back to camera
    try {
      _currentFile.delete();
    } catch (_) {
      // Ignore delete errors
    }
    Navigator.of(context).pop(null); // null means retake
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleImages = _files.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image preview with swipe support for multiple images
          if (hasMultipleImages && widget.isViewOnly)
            PageView.builder(
              controller: _pageController,
              itemCount: _files.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(_files[index], fit: BoxFit.contain),
                  ),
                );
              },
            )
          else
            // Single image preview
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(_currentFile, fit: BoxFit.contain),
              ),
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    if (_processingMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Top bar with close/retake
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopButton(
                  icon: Icons.close,
                  label: widget.isViewOnly ? 'Close' : 'Retake',
                  onTap: widget.isViewOnly
                      ? () => Navigator.of(context).pop()
                      : _retake,
                ),
                // Show page indicator for multiple images
                if (hasMultipleImages && widget.isViewOnly)
                  Text(
                    '${_currentIndex + 1} / ${_files.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    widget.isViewOnly ? 'Photo' : 'Preview',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(width: 80), // Placeholder for balance
              ],
            ),
          ),

          // Bottom action buttons (only show if not view-only)
          if (!widget.isViewOnly)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main action: Share with event
                  _buildPrimaryButton(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Share with Event',
                    onTap: _shareWithEvent,
                  ),
                  const SizedBox(height: 12),

                  // Secondary actions row
                  Row(
                    children: [
                      // Save locally
                      Expanded(
                        child: _buildSecondaryButton(
                          icon: Icons.save_alt,
                          label: 'Save to Device',
                          onTap: _saveLocally,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Discard
                      Expanded(
                        child: _buildSecondaryButton(
                          icon: Icons.delete_outline,
                          label: 'Discard',
                          onTap: _discard,
                          isDestructive: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : Colors.white;

    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
