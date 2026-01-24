import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../models/event_model.dart';
import '../models/photo_metadata.dart';
import '../services/qr_service.dart';

/// Event card for home screen
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: AppPadding.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppPadding.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Color(0xFF14B8A6),
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                event.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                QRService().formatEventCode(event.eventCode),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Folder selector chip
class FolderChip extends StatelessWidget {
  final EventFolder folder;
  final bool isSelected;
  final VoidCallback onTap;

  const FolderChip({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppPadding.md,
          vertical: AppPadding.sm,
        ),
        margin: const EdgeInsets.only(right: AppPadding.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E293B)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          folder.name,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Photo grid item
class PhotoGridItem extends StatelessWidget {
  final PhotoMetadata photo;
  final VoidCallback onTap;
  final String? heroTag;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (photo.localPath != null && File(photo.localPath!).existsSync()) {
      // Show local image (exists on this device)
      imageWidget = Image.file(
        File(photo.localPath!),
        fit: BoxFit.cover,
        cacheWidth: 400, // Limit memory usage
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (photo.displayUrl != null) {
      // Show Drive image for photos from other users or when local file doesn't exist
      imageWidget = CachedNetworkImage(
        imageUrl: photo.displayUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildLoadingPlaceholder(),
        errorWidget: (_, url, error) => _buildErrorPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 200),
        memCacheWidth: 400, // Limit memory usage
      );
    } else {
      // No image available (still pending upload or no driveFileId)
      imageWidget = _buildPendingPlaceholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: heroTag != null
                ? Hero(tag: heroTag!, child: imageWidget)
                : imageWidget,
          ),
          // Upload status overlay
          if (!photo.isUploaded) _buildStatusOverlay(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Icon(Icons.image, color: Colors.white24),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Icon(Icons.broken_image, color: Colors.white38),
    );
  }

  Widget _buildPendingPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_queue, color: Colors.white38, size: 28),
          SizedBox(height: 4),
          Text(
            'Uploading...',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    IconData icon;
    Color color;

    switch (photo.uploadStatus) {
      case PhotoUploadStatus.pending:
        icon = Icons.cloud_queue;
        color = Colors.white54;
        break;
      case PhotoUploadStatus.uploading:
        icon = Icons.cloud_upload;
        color = AppColors.primary;
        break;
      case PhotoUploadStatus.failed:
        icon = Icons.cloud_off;
        color = AppColors.error;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: photo.isUploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, size: 16, color: color),
      ),
    );
  }
}

/// QR Code display widget
class EventQRCode extends StatelessWidget {
  final String eventCode;
  final double size;

  const EventQRCode({super.key, required this.eventCode, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final qrData = QRService().createQRData(eventCode);

    return Container(
      padding: const EdgeInsets.all(AppPadding.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.circle,
          color: Color(0xFF1E293B),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.circle,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}

/// Member list item
class MemberListItem extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final bool isCreator;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const MemberListItem({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.isCreator = false,
    this.isPending = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.background)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isCreator
                    ? const Color(0xFF14B8A6)
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.background,
              backgroundImage: photoUrl != null
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: AppColors.textSecondary,
                      size: 24,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (isCreator)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Creator',
                      style: TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isPending)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Pending approval',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isPending && onApprove != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  onPressed: onApprove!,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onPressed: onReject!,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// Action button for home screen
class HomeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HomeActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppPadding.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// QR Code dialog
class QRCodeDialog extends StatelessWidget {
  final String eventCode;
  final String eventName;

  const QRCodeDialog({
    super.key,
    required this.eventCode,
    required this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eventName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to join',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            EventQRCode(eventCode: eventCode),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppPadding.md,
                vertical: AppPadding.sm,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                QRService().formatEventCode(eventCode),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
