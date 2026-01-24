import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';
import 'event/event_create_screen.dart';
import 'event/event_detail_screen.dart';
import 'event/join_event_screen.dart';
import 'personal_photos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _onRefresh() async {
    await context.read<EventProvider>().refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(context)),

              // Quick Stats
              SliverToBoxAdapter(child: _buildQuickStats(context)),

              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions(context)),

              // Events Section Header
              SliverToBoxAdapter(child: _buildSectionHeader()),

              // Events List
              _buildEventsList(context),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppPadding.lg,
        AppPadding.lg,
        AppPadding.lg,
        AppPadding.md,
      ),
      child: Column(
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildIconButton(
                    Icons.photo_library_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalPhotosScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    Icons.logout_rounded,
                    onPressed: () => _showLogoutDialog(context, authProvider),
                  ),
                  const SizedBox(width: 8),
                  // User avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Welcome section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppPadding.lg),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.medium,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.displayNameOrEmail ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Capture and share your moments',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final events = eventProvider.userEvents;
        final totalMembers = events.fold<int>(
          0,
          (sum, e) => sum + e.memberIds.length,
        );
        final totalFolders = events.fold<int>(
          0,
          (sum, e) => sum + e.folders.length,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              _buildStatCard(
                Icons.calendar_today_rounded,
                '${events.length}',
                'Events',
                const Color(0xFF6366F1),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.group_rounded,
                '$totalMembers',
                'Members',
                const Color(0xFF14B8A6),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.folder_rounded,
                '$totalFolders',
                'Folders',
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              Icons.add_rounded,
              'Create Event',
              const Color(0xFF1E293B),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventCreateScreen()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              Icons.qr_code_scanner_rounded,
              'Join Event',
              const Color(0xFF14B8A6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinEventScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Your Events',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Consumer<EventProvider>(
              builder: (context, provider, _) => Text(
                '${provider.userEvents.length} total',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final events = eventProvider.userEvents;

        if (events.isEmpty) {
          return SliverFillRemaining(child: _buildEmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildModernEventCard(context, events[index], index),
              childCount: events.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernEventCard(
    BuildContext context,
    EventModel event,
    int index,
  ) {
    final colors = [
      const Color(0xFF6366F1), // Purple
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Green
    ];
    final accentColor = colors[index % colors.length];
    final pendingCount = event.pendingMemberIds.length;
    final authProvider = context.read<AuthProvider>();
    final isCreator = event.isCreator(authProvider.userId ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with event info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container with notification badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.photo_camera_rounded,
                          color: accentColor,
                          size: 26,
                        ),
                      ),
                      // Notification badge for pending requests (only for creator)
                      if (isCreator && pendingCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.cardBackground,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              pendingCount > 9 ? '9+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Code: ${event.eventCode}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.background,
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEventStat(
                    Icons.group_outlined,
                    '${event.memberIds.length}',
                    'Members',
                  ),
                  Container(width: 1, height: 32, color: AppColors.background),
                  _buildEventStat(
                    Icons.folder_outlined,
                    '${event.folders.length}',
                    'Folders',
                  ),
                  Container(width: 1, height: 32, color: AppColors.background),
                  _buildEventStat(
                    Icons.calendar_today_outlined,
                    _formatDate(event.createdAt ?? DateTime.now()),
                    'Created',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 64,
                color: AppColors.accent.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Events Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first event or join an existing one\nto start capturing memories together!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EventCreateScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinEventScreen()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Join'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF14B8A6),
                    side: const BorderSide(
                      color: Color(0xFF14B8A6),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        if (eventProvider.userEvents.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventCreateScreen()),
          ),
          backgroundColor: const Color(0xFF1E293B),
          elevation: 4,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${date.day}/${date.month}';
  }
}
