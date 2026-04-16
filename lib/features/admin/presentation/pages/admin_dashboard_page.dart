import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/admin_provider.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/utils/image_picker_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  _AdminSection _section = _AdminSection.videos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).loadVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);
    final authState = ref.watch(authProvider);

    // Show feedback snackbars
    ref.listen<AdminState>(adminProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF21A45D),
          ),
        );
        ref.read(adminProvider.notifier).clearFeedback();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFF05454),
          ),
        );
        ref.read(adminProvider.notifier).clearFeedback();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          _Sidebar(
            selected: _section,
            username: authState.user?.username ?? 'Admin',
            onSelect: (s) => setState(() => _section = s),
            onBack: () => context.go('/'),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                _TopBar(section: _section, isLoading: adminState.isLoading),

                // Body
                Expanded(
                  child: _section == _AdminSection.videos
                      ? _VideosSection(adminState: adminState)
                      : _UsersSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section enum
// ─────────────────────────────────────────────────────────────────────────────

enum _AdminSection { videos, users }

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _AdminSection selected;
  final String username;
  final ValueChanged<_AdminSection> onSelect;
  final VoidCallback onBack;

  const _Sidebar({
    required this.selected,
    required this.username,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF0D1520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05454),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'StreamOTT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Admin Panel',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1A2840), height: 1),
          const SizedBox(height: 16),

          // Nav items
          _NavItem(
            icon: Icons.movie_outlined,
            label: 'Videos',
            selected: selected == _AdminSection.videos,
            onTap: () => onSelect(_AdminSection.videos),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Users',
            selected: selected == _AdminSection.users,
            onTap: () => onSelect(_AdminSection.users),
          ),

          const Spacer(),
          const Divider(color: Color(0xFF1A2840), height: 1),
          const SizedBox(height: 12),

          // User info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFF05454),
                  child: Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Super Admin',
                        style: TextStyle(
                          color: Color(0xFFF05454),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Back to app
          _NavItem(
            icon: Icons.arrow_back_rounded,
            label: 'Back to App',
            selected: false,
            onTap: onBack,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF05454).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFFF05454).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFFF05454) : Colors.white54,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final _AdminSection section;
  final bool isLoading;

  const _TopBar({required this.section, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final title = section == _AdminSection.videos
        ? 'Video Management'
        : 'User Management';
    return Container(
      height: 64,
      color: const Color(0xFF0D1520),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF05454)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEOS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _VideosSection extends ConsumerStatefulWidget {
  final AdminState adminState;
  const _VideosSection({required this.adminState});

  @override
  ConsumerState<_VideosSection> createState() => _VideosSectionState();
}

class _VideosSectionState extends ConsumerState<_VideosSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _ContentFilter _contentFilter = _ContentFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allContent = widget.adminState.videos;
    final videos = allContent.where((v) {
      final matchesFilter = switch (_contentFilter) {
        _ContentFilter.all => true,
        _ContentFilter.videos => !v.isReel,
        _ContentFilter.reels => v.isReel,
      };
      if (!matchesFilter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return v.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.genre.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final totalContent = allContent.length;
    final videoCount = allContent.where((v) => !v.isReel).length;
    final reelCount = allContent.where((v) => v.isReel).length;
    final premiumCount = allContent.where((v) => v.requiresPremium).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                label: 'Total Content',
                value: '$totalContent',
                icon: Icons.movie_outlined,
                color: const Color(0xFF1F9DCC),
              ),
              _StatCard(
                label: 'Videos',
                value: '$videoCount',
                icon: Icons.movie_creation_outlined,
                color: const Color(0xFF21A45D),
              ),
              _StatCard(
                label: 'Reels',
                value: '$reelCount',
                icon: Icons.video_collection_outlined,
                color: const Color(0xFFFFB44C),
              ),
              _StatCard(
                label: 'Premium Locked',
                value: '$premiumCount',
                icon: Icons.workspace_premium_outlined,
                color: const Color(0xFFF05454),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Toolbar
          Row(
            children: [
              // Search
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search videos or reels...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF162235),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF243247)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF243247)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1F9DCC)),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _FilterChipButton(
                label: 'All',
                selected: _contentFilter == _ContentFilter.all,
                onTap: () =>
                    setState(() => _contentFilter = _ContentFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: 'Videos',
                selected: _contentFilter == _ContentFilter.videos,
                onTap: () =>
                    setState(() => _contentFilter = _ContentFilter.videos),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: 'Reels',
                selected: _contentFilter == _ContentFilter.reels,
                onTap: () =>
                    setState(() => _contentFilter = _ContentFilter.reels),
              ),
              const SizedBox(width: 12),
              // Add video button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05454),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Video',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showVideoForm(context),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB44C),
                  foregroundColor: const Color(0xFF0D1520),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.video_collection_outlined, size: 18),
                label: const Text(
                  'Add Reel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _showVideoForm(context, initialIsReel: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2840)),
              ),
              child: Column(
                children: [
                  // Header
                  _TableHeader(),
                  const Divider(color: Color(0xFF1A2840), height: 1),

                  // Rows
                  Expanded(
                    child: videos.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? _contentFilter == _ContentFilter.reels
                                        ? 'No reels yet'
                                        : _contentFilter ==
                                              _ContentFilter.videos
                                        ? 'No videos yet'
                                        : 'No content yet'
                                  : _contentFilter == _ContentFilter.reels
                                  ? 'No matching reels'
                                  : _contentFilter == _ContentFilter.videos
                                  ? 'No matching videos'
                                  : 'No results',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: videos.length,
                            separatorBuilder: (_, __) => const Divider(
                              color: Color(0xFF1A2840),
                              height: 1,
                            ),
                            itemBuilder: (context, i) {
                              final video = videos[i];
                              return _VideoRow(
                                key: ValueKey<String>(video.id),
                                video: video,
                                onEdit: () =>
                                    _showVideoForm(context, video: video),
                                onDelete: () => _confirmDelete(context, video),
                                onToggleFree: (value) => ref
                                    .read(adminProvider.notifier)
                                    .toggleFree(video.id, isFree: value),
                                onToggleFeatured: (value) => ref
                                    .read(adminProvider.notifier)
                                    .toggleFeatured(
                                      video.id,
                                      isFeatured: value,
                                    ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoForm(
    BuildContext context, {
    VideoModel? video,
    bool initialIsReel = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _VideoFormDialog(existing: video, initialIsReel: initialIsReel),
    );
  }

  void _confirmDelete(BuildContext context, VideoModel video) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Video',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05454),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(adminProvider.notifier).deleteVideo(video.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

enum _ContentFilter { all, videos, reels }

// ─────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2840)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1F9DCC).withValues(alpha: 0.18)
              : const Color(0xFF162235),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF1F9DCC) : const Color(0xFF243247),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Table header
// ─────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              'TITLE',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'GENRE',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'CONTENT',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'ACCESS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'FEATURED',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'ACTIONS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Video row
// ─────────────────────────────────────────

class _VideoRow extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleFree;
  final ValueChanged<bool> onToggleFeatured;

  const _VideoRow({
    super.key,
    required this.video,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFree,
    required this.onToggleFeatured,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 60,
              height: 40,
              child: video.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF162235),
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF162235),
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white24,
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Title / description
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (video.description.isNotEmpty)
                  Text(
                    video.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Genre
          Expanded(
            flex: 2,
            child: Text(
              video.genre,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: video.isReel
                      ? const Color(0xFFFFB44C).withValues(alpha: 0.18)
                      : const Color(0xFF1F9DCC).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: video.isReel
                        ? const Color(0xFFFFB44C)
                        : const Color(0xFF1F9DCC),
                  ),
                ),
                child: Text(
                  video.isReel ? 'REEL' : 'VIDEO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: video.isReel
                        ? const Color(0xFFFFB44C)
                        : const Color(0xFF1F9DCC),
                  ),
                ),
              ),
            ),
          ),

          // Free toggle
          SizedBox(
            width: 90,
            child: Row(
              children: [
                Switch(
                  key: ValueKey<String>(
                    'free-${video.id}-${video.requiresPremium}',
                  ),
                  value: !video.requiresPremium,
                  onChanged: onToggleFree,
                  activeColor: const Color(0xFF21A45D),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  video.requiresPremium ? 'P' : 'FREE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: video.requiresPremium
                        ? const Color(0xFFF05454)
                        : const Color(0xFF21A45D),
                  ),
                ),
              ],
            ),
          ),

          // Featured toggle
          SizedBox(
            width: 90,
            child: Switch(
              key: ValueKey<String>('featured-${video.id}-${video.isFeatured}'),
              value: video.isFeatured,
              onChanged: onToggleFeatured,
              activeColor: const Color(0xFFFFB44C),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          // Actions
          SizedBox(
            width: 90,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF1F9DCC),
                  ),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color(0xFFF05454),
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO FORM DIALOG (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _VideoFormDialog extends ConsumerStatefulWidget {
  final VideoModel? existing;
  final bool initialIsReel;

  const _VideoFormDialog({this.existing, this.initialIsReel = false});

  @override
  ConsumerState<_VideoFormDialog> createState() => _VideoFormDialogState();
}

class _VideoFormDialogState extends ConsumerState<_VideoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  static const Uuid _uuid = Uuid();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _thumbCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _directorCtrl;

  bool _isFree = true;
  bool _isReel = false;
  bool _isFeatured = false;
  bool _isSubmitting = false;
  bool _isUploadingThumbnail = false;

  String _formatError(Object error) {
    if (error is StorageException) {
      return 'StorageException: ${error.message}';
    }
    if (error is PostgrestException) {
      return 'PostgrestException: ${error.message}';
    }
    if (error is AuthException) {
      return 'AuthException: ${error.message}';
    }
    return '${error.runtimeType}: $error';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF05454),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _handleThumbnailChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _titleCtrl = TextEditingController(text: v?.title ?? '');
    _descCtrl = TextEditingController(text: v?.description ?? '');
    _thumbCtrl = TextEditingController(text: v?.thumbnailUrl ?? '');
    _thumbCtrl.addListener(_handleThumbnailChanged);
    _videoUrlCtrl = TextEditingController(text: v?.videoUrl ?? '');
    _genreCtrl = TextEditingController(text: v?.genre ?? 'Drama');
    _durationCtrl = TextEditingController(
      text: v != null ? '${v.duration}' : '',
    );
    _directorCtrl = TextEditingController(text: v?.director ?? '');
    _isFree = v != null ? !v.requiresPremium : true;
    _isReel = v?.isReel ?? widget.initialIsReel;
    _isFeatured = v?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _thumbCtrl.removeListener(_handleThumbnailChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _thumbCtrl.dispose();
    _videoUrlCtrl.dispose();
    _genreCtrl.dispose();
    _durationCtrl.dispose();
    _directorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final contentLabel = _isReel ? 'Reel' : 'Video';
    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit $contentLabel' : 'Add New $contentLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF1A2840)),
                const SizedBox(height: 16),

                // Title
                _FormField(
                  label: 'Title *',
                  child: _textField(
                    _titleCtrl,
                    'Enter video title',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                _FormField(
                  label: 'Description',
                  child: _textField(
                    _descCtrl,
                    'Enter description',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),

                // Thumbnail URL
                _FormField(
                  label: 'Thumbnail URL *',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              _thumbCtrl,
                              'https://...image.jpg',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingThumbnail
                                  ? null
                                  : _pickAndUploadThumbnail,
                              icon: _isUploadingThumbnail
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file_outlined),
                              label: Text(
                                _isUploadingThumbnail
                                    ? 'Uploading...'
                                    : 'Pick Image',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF243247),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload to Supabase Storage or paste a public image URL manually.',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      if (_thumbCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: Image.network(
                              _thumbCtrl.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF162235),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Thumbnail preview unavailable',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Video URL
                _FormField(
                  label: 'Video URL *',
                  child: _textField(
                    _videoUrlCtrl,
                    'https://...video.mp4',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 14),

                // Genre + Duration row
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Genre',
                        child: _textField(_genreCtrl, 'Drama, Action...'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label: 'Duration (seconds) *',
                        child: _textField(
                          _durationCtrl,
                          '3600',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final parsedValue = int.tryParse(v.trim());
                            if (parsedValue == null) {
                              return 'Must be a number';
                            }
                            if (parsedValue <= 0) {
                              return 'Must be greater than 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Director
                _FormField(
                  label: 'Director',
                  child: _textField(_directorCtrl, 'Optional'),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _ToggleChip(
                      label: 'Video',
                      selected: !_isReel,
                      activeColor: const Color(0xFF1F9DCC),
                      icon: Icons.movie_creation_outlined,
                      onTap: () => setState(() => _isReel = false),
                    ),
                    const SizedBox(width: 10),
                    _ToggleChip(
                      label: 'Reel',
                      selected: _isReel,
                      activeColor: const Color(0xFFFFB44C),
                      icon: Icons.video_collection_outlined,
                      onTap: () => setState(() => _isReel = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Type toggle
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Free',
                      selected: _isFree,
                      activeColor: const Color(0xFF21A45D),
                      icon: Icons.lock_open_outlined,
                      onTap: () => setState(() => _isFree = true),
                    ),
                    const SizedBox(width: 10),
                    _ToggleChip(
                      label: 'Premium',
                      selected: !_isFree,
                      activeColor: const Color(0xFFF05454),
                      icon: Icons.workspace_premium_outlined,
                      onTap: () => setState(() => _isFree = false),
                    ),
                    const SizedBox(width: 24),
                    // Featured
                    Row(
                      children: [
                        Checkbox(
                          value: _isFeatured,
                          onChanged: (v) => setState(() => _isFeatured = v!),
                          activeColor: const Color(0xFFFFB44C),
                          side: const BorderSide(color: Colors.white38),
                        ),
                        const Text(
                          'Featured',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFF1A2840)),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              isEdit ? 'Save Changes' : 'Add $contentLabel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF162235),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF243247)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF243247)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1F9DCC)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF05454)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF05454)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFF05454), fontSize: 11),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final durationSecs = int.parse(_durationCtrl.text.trim());
    bool success;

    if (widget.existing != null) {
      success = await ref
          .read(adminProvider.notifier)
          .updateVideo(
            id: widget.existing!.id,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            thumbnailUrl: _thumbCtrl.text,
            videoUrl: _videoUrlCtrl.text,
            genre: _genreCtrl.text,
            durationSeconds: durationSecs,
            isFree: _isFree,
            isReel: _isReel,
            isFeatured: _isFeatured,
            director: _directorCtrl.text,
          );
    } else {
      success = await ref
          .read(adminProvider.notifier)
          .addVideo(
            title: _titleCtrl.text,
            description: _descCtrl.text,
            thumbnailUrl: _thumbCtrl.text,
            videoUrl: _videoUrlCtrl.text,
            genre: _genreCtrl.text,
            durationSeconds: durationSecs,
            isFree: _isFree,
            isReel: _isReel,
            isFeatured: _isFeatured,
            director: _directorCtrl.text,
          );
    }

    setState(() => _isSubmitting = false);
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> _pickAndUploadThumbnail() async {
    try {
      setState(() => _isUploadingThumbnail = true);

      final pickedFile = await pickImageFile();

      if (pickedFile == null) {
        setState(() => _isUploadingThumbnail = false);
        return;
      }

      final String extension = _extractFileExtension(pickedFile.name);
      final String contentType = _imageContentType(extension);
      final String filePath =
          'admin/${_uuid.v4()}.${extension.isEmpty ? 'jpg' : extension}';

      await Supabase.instance.client.storage
          .from('thumbnails')
          .uploadBinary(
            filePath,
            pickedFile.bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('thumbnails')
          .getPublicUrl(filePath);

      setState(() {
        _thumbCtrl.text = publicUrl;
        _isUploadingThumbnail = false;
      });
    } catch (error, stackTrace) {
      final message = _formatError(error);
      debugPrint('[AdminDashboardPage] Thumbnail upload failed: $message');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() => _isUploadingThumbnail = false);
        _showErrorSnackBar('Thumbnail upload failed: $message');
      }
    }
  }

  String _extractFileExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.2)
              : const Color(0xFF162235),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFF243247),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? activeColor : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : Colors.white38,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USERS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _UsersSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await ref.read(adminProvider.notifier).loadUsers();
    if (mounted)
      setState(() {
        _users = users;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(
                label: 'Total Users',
                value: '${_users.length}',
                icon: Icons.people_outline,
                color: const Color(0xFF1F9DCC),
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Admins',
                value: '${_users.where((u) => u['is_admin'] == true).length}',
                icon: Icons.admin_panel_settings_outlined,
                color: const Color(0xFFFFB44C),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2840)),
              ),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF05454),
                      ),
                    )
                  : _users.isEmpty
                  ? const Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'EMAIL',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'USERNAME',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFF1A2840), height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const Divider(
                              color: Color(0xFF1A2840),
                              height: 1,
                            ),
                            itemBuilder: (context, i) {
                              final u = _users[i];
                              final isAdmin = u['is_admin'] as bool? ?? false;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        u['email'] ?? u['id'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        u['username'] ?? '-',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Switch(
                                        value: isAdmin,
                                        activeColor: const Color(0xFFFFB44C),
                                        onChanged: (v) async {
                                          await ref
                                              .read(adminProvider.notifier)
                                              .setUserAdmin(
                                                u['id'] as String,
                                                isAdmin: v,
                                              );
                                          await _loadUsers();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
