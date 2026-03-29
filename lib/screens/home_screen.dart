import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/event_model.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import 'event/event_create_screen.dart';
import 'event/event_detail_screen.dart';
import 'event/join_event_screen.dart';
import 'personal_photos_screen.dart';

class _Palette {
  static const Color canvas = Color(0xFFF3F6FB);
  static const Color canvasEnd = Color(0xFFEAF0F9);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkSoft = Color(0xFF64748B);
  static const Color cardStroke = Color(0xFFDDE6F2);
  static const Color card = Colors.white;
  static const Color navyStart = Color(0xFF0F1F3E);
  static const Color navyEnd = Color(0xFF1E3A6D);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentTeal = Color(0xFF0F766E);
  static const Color accentCoral = Color(0xFFFB7185);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _heroSlideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _heroSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<EventProvider>().refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _Palette.canvas,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              _buildBackground(),
              RefreshIndicator(
                onRefresh: _onRefresh,
                color: _Palette.accentBlue,
                edgeOffset: 16,
                displacement: 28,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: mediaQuery.padding.top + 10),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(child: _buildTopBar(context)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: SlideTransition(
                          position: _heroSlideAnimation,
                          child: _buildHeroPanel(context),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _buildQuickActions(context),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                      sliver: SliverToBoxAdapter(child: _buildEventsHeader()),
                    ),
                    _buildEventsList(context),
                    SliverToBoxAdapter(
                      child: SizedBox(height: bottomInset + 120),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset > 0 ? bottomInset + 8 : 16,
                child: _buildBottomDock(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_Palette.canvas, _Palette.canvasEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -110,
            top: -130,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Palette.accentBlue.withValues(alpha: 0.17),
                    _Palette.accentBlue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            top: 120,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Palette.accentCyan.withValues(alpha: 0.15),
                    _Palette.accentCyan.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_mosaic_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: TextStyle(
                  color: _Palette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _TopIconButton(
          icon: Icons.photo_library_outlined,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalPhotosScreen()),
            );
          },
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showProfileMenu(context, authProvider),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_Palette.accentBlue, _Palette.accentCyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Palette.accentBlue.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? const Icon(Icons.person_rounded, color: _Palette.ink)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final userId = context.read<AuthProvider>().userId ?? '';

    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final events = eventProvider.userEvents;
        final members = events.fold<int>(
          0,
          (sum, e) => sum + e.memberIds.length,
        );
        final folders = events.fold<int>(0, (sum, e) => sum + e.folders.length);
        final pendingApprovals = events
            .where((event) => event.isCreator(userId))
            .fold<int>(0, (sum, event) => sum + event.pendingMemberIds.length);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_Palette.navyStart, _Palette.navyEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _Palette.navyStart.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -34,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -14,
                bottom: -34,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      _SyncPill(isRefreshing: eventProvider.isRefreshing),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.displayNameOrEmail ?? 'Photographer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Collect every memory in one shared timeline.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _MetricTile(label: 'Events', value: events.length),
                      const SizedBox(width: 10),
                      _MetricTile(label: 'Members', value: members),
                      const SizedBox(width: 10),
                      _MetricTile(label: 'Folders', value: folders),
                    ],
                  ),
                  if (pendingApprovals > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _Palette.accentCoral.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _Palette.accentCoral.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            size: 16,
                            color: _Palette.accentCoral,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pendingApprovals join request${pendingApprovals > 1 ? 's' : ''} awaiting approval',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.photo_library_rounded,
            title: 'My Photos',
            subtitle: 'Personal gallery',
            color: _Palette.accentTeal,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalPhotosScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Join Event',
            subtitle: 'Scan or use code',
            color: _Palette.accentBlue,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinEventScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventsHeader() {
    return Consumer<EventProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            const Text(
              'Shared Events',
              style: TextStyle(
                color: _Palette.ink,
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _Palette.cardStroke),
              ),
              child: Text(
                '${provider.userEvents.length} active',
                style: const TextStyle(
                  color: _Palette.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventsList(BuildContext context) {
    return Consumer2<EventProvider, AuthProvider>(
      builder: (context, eventProvider, authProvider, _) {
        final events = [...eventProvider.userEvents]
          ..sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

        if (events.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          );
        }

        final userId = authProvider.userId ?? '';
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildEventCard(context, events[index], index, userId),
              childCount: events.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    EventModel event,
    int index,
    String userId,
  ) {
    final accentColors = <Color>[
      _Palette.accentBlue,
      _Palette.accentTeal,
      _Palette.accentAmber,
      _Palette.accentCoral,
      const Color(0xFF0EA5E9),
      const Color(0xFF22C55E),
      const Color(0xFFF97316),
    ];
    final accent = accentColors[index % accentColors.length];
    final isCreator = event.isCreator(userId);
    final pendingCount = event.pendingMemberIds.length;
    final eventDate = event.createdAt ?? DateTime.now();

    final start = (0.12 + (index * 0.05)).clamp(0.0, 0.78).toDouble();
    final itemAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(itemAnimation),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: event),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Palette.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _Palette.cardStroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.26),
                                accent.withValues(alpha: 0.12),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _Palette.ink,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _Palette.canvas,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#${event.eventCode}',
                                      style: const TextStyle(
                                        color: _Palette.inkSoft,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (isCreator) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Owner',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _Palette.canvas,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: _Palette.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildMemberStack(event.memberIds.length, accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _SoftChip(
                                icon: Icons.folder_copy_outlined,
                                text: '${event.folders.length} folders',
                              ),
                              _SoftChip(
                                icon: Icons.schedule_rounded,
                                text: _formatDate(eventDate),
                              ),
                              if (pendingCount > 0 && isCreator)
                                _SoftChip(
                                  icon: Icons.mark_email_unread_rounded,
                                  text: '$pendingCount pending',
                                  color: _Palette.danger,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberStack(int totalMembers, Color accent) {
    final visibleCount = totalMembers.clamp(0, 3).toInt();
    final extra = totalMembers - visibleCount;
    final width = (visibleCount * 18.0) + (extra > 0 ? 28 : 12);

    return SizedBox(
      width: width,
      height: 30,
      child: Stack(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.3),
                      accent.withValues(alpha: 0.16),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: accent.withValues(alpha: 0.92),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visibleCount * 14.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _Palette.ink,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 130),
        child: Column(
          children: [
            Container(
              width: 102,
              height: 102,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Palette.accentBlue.withValues(alpha: 0.24),
                    _Palette.accentBlue.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 48,
                color: _Palette.accentBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No events yet',
              style: TextStyle(
                color: _Palette.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new event or join an existing one to start building your shared album.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Palette.inkSoft,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EventCreateScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Palette.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinEventScreen()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Join Event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Palette.ink,
                  side: const BorderSide(color: _Palette.cardStroke),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _DockButton(
                  icon: Icons.add_rounded,
                  label: 'Create',
                  gradient: const LinearGradient(
                    colors: [_Palette.accentBlue, _Palette.accentCyan],
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EventCreateScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DockButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Join',
                  borderColor: _Palette.cardStroke,
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  foregroundColor: _Palette.ink,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JoinEventScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 34,
                  backgroundColor: _Palette.canvas,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: _Palette.ink,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayNameOrEmail ?? 'User',
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email,
                    style: const TextStyle(
                      color: _Palette.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1, color: _Palette.cardStroke),
                _SheetMenuTile(
                  icon: Icons.photo_library_rounded,
                  label: 'My Photos',
                  color: _Palette.accentBlue,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalPhotosScreen(),
                      ),
                    );
                  },
                ),
                _SheetMenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: _Palette.danger,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmSignOut(context, authProvider);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider authProvider) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Sign Out',
            style: TextStyle(color: _Palette.ink, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Do you want to sign out from SnapNest?',
            style: TextStyle(color: _Palette.inkSoft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _Palette.inkSoft),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                authProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative) return 'Just now';
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
          ),
          child: Icon(icon, color: _Palette.ink),
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.isRefreshing});

  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: isRefreshing
                ? const CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white,
                  )
                : const DecoratedBox(
                    decoration: BoxDecoration(
                      color: _Palette.success,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            isRefreshing ? 'Syncing' : 'Live',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _Palette.cardStroke),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.inkSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.icon,
    required this.text,
    this.color = _Palette.inkSoft,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? backgroundColor : null,
            borderRadius: BorderRadius.circular(18),
            border: borderColor != null
                ? Border.all(color: borderColor!)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetMenuTile extends StatelessWidget {
  const _SheetMenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: _Palette.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: _Palette.inkSoft,
      ),
    );
  }
}
