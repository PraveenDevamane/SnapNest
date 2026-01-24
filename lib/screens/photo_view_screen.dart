import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/photo_metadata.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';

class PhotoViewScreen extends StatefulWidget {
  final PhotoMetadata photo;
  final String? heroTag;

  const PhotoViewScreen({super.key, required this.photo, this.heroTag});

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  bool _isDownloading = false;
  bool _isDeleting = false;
  bool _isLoading = true;
  bool _hasError = false;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  Future<void> _downloadToGallery() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      String? filePath;

      if (widget.photo.localPath != null &&
          File(widget.photo.localPath!).existsSync()) {
        filePath = widget.photo.localPath!;
      } else if (widget.photo.downloadUrl != null) {
        _showMessage('Downloading photo...');
        final response = await http.get(Uri.parse(widget.photo.downloadUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/snapnest_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        }
      }

      if (filePath != null) {
        await Gal.putImage(filePath);
        if (mounted) {
          _showSuccess('Photo saved to gallery!');
        }
      } else {
        throw Exception('Could not get photo file');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save photo');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _deletePhoto() async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    if (currentUserId != widget.photo.ownerId) {
      _showError('You can only delete your own photos');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Photo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this photo? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final dbService = DatabaseService();
      await dbService.deletePhoto(widget.photo.id);

      if (widget.photo.localPath != null) {
        final file = File(widget.photo.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (mounted) {
        _showSuccess('Photo deleted');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to delete photo');
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildPhotoView()),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPhotoView() {
    ImageProvider? imageProvider;

    if (widget.photo.localPath != null &&
        File(widget.photo.localPath!).existsSync()) {
      imageProvider = FileImage(File(widget.photo.localPath!));
    } else if (widget.photo.displayUrl != null) {
      imageProvider = CachedNetworkImageProvider(widget.photo.displayUrl!);
    }

    if (imageProvider == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 80),
            const SizedBox(height: 16),
            Text(
              'Image not available',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    Widget imageWidget = Image(
      image: imageProvider,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isLoading) {
              setState(() => _isLoading = false);
            }
          });
          return child;
        }
        final progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
            : null;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: progress,
                  color: const Color(0xFF14B8A6),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                progress != null
                    ? '${(progress * 100).toInt()}%'
                    : 'Loading...',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        });
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red[300],
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                },
                icon: const Icon(Icons.refresh, color: Color(0xFF14B8A6)),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF14B8A6)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(child: imageWidget),
    );
  }

  Widget _buildBottomActionBar() {
    final authProvider = context.read<AuthProvider>();
    final isOwner = authProvider.userId == widget.photo.ownerId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: _isDownloading
                ? Icons.hourglass_top_rounded
                : Icons.download_rounded,
            label: _isDownloading ? 'Saving...' : 'Save',
            onPressed: _isDownloading || _hasError ? null : _downloadToGallery,
            color: const Color(0xFF14B8A6),
          ),
          if (isOwner)
            _buildActionButton(
              icon: _isDeleting
                  ? Icons.hourglass_top_rounded
                  : Icons.delete_outline_rounded,
              label: _isDeleting ? 'Deleting...' : 'Delete',
              onPressed: _isDeleting || _hasError ? null : _deletePhoto,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.3)
              : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.3)
                : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? Colors.grey : color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
