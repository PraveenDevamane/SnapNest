import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../models/event_model.dart';
import '../../models/app_user.dart';
import '../../models/photo_metadata.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/event_widgets.dart';
import '../camera_screen.dart';
import '../photo_view_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _likedPhotoIds = {};
  bool _showLikedOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set current event in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().setCurrentEvent(widget.event);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showQRCode() {
    final event = context.read<EventProvider>().currentEvent ?? widget.event;
    showDialog(
      context: context,
      builder: (_) =>
          QRCodeDialog(eventCode: event.eventCode, eventName: event.name),
    );
  }

  void _openCamera() {
    debugPrint('>>> _openCamera called');
    final eventProvider = context.read<EventProvider>();
    if (eventProvider.currentFolderId == null) {
      debugPrint('>>> No folder selected, showing message');
      _showSelectFolderMessage();
      return;
    }
    debugPrint('>>> Navigating to CameraScreen');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CameraScreen()));
  }

  void _showSelectFolderMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a folder first to take photos'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    final eventProvider = context.read<EventProvider>();

    // Check if a folder is selected
    if (eventProvider.currentFolderId == null) {
      _showSelectFolderMessage();
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (images.isEmpty) return;

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UploadProgressDialog(totalImages: images.length),
      );

      int uploadedCount = 0;
      int failedCount = 0;

      for (final image in images) {
        final file = File(image.path);
        final result = await eventProvider.capturePhoto(
          file,
          PhotoStorageType.shared,
        );

        if (result != null) {
          uploadedCount++;
        } else {
          failedCount++;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      // Show result
      String message;
      Color backgroundColor;
      if (failedCount == 0) {
        message =
            '$uploadedCount photo${uploadedCount > 1 ? 's' : ''} uploaded successfully';
        backgroundColor = AppColors.success;
      } else if (uploadedCount == 0) {
        message = 'Failed to upload photos';
        backgroundColor = AppColors.error;
      } else {
        message = '$uploadedCount uploaded, $failedCount failed';
        backgroundColor = AppColors.warning;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final event = eventProvider.currentEvent ?? widget.event;
        final authProvider = context.read<AuthProvider>();
        final isCreator = event.isCreator(authProvider.userId ?? '');
        final currentUser = authProvider.currentUser;
        String userName = 'User';
        if (currentUser != null) {
          userName = currentUser.displayName ??
              currentUser.email.split('@').first;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: SafeArea(
            child: _MainContentView(
              event: event,
              isCreator: isCreator,
              userName: userName,
              onShowQR: _showQRCode,
              onOpenCamera: _openCamera,
              onPickImages: _pickImagesFromGallery,
              onAddFolder: () => _showAddFolderDialog(context),
              onShare: _shareEventNative,
              likedPhotoIds: _likedPhotoIds,
              showLikedOnly: _showLikedOnly,
              onToggleLike: (photoId) {
                setState(() {
                  if (_likedPhotoIds.contains(photoId)) {
                    _likedPhotoIds.remove(photoId);
                  } else {
                    _likedPhotoIds.add(photoId);
                  }
                });
              },
              onShowInfo: () => _showInfoBottomSheet(context, event, isCreator),
            ),
          ),
          bottomNavigationBar: _buildNewBottomBar(isCreator, event),
        );
      },
    );
  }

  void _showInfoBottomSheet(BuildContext context, EventModel event, bool isCreator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: _InfoTab(
            event: event,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  void _shareEventNative() async {
    final event = context.read<EventProvider>().currentEvent ?? widget.event;
    final shareText =
        '''
Join my event "${event.name}" on SnapNest!

Event Code: ${event.eventCode}

Download SnapNest  with given link and enter the code to join and share photos together!
link:https://drive.google.com/file/d/12n2JouMmZedPVsgcTF4lpwdmwZhl-2oM/view?usp=drive_link
''';

    await SharePlus.instance.share(
      ShareParams(text: shareText, subject: 'Join ${event.name} on SnapNest'),
    );
  }

  Widget _buildNewBottomBar(bool isCreator, EventModel event) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0), // Light creamy color
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Upload button
              _buildBottomNavItem(
                icon: Icons.file_upload_outlined,
                isActive: false,
                onTap: _pickImagesFromGallery,
              ),
              // Liked photos button
              _buildBottomNavItem(
                icon: _showLikedOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                isActive: _showLikedOnly,
                activeColor: const Color(0xFFE8985A),
                onTap: () {
                  setState(() {
                    _showLikedOnly = !_showLikedOnly;
                  });
                },
              ),
              // Info button (for members/requests)
              _buildBottomNavItem(
                icon: Icons.info_outline_rounded,
                isActive: false,
                onTap: () => _showInfoBottomSheet(context, event, isCreator),
              ),
              // Share button
              _buildBottomNavItem(
                icon: Icons.share_outlined,
                isActive: false,
                onTap: _shareEventNative,
              ),
              // Camera button on the right
              _buildCameraNavItem(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraNavItem() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _openCamera();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8985A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8985A).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return Container(
      height: 64,
      width: 64,
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE8985A),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8985A).withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _openCamera();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: const Icon(
          Icons.camera_alt_rounded,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? (activeColor ?? const Color(0xFFE8985A)).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isActive
              ? (activeColor ?? const Color(0xFFE8985A))
              : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildScrollableAppBar(EventModel event) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Event code pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.eventCode,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Member count pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        size: 11,
                        color: Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${event.memberIds.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 0,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Photos'),
                ],
              ),
            ),
            Tab(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Info'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBottomBar(bool isCreator) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildModernBottomBarItem(
                    icon: Icons.photo_library_outlined,
                    activeIcon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: _pickImagesFromGallery,
                  ),
                  _buildModernBottomBarItem(
                    icon: Icons.qr_code_scanner_rounded,
                    activeIcon: Icons.qr_code_rounded,
                    label: 'QR Code',
                    onTap: _showQRCode,
                  ),
                  const SizedBox(width: 72), // Space for FAB
                  if (isCreator)
                    _buildModernBottomBarItem(
                      icon: Icons.create_new_folder_outlined,
                      activeIcon: Icons.create_new_folder_rounded,
                      label: 'Folder',
                      onTap: () => _showAddFolderDialog(context),
                    )
                  else
                    _buildModernBottomBarItem(
                      icon: Icons.info_outline_rounded,
                      activeIcon: Icons.info_rounded,
                      label: 'Info',
                      onTap: () => _tabController.animateTo(1),
                    ),
                  _buildModernBottomBarItem(
                    icon: Icons.ios_share_outlined,
                    activeIcon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: _shareEvent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernBottomBarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF06B6D4).withOpacity(0.1),
        highlightColor: const Color(0xFF06B6D4).withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareEvent() {
    final event = context.read<EventProvider>().currentEvent ?? widget.event;
    // Show share options
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Share Event',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_rounded,
                    color: Color(0xFF1E293B),
                  ),
                ),
                title: const Text(
                  'Show QR Code',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Let others scan to join',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showQRCode();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                ),
                title: const Text(
                  'Copy Event Code',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Code: ${event.eventCode}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Copy to clipboard
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Event code "${event.eventCode}" copied!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final folderNameController = TextEditingController();
    final eventProvider = context.read<EventProvider>();
    final event = eventProvider.currentEvent ?? widget.event;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create New Folder',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(
              Icons.folder_outlined,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = folderNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a folder name'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);

              final success = await eventProvider.addFolder(event.id, name);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Folder "$name" created'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      eventProvider.error ?? 'Failed to create folder',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicAppBar(EventModel event) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 20, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Event code pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        event.eventCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Member count pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF06B6D4).withOpacity(0.3),
                        const Color(0xFF06B6D4).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        size: 12,
                        color: Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${event.memberIds.length} members',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF334155),
                    Color(0xFF475569),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Glassmorphic overlay circles
            Positioned(
              right: -60,
              top: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: 20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withOpacity(0.1),
                      const Color(0xFF06B6D4).withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
            // Top gradient for status bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main Content View - New Gallery-style UI like reference image
class _MainContentView extends StatefulWidget {
  final EventModel event;
  final bool isCreator;
  final String userName;
  final VoidCallback onShowQR;
  final VoidCallback onOpenCamera;
  final VoidCallback onPickImages;
  final VoidCallback onAddFolder;
  final VoidCallback onShare;
  final Set<String> likedPhotoIds;
  final bool showLikedOnly;
  final Function(String) onToggleLike;
  final VoidCallback onShowInfo;

  const _MainContentView({
    required this.event,
    required this.isCreator,
    required this.userName,
    required this.onShowQR,
    required this.onOpenCamera,
    required this.onPickImages,
    required this.onAddFolder,
    required this.onShare,
    required this.likedPhotoIds,
    required this.showLikedOnly,
    required this.onToggleLike,
    required this.onShowInfo,
  });

  @override
  State<_MainContentView> createState() => _MainContentViewState();
}

class _MainContentViewState extends State<_MainContentView> {
  List<AppUser> _members = [];
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final eventProvider = context.read<EventProvider>();
    final members = await eventProvider.getEventMembers(widget.event.memberIds);
    if (mounted) {
      setState(() {
        _members = members.cast<AppUser>();
        _isLoadingMembers = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await context.read<EventProvider>().refreshData();
    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        var photos = eventProvider.currentPhotos;
        final isRefreshing = eventProvider.isRefreshing;

        // Filter by liked photos if showLikedOnly is true
        if (widget.showLikedOnly) {
          photos = photos
              .where((p) => widget.likedPhotoIds.contains(p.id))
              .toList();
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFFE8985A),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Search bar header
              SliverToBoxAdapter(child: _buildSearchHeader()),

              // People Section
              SliverToBoxAdapter(child: _buildPeopleSection()),

              // Folders Section
              SliverToBoxAdapter(child: _buildFoldersSection(eventProvider)),

              // Photos Section Header
              SliverToBoxAdapter(child: _buildPhotosHeader()),

              // Photo Grid
              if (isRefreshing)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8985A),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              else if (photos.isEmpty)
                SliverToBoxAdapter(
                  child: widget.showLikedOnly
                      ? _buildNoLikedPhotosState()
                      : _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _buildPhotoGrid(photos),
                ),

              // Bottom spacing
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Hi Username and Event name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👋 Hi ${widget.userName}',
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.event.name,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // QR Code button
          GestureDetector(
            onTap: widget.onShowQR,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8985A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8985A).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'People',
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: _isLoadingMembers
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE8985A),
                    strokeWidth: 2,
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return _buildPersonAvatar(member);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPersonAvatar(AppUser member) {
    final isCreator = member.uid == widget.event.creatorId;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCreator
                        ? const Color(0xFFE8985A)
                        : Colors.grey.shade200,
                    width: isCreator ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: member.photoUrl != null
                      ? Image.network(
                          member.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarPlaceholder(member),
                        )
                      : _buildAvatarPlaceholder(member),
                ),
              ),
              if (isCreator)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8985A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 60,
            child: Text(
              member.displayNameOrEmail.split(' ').first,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(AppUser member) {
    return Container(
      color: const Color(0xFFE8985A).withOpacity(0.2),
      child: Center(
        child: Text(
          member.displayNameOrEmail.isNotEmpty
              ? member.displayNameOrEmail[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Color(0xFFE8985A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMorePeopleButton(int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+$count More',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(width: 60, height: 14),
        ],
      ),
    );
  }

  Widget _buildFoldersSection(EventProvider eventProvider) {
    final folders = widget.event.folders;
    final currentFolderId = eventProvider.currentFolderId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders',
                style: TextStyle(
                  color: Colors.grey.shade900,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.isCreator)
                GestureDetector(
                  onTap: widget.onAddFolder,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Color(0xFFE8985A),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add New',
                        style: TextStyle(
                          color: const Color(0xFFE8985A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              // All folders chip
              _buildFolderChip(
                name: 'All',
                icon: Icons.grid_view_rounded,
                isSelected: currentFolderId == null,
                onTap: () => eventProvider.setCurrentFolder(null),
              ),
              // Individual folder chips
              ...folders.map(
                (folder) => _buildFolderChip(
                  name: folder.name,
                  icon: Icons.folder_rounded,
                  isSelected: folder.id == currentFolderId,
                  onTap: () => eventProvider.setCurrentFolder(folder.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderChip({
    required String name,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1E293B).withOpacity(0.3)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Photos',
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          GestureDetector(
            onTap: widget.onPickImages,
            child: Row(
              children: [
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Color(0xFFE8985A),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add Photos',
                  style: TextStyle(
                    color: const Color(0xFFE8985A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8985A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 48,
                color: const Color(0xFFE8985A).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No photos yet',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap camera to capture memories',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLikedPhotosState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8985A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: const Color(0xFFE8985A).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No liked photos',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on photos to like them',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<PhotoMetadata> photos) {
    // Create album-style grid like reference image
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final photo = photos[index];
        // Make first and fifth items taller (staggered look)
        final isLarge = index == 0 || index == 4;
        return _buildPhotoCard(photo, isLarge: isLarge);
      }, childCount: photos.length),
    );
  }

  Widget _buildPhotoCard(PhotoMetadata photo, {bool isLarge = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PhotoViewScreen(photo: photo, heroTag: 'photo_${photo.id}'),
          ),
        );
      },
      child: Hero(
        tag: 'photo_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo.thumbnailUrl ?? photo.displayUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: const Color(0xFFE8985A),
                        ),
                      ),
                    );
                  },
                ),
                // Gradient overlay at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Like button
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onToggleLike(photo.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.likedPhotoIds.contains(photo.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: widget.likedPhotoIds.contains(photo.id)
                            ? const Color(0xFFE8985A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFolderName(String folderId) {
    final folder = widget.event.folders
        .where((f) => f.id == folderId)
        .firstOrNull;
    return folder?.name ?? 'General';
  }
}

// Modern Tab bar delegate with pill-style indicator
class _ModernTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  _ModernTabBarDelegate({required this.tabController});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Photos'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Info'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant _ModernTabBarDelegate oldDelegate) => false;
}

// Photos Tab
class _PhotosTab extends StatelessWidget {
  final EventModel event;

  const _PhotosTab({required this.event});

  Future<void> _onRefresh(BuildContext context) async {
    await context.read<EventProvider>().refreshData();
  }

  void _showAddFolderDialog(BuildContext context) {
    final folderNameController = TextEditingController();
    final eventProvider = context.read<EventProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create New Folder',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(
              Icons.folder_outlined,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = folderNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a folder name'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);

              final success = await eventProvider.addFolder(event.id, name);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Folder "$name" created'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      eventProvider.error ?? 'Failed to create folder',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAllFolderChip({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                'All',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFolderChip({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    // Determine icon based on folder name
    IconData folderIcon = icon ?? Icons.folder_rounded;
    if (name.toLowerCase().contains('general')) {
      folderIcon = Icons.star_rounded;
    } else if (name.toLowerCase().contains('event')) {
      folderIcon = Icons.celebration_rounded;
    } else if (name.toLowerCase().contains('group')) {
      folderIcon = Icons.group_rounded;
    } else if (name.toLowerCase().contains('food')) {
      folderIcon = Icons.restaurant_rounded;
    } else if (name.toLowerCase().contains('portrait')) {
      folderIcon = Icons.portrait_rounded;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              folderIcon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFolderButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showAddFolderDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 14,
                color: Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'New Folder',
              style: TextStyle(
                color: Color(0xFF06B6D4),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isCreator = event.isCreator(authProvider.userId ?? '');

    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final currentFolderId = eventProvider.currentFolderId;
        final photos = eventProvider.currentPhotos;
        final isRefreshing = eventProvider.isRefreshing;

        return RefreshIndicator(
          onRefresh: () => _onRefresh(context),
          color: const Color(0xFF06B6D4),
          backgroundColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Loading indicator
              if (isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                ),

              // Modern folder selector
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // "All" option with teal accent
                    _buildAllFolderChip(
                      isSelected: currentFolderId == null,
                      onTap: () => eventProvider.setCurrentFolder(null),
                    ),
                    // Existing folders with modern styling
                    ...event.folders.map(
                      (folder) => _buildModernFolderChip(
                        name: folder.name,
                        isSelected: folder.id == currentFolderId,
                        onTap: () => eventProvider.setCurrentFolder(folder.id),
                      ),
                    ),
                    // Add folder button (only for creator)
                    if (isCreator) _buildAddFolderButton(context),
                  ],
                ),
              ),

              // Modern photo grid with rounded corners
              if (photos.isEmpty)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 48,
                            color: const Color(0xFF06B6D4).withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No photos yet',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pull down to refresh or tap camera to capture',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return _ModernPhotoGridItem(
                        photo: photo,
                        heroTag: 'photo_${photo.id}',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoViewScreen(
                                photo: photo,
                                heroTag: 'photo_${photo.id}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

              // Bottom padding for FAB
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}

// Info Tab
class _InfoTab extends StatefulWidget {
  final EventModel event;
  final ScrollController? scrollController;

  const _InfoTab({required this.event, this.scrollController});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  List<AppUser> _members = [];
  List<AppUser> _pendingMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant _InfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload members when event changes
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final eventProvider = context.read<EventProvider>();
    final event = eventProvider.currentEvent ?? widget.event;

    final members = await eventProvider.getEventMembers(event.memberIds);
    final pending = await eventProvider.getEventMembers(event.pendingMemberIds);

    if (mounted) {
      setState(() {
        _members = members.cast<AppUser>();
        _pendingMembers = pending.cast<AppUser>();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await context.read<EventProvider>().refreshData();
    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final eventProvider = context.watch<EventProvider>();
    final event = eventProvider.currentEvent ?? widget.event;
    final isCreator = event.isCreator(authProvider.userId ?? '');

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF06B6D4),
      backgroundColor: Colors.white,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Event info card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Details',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.tag_rounded,
                    'Event Code',
                    event.eventCode,
                  ),
                  _buildInfoRow(
                    Icons.folder_rounded,
                    'Folders',
                    '${event.folders.length}',
                  ),
                  _buildInfoRow(
                    Icons.group_rounded,
                    'Members',
                    '${event.memberIds.length}',
                  ),
                  if (event.publicDriveLink != null)
                    _buildInfoRow(
                      Icons.cloud_rounded,
                      'Drive Folder',
                      'Linked',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Pending requests (for creator)
          if (isCreator && _pendingMembers.isNotEmpty) ...[
            const Text(
              'Pending Requests',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _pendingMembers.map((user) {
                  return MemberListItem(
                    displayName: user.displayNameOrEmail,
                    photoUrl: user.photoUrl,
                    isPending: true,
                    onApprove: () async {
                      await eventProvider.approveJoinRequest(
                        event.id,
                        user.uid,
                      );
                      _loadMembers();
                    },
                    onReject: () async {
                      await eventProvider.rejectJoinRequest(event.id, user.uid);
                      _loadMembers();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Members list
          const Text(
            'Members',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _members.map((user) {
                return MemberListItem(
                  displayName: user.displayNameOrEmail,
                  photoUrl: user.photoUrl,
                  isCreator: user.uid == event.creatorId,
                );
              }).toList(),
            ),
          ),
          // Bottom padding
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF14B8A6), size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Upload Progress Dialog
class _UploadProgressDialog extends StatelessWidget {
  final int totalImages;

  const _UploadProgressDialog({required this.totalImages});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF06B6D4),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Uploading Photos',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading $totalImages photo${totalImages > 1 ? 's' : ''}...',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please wait',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern Photo Grid Item with rounded corners and shadow
class _ModernPhotoGridItem extends StatefulWidget {
  final PhotoMetadata photo;
  final String heroTag;
  final VoidCallback onTap;

  const _ModernPhotoGridItem({
    required this.photo,
    required this.heroTag,
    required this.onTap,
  });

  @override
  State<_ModernPhotoGridItem> createState() => _ModernPhotoGridItemState();
}

class _ModernPhotoGridItemState extends State<_ModernPhotoGridItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Hero(
          tag: widget.heroTag,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Loading skeleton
                  Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Center(
                      child: Icon(
                        Icons.image_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 28,
                      ),
                    ),
                  ),
                  // Actual image
                  Image.network(
                    widget.photo.thumbnailUrl ?? widget.photo.displayUrl ?? '',
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF06B6D4),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Color(0xFF94A3B8),
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                  // Subtle gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.15),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
