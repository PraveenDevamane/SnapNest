import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/photo_metadata.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';

class PhotoViewScreen extends StatefulWidget {
  /// Single photo (for backward compatibility)
  final PhotoMetadata? photo;

  /// List of photos for swipe navigation
  final List<PhotoMetadata>? photos;

  /// Initial index when viewing multiple photos
  final int initialIndex;

  final String? heroTag;

  const PhotoViewScreen({
    super.key,
    this.photo,
    this.photos,
    this.initialIndex = 0,
    this.heroTag,
  }) : assert(
         photo != null || photos != null,
         'Either photo or photos must be provided',
       );

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

  late PageController _pageController;
  late int _currentIndex;

  /// Get the list of photos
  List<PhotoMetadata> get _photos => widget.photos ?? [widget.photo!];

  /// Get the current photo being displayed
  PhotoMetadata get _currentPhoto => _photos[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
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

      if (_currentPhoto.localPath != null &&
          File(_currentPhoto.localPath!).existsSync()) {
        filePath = _currentPhoto.localPath!;
      } else if (_currentPhoto.downloadUrl != null) {
        _showMessage('Downloading photo...');
        final response = await http.get(Uri.parse(_currentPhoto.downloadUrl!));
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

    if (currentUserId != _currentPhoto.ownerId) {
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
      await dbService.deletePhoto(_currentPhoto.id);

      if (_currentPhoto.localPath != null) {
        final file = File(_currentPhoto.localPath!);
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
        child: Stack(
          children: [
            // Photo view takes full space
            _buildPhotoView(),
            // Top bar overlay
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final bool hasMultiplePhotos = _photos.length > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Show page indicator for multiple photos
          if (hasMultiplePhotos)
            Text(
              '${_currentIndex + 1} / ${_photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              'Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          // 3-dot menu button
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    final authProvider = context.read<AuthProvider>();
    final isOwner = authProvider.userId == _currentPhoto.ownerId;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'save':
            _downloadToGallery();
            break;
          case 'delete':
            _deletePhoto();
            break;
          case 'info':
            _showPhotoInfo();
            break;
        }
      },
      itemBuilder: (context) => [
        // Save option
        PopupMenuItem<String>(
          value: 'save',
          enabled: !_isDownloading && !_hasError,
          child: Row(
            children: [
              Icon(
                _isDownloading ? Icons.hourglass_top : Icons.download_rounded,
                color: _isDownloading ? Colors.grey : const Color(0xFF14B8A6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                _isDownloading ? 'Saving...' : 'Save to Gallery',
                style: TextStyle(
                  color: _isDownloading ? Colors.grey : Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Delete option (only for owner)
        if (isOwner)
          PopupMenuItem<String>(
            value: 'delete',
            enabled: !_isDeleting && !_hasError,
            child: Row(
              children: [
                Icon(
                  _isDeleting
                      ? Icons.hourglass_top
                      : Icons.delete_outline_rounded,
                  color: _isDeleting ? Colors.grey : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _isDeleting ? 'Deleting...' : 'Delete',
                  style: TextStyle(
                    color: _isDeleting ? Colors.grey : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        // Divider
        const PopupMenuDivider(),
        // Info option
        const PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Photo Info', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  void _showPhotoInfo() {
    final photo = _currentPhoto;
    final uploadDate = photo.uploadTime;
    final formattedDate = uploadDate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(uploadDate)
        : 'Unknown';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Photo Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Uploaded by - fetch owner name from database
            FutureBuilder<String>(
              future: _getOwnerName(photo.ownerId),
              builder: (context, snapshot) {
                return _buildInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Uploaded by',
                  value: snapshot.data ?? 'Loading...',
                );
              },
            ),
            const SizedBox(height: 16),

            // Upload date
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Uploaded on',
              value: formattedDate,
            ),
            const SizedBox(height: 16),

            // Storage type
            _buildInfoRow(
              icon: Icons.cloud_outlined,
              label: 'Storage',
              value: photo.storageType == PhotoStorageType.shared
                  ? 'Shared with Event'
                  : 'Local Only',
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<String> _getOwnerName(String ownerId) async {
    if (ownerId.isEmpty) return 'Unknown';

    try {
      final dbService = DatabaseService();
      final user = await dbService.getUser(ownerId);
      return user?.displayName ?? user?.email ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF14B8A6), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoView() {
    final bool hasMultiplePhotos = _photos.length > 1;

    if (hasMultiplePhotos) {
      return PageView.builder(
        controller: _pageController,
        itemCount: _photos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _isLoading = true;
            _hasError = false;
          });
        },
        itemBuilder: (context, index) {
          return _buildSinglePhotoView(_photos[index]);
        },
      );
    }

    return _buildSinglePhotoView(_currentPhoto);
  }

  Widget _buildSinglePhotoView(PhotoMetadata photo) {
    ImageProvider? imageProvider;

    if (photo.localPath != null && File(photo.localPath!).existsSync()) {
      imageProvider = FileImage(File(photo.localPath!));
    } else if (photo.displayUrl != null) {
      imageProvider = CachedNetworkImageProvider(photo.displayUrl!);
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
}
