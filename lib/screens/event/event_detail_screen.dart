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
import '../../services/face_cluster_service.dart';
import 'package:http/http.dart' as http;
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
  String? _currentEventId; // Track current event to detect changes

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentEventId = widget.event.id;

    // Set current event in provider immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().setCurrentEvent(widget.event);
    });
  }

  @override
  void didUpdateWidget(covariant EventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If event changed, clear state and update provider
    if (oldWidget.event.id != widget.event.id) {
      _currentEventId = widget.event.id;
      setState(() {
        _likedPhotoIds = {}; // Clear liked photos for privacy
        _showLikedOnly = false;
      });
      // Update provider with new event
      context.read<EventProvider>().setCurrentEvent(widget.event);
    }
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
          userName =
              currentUser.displayName ?? currentUser.email.split('@').first;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Stack(
            children: [
              _MainContentView(
                key: ValueKey(
                  'main_content_${event.id}',
                ), // Force rebuild on event change
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
                onShowInfo: () =>
                    _showInfoBottomSheet(context, event, isCreator),
              ),
              // Floating bottom bar
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 9
                    : 12,
                child: _buildNewBottomBar(isCreator, event),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoBottomSheet(
    BuildContext context,
    EventModel event,
    bool isCreator,
  ) {
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
            key: ValueKey('info_tab_${event.id}'),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            // Dark tint for visibility on light backgrounds
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(32),
            // Subtle border for glass feel
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
              ? (activeColor ?? const Color(0xFFE8985A)).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive
              ? (activeColor ?? const Color(0xFFE8985A))
              : Colors.white.withOpacity(0.7),
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
    super.key,
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
  final ScrollController _scrollController = ScrollController();
  String? _currentEventId; // Track current event to detect changes
  final _clusterService = FaceClusterService();
  int? _selectedPersonId;
  bool _isClustering = false;
  int _clusteringToken = 0;

  Set<String> _processedPhotoUrls = {};
  bool _isClusterServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentEventId = widget.event.id;
    _loadMembers();
    _clusterService.init().then((_) {
      if (!mounted) return;
      _isClusterServiceInitialized = true;
      _processAllPhotos(context.read<EventProvider>().currentPhotos);
    });
  }

  Future<Uint8List> _downloadPhoto(String url) async {
    final response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  Future<void> _processAllPhotos(List<PhotoMetadata> photos) async {
    if (!_isClusterServiceInitialized) return;
    if (_isClustering) return;
    _isClustering = true;
    final token = _clusteringToken;
    bool clusterUpdated = false;

    for (final photo in photos) {
      if (token != _clusteringToken) break;
      if (photo.displayUrl == null && photo.thumbnailUrl == null) continue;
      final url = photo.displayUrl ?? photo.thumbnailUrl!;
      if (_processedPhotoUrls.contains(url)) continue;

      try {
        final bytes = await _downloadPhoto(url);
        if (token != _clusteringToken) break;
        await _clusterService.processPhoto(url, bytes);
        _processedPhotoUrls.add(url);
        clusterUpdated = true;
      } catch (e) {
        debugPrint('Error processing photo ${photo.id}: $e');
      }
    }

    if (token != _clusteringToken) {
      _clusterService.reset();
      _isClustering = false;
      return;
    }

    _isClustering = false;
    if (clusterUpdated && mounted) setState(() {});
  }

  void _filterByPerson(int clusterId) {
    setState(() {
      _selectedPersonId = _selectedPersonId == clusterId ? null : clusterId;
    });
  }

  @override
  void didUpdateWidget(covariant _MainContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If event changed, clear old data and reload
    if (oldWidget.event.id != widget.event.id) {
      _currentEventId = widget.event.id;
      _clusteringToken++;
      _clusterService.reset();
      _processedPhotoUrls.clear();
      setState(() {
        _members = []; // Clear old members immediately
        _isLoadingMembers = true;
        _selectedPersonId = null;
      });
      _loadMembers();
    }
  }

  @override
  void dispose() {
    _clusterService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final eventProvider = context.read<EventProvider>();
    // Always use widget.event.memberIds to get the correct members
    // Don't rely on currentEvent as it may not be set yet
    final members = await eventProvider.getEventMembers(widget.event.memberIds);
    if (mounted && _currentEventId == widget.event.id) {
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

  // Get emoji based on event name
  String _getEventEmoji(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('diwali')) return '🪔';
    if (name.contains('holi')) return '🎨';
    if (name.contains('christmas')) return '🎄';
    if (name.contains('new year')) return '🎆';
    if (name.contains('birthday')) return '🎂';
    if (name.contains('wedding')) return '💒';
    if (name.contains('party')) return '🎉';
    if (name.contains('trip') || name.contains('travel')) return '✈️';
    if (name.contains('vacation')) return '🏖️';
    if (name.contains('graduation')) return '🎓';
    if (name.contains('anniversary')) return '💕';
    if (name.contains('baby')) return '👶';
    if (name.contains('eid')) return '🌙';
    if (name.contains('easter')) return '🐰';
    if (name.contains('halloween')) return '🎃';
    if (name.contains('thanks')) return '🦃';
    if (name.contains('picnic')) return '🧺';
    if (name.contains('concert') || name.contains('music')) return '🎵';
    if (name.contains('game') || name.contains('sport')) return '⚽';
    if (name.contains('office') || name.contains('work')) return '💼';
    if (name.contains('reunion')) return '👨‍👩‍👧‍👦';
    return '📸'; // Default camera emoji for general events
  }

  // Get gradient colors based on event name
  List<Color> _getEventGradient(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('diwali')) {
      return [const Color(0xFFFF6B35), const Color(0xFFFFB347)];
    }
    if (name.contains('holi')) {
      return [const Color(0xFFFF6B6B), const Color(0xFF4ECDC4)];
    }
    if (name.contains('christmas')) {
      return [const Color(0xFF165B33), const Color(0xFFBB2528)];
    }
    if (name.contains('new year')) {
      return [const Color(0xFF667eea), const Color(0xFF764ba2)];
    }
    if (name.contains('birthday')) {
      return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
    }
    if (name.contains('wedding')) {
      return [const Color(0xFFffecd2), const Color(0xFFfcb69f)];
    }
    if (name.contains('eid')) {
      return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
    }
    // Default warm gradient
    return [const Color(0xFFE8985A), const Color(0xFFF4C896)];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        var photos = eventProvider.currentPhotos;
        final isRefreshing = eventProvider.isRefreshing;
        final isPhotosLoading = eventProvider.isPhotosLoading;

        // Process any new photos for clustering if not already done
        if (!isPhotosLoading && photos.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _processAllPhotos(photos);
          });
        }

        // Filter by liked photos if showLikedOnly is true
        if (widget.showLikedOnly) {
          photos = photos
              .where((p) => widget.likedPhotoIds.contains(p.id))
              .toList();
        }

        // Filter by face cluster if selected
        if (_selectedPersonId != null &&
            _clusterService.clusters.containsKey(_selectedPersonId)) {
          final clusterPhotoUrls = _clusterService.clusters[_selectedPersonId]!;
          photos = photos.where((photo) {
            final url = photo.displayUrl ?? photo.thumbnailUrl;
            return url != null && clusterPhotoUrls.contains(url);
          }).toList();
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFFE8985A),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Collapsible App Bar with festive header
              _buildCollapsibleHeader(),

              // Members Section
              SliverToBoxAdapter(child: _buildMembersSection()),

              // Face Clusters Section
              if (_clusterService.clusters.isNotEmpty)
                SliverToBoxAdapter(child: _buildFaceClustersSection()),

              // Folders Section
              SliverToBoxAdapter(child: _buildFoldersSection(eventProvider)),

              // Photos Section Header
              SliverToBoxAdapter(child: _buildPhotosHeader()),

              // Photo Grid - Show skeleton while loading
              if (isRefreshing || isPhotosLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _buildPhotoSkeletonGrid(),
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

  // Skeleton loader for photos grid
  Widget _buildPhotoSkeletonGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 8,
        ),
        childCount: 12, // Show 12 skeleton items
      ),
    );
  }

  Widget _buildCollapsibleHeader() {
    final gradient = _getEventGradient(widget.event.name);
    final emoji = _getEventEmoji(widget.event.name);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: null,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate collapse ratio (0 = expanded, 1 = collapsed)
          final expandedHeight = 240.0;
          final collapsedHeight = kToolbarHeight + statusBarHeight;
          final currentHeight = constraints.maxHeight;
          final collapseRatio =
              ((expandedHeight - currentHeight) /
                      (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);
          final isCollapsed = collapseRatio > 0.7;

          // Calculate corner radius based on collapse
          final cornerRadius = isCollapsed ? 0.0 : 28.0 * (1 - collapseRatio);

          return ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(cornerRadius),
              bottomRight: Radius.circular(cornerRadius),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Pattern background (fades out when collapsed)
                  if (!isCollapsed)
                    Opacity(
                      opacity: 1 - collapseRatio,
                      child: _buildPatternBackground(widget.event.name),
                    ),

                  // Content
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Top row with back button and QR
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // Back button
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Collapsed title (shows when collapsed)
                              Expanded(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isCollapsed ? 1.0 : 0.0,
                                  child: Text(
                                    widget.event.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // QR button
                              GestureDetector(
                                onTap: widget.onShowQR,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Expanded content (event name and tagline)
                        // Only show when there's enough space (collapseRatio < 0.5)
                        if (collapseRatio < 0.5)
                          Flexible(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: (1 - collapseRatio * 2).clamp(0.0, 1.0),
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$emoji ${widget.event.name}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Share memories together',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Pattern background for different festivals
  Widget _buildPatternBackground(String eventName) {
    final name = eventName.toLowerCase();

    if (name.contains('diwali')) {
      return _buildDiwaliPattern();
    } else if (name.contains('holi')) {
      return _buildHoliPattern();
    } else if (name.contains('christmas')) {
      return _buildChristmasPattern();
    } else if (name.contains('birthday')) {
      return _buildBirthdayPattern();
    }
    // Default decorative pattern
    return _buildDefaultPattern();
  }

  Widget _buildDiwaliPattern() {
    return Stack(
      children: [
        // Decorative diyas and lights
        Positioned(
          top: 20,
          right: 30,
          child: _buildGlowingCircle(30, Colors.yellow.withOpacity(0.3)),
        ),
        Positioned(
          top: 60,
          right: 80,
          child: _buildGlowingCircle(20, Colors.orange.withOpacity(0.3)),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          child: _buildGlowingCircle(25, Colors.yellow.withOpacity(0.25)),
        ),
        Positioned(
          top: 30,
          left: 40,
          child: _buildGlowingCircle(15, Colors.amber.withOpacity(0.3)),
        ),
        Positioned(
          bottom: 60,
          right: 40,
          child: _buildGlowingCircle(18, Colors.orange.withOpacity(0.25)),
        ),
      ],
    );
  }

  Widget _buildHoliPattern() {
    return Stack(
      children: [
        Positioned(
          top: 25,
          right: 40,
          child: _buildColorSplash(Colors.pink.withOpacity(0.3), 35),
        ),
        Positioned(
          top: 50,
          left: 30,
          child: _buildColorSplash(Colors.purple.withOpacity(0.3), 28),
        ),
        Positioned(
          bottom: 50,
          right: 60,
          child: _buildColorSplash(Colors.cyan.withOpacity(0.3), 32),
        ),
        Positioned(
          bottom: 30,
          left: 50,
          child: _buildColorSplash(Colors.yellow.withOpacity(0.3), 25),
        ),
      ],
    );
  }

  Widget _buildChristmasPattern() {
    return Stack(
      children: [
        Positioned(
          top: 20,
          right: 30,
          child: Icon(
            Icons.star,
            size: 30,
            color: Colors.yellow.withOpacity(0.5),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 25,
          child: Icon(
            Icons.ac_unit,
            size: 25,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        Positioned(
          top: 60,
          left: 50,
          child: Icon(
            Icons.ac_unit,
            size: 18,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 50,
          child: Icon(
            Icons.ac_unit,
            size: 22,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayPattern() {
    return Stack(
      children: [
        Positioned(
          top: 25,
          right: 35,
          child: _buildGlowingCircle(28, Colors.pink.withOpacity(0.3)),
        ),
        Positioned(
          top: 55,
          left: 40,
          child: _buildGlowingCircle(22, Colors.purple.withOpacity(0.25)),
        ),
        Positioned(
          bottom: 45,
          right: 55,
          child: _buildGlowingCircle(25, Colors.blue.withOpacity(0.25)),
        ),
        Positioned(
          bottom: 30,
          left: 30,
          child: _buildGlowingCircle(18, Colors.yellow.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildDefaultPattern() {
    return Stack(
      children: [
        Positioned(
          top: 30,
          right: 40,
          child: _buildGlowingCircle(25, Colors.white.withOpacity(0.15)),
        ),
        Positioned(
          bottom: 50,
          left: 30,
          child: _buildGlowingCircle(30, Colors.white.withOpacity(0.1)),
        ),
        Positioned(
          top: 70,
          left: 60,
          child: _buildGlowingCircle(18, Colors.white.withOpacity(0.12)),
        ),
      ],
    );
  }

  Widget _buildGlowingCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.8,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSplash(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
          const SizedBox(width: 12),
          // Event name centered
          Expanded(
            child: Text(
              widget.event.name,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          // QR Code button
          GestureDetector(
            onTap: widget.onShowQR,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8985A),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8985A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Members',
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
              ? _buildPeopleSkeletonLoader()
              : _members.isEmpty
              ? Center(
                  child: Text(
                    'No members yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
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

  Widget _buildPeopleSkeletonLoader() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5, // Show 5 skeleton avatars
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            _ShimmerBox(width: 56, height: 56, borderRadius: 28),
            const SizedBox(height: 6),
            _ShimmerBox(width: 48, height: 12, borderRadius: 4),
          ],
        ),
      ),
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
    return Column(
      children: [
        Padding(
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
        ),
      ],
    );
  }

  Widget _buildFaceClustersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
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
          height: 120, // Enough height for folders
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _clusterService.clusters.length,
            itemBuilder: (ctx, i) {
              final clusterId = _clusterService.clusters.keys.elementAt(i);
              final photos = _clusterService.clusters[clusterId]!;
              final isSelected = _selectedPersonId == clusterId;

              return GestureDetector(
                onTap: () => _filterByPerson(clusterId),
                child: Container(
                  width: 100, // Fixed width for the folder UI
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      // Folder/Wallpaper look
                      Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE8985A)
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(photos.first),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Person ${clusterId + 1}',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFE8985A)
                              : const Color(0xFF475569),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
        return _buildPhotoCard(
          photo,
          photos: photos,
          index: index,
          isLarge: isLarge,
        );
      }, childCount: photos.length),
    );
  }

  Widget _buildPhotoCard(
    PhotoMetadata photo, {
    required List<PhotoMetadata> photos,
    required int index,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoViewScreen(
              photos: photos,
              initialIndex: index,
              heroTag: 'photo_${photo.id}',
            ),
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
                                photos: photos,
                                initialIndex: index,
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

  const _InfoTab({super.key, required this.event, this.scrollController});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  List<AppUser> _members = [];
  List<AppUser> _pendingMembers = [];
  bool _isLoading = true;
  String? _currentEventId;

  @override
  void initState() {
    super.initState();
    _currentEventId = widget.event.id;
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant _InfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload members when event changes - clear old data immediately
    if (oldWidget.event.id != widget.event.id) {
      _currentEventId = widget.event.id;
      setState(() {
        _members = [];
        _pendingMembers = [];
        _isLoading = true;
      });
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    final eventProvider = context.read<EventProvider>();
    // Always use widget.event to get the correct members
    // Don't rely on currentEvent as it may not be set yet
    final members = await eventProvider.getEventMembers(widget.event.memberIds);
    final pending = await eventProvider.getEventMembers(
      widget.event.pendingMemberIds,
    );

    if (mounted && _currentEventId == widget.event.id) {
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

// Shimmer effect widget for skeleton loading
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
