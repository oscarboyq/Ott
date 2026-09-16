import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/constants/app_strings.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/subscription_plan_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/common/widgets/branding_logo.dart';
import 'package:video/core/providers/admin_provider.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/branding_provider.dart';
import 'package:video/core/providers/service_providers.dart';
import 'package:video/core/providers/theme_provider.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/utils/image_picker_service.dart';
import 'package:video/core/utils/video_picker_service.dart';
import 'package:video/features/admin/presentation/controllers/media_upload_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _genreFilterItems = [
  'Action',
  'Animation',
  'Comedy',
  'Drama',
  'Horror',
  'Romance',
  'Thriller',
  'Sci-Fi',
];

List<String> _genreDropdownItems(String currentGenre) {
  final trimmedGenre = currentGenre.trim();
  if (trimmedGenre.isEmpty || _genreFilterItems.contains(trimmedGenre)) {
    return _genreFilterItems;
  }

  return [
    _genreFilterItems.first,
    trimmedGenre,
    ..._genreFilterItems.where((genre) => genre != trimmedGenre),
  ];
}

String _genreDropdownValue(String currentGenre) {
  final trimmedGenre = currentGenre.trim();
  if (trimmedGenre.isEmpty) {
    return 'Drama';
  }

  return trimmedGenre;
}

const Uuid _adminImageUuid = Uuid();

String _formatAdminUploadError(Object error) {
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

String _extractAdminImageFileExtension(String fileName) {
  final int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return 'jpg';
  }
  return fileName.substring(dotIndex + 1).toLowerCase();
}

String _adminImageContentType(String extension) {
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

Future<String?> _pickAndUploadAdminImage() async {
  final pickedFile = await pickImageFile();
  if (pickedFile == null) {
    return null;
  }

  final String extension = _extractAdminImageFileExtension(pickedFile.name);
  final String contentType = _adminImageContentType(extension);
  final String filePath =
      'admin/${_adminImageUuid.v4()}.${extension.isEmpty ? 'jpg' : extension}';

  await Supabase.instance.client.storage
      .from('thumbnails')
      .uploadBinary(
        filePath,
        pickedFile.bytes,
        fileOptions: FileOptions(contentType: contentType),
      );

  return Supabase.instance.client.storage
      .from('thumbnails')
      .getPublicUrl(filePath);
}

void _showAdminImageUploadError({
  required BuildContext context,
  required String fieldLabel,
  required Object error,
  required StackTrace stackTrace,
}) {
  final message = _formatAdminUploadError(error);
  debugPrint('[AdminDashboardPage] $fieldLabel upload failed: $message');
  debugPrintStack(stackTrace: stackTrace);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$fieldLabel upload failed: $message'),
      backgroundColor: const Color(0xFFF05454),
      duration: const Duration(seconds: 6),
    ),
  );
}

InputDecoration _adminFieldDecoration(String hint, [BuildContext? context]) {
  final isDark = context?.isDark ?? true;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
      fontSize: 14,
    ),
    filled: true,
    fillColor: isDark ? const Color(0xFF162235) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF243247) : const Color(0xFFCBD5E1),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF243247) : const Color(0xFFCBD5E1),
      ),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFF1F9DCC)),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFFF05454)),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFFF05454)),
    ),
    errorStyle: const TextStyle(color: Color(0xFFF05454), fontSize: 11),
  );
}

Widget _adminGenreDropdownField(
  TextEditingController ctrl, {
  String hint = 'Select genre',
  String? Function(String?)? validator,
}) {
  final genreItems = _genreDropdownItems(ctrl.text);
  return Builder(
    builder: (context) {
      final isDark = context.isDark;
      return DropdownButtonFormField<String>(
        initialValue: _genreDropdownValue(ctrl.text),
        validator: validator,
        dropdownColor: isDark ? const Color(0xFF162235) : Colors.white,
        iconEnabledColor: isDark ? Colors.white70 : const Color(0xFF475569),
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: _adminFieldDecoration(hint, context),
        items: genreItems
            .map(
              (genre) => DropdownMenuItem<String>(
                value: genre,
                child: Text(
                  genre,
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          ctrl.text = value;
        },
      );
    },
  );
}

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
      ref.read(adminProvider.notifier).loadSeries();
      ref.read(adminProvider.notifier).loadSubscriptionPlans();
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
      backgroundColor: context.scaffoldBg,
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
                      : _section == _AdminSection.series
                      ? _SeriesSection(adminState: adminState)
                      : _section == _AdminSection.subscriptions
                      ? _SubscriptionsSection(adminState: adminState)
                      : _section == _AdminSection.settings
                      ? const _SettingsSection()
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

enum _AdminSection { videos, series, subscriptions, users, settings }

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(platformBrandingProvider);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.sidebarBg,
        border: Border(
          right: BorderSide(color: context.borderCol),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (branding.hasCustomLogo)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppBrandingLogo(
                      logoUrl: branding.logoUrl!,
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      borderRadius: BorderRadius.circular(8),
                      whiteTile: true,
                    ),
                  )
                else
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
                Expanded(
                  child: Text(
                    branding.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
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
                color: context.textSecondary,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: context.borderCol, height: 1),
          const SizedBox(height: 16),

          // Nav items
          _NavItem(
            icon: Icons.movie_outlined,
            label: 'Videos',
            selected: selected == _AdminSection.videos,
            onTap: () => onSelect(_AdminSection.videos),
          ),
          _NavItem(
            icon: Icons.live_tv_rounded,
            label: 'Series',
            selected: selected == _AdminSection.series,
            onTap: () => onSelect(_AdminSection.series),
          ),
          _NavItem(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscriptions',
            selected: selected == _AdminSection.subscriptions,
            onTap: () => onSelect(_AdminSection.subscriptions),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Users',
            selected: selected == _AdminSection.users,
            onTap: () => onSelect(_AdminSection.users),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: selected == _AdminSection.settings,
            onTap: () => onSelect(_AdminSection.settings),
          ),

          const Spacer(),
          Divider(color: context.borderCol, height: 1),
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
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
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
                        style: TextStyle(
                          color: context.textPrimary,
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
      borderRadius: BorderRadius.circular(8),
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
              color: selected ? const Color(0xFFF05454) : context.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFF05454) : context.textSecondary,
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
    final title = switch (section) {
      _AdminSection.videos => 'Video Management',
      _AdminSection.series => 'Series Management',
      _AdminSection.subscriptions => 'Subscription Plans',
      _AdminSection.users => 'User Management',
      _AdminSection.settings => 'Platform Settings',
    };
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: context.topBarBg,
        border: Border(
          bottom: BorderSide(color: context.borderCol),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
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
          const Spacer(),
          const ThemeToggleButton(),
        ],
      ),
    );
  }
}

class _SubscriptionsSection extends ConsumerStatefulWidget {
  const _SubscriptionsSection({required this.adminState});

  final AdminState adminState;

  @override
  ConsumerState<_SubscriptionsSection> createState() =>
      _SubscriptionsSectionState();
}

class _SubscriptionsSectionState extends ConsumerState<_SubscriptionsSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allPlans = widget.adminState.subscriptionPlans;
    final filteredPlans = allPlans
        .where((plan) {
          if (_searchQuery.isEmpty) {
            return true;
          }

          final query = _searchQuery.toLowerCase();
          return plan.name.toLowerCase().contains(query) ||
              plan.description.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final activePlans = allPlans.where((plan) => plan.monthlyPrice > 0).length;
    final enabledPlans = allPlans.where((plan) => plan.isActive).length;
    final disabledPlans = allPlans.where((plan) => !plan.isActive).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                label: 'Total Plans',
                value: '${allPlans.length}',
                icon: Icons.view_carousel_outlined,
                color: const Color(0xFF1F9DCC),
              ),
              _StatCard(
                label: 'Paid Plans',
                value: '$activePlans',
                icon: Icons.payments_outlined,
                color: const Color(0xFF21A45D),
              ),
              _StatCard(
                label: 'Purchasable',
                value: '$enabledPlans',
                icon: Icons.workspace_premium_outlined,
                color: const Color(0xFFFFB44C),
              ),
              _StatCard(
                label: 'Disabled Paid',
                value: '$disabledPlans',
                icon: Icons.pause_circle_outline_rounded,
                color: const Color(0xFFF05454),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 320,
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search plans...',
                    hintStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: context.elevatedBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
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
              const Text(
                'Price changes affect new subscriptions only.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  const _SubscriptionPlansHeader(),
                  const Divider(color: Color(0xFF1A2840), height: 1),
                  Expanded(
                    child: filteredPlans.isEmpty
                        ? const Center(
                            child: Text(
                              'No subscription plans found',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredPlans.length,
                            separatorBuilder: (_, _) => const Divider(
                              color: Color(0xFF1A2840),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final plan = filteredPlans[index];
                              return _SubscriptionPlanRow(
                                plan: plan,
                                onEdit: () => _showPlanEditor(context, plan),
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

  void _showPlanEditor(BuildContext context, SubscriptionPlanModel plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubscriptionPlanFormDialog(existing: plan),
    );
  }
}

class _SubscriptionPlansHeader extends StatelessWidget {
  const _SubscriptionPlansHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'PLAN',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'MONTHLY',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'ANNUAL',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'STATUS',
              style: TextStyle(
                color: context.textMuted,
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
                color: context.textMuted,
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

class _SubscriptionPlanRow extends StatelessWidget {
  const _SubscriptionPlanRow({required this.plan, required this.onEdit});

  final SubscriptionPlanModel plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isFreePlan =
        plan.monthlyPrice == 0 && plan.name.toLowerCase() == 'free';
    final isPurchasable = plan.isActive && plan.monthlyPrice > 0;
    final statusColor = isFreePlan
        ? const Color(0xFF1F9DCC)
        : isPurchasable
        ? const Color(0xFF21A45D)
        : const Color(0xFFF05454);
    final statusLabel = isFreePlan
        ? 'Free'
        : isPurchasable
        ? 'Active'
        : 'Disabled';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (plan.description.isNotEmpty)
                  Text(
                    plan.description,
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              plan.monthlyPrice <= 0
                  ? '0.00'
                  : plan.monthlyPrice.toStringAsFixed(2),
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              plan.yearlyPrice <= 0 ? '-' : plan.yearlyPrice.toStringAsFixed(2),
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
                  tooltip: 'Edit plan',
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

class _SubscriptionPlanFormDialog extends ConsumerStatefulWidget {
  const _SubscriptionPlanFormDialog({required this.existing});

  final SubscriptionPlanModel existing;

  @override
  ConsumerState<_SubscriptionPlanFormDialog> createState() =>
      _SubscriptionPlanFormDialogState();
}

class _SubscriptionPlanFormDialogState
    extends ConsumerState<_SubscriptionPlanFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _monthlyCtrl;
  late final TextEditingController _annualCtrl;
  late final TextEditingController _featuresCtrl;

  late bool _isActive;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existing;
    _nameCtrl = TextEditingController(text: plan.name);
    _descCtrl = TextEditingController(text: plan.description);
    _monthlyCtrl = TextEditingController(
      text: plan.monthlyPrice.toStringAsFixed(2),
    );
    _annualCtrl = TextEditingController(
      text: plan.yearlyPrice.toStringAsFixed(2),
    );
    _featuresCtrl = TextEditingController(text: plan.features.join('\n'));
    _isActive = plan.isActive;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _monthlyCtrl.dispose();
    _annualCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.surfaceBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Edit Subscription Plan',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),
                _FormField(
                  label: 'Plan Name *',
                  child: _adminTextField(
                    _nameCtrl,
                    'Premium',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Description',
                  child: _adminTextField(
                    _descCtrl,
                    'Unlock premium playback',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Monthly Price *',
                        child: _adminTextField(
                          _monthlyCtrl,
                          '10.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _priceField,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label: 'Annual Price',
                        child: _adminTextField(
                          _annualCtrl,
                          '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _optionalPriceField,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Features',
                  child: _adminTextField(
                    _featuresCtrl,
                    'One feature per line',
                    maxLines: 6,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Checkbox(
                      value: _isActive,
                      onChanged: (value) =>
                          setState(() => _isActive = value ?? false),
                      activeColor: const Color(0xFF21A45D),
                      side: const BorderSide(color: Colors.white38),
                    ),
                    const Text(
                      'Enable plan for future purchases',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Existing subscribers keep their stored subscription price. Changes here only affect new purchases and renewals created after the edit.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFF1A2840)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Changes'),
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

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _priceField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final parsedValue = double.tryParse(value.trim());
    if (parsedValue == null) {
      return 'Enter a valid number';
    }
    if (parsedValue < 0) {
      return 'Must be 0 or higher';
    }
    return null;
  }

  String? _optionalPriceField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(value.trim());
    if (parsedValue == null) {
      return 'Enter a valid number';
    }
    if (parsedValue < 0) {
      return 'Must be 0 or higher';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final monthlyPrice = double.parse(_monthlyCtrl.text.trim());
    final yearlyPrice =
        double.tryParse(
          _annualCtrl.text.trim().isEmpty ? '0' : _annualCtrl.text.trim(),
        ) ??
        0;
    final features = _featuresCtrl.text
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final success = await ref
        .read(adminProvider.notifier)
        .updateSubscriptionPlan(
          id: widget.existing.id,
          name: _nameCtrl.text,
          description: _descCtrl.text,
          monthlyPrice: monthlyPrice,
          yearlyPrice: yearlyPrice,
          features: features,
          isActive: _isActive,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _SeriesSection extends ConsumerStatefulWidget {
  const _SeriesSection({required this.adminState});

  final AdminState adminState;

  @override
  ConsumerState<_SeriesSection> createState() => _SeriesSectionState();
}

class _SeriesSectionState extends ConsumerState<_SeriesSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSeries = widget.adminState.series;
    final seriesStatusMessage = widget.adminState.seriesStatusMessage;
    final filteredSeries = allSeries
        .where((item) {
          if (_searchQuery.isEmpty) {
            return true;
          }
          final query = _searchQuery.toLowerCase();
          return item.title.toLowerCase().contains(query) ||
              item.genre.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final featuredCount = allSeries.where((item) => item.isFeatured).length;
    final freeCount = allSeries.where((item) => !item.requiresPremium).length;
    final premiumCount = allSeries.where((item) => item.requiresPremium).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                label: 'Total Series',
                value: '${allSeries.length}',
                icon: Icons.live_tv_rounded,
                color: const Color(0xFF1F9DCC),
              ),
              _StatCard(
                label: 'Featured',
                value: '$featuredCount',
                icon: Icons.workspace_premium_outlined,
                color: const Color(0xFFFFB44C),
              ),
              _StatCard(
                label: 'Free Entry',
                value: '$freeCount',
                icon: Icons.lock_open_rounded,
                color: const Color(0xFF21A45D),
              ),
              _StatCard(
                label: 'Premium',
                value: '$premiumCount',
                icon: Icons.lock_outline_rounded,
                color: const Color(0xFFF05454),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search series...',
                    hintStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: context.elevatedBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
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
                  'Add Series',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showSeriesForm(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  if (seriesStatusMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0x221F9DCC),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1A2840)),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF7CC6E6),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              seriesStatusMessage,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const _SeriesTableHeader(),
                  const Divider(color: Color(0xFF1A2840), height: 1),
                  Expanded(
                    child: filteredSeries.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No series yet'
                                  : 'No matching series',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredSeries.length,
                            separatorBuilder: (_, _) => const Divider(
                              color: Color(0xFF1A2840),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final item = filteredSeries[index];
                              return _SeriesRow(
                                key: ValueKey<String>(item.id),
                                series: item,
                                onManage: () =>
                                    _showSeriesStructure(context, item),
                                onEdit: () =>
                                    _showSeriesForm(context, existing: item),
                                onDelete: () =>
                                    _confirmDeleteSeries(context, item),
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

  void _showSeriesForm(BuildContext context, {SeriesModel? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SeriesFormDialog(existing: existing),
    );
  }

  void _showSeriesStructure(BuildContext context, SeriesModel series) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SeriesStructureDialog(series: series),
    );
  }

  void _confirmDeleteSeries(BuildContext context, SeriesModel series) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Series',
          style: TextStyle(color: dialogCtx.textPrimary),
        ),
        content: Text(
          'Delete "${series.title}" and all seasons and episodes under it?',
          style: TextStyle(color: dialogCtx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogCtx.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05454),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(adminProvider.notifier).deleteSeries(series.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SeriesTableHeader extends StatelessWidget {
  const _SeriesTableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'TITLE',
              style: TextStyle(
                color: context.textMuted,
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
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'STRUCTURE',
              style: TextStyle(
                color: context.textMuted,
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
                color: context.textMuted,
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
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              'ACTIONS',
              style: TextStyle(
                color: context.textMuted,
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

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    super.key,
    required this.series,
    required this.onManage,
    required this.onEdit,
    required this.onDelete,
  });

  final SeriesModel series;
  final VoidCallback onManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 60,
                    height: 40,
                    child: series.posterUrl.isNotEmpty
                        ? Image.network(
                            series.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: context.elevatedBg,
                              child: Icon(
                                Icons.live_tv_rounded,
                                color: context.textMuted,
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            color: context.elevatedBg,
                            child: Icon(
                              Icons.live_tv_rounded,
                              color: context.textMuted,
                              size: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (series.tagline.isNotEmpty)
                        Text(
                          series.tagline,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              series.genre,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '${series.seasonCount} seasons / ${series.episodeCount} eps',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              series.requiresPremium ? 'Premium' : 'Free',
              style: TextStyle(
                color: series.requiresPremium
                    ? const Color(0xFFF05454)
                    : const Color(0xFF21A45D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Icon(
              series.isFeatured
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: series.isFeatured
                  ? const Color(0xFFFFB44C)
                  : Colors.white30,
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: Color(0xFF1F9DCC),
                  ),
                  onPressed: onManage,
                  tooltip: 'Manage seasons and episodes',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF1F9DCC),
                  ),
                  onPressed: onEdit,
                  tooltip: 'Edit series',
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
                  tooltip: 'Delete series',
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
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search videos or reels...',
                    hintStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: context.elevatedBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderCol),
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
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
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
                            separatorBuilder: (_, _) => const Divider(
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
    final typeLabel = video.isReel ? 'Reel' : 'Video';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete $typeLabel',
          style: TextStyle(color: dialogCtx.textPrimary),
        ),
        content: Text(
          video.mediaProvider == 'bunny'
              ? 'Are you sure you want to delete "${video.title}"? This will permanently delete the video from Bunny Stream hosting, remove custom storage thumbnails, and delete the record.'
              : 'Are you sure you want to delete "${video.title}"? This will remove custom storage thumbnails and delete the record permanently.',
          style: TextStyle(color: dialogCtx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogCtx.textMuted),
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
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
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
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: context.textSecondary, fontSize: 11),
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
              : context.elevatedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF1F9DCC) : context.borderCol,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1F9DCC) : context.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              'TITLE',
              style: TextStyle(
                color: context.textMuted,
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
                color: context.textMuted,
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
                color: context.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'MEDIA',
              style: TextStyle(
                color: context.textMuted,
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
                color: context.textMuted,
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
                color: context.textMuted,
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
                color: context.textMuted,
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
  final ValueChanged<bool>? onToggleFeatured;

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
                      errorBuilder: (_, _, _) => Container(
                        color: context.elevatedBg,
                        child: Icon(
                          Icons.movie,
                          color: context.textMuted,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      color: context.elevatedBg,
                      child: Icon(
                        Icons.movie,
                        color: context.textMuted,
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
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (video.description.isNotEmpty)
                  Text(
                    video.description,
                    style: TextStyle(color: context.textMuted, fontSize: 11),
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
              style: TextStyle(color: context.textSecondary, fontSize: 13),
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

          SizedBox(width: 110, child: _MediaStatusBadge(video: video)),

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
                  activeThumbColor: const Color(0xFF21A45D),
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
            child: video.isReel
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'N/A',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  )
                : Switch(
                    key: ValueKey<String>(
                      'featured-${video.id}-${video.isFeatured}',
                    ),
                    value: video.isFeatured,
                    onChanged: onToggleFeatured,
                    activeThumbColor: const Color(0xFFFFB44C),
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

class _MediaStatusBadge extends ConsumerWidget {
  const _MediaStatusBadge({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, color, icon) = switch (video.mediaStatus) {
      'creating' => ('CREATING', const Color(0xFFFFB44C), Icons.hourglass_top),
      'uploading' => (
        'UPLOADING',
        const Color(0xFF1F9DCC),
        Icons.cloud_upload_outlined,
      ),
      'processing' => (
        video.processingProgress > 0 ? '${video.processingProgress}%' : '0% (PROC)',
        const Color(0xFFFFB44C),
        Icons.settings_outlined,
      ),
      'failed' => ('FAILED', const Color(0xFFF05454), Icons.error_outline),
      'deleting' => ('DELETING', Colors.white38, Icons.delete_outline),
      _ => ('READY', const Color(0xFF21A45D), Icons.check_circle_outline),
    };

    return PopupMenuButton<String>(
      tooltip: 'Click to change status (e.g. Mark as Ready)',
      onSelected: (newStatus) async {
        final progress = newStatus == 'ready' ? 100 : (newStatus == 'processing' ? 0 : null);
        await ref.read(adminProvider.notifier).updateBunnyMediaStatus(
              id: video.id,
              status: newStatus,
              processingProgress: progress,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video status updated to "$newStatus"'),
              backgroundColor: newStatus == 'ready'
                  ? const Color(0xFF21A45D)
                  : const Color(0xFF1F9DCC),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      color: context.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.borderCol),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'ready',
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF21A45D)),
              const SizedBox(width: 8),
              Text('Mark as Ready', style: TextStyle(color: ctx.textPrimary, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'processing',
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 16, color: Color(0xFFFFB44C)),
              const SizedBox(width: 8),
              Text('Mark as Processing', style: TextStyle(color: ctx.textPrimary, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'failed',
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Color(0xFFF05454)),
              const SizedBox(width: 8),
              Text('Mark as Failed', style: TextStyle(color: ctx.textPrimary, fontSize: 12)),
            ],
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO FORM DIALOG (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────

enum _VideoMediaSource { bunny, external }

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

  bool _isFree = true;
  bool _isReel = false;
  bool _isFeatured = false;
  bool _isSubmitting = false;
  bool _isUploadingThumbnail = false;
  _VideoMediaSource _mediaSource = _VideoMediaSource.bunny;
  XFile? _selectedVideo;
  int? _selectedVideoSize;
  String? _videoSelectionError;
  String? _bunnyDraftId;
  bool _uploadTerminalStateHandled = false;

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
    _isFree = v != null ? !v.requiresPremium : true;
    _isReel = v?.isReel ?? widget.initialIsReel;
    _isFeatured = v?.isFeatured ?? false;
    _mediaSource = v?.mediaProvider == 'bunny'
        ? _VideoMediaSource.bunny
        : _VideoMediaSource.external;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final contentLabel = _isReel ? 'Reel' : 'Video';
    final uploadState = ref.watch(mediaUploadControllerProvider);
    final uploadBusy = uploadState.isActive;
    return Dialog(
      backgroundColor: context.surfaceBg,
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
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary),
                      onPressed: uploadBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),

                if (!isEdit) ...[
                  _FormField(
                    label: 'Media Source',
                    child: Row(
                      children: [
                        Expanded(
                          child: _MediaSourceButton(
                            label: 'Bunny Stream',
                            icon: Icons.cloud_upload_outlined,
                            selected: _mediaSource == _VideoMediaSource.bunny,
                            onTap: uploadBusy
                                ? null
                                : () => setState(() {
                                    _mediaSource = _VideoMediaSource.bunny;
                                    _videoSelectionError = null;
                                  }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MediaSourceButton(
                            label: 'External URL',
                            icon: Icons.link,
                            selected:
                                _mediaSource == _VideoMediaSource.external,
                            onTap: uploadBusy
                                ? null
                                : () => setState(() {
                                    _mediaSource = _VideoMediaSource.external;
                                    _videoSelectionError = null;
                                  }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
                  label: _mediaSource == _VideoMediaSource.bunny
                      ? 'Thumbnail (optional)'
                      : 'Thumbnail URL *',
                  child: _mediaSource == _VideoMediaSource.bunny
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_thumbCtrl.text.trim().isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: Image.network(
                                    _thumbCtrl.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color: context.elevatedBg,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Thumbnail preview unavailable',
                                        style: TextStyle(color: context.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _isUploadingThumbnail
                                        ? null
                                        : _pickAndUploadThumbnail,
                                    icon: _isUploadingThumbnail
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                context.textPrimary,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.upload_file_outlined),
                                    label: Text(
                                      _isUploadingThumbnail
                                          ? 'Uploading...'
                                          : 'Change Image',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: context.textPrimary,
                                      disabledForegroundColor:
                                          context.textPrimary,
                                      side: BorderSide(
                                        color: context.borderCol,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: _isUploadingThumbnail
                                        ? null
                                        : () {
                                            setState(() {
                                              _thumbCtrl.clear();
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Remove Custom Image',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Custom thumbnail will be used. Remove to let Bunny generate the thumbnail automatically.',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _isUploadingThumbnail
                                        ? null
                                        : _pickAndUploadThumbnail,
                                    icon: _isUploadingThumbnail
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                context.textPrimary,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.upload_file_outlined),
                                    label: Text(
                                      _isUploadingThumbnail
                                          ? 'Uploading...'
                                          : 'Pick Image',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: context.textPrimary,
                                      disabledForegroundColor:
                                          context.textPrimary,
                                      side: BorderSide(
                                        color: context.borderCol,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Optional fallback image. Bunny will generate a thumbnail during processing when no image is uploaded.',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    _thumbCtrl,
                                    'https://...image.jpg',
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
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
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                context.textPrimary,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.upload_file_outlined),
                                    label: Text(
                                      _isUploadingThumbnail
                                          ? 'Uploading...'
                                          : 'Pick Image',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: context.textPrimary,
                                      disabledForegroundColor:
                                          context.textPrimary,
                                      side: BorderSide(
                                        color: context.borderCol,
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
                              style: TextStyle(
                                color: context.textMuted,
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
                                    errorBuilder: (_, _, _) => Container(
                                      color: context.elevatedBg,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Thumbnail preview unavailable',
                                        style: TextStyle(color: context.textMuted),
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

                if (_mediaSource == _VideoMediaSource.bunny && !isEdit)
                  _FormField(
                    label: 'Video File *',
                    child: _BunnyVideoPicker(
                      file: _selectedVideo,
                      fileSize: _selectedVideoSize,
                      error: _videoSelectionError,
                      enabled: !uploadBusy && !_isSubmitting,
                      onPick: _pickVideo,
                    ),
                  )
                else
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
                        child: _adminGenreDropdownField(
                          _genreCtrl,
                          hint: 'Select genre',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label:
                            _mediaSource == _VideoMediaSource.bunny && !isEdit
                            ? 'Duration (from Bunny)'
                            : 'Duration (seconds) *',
                        child: _textField(
                          _durationCtrl,
                          '3600',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (_mediaSource == _VideoMediaSource.bunny &&
                                !isEdit &&
                                (v == null || v.trim().isEmpty)) {
                              return null;
                            }
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
                const SizedBox(height: 20),

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
                    if (!_isReel) ...[
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Checkbox(
                            value: _isFeatured,
                            onChanged: (v) =>
                                setState(() => _isFeatured = v ?? false),
                            activeColor: const Color(0xFFFFB44C),
                            side: BorderSide(color: context.borderCol),
                          ),
                          Text(
                            'Featured',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (_mediaSource == _VideoMediaSource.bunny && !isEdit) ...[
                  _BunnyUploadProgressCard(state: uploadState),
                  const SizedBox(height: 16),
                ],
                Divider(color: context.borderCol),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting || uploadBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                    if (uploadState.stage == MediaUploadStage.uploading) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .pause(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Pause'),
                      ),
                    ],
                    if (uploadState.stage == MediaUploadStage.paused) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .resume(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Resume'),
                      ),
                    ],
                    if (uploadBusy) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _cancelBunnyUpload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Cancel Upload'),
                      ),
                    ],
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
                      onPressed: _isSubmitting || uploadBusy ? null : _submit,
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
                              isEdit
                                  ? 'Save Changes'
                                  : _mediaSource == _VideoMediaSource.bunny
                                  ? 'Upload $contentLabel'
                                  : 'Add $contentLabel',
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
      style: TextStyle(color: context.textPrimary, fontSize: 14),
      decoration: _adminFieldDecoration(hint, context),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.existing == null &&
        _mediaSource == _VideoMediaSource.bunny &&
        _selectedVideo == null) {
      setState(() => _videoSelectionError = 'Select a video file');
      return;
    }

    if (widget.existing == null && _mediaSource == _VideoMediaSource.bunny) {
      await _startBunnyUpload();
      return;
    }

    setState(() => _isSubmitting = true);

    final durationSecs = int.parse(_durationCtrl.text.trim());
    final isFeatured = _isReel ? false : _isFeatured;
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
            isFeatured: isFeatured,
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
            isFeatured: isFeatured,
          );
    }

    setState(() => _isSubmitting = false);
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> _startBunnyUpload() async {
    final file = _selectedVideo;
    if (file == null) return;

    setState(() {
      _isSubmitting = true;
      _videoSelectionError = null;
      _uploadTerminalStateHandled = false;
    });

    try {
      final session = await ref
          .read(bunnyStreamServiceProvider)
          .createVideo(title: _titleCtrl.text.trim(), thumbnailTime: 5000);

      if (session.libraryId.isNotEmpty) {
        unawaited(
          ref
              .read(appSettingsServiceProvider)
              .set(SettingKeys.bunnyLibraryId, session.libraryId),
        );
      }

      final draftId = await ref
          .read(adminProvider.notifier)
          .addBunnyVideoDraft(
            title: _titleCtrl.text,
            description: _descCtrl.text,
            thumbnailUrl: _thumbCtrl.text,
            playbackUrl: session.embedUrl.isNotEmpty
                ? session.embedUrl
                : session.playbackUrl,
            bunnyVideoId: session.videoId,
            genre: _genreCtrl.text,
            isFree: _isFree,
            isReel: _isReel,
          );

      if (!mounted) return;
      setState(() {
        _bunnyDraftId = draftId;
        _isSubmitting = false;
      });

      unawaited(
        ref
            .read(mediaUploadControllerProvider.notifier)
            .start(
              file: file,
              title: _titleCtrl.text.trim(),
              session: session,
              onComplete: _handleBunnyUploadComplete,
              onError: _handleBunnyUploadError,
            ),
      );
    } catch (error, stackTrace) {
      final message = _formatError(error);
      debugPrint('[AdminDashboardPage] Bunny upload setup failed: $message');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackBar('Could not start Bunny upload: $message');
      }
    }
  }

  Future<void> _handleBunnyUploadComplete() async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    final draftId = _bunnyDraftId;
    if (draftId == null) return;

    try {
      await ref
          .read(adminProvider.notifier)
          .updateBunnyMediaStatus(
            id: draftId,
            status: 'processing',
            processingProgress: 0,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload completed. Bunny is now processing the video.',
            ),
            backgroundColor: Color(0xFF21A45D),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      _uploadTerminalStateHandled = false;
      if (mounted) {
        _showErrorSnackBar(
          'Upload completed, but the processing status could not be saved: $error',
        );
      }
    }
  }

  Future<void> _handleBunnyUploadError(Object error) async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    final draftId = _bunnyDraftId;
    if (draftId != null) {
      try {
        await ref
            .read(adminProvider.notifier)
            .updateBunnyMediaStatus(
              id: draftId,
              status: 'failed',
              processingProgress: 0,
              error: error.toString(),
            );
      } catch (_) {
        // The upload error remains visible in the local progress card.
      }
    }
  }

  Future<void> _cancelBunnyUpload() async {
    _uploadTerminalStateHandled = true;
    await ref.read(mediaUploadControllerProvider.notifier).cancel();
    final draftId = _bunnyDraftId;
    if (draftId != null) {
      await ref
          .read(adminProvider.notifier)
          .updateBunnyMediaStatus(
            id: draftId,
            status: 'failed',
            processingProgress: 0,
            error: 'Upload cancelled by administrator',
          );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await pickVideoFile();
      if (file == null) return;

      final size = await file.length();
      if (!mounted) return;
      setState(() {
        _selectedVideo = file;
        _selectedVideoSize = size;
        _videoSelectionError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _videoSelectionError = 'Could not read video: $error');
      }
    }
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
    } finally {
      if (mounted && _isUploadingThumbnail) {
        setState(() => _isUploadingThumbnail = false);
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

class _MediaSourceButton extends StatelessWidget {
  const _MediaSourceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFFF05454)
        : (context.isDark ? Colors.white38 : context.textMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF05454).withValues(alpha: 0.12)
              : context.surfaceBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? (context.isDark ? Colors.white : const Color(0xFFF05454))
                      : context.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class BunnyVideoPicker extends StatelessWidget {
  const BunnyVideoPicker({
    required this.file,
    required this.fileSize,
    required this.error,
    required this.enabled,
    required this.onPick,
  });

  final XFile? file;
  final int? fileSize;
  final String? error;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFF05454)
                  : context.borderCol,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF05454).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.video_file_outlined,
                  color: Color(0xFFF05454),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: file == null
                    ? Text(
                        'MP4, MOV, WebM, MKV or AVI',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatFileSize(fileSize ?? 0),
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: enabled ? onPick : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textPrimary,
                  side: BorderSide(color: context.borderCol),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: Text(file == null ? 'Select Video' : 'Change'),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(color: Color(0xFFF05454), fontSize: 12),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          'The file uploads directly from this device to Bunny Stream.',
          style: TextStyle(color: context.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes bytes';
  }
}

typedef _BunnyVideoPicker = BunnyVideoPicker;

@visibleForTesting
class BunnyUploadProgressCard extends StatelessWidget {
  const BunnyUploadProgressCard({required this.state});

  final MediaUploadState state;

  @override
  Widget build(BuildContext context) {
    final visible = state.stage != MediaUploadStage.idle;
    if (!visible) return const SizedBox.shrink();

    final failed = state.stage == MediaUploadStage.failed;
    final cancelled = state.stage == MediaUploadStage.cancelled;
    final color = failed || cancelled
        ? const Color(0xFFF05454)
        : state.stage == MediaUploadStage.uploaded
        ? const Color(0xFF21A45D)
        : const Color(0xFFFFB44C);

    final label = switch (state.stage) {
      MediaUploadStage.idle => '',
      MediaUploadStage.uploading => 'Uploading to Bunny Stream',
      MediaUploadStage.paused => 'Upload paused',
      MediaUploadStage.uploaded => 'Upload complete — preparing processing',
      MediaUploadStage.cancelled => 'Upload cancelled',
      MediaUploadStage.failed => 'Upload failed',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed || cancelled
                    ? Icons.error_outline
                    : state.stage == MediaUploadStage.uploaded
                    ? Icons.check_circle_outline
                    : Icons.cloud_upload_outlined,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${state.progress.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.progress.clamp(0, 100) / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: context.borderCol,
          ),
          if (state.estimatedRemaining != null &&
              state.stage == MediaUploadStage.uploading) ...[
            const SizedBox(height: 8),
            Text(
              'Estimated time remaining: ${_formatDuration(state.estimatedRemaining!)}',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: const TextStyle(color: Color(0xFFF05454), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}

typedef _BunnyUploadProgressCard = BunnyUploadProgressCard;

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
          style: TextStyle(
            color: context.textSecondary,
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

@visibleForTesting
class AdminImageUploadField extends StatelessWidget {
  const AdminImageUploadField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.isUploading,
    required this.onUpload,
    this.validator,
    this.previewUnavailableText = 'Image preview unavailable',
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isUploading;
  final VoidCallback onUpload;
  final String? Function(String?)? validator;
  final String previewUnavailableText;

  @override
  Widget build(BuildContext context) {
    return _FormField(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _adminTextField(controller, hint, validator: validator),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.textPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    isUploading ? 'Uploading...' : 'Pick Image',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    disabledForegroundColor: context.textPrimary,
                    side: BorderSide(color: context.borderCol),
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
            style: TextStyle(color: context.textMuted, fontSize: 11),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final imageUrl = value.text.trim();
              if (imageUrl.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: context.elevatedBg,
                          alignment: Alignment.center,
                          child: Text(
                            previewUnavailableText,
                            style: TextStyle(color: context.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

typedef _AdminImageUploadField = AdminImageUploadField;

mixin _AdminImageUploadStateMixin<T extends StatefulWidget> on State<T> {
  Future<void> uploadImageToController({
    required TextEditingController controller,
    required void Function(bool value) setUploading,
    required String fieldLabel,
  }) async {
    try {
      setState(() => setUploading(true));

      final publicUrl = await _pickAndUploadAdminImage();
      if (!mounted) {
        return;
      }

      if (publicUrl == null) {
        setState(() => setUploading(false));
        return;
      }

      setState(() {
        controller.text = publicUrl;
        setUploading(false);
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      setState(() => setUploading(false));
      _showAdminImageUploadError(
        context: context,
        fieldLabel: fieldLabel,
        error: error,
        stackTrace: stackTrace,
      );
    }
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
              : context.surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : context.borderCol,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? activeColor : context.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : context.textMuted,
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

class _SeriesFormDialog extends ConsumerStatefulWidget {
  const _SeriesFormDialog({this.existing});

  final SeriesModel? existing;

  @override
  ConsumerState<_SeriesFormDialog> createState() => _SeriesFormDialogState();
}

class _SeriesFormDialogState extends ConsumerState<_SeriesFormDialog>
    with _AdminImageUploadStateMixin<_SeriesFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _posterCtrl;
  late final TextEditingController _backdropCtrl;
  late final TextEditingController _trailerCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _releaseDateCtrl;

  bool _isFree = true;
  bool _isFeatured = false;
  bool _isSubmitting = false;
  bool _isUploadingPoster = false;
  bool _isUploadingBackdrop = false;

  // Bunny upload state for series trailer
  _VideoMediaSource _trailerMediaSource = _VideoMediaSource.bunny;
  XFile? _selectedTrailerVideo;
  int? _selectedTrailerVideoSize;
  String? _trailerSelectionError;
  bool _uploadTerminalStateHandled = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _posterCtrl = TextEditingController(text: existing?.posterUrl ?? '');
    _backdropCtrl = TextEditingController(text: existing?.backdropUrl ?? '');
    _trailerCtrl = TextEditingController(text: existing?.trailerUrl ?? '');
    _genreCtrl = TextEditingController(text: existing?.genre ?? 'Drama');
    _taglineCtrl = TextEditingController(text: existing?.tagline ?? '');
    _releaseDateCtrl = TextEditingController(
      text: existing == null
          ? DateTime.now().toIso8601String().substring(0, 10)
          : existing.releaseDate.toIso8601String().substring(0, 10),
    );
    _isFree = existing != null ? !existing.requiresPremium : false;
    _isFeatured = existing?.isFeatured ?? false;

    if (existing != null && (existing.trailerUrl ?? '').isNotEmpty) {
      _trailerMediaSource = _VideoMediaSource.external;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _posterCtrl.dispose();
    _backdropCtrl.dispose();
    _trailerCtrl.dispose();
    _genreCtrl.dispose();
    _taglineCtrl.dispose();
    _releaseDateCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _pickTrailerVideo() async {
    try {
      final file = await pickVideoFile();
      if (file == null) return;

      final size = await file.length();
      if (!mounted) return;
      setState(() {
        _selectedTrailerVideo = file;
        _selectedTrailerVideoSize = size;
        _trailerSelectionError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _trailerSelectionError = 'Could not read video: $error');
      }
    }
  }

  Future<void> _startBunnyTrailerUpload() async {
    final file = _selectedTrailerVideo;
    if (file == null) return;

    setState(() {
      _isSubmitting = true;
      _trailerSelectionError = null;
      _uploadTerminalStateHandled = false;
    });

    try {
      final session = await ref.read(bunnyStreamServiceProvider).createVideo(
            title: '${_titleCtrl.text.trim()} (Trailer)',
            thumbnailTime: 1000,
          );

      if (session.libraryId.isNotEmpty) {
        unawaited(
          ref
              .read(appSettingsServiceProvider)
              .set(SettingKeys.bunnyLibraryId, session.libraryId),
        );
      }

      final playbackUrl = session.embedUrl.isNotEmpty
          ? session.embedUrl
          : session.playbackUrl;

      final notifier = ref.read(adminProvider.notifier);
      final success = widget.existing != null
          ? await notifier.updateSeries(
              id: widget.existing!.id,
              title: _titleCtrl.text,
              description: _descCtrl.text,
              posterUrl: _posterCtrl.text,
              backdropUrl: _backdropCtrl.text,
              trailerUrl: playbackUrl,
              genre: _genreCtrl.text,
              tagline: _taglineCtrl.text,
              releaseDate: _releaseDateCtrl.text,
              isFree: _isFree,
              isFeatured: _isFeatured,
            )
          : await notifier.addSeries(
              title: _titleCtrl.text,
              description: _descCtrl.text,
              posterUrl: _posterCtrl.text,
              backdropUrl: _backdropCtrl.text,
              trailerUrl: playbackUrl,
              genre: _genreCtrl.text,
              tagline: _taglineCtrl.text,
              releaseDate: _releaseDateCtrl.text,
              isFree: _isFree,
              isFeatured: _isFeatured,
            );

      if (!success) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      unawaited(
        ref
            .read(mediaUploadControllerProvider.notifier)
            .start(
              file: file,
              title: '${_titleCtrl.text.trim()} (Trailer)',
              session: session,
              onComplete: _handleTrailerUploadComplete,
              onError: _handleTrailerUploadError,
            ),
      );
    } catch (error, stackTrace) {
      final message = _formatError(error);
      debugPrint('[AdminDashboardPage] Bunny trailer upload setup failed: $message');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackBar('Could not start Bunny upload: $message');
      }
    }
  }

  Future<void> _handleTrailerUploadComplete() async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trailer upload completed. Bunny is now processing the video.',
          ),
          backgroundColor: Color(0xFF21A45D),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleTrailerUploadError(Object error) async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    if (mounted) {
      _showErrorSnackBar('Trailer upload failed: $error');
    }
  }

  Future<void> _cancelBunnyUpload() async {
    _uploadTerminalStateHandled = true;
    await ref.read(mediaUploadControllerProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final uploadState = ref.watch(mediaUploadControllerProvider);
    final uploadBusy = uploadState.isActive;

    return Dialog(
      backgroundColor: context.surfaceBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Series' : 'Add New Series',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary),
                      onPressed: uploadBusy ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),
                _FormField(
                  label: 'Title *',
                  child: _adminTextField(
                    _titleCtrl,
                    'Enter series title',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Tagline',
                  child: _adminTextField(
                    _taglineCtrl,
                    'Short hook for the series',
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Description',
                  child: _adminTextField(
                    _descCtrl,
                    'Enter series description',
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Genre',
                        child: _adminGenreDropdownField(
                          _genreCtrl,
                          hint: 'Select genre',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label: 'Release Date (YYYY-MM-DD)',
                        child: _adminTextField(
                          _releaseDateCtrl,
                          '2026-01-18',
                          validator: _requiredField,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AdminImageUploadField(
                  label: 'Poster URL *',
                  controller: _posterCtrl,
                  hint: 'https://...poster.jpg',
                  validator: _requiredField,
                  isUploading: _isUploadingPoster,
                  onUpload: () => uploadImageToController(
                    controller: _posterCtrl,
                    setUploading: (value) => _isUploadingPoster = value,
                    fieldLabel: 'Poster',
                  ),
                  previewUnavailableText: 'Poster preview unavailable',
                ),
                const SizedBox(height: 14),
                _AdminImageUploadField(
                  label: 'Backdrop URL',
                  controller: _backdropCtrl,
                  hint: 'https://...backdrop.jpg',
                  isUploading: _isUploadingBackdrop,
                  onUpload: () => uploadImageToController(
                    controller: _backdropCtrl,
                    setUploading: (value) => _isUploadingBackdrop = value,
                    fieldLabel: 'Backdrop',
                  ),
                  previewUnavailableText: 'Backdrop preview unavailable',
                ),
                const SizedBox(height: 14),

                // Trailer Media Source toggle
                _FormField(
                  label: 'Trailer Media Source',
                  child: Row(
                    children: [
                      Expanded(
                        child: _MediaSourceButton(
                          label: 'Bunny Stream',
                          icon: Icons.cloud_upload_outlined,
                          selected: _trailerMediaSource == _VideoMediaSource.bunny,
                          onTap: uploadBusy
                              ? null
                              : () => setState(() {
                                  _trailerMediaSource = _VideoMediaSource.bunny;
                                  _trailerSelectionError = null;
                                }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaSourceButton(
                          label: 'External URL',
                          icon: Icons.link,
                          selected: _trailerMediaSource == _VideoMediaSource.external,
                          onTap: uploadBusy
                              ? null
                              : () => setState(() {
                                  _trailerMediaSource = _VideoMediaSource.external;
                                  _trailerSelectionError = null;
                                }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Trailer Video Picker or URL
                if (_trailerMediaSource == _VideoMediaSource.bunny)
                  _FormField(
                    label: 'Trailer Video (Optional)',
                    child: _BunnyVideoPicker(
                      file: _selectedTrailerVideo,
                      fileSize: _selectedTrailerVideoSize,
                      error: _trailerSelectionError,
                      enabled: !uploadBusy && !_isSubmitting,
                      onPick: _pickTrailerVideo,
                    ),
                  )
                else
                  _FormField(
                    label: 'Trailer URL (Optional)',
                    child: _adminTextField(
                      _trailerCtrl,
                      'https://...trailer.mp4',
                    ),
                  ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _ToggleChip(
                      label: 'Free Entry',
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
                    Row(
                      children: [
                        Checkbox(
                          value: _isFeatured,
                          onChanged: (value) =>
                              setState(() => _isFeatured = value ?? false),
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
                if (_trailerMediaSource == _VideoMediaSource.bunny && _selectedTrailerVideo != null) ...[
                  const SizedBox(height: 16),
                  _BunnyUploadProgressCard(state: uploadState),
                ],
                const SizedBox(height: 24),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting || uploadBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ),
                    if (uploadState.stage == MediaUploadStage.uploading) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .pause(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Pause'),
                      ),
                    ],
                    if (uploadState.stage == MediaUploadStage.paused) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .resume(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Resume'),
                      ),
                    ],
                    if (uploadBusy) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _cancelBunnyUpload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Cancel Upload'),
                      ),
                    ],
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting || uploadBusy ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(isEdit ? 'Save Changes' : 'Add Series'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_trailerMediaSource == _VideoMediaSource.bunny && _selectedTrailerVideo != null) {
      await _startBunnyTrailerUpload();
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(adminProvider.notifier);
    final success = widget.existing != null
        ? await notifier.updateSeries(
            id: widget.existing!.id,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            posterUrl: _posterCtrl.text,
            backdropUrl: _backdropCtrl.text,
            trailerUrl: _trailerCtrl.text,
            genre: _genreCtrl.text,
            tagline: _taglineCtrl.text,
            releaseDate: _releaseDateCtrl.text,
            isFree: _isFree,
            isFeatured: _isFeatured,
          )
        : await notifier.addSeries(
            title: _titleCtrl.text,
            description: _descCtrl.text,
            posterUrl: _posterCtrl.text,
            backdropUrl: _backdropCtrl.text,
            trailerUrl: _trailerCtrl.text,
            genre: _genreCtrl.text,
            tagline: _taglineCtrl.text,
            releaseDate: _releaseDateCtrl.text,
            isFree: _isFree,
            isFeatured: _isFeatured,
          );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _SeriesStructureDialog extends ConsumerStatefulWidget {
  const _SeriesStructureDialog({required this.series});

  final SeriesModel series;

  @override
  ConsumerState<_SeriesStructureDialog> createState() =>
      _SeriesStructureDialogState();
}

class _SeriesStructureDialogState
    extends ConsumerState<_SeriesStructureDialog> {
  List<SeriesSeasonModel> _seasons = const [];
  List<SeriesEpisodeModel> _episodes = const [];
  String? _selectedSeasonId;
  bool _loadingSeasons = true;
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSeasons());
  }

  @override
  Widget build(BuildContext context) {
    final selectedSeason = _seasons
        .where((season) => season.id == _selectedSeasonId)
        .firstOrNull;

    return Dialog(
      backgroundColor: context.surfaceBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 920,
        height: 700,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.series.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage seasons and episodes',
                          style: TextStyle(color: context.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddSeason,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F9DCC),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Season'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.borderCol),
              const SizedBox(height: 16),
              if (_loadingSeasons)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFF05454)),
                  ),
                )
              else ...[
                Text(
                  'Seasons',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _seasons
                      .map((season) {
                        final selected = season.id == _selectedSeasonId;
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(
                                    0xFF1F9DCC,
                                  ).withValues(alpha: 0.18)
                                : context.surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF1F9DCC)
                                  : context.borderCol,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _selectSeason(season.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Text(
                                    'S${season.seasonNumber} • ${season.episodeCount} eps',
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFF1F9DCC)
                                          : context.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showEditSeason(season),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: context.textSecondary,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                onPressed: () => _deleteSeason(season),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Color(0xFFF05454),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      selectedSeason == null
                          ? 'Episodes'
                          : 'Episodes for Season ${selectedSeason.seasonNumber}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: selectedSeason == null
                          ? null
                          : () => _showAddEpisode(selectedSeason),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Episode'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loadingEpisodes
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFF05454),
                          ),
                        )
                      : selectedSeason == null
                      ? Center(
                          child: Text(
                            'Add a season to start managing episodes',
                            style: TextStyle(color: context.textMuted),
                          ),
                        )
                      : _episodes.isEmpty
                      ? Center(
                          child: Text(
                            'No episodes in this season yet',
                            style: TextStyle(color: context.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _episodes.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final episode = _episodes[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: context.surfaceBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.borderCol,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: context.elevatedBg,
                                  child: Text(
                                    episode.episodeNumber.toString(),
                                    style: TextStyle(color: context.textPrimary),
                                  ),
                                ),
                                title: Text(
                                  episode.title,
                                  style: TextStyle(color: context.textPrimary),
                                ),
                                subtitle: Text(
                                  '${episode.duration ~/ 60} min • ${episode.requiresPremium ? 'Premium' : 'Free'}',
                                  style: TextStyle(color: context.textSecondary),
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showEditEpisode(
                                        selectedSeason,
                                        episode,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Color(0xFF1F9DCC),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteEpisode(episode),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Color(0xFFF05454),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSeasons() async {
    setState(() => _loadingSeasons = true);
    final seasons = await ref
        .read(adminProvider.notifier)
        .loadSeriesSeasons(widget.series.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _seasons = seasons;
      _loadingSeasons = false;
      _selectedSeasonId = seasons.isEmpty
          ? null
          : (_selectedSeasonId ?? seasons.first.id);
    });

    if (_selectedSeasonId != null) {
      await _loadEpisodes(_selectedSeasonId!);
    }
  }

  Future<void> _loadEpisodes(String seasonId) async {
    setState(() => _loadingEpisodes = true);
    final episodes = await ref
        .read(adminProvider.notifier)
        .loadSeasonEpisodes(seasonId);
    if (!mounted) {
      return;
    }

    setState(() {
      _episodes = episodes;
      _loadingEpisodes = false;
    });
  }

  Future<void> _selectSeason(String seasonId) async {
    setState(() {
      _selectedSeasonId = seasonId;
    });
    await _loadEpisodes(seasonId);
  }

  Future<void> _showAddSeason() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => _SeasonFormDialog(seriesId: widget.series.id),
    );
    if (success == true) {
      await _loadSeasons();
    }
  }

  Future<void> _showEditSeason(SeriesSeasonModel season) async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _SeasonFormDialog(seriesId: widget.series.id, existing: season),
    );
    if (success == true) {
      await _loadSeasons();
    }
  }

  Future<void> _deleteSeason(SeriesSeasonModel season) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.surfaceBg,
        title: Text(
          'Delete Season',
          style: TextStyle(color: dialogCtx.textPrimary),
        ),
        content: Text(
          'Delete Season ${season.seasonNumber} and all its episodes?',
          style: TextStyle(color: dialogCtx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogCtx.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05454),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(adminProvider.notifier)
        .deleteSeason(season.id);
    if (success) {
      await _loadSeasons();
    }
  }

  Future<void> _showAddEpisode(SeriesSeasonModel? season) async {
    if (season == null) {
      return;
    }
    final success = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EpisodeFormDialog(seriesId: widget.series.id, season: season),
    );
    if (success == true) {
      await _loadSeasons();
      await _loadEpisodes(season.id);
    }
  }

  Future<void> _showEditEpisode(
    SeriesSeasonModel? season,
    SeriesEpisodeModel episode,
  ) async {
    if (season == null) {
      return;
    }
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => _EpisodeFormDialog(
        seriesId: widget.series.id,
        season: season,
        existing: episode,
      ),
    );
    if (success == true) {
      await _loadSeasons();
      await _loadEpisodes(season.id);
    }
  }

  Future<void> _deleteEpisode(SeriesEpisodeModel episode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.surfaceBg,
        title: Text(
          'Delete Episode',
          style: TextStyle(color: dialogCtx.textPrimary),
        ),
        content: Text(
          'Delete "${episode.title}"?',
          style: TextStyle(color: dialogCtx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogCtx.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05454),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(adminProvider.notifier)
        .deleteEpisode(episode.id);
    if (success && _selectedSeasonId != null) {
      await _loadSeasons();
      await _loadEpisodes(_selectedSeasonId!);
    }
  }
}

class _SeasonFormDialog extends ConsumerStatefulWidget {
  const _SeasonFormDialog({required this.seriesId, this.existing});

  final String seriesId;
  final SeriesSeasonModel? existing;

  @override
  ConsumerState<_SeasonFormDialog> createState() => _SeasonFormDialogState();
}

class _SeasonFormDialogState extends ConsumerState<_SeasonFormDialog>
    with _AdminImageUploadStateMixin<_SeasonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seasonNumberCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _posterCtrl;
  late final TextEditingController _releaseDateCtrl;
  bool _isSubmitting = false;
  bool _isUploadingPoster = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _seasonNumberCtrl = TextEditingController(
      text: existing?.seasonNumber.toString() ?? '1',
    );
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    _posterCtrl = TextEditingController(text: existing?.posterUrl ?? '');
    _releaseDateCtrl = TextEditingController(
      text:
          existing?.releaseDate?.toIso8601String().substring(0, 10) ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
  }

  @override
  void dispose() {
    _seasonNumberCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _posterCtrl.dispose();
    _releaseDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.surfaceBg,
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null ? 'Add Season' : 'Edit Season',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _FormField(
                  label: 'Season Number *',
                  child: _adminTextField(
                    _seasonNumberCtrl,
                    '1',
                    keyboardType: TextInputType.number,
                    validator: _positiveNumberField,
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Title',
                  child: _adminTextField(_titleCtrl, 'Season 1'),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Description',
                  child: _adminTextField(
                    _descriptionCtrl,
                    'Season description',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),
                _AdminImageUploadField(
                  label: 'Poster URL',
                  controller: _posterCtrl,
                  hint: 'https://...season.jpg',
                  isUploading: _isUploadingPoster,
                  onUpload: () => uploadImageToController(
                    controller: _posterCtrl,
                    setUploading: (value) => _isUploadingPoster = value,
                    fieldLabel: 'Season poster',
                  ),
                  previewUnavailableText: 'Season poster preview unavailable',
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Release Date *',
                  child: _adminTextField(
                    _releaseDateCtrl,
                    '2026-01-18',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F9DCC),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.existing == null
                                  ? 'Add Season'
                                  : 'Save Season',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(adminProvider.notifier);
    final success = widget.existing == null
        ? await notifier.addSeason(
            seriesId: widget.seriesId,
            seasonNumber: int.parse(_seasonNumberCtrl.text.trim()),
            title: _titleCtrl.text,
            description: _descriptionCtrl.text,
            posterUrl: _posterCtrl.text,
            releaseDate: _releaseDateCtrl.text,
          )
        : await notifier.updateSeason(
            id: widget.existing!.id,
            seasonNumber: int.parse(_seasonNumberCtrl.text.trim()),
            title: _titleCtrl.text,
            description: _descriptionCtrl.text,
            posterUrl: _posterCtrl.text,
            releaseDate: _releaseDateCtrl.text,
          );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(success);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EPISODE MEDIA SOURCE
// ─────────────────────────────────────────────────────────────────────────────

enum _EpisodeMediaSource { bunny, external }

// ─────────────────────────────────────────────────────────────────────────────
// EPISODE FORM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeFormDialog extends ConsumerStatefulWidget {
  const _EpisodeFormDialog({
    required this.seriesId,
    required this.season,
    this.existing,
  });

  final String seriesId;
  final SeriesSeasonModel season;
  final SeriesEpisodeModel? existing;

  @override
  ConsumerState<_EpisodeFormDialog> createState() => _EpisodeFormDialogState();
}

class _EpisodeFormDialogState extends ConsumerState<_EpisodeFormDialog>
    with _AdminImageUploadStateMixin<_EpisodeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _episodeNumberCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _thumbnailCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _releaseDateCtrl;

  bool _isFree = false;
  bool _isSubmitting = false;
  bool _isUploadingThumbnail = false;

  // Bunny upload state
  _EpisodeMediaSource _mediaSource = _EpisodeMediaSource.bunny;
  XFile? _selectedVideo;
  int? _selectedVideoSize;
  String? _videoSelectionError;
  String? _bunnyDraftId;
  bool _uploadTerminalStateHandled = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _episodeNumberCtrl = TextEditingController(
      text: existing?.episodeNumber.toString() ?? '1',
    );
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    _thumbnailCtrl = TextEditingController(text: existing?.thumbnailUrl ?? '');
    _thumbnailCtrl.addListener(_handleThumbnailChanged);
    _videoUrlCtrl = TextEditingController(text: existing?.videoUrl ?? '');
    _durationCtrl = TextEditingController(
      text: existing?.duration != null && existing!.duration > 0
          ? existing.duration.toString()
          : '',
    );
    _releaseDateCtrl = TextEditingController(
      text:
          existing?.releaseDate?.toIso8601String().substring(0, 10) ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    _isFree = existing != null ? !existing.requiresPremium : false;
    // Existing episodes with a Bunny provider default to external URL on edit
    // since we don't support re-uploading from the edit dialog.
    if (existing != null) {
      _mediaSource = _EpisodeMediaSource.external;
    }
  }

  void _handleThumbnailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _thumbnailCtrl.removeListener(_handleThumbnailChanged);
    _episodeNumberCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _thumbnailCtrl.dispose();
    _videoUrlCtrl.dispose();
    _durationCtrl.dispose();
    _releaseDateCtrl.dispose();
    super.dispose();
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

  String _formatError(Object error) {
    if (error is StorageException) {
      return 'StorageException: ${error.message}';
    }
    if (error is PostgrestException) {
      return 'PostgrestException: ${error.message}';
    }
    return '${error.runtimeType}: $error';
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(mediaUploadControllerProvider);
    final uploadBusy = uploadState.isActive;

    return Dialog(
      backgroundColor: context.surfaceBg,
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
                      _isEdit
                          ? 'Edit Episode'
                          : 'Add Episode to Season ${widget.season.seasonNumber}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary),
                      onPressed: uploadBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),

                // Media source toggle (add only)
                if (!_isEdit) ...[
                  _FormField(
                    label: 'Media Source',
                    child: Row(
                      children: [
                        Expanded(
                          child: _MediaSourceButton(
                            label: 'Bunny Stream',
                            icon: Icons.cloud_upload_outlined,
                            selected:
                                _mediaSource == _EpisodeMediaSource.bunny,
                            onTap: uploadBusy
                                ? null
                                : () => setState(() {
                                    _mediaSource = _EpisodeMediaSource.bunny;
                                    _videoSelectionError = null;
                                  }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MediaSourceButton(
                            label: 'External URL',
                            icon: Icons.link,
                            selected:
                                _mediaSource == _EpisodeMediaSource.external,
                            onTap: uploadBusy
                                ? null
                                : () => setState(() {
                                    _mediaSource = _EpisodeMediaSource.external;
                                    _videoSelectionError = null;
                                  }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Episode number + duration row
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Episode Number *',
                        child: _adminTextField(
                          _episodeNumberCtrl,
                          '1',
                          keyboardType: TextInputType.number,
                          validator: _positiveNumberField,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label: !_isEdit &&
                                _mediaSource == _EpisodeMediaSource.bunny
                            ? 'Duration (from Bunny)'
                            : 'Duration (seconds) *',
                        child: _adminTextField(
                          _durationCtrl,
                          '2700',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!_isEdit &&
                                _mediaSource == _EpisodeMediaSource.bunny &&
                                (v == null || v.trim().isEmpty)) {
                              return null; // Optional for Bunny uploads
                            }
                            return _positiveNumberField(v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                _FormField(
                  label: 'Title *',
                  child: _adminTextField(
                    _titleCtrl,
                    'Episode title',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                _FormField(
                  label: 'Description',
                  child: _adminTextField(
                    _descriptionCtrl,
                    'Episode description',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),

                // Thumbnail
                _AdminImageUploadField(
                  label: _mediaSource == _EpisodeMediaSource.bunny && !_isEdit
                      ? 'Thumbnail (optional)'
                      : 'Thumbnail URL *',
                  controller: _thumbnailCtrl,
                  hint: 'https://...episode.jpg',
                  validator: _mediaSource == _EpisodeMediaSource.bunny &&
                          !_isEdit
                      ? null
                      : _requiredField,
                  isUploading: _isUploadingThumbnail,
                  onUpload: () => uploadImageToController(
                    controller: _thumbnailCtrl,
                    setUploading: (value) => _isUploadingThumbnail = value,
                    fieldLabel: 'Episode thumbnail',
                  ),
                  previewUnavailableText:
                      'Episode thumbnail preview unavailable',
                ),
                const SizedBox(height: 14),

                // Video — Bunny picker or URL field
                if (_mediaSource == _EpisodeMediaSource.bunny && !_isEdit)
                  _FormField(
                    label: 'Video File *',
                    child: _BunnyVideoPicker(
                      file: _selectedVideo,
                      fileSize: _selectedVideoSize,
                      error: _videoSelectionError,
                      enabled: !uploadBusy && !_isSubmitting,
                      onPick: _pickVideo,
                    ),
                  )
                else
                  _FormField(
                    label: 'Video URL *',
                    child: _adminTextField(
                      _videoUrlCtrl,
                      'https://...episode.mp4',
                      validator: _requiredField,
                    ),
                  ),
                const SizedBox(height: 14),

                // Release date
                _FormField(
                  label: 'Release Date *',
                  child: _adminTextField(
                    _releaseDateCtrl,
                    '2026-01-18',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 20),

                // Free / Premium toggle
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
                  ],
                ),

                // Bunny upload progress card (add + Bunny only)
                if (_mediaSource == _EpisodeMediaSource.bunny && !_isEdit) ...[
                  const SizedBox(height: 20),
                  _BunnyUploadProgressCard(state: uploadState),
                ],

                const SizedBox(height: 20),
                Divider(color: context.borderCol),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting || uploadBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ),
                    if (uploadState.stage == MediaUploadStage.uploading) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .pause(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Pause'),
                      ),
                    ],
                    if (uploadState.stage == MediaUploadStage.paused) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(mediaUploadControllerProvider.notifier)
                            .resume(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Resume'),
                      ),
                    ],
                    if (uploadBusy) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _cancelBunnyUpload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          side: BorderSide(color: context.borderCol),
                        ),
                        child: const Text('Cancel Upload'),
                      ),
                    ],
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
                      onPressed: _isSubmitting || uploadBusy ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isEdit
                                  ? 'Save Episode'
                                  : _mediaSource == _EpisodeMediaSource.bunny
                                  ? 'Upload Episode'
                                  : 'Add Episode',
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

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEdit &&
        _mediaSource == _EpisodeMediaSource.bunny &&
        _selectedVideo == null) {
      setState(() => _videoSelectionError = 'Select a video file');
      return;
    }

    if (!_isEdit && _mediaSource == _EpisodeMediaSource.bunny) {
      await _startBunnyUpload();
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(adminProvider.notifier);
    final success = _isEdit
        ? await notifier.updateEpisode(
            id: widget.existing!.id,
            episodeNumber: int.parse(_episodeNumberCtrl.text.trim()),
            title: _titleCtrl.text,
            description: _descriptionCtrl.text,
            thumbnailUrl: _thumbnailCtrl.text,
            videoUrl: _videoUrlCtrl.text,
            durationSeconds: int.parse(_durationCtrl.text.trim()),
            isFree: _isFree,
            releaseDate: _releaseDateCtrl.text,
          )
        : await notifier.addEpisode(
            seriesId: widget.seriesId,
            seasonId: widget.season.id,
            episodeNumber: int.parse(_episodeNumberCtrl.text.trim()),
            title: _titleCtrl.text,
            description: _descriptionCtrl.text,
            thumbnailUrl: _thumbnailCtrl.text,
            videoUrl: _videoUrlCtrl.text,
            durationSeconds: int.parse(_durationCtrl.text.trim()),
            isFree: _isFree,
            releaseDate: _releaseDateCtrl.text,
          );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(success);
    }
  }

  Future<void> _startBunnyUpload() async {
    final file = _selectedVideo;
    if (file == null) return;

    setState(() {
      _isSubmitting = true;
      _videoSelectionError = null;
      _uploadTerminalStateHandled = false;
    });

    try {
      final session = await ref
          .read(bunnyStreamServiceProvider)
          .createVideo(title: _titleCtrl.text.trim(), thumbnailTime: 5000);

      if (session.libraryId.isNotEmpty) {
        unawaited(
          ref
              .read(appSettingsServiceProvider)
              .set(SettingKeys.bunnyLibraryId, session.libraryId),
        );
      }

      final draftId = await ref
          .read(adminProvider.notifier)
          .addBunnyEpisodeDraft(
            seriesId: widget.seriesId,
            seasonId: widget.season.id,
            episodeNumber: int.parse(_episodeNumberCtrl.text.trim()),
            title: _titleCtrl.text,
            description: _descriptionCtrl.text,
            thumbnailUrl: _thumbnailCtrl.text,
            playbackUrl: session.embedUrl.isNotEmpty
                ? session.embedUrl
                : session.playbackUrl,
            bunnyVideoId: session.videoId,
            isFree: _isFree,
            releaseDate: _releaseDateCtrl.text,
          );

      if (!mounted) return;
      setState(() {
        _bunnyDraftId = draftId;
        _isSubmitting = false;
      });

      unawaited(
        ref
            .read(mediaUploadControllerProvider.notifier)
            .start(
              file: file,
              title: _titleCtrl.text.trim(),
              session: session,
              onComplete: _handleBunnyUploadComplete,
              onError: _handleBunnyUploadError,
            ),
      );
    } catch (error, stackTrace) {
      final message = _formatError(error);
      debugPrint('[EpisodeFormDialog] Bunny upload setup failed: $message');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackBar('Could not start Bunny upload: $message');
      }
    }
  }

  Future<void> _handleBunnyUploadComplete() async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    final draftId = _bunnyDraftId;
    if (draftId == null) return;

    try {
      await ref
          .read(adminProvider.notifier)
          .updateBunnyEpisodeStatus(
            id: draftId,
            status: 'processing',
            processingProgress: 0,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload completed. Bunny is now processing the episode.',
            ),
            backgroundColor: Color(0xFF21A45D),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _uploadTerminalStateHandled = false;
      if (mounted) {
        _showErrorSnackBar(
          'Upload completed, but processing status could not be saved: $error',
        );
      }
    }
  }

  Future<void> _handleBunnyUploadError(Object error) async {
    if (_uploadTerminalStateHandled) return;
    _uploadTerminalStateHandled = true;
    final draftId = _bunnyDraftId;
    if (draftId != null) {
      try {
        await ref
            .read(adminProvider.notifier)
            .updateBunnyEpisodeStatus(
              id: draftId,
              status: 'failed',
              processingProgress: 0,
              error: error.toString(),
            );
      } catch (_) {
        // Upload error remains visible in the local progress card.
      }
    }
  }

  Future<void> _cancelBunnyUpload() async {
    _uploadTerminalStateHandled = true;
    await ref.read(mediaUploadControllerProvider.notifier).cancel();
    final draftId = _bunnyDraftId;
    if (draftId != null) {
      await ref
          .read(adminProvider.notifier)
          .updateBunnyEpisodeStatus(
            id: draftId,
            status: 'failed',
            processingProgress: 0,
            error: 'Upload cancelled by administrator',
          );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await pickVideoFile();
      if (file == null) return;
      final size = await file.length();
      if (!mounted) return;
      setState(() {
        _selectedVideo = file;
        _selectedVideoSize = size;
        _videoSelectionError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _videoSelectionError = 'Could not read video: $error');
      }
    }
  }
}




Widget _adminTextField(
  TextEditingController ctrl,
  String hint, {
  int maxLines = 1,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return Builder(
    builder: (context) {
      return TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: _adminFieldDecoration(hint, context),
      );
    },
  );
}

String? _requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

String? _positiveNumberField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  final parsedValue = int.tryParse(value.trim());
  if (parsedValue == null) {
    return 'Must be a number';
  }
  if (parsedValue <= 0) {
    return 'Must be greater than 0';
  }
  return null;
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
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
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
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderCol),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
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
                                    color: context.textMuted,
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
                                    color: context.textMuted,
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
                                    color: context.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: context.borderCol, height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, _) => Divider(
                              color: context.borderCol,
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
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        u['username'] ?? '-',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Switch(
                                        value: isAdmin,
                                        activeThumbColor: const Color(0xFFFFB44C),
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

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SECTION (Enterprise OTT Platform Configuration)
// ─────────────────────────────────────────────────────────────────────────────

enum _SettingsTab {
  branding,
  playback,
  features,
  legal,
  infrastructure,
}

@visibleForTesting
class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

// Backward-compatible alias
typedef _SettingsSection = SettingsSection;

class _SettingsSectionState extends ConsumerState<SettingsSection>
    with _AdminImageUploadStateMixin<SettingsSection> {
  _SettingsTab _activeTab = _SettingsTab.branding;

  late final TextEditingController _appNameController;
  late final TextEditingController _appTaglineController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _faviconUrlController;
  late final TextEditingController _platformNoticeController;
  late final TextEditingController _supportEmailController;
  late final TextEditingController _termsUrlController;
  late final TextEditingController _privacyUrlController;
  late final TextEditingController _copyrightController;
  late final TextEditingController _bunnyPullZoneController;

  String _defaultStreamQuality = '720p HD';
  String _freeTierMaxQuality = '720p HD';
  String _premiumTierMaxQuality = '1080p Full HD';
  String _bufferProfile = 'Standard (Balanced)';
  bool _autoplayNextEpisode = true;
  bool _autoplayHeroTrailers = true;
  bool _enableReels = true;
  bool _enableReviews = true;

  bool _uploadingLogo = false;
  bool _uploadingFavicon = false;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  static const _qualityOptions = [
    'Auto (Adaptive Bitrate)',
    '4K Ultra HD',
    '1080p Full HD',
    '720p HD',
    '480p SD',
    '360p Low',
  ];

  static const _bufferOptions = [
    'Standard (Balanced)',
    'Aggressive Preload (Fast Start)',
    'Data Saver (Low Bandwidth)',
  ];

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController();
    _appTaglineController = TextEditingController();
    _logoUrlController = TextEditingController();
    _faviconUrlController = TextEditingController();
    _platformNoticeController = TextEditingController();
    _supportEmailController = TextEditingController();
    _termsUrlController = TextEditingController();
    _privacyUrlController = TextEditingController();
    _copyrightController = TextEditingController();
    _bunnyPullZoneController = TextEditingController();

    _appNameController.addListener(_onFieldChanged);
    _appTaglineController.addListener(_onFieldChanged);
    _logoUrlController.addListener(_onFieldChanged);
    _faviconUrlController.addListener(_onFieldChanged);

    _loadSettings();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _appNameController.removeListener(_onFieldChanged);
    _appTaglineController.removeListener(_onFieldChanged);
    _logoUrlController.removeListener(_onFieldChanged);
    _faviconUrlController.removeListener(_onFieldChanged);

    _appNameController.dispose();
    _appTaglineController.dispose();
    _logoUrlController.dispose();
    _faviconUrlController.dispose();
    _platformNoticeController.dispose();
    _supportEmailController.dispose();
    _termsUrlController.dispose();
    _privacyUrlController.dispose();
    _copyrightController.dispose();
    _bunnyPullZoneController.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final settings = await ref.read(allSettingsProvider.future);
      _appNameController.text =
          settings[SettingKeys.appName] ?? AppStrings.appName;
      _appTaglineController.text =
          settings[SettingKeys.appTagline] ??
          'Stream unlimited movies, series, and exclusive originals';
      _logoUrlController.text = settings[SettingKeys.appLogoUrl] ?? '';
      _faviconUrlController.text = settings[SettingKeys.appFaviconUrl] ?? '';
      _platformNoticeController.text =
          settings[SettingKeys.platformNotice] ?? '';
      _supportEmailController.text = settings[SettingKeys.supportEmail] ?? '';
      _termsUrlController.text = settings[SettingKeys.termsUrl] ?? '';
      _privacyUrlController.text = settings[SettingKeys.privacyUrl] ?? '';
      _copyrightController.text =
          settings[SettingKeys.copyrightText] ??
          '© ${DateTime.now().year} ${settings[SettingKeys.appName] ?? AppStrings.appName}. All rights reserved.';
      _bunnyPullZoneController.text =
          settings[SettingKeys.bunnyPullZone] ?? '';

      if (settings.containsKey(SettingKeys.freeTierMaxQuality) &&
          _qualityOptions.contains(settings[SettingKeys.freeTierMaxQuality])) {
        _freeTierMaxQuality = settings[SettingKeys.freeTierMaxQuality]!;
      } else if (settings.containsKey(SettingKeys.defaultStreamQuality) &&
          _qualityOptions.contains(settings[SettingKeys.defaultStreamQuality])) {
        _freeTierMaxQuality = settings[SettingKeys.defaultStreamQuality]!;
      }
      if (settings.containsKey(SettingKeys.premiumTierMaxQuality) &&
          _qualityOptions.contains(settings[SettingKeys.premiumTierMaxQuality])) {
        _premiumTierMaxQuality = settings[SettingKeys.premiumTierMaxQuality]!;
      }
      _defaultStreamQuality = _freeTierMaxQuality;
      if (settings.containsKey(SettingKeys.bufferProfile) &&
          _bufferOptions.contains(settings[SettingKeys.bufferProfile])) {
        _bufferProfile = settings[SettingKeys.bufferProfile]!;
      }
      if (settings.containsKey(SettingKeys.autoplayNextEpisode)) {
        _autoplayNextEpisode =
            settings[SettingKeys.autoplayNextEpisode] == 'true';
      }
      if (settings.containsKey(SettingKeys.autoplayHeroTrailers)) {
        _autoplayHeroTrailers =
            settings[SettingKeys.autoplayHeroTrailers] == 'true';
      }
      if (settings.containsKey(SettingKeys.enableReels)) {
        _enableReels = settings[SettingKeys.enableReels] != 'false';
      }
      if (settings.containsKey(SettingKeys.enableReviews)) {
        _enableReviews = settings[SettingKeys.enableReviews] != 'false';
      }
    } catch (e) {
      debugPrint('Failed to load platform settings: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final service = ref.read(appSettingsServiceProvider);
      final cleanName = _appNameController.text.trim();
      final updates = <String, String>{
        SettingKeys.appName: cleanName.isEmpty ? AppStrings.appName : cleanName,
        SettingKeys.appTagline: _appTaglineController.text.trim(),
        SettingKeys.appLogoUrl: _logoUrlController.text.trim(),
        SettingKeys.appFaviconUrl: _faviconUrlController.text.trim(),
        SettingKeys.freeTierMaxQuality: _freeTierMaxQuality,
        SettingKeys.premiumTierMaxQuality: _premiumTierMaxQuality,
        SettingKeys.defaultStreamQuality: _freeTierMaxQuality,
        SettingKeys.bufferProfile: _bufferProfile,
        SettingKeys.bunnyPullZone: _bunnyPullZoneController.text.trim(),
        SettingKeys.autoplayNextEpisode: _autoplayNextEpisode.toString(),
        SettingKeys.autoplayHeroTrailers: _autoplayHeroTrailers.toString(),
        SettingKeys.enableReels: _enableReels.toString(),
        SettingKeys.enableReviews: _enableReviews.toString(),
        SettingKeys.platformNotice: _platformNoticeController.text.trim(),
        SettingKeys.supportEmail: _supportEmailController.text.trim(),
        SettingKeys.termsUrl: _termsUrlController.text.trim(),
        SettingKeys.privacyUrl: _privacyUrlController.text.trim(),
        SettingKeys.copyrightText: _copyrightController.text.trim(),
      };

      await service.setAll(updates);
      ref.invalidate(allSettingsProvider);

      if (mounted) {
        setState(() {
          _saving = false;
          _message =
              'Platform settings successfully saved! Changes are live across all viewer sessions.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Platform configuration saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = 'Error saving platform settings: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFF05454)),
            const SizedBox(height: 16),
            Text(
              'Loading platform configuration...',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Strip
          _buildHeader(),
          const SizedBox(height: 20),

          // 2. Executive Stat / Status Cards
          _buildOverviewMetrics(),
          const SizedBox(height: 24),

          // 3. Segmented Tab Selector
          _buildTabSelector(),
          const SizedBox(height: 24),

          // 4. Tab Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildActiveTabContent(),
          ),
          const SizedBox(height: 28),

          // 5. Bottom Save Action Bar
          _buildSaveBar(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Platform Configuration & Policies',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Production Live',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configure global streaming branding, player engine defaults, feature modules, and compliance policies.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewMetrics() {
    final currentName = _appNameController.text.trim().isNotEmpty
        ? _appNameController.text.trim()
        : AppStrings.appName;
    final hasLogo = _logoUrlController.text.trim().isNotEmpty;
    final hasFavicon = _faviconUrlController.text.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final cardWidth = isNarrow
            ? double.infinity
            : (constraints.maxWidth - 32) / 3;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Platform Identity',
                value: currentName,
                subtitle:
                    'Logo: ${hasLogo ? 'Custom' : 'Default'} • Favicon: ${hasFavicon ? 'Custom' : 'Default'}',
                icon: Icons.branding_watermark_rounded,
                accentColor: const Color(0xFF38BDF8),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Stream Delivery Profile',
                value: 'Free: $_freeTierMaxQuality • VIP: $_premiumTierMaxQuality',
                subtitle: 'Bunny Stream Tier-Capped HLS Engine Active',
                icon: Icons.live_tv_rounded,
                accentColor: const Color(0xFFF05454),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Security Architecture',
                value: 'Server-Side Vault',
                subtitle: 'Crypto & CDN Keys Isolated in Supabase',
                icon: Icons.security_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTabButton(
          tab: _SettingsTab.branding,
          label: 'Branding & Identity',
          icon: Icons.palette_outlined,
        ),
        _buildTabButton(
          tab: _SettingsTab.playback,
          label: 'Playback & Streaming',
          icon: Icons.play_circle_outline_rounded,
        ),
        _buildTabButton(
          tab: _SettingsTab.features,
          label: 'Catalog & Features',
          icon: Icons.auto_awesome_mosaic_outlined,
        ),
        _buildTabButton(
          tab: _SettingsTab.legal,
          label: 'Legal & Support',
          icon: Icons.verified_user_outlined,
        ),
        _buildTabButton(
          tab: _SettingsTab.infrastructure,
          label: 'Infrastructure & Security',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required _SettingsTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF05454).withValues(alpha: 0.15)
              : context.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFF05454) : context.borderCol,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFFF05454)
                  : context.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? context.textPrimary : context.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case _SettingsTab.branding:
        return _buildBrandingTab();
      case _SettingsTab.playback:
        return _buildPlaybackTab();
      case _SettingsTab.features:
        return _buildFeaturesTab();
      case _SettingsTab.legal:
        return _buildLegalTab();
      case _SettingsTab.infrastructure:
        return _buildInfrastructureTab();
    }
  }

  // ── Tab 1: Branding & Identity ──────────────────────────────────────────────
  Widget _buildBrandingTab() {
    final currentName = _appNameController.text.trim().isNotEmpty
        ? _appNameController.text.trim()
        : AppStrings.appName;
    final logoUrl = _logoUrlController.text.trim();
    final faviconUrl = _faviconUrlController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Platform Identity & Visual Assets',
          subtitle:
              'Customize your streaming brand title, tagline, navigation logo, and browser favicon.',
          icon: Icons.palette_outlined,
          children: [
            // Platform Name
            _buildFieldLabel(
              'Platform Name',
              'Displayed in browser page titles, navbar headers, notification emails, and SEO metadata.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _appNameController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. StreamOTT',
                prefixIcon: Icon(
                  Icons.title_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Platform Tagline / Slogan
            _buildFieldLabel(
              'Brand Tagline / Slogan',
              'Secondary punchline used across hero banners, meta descriptions, and invite links.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _appTaglineController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint:
                    'e.g. Stream unlimited movies, series, and exclusive originals',
                prefixIcon: Icon(
                  Icons.short_text_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Website Header Logo
            Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  color: Color(0xFFF05454),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Website Navigation Bar Logo',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSpecBanner(
              title: 'Recommended Logo Specifications:',
              specs: const [
                'Dimensions: 512 × 128 px (horizontal) or 256 × 256 px (square)',
                'Format: Transparent PNG or SVG (looks best against dark & light navigation bars)',
                'Max File Size: 2 MB',
                'Placement: Top navigation bar, login hero panel, and admin sidebar',
              ],
            ),
            const SizedBox(height: 12),

            // Live Navigation Bar Preview
            _buildNavbarPreview(currentName: currentName, logoUrl: logoUrl),
            const SizedBox(height: 12),

            // Logo Upload & URL controls
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadingLogo
                      ? null
                      : () => uploadImageToController(
                            controller: _logoUrlController,
                            setUploading: (v) =>
                                setState(() => _uploadingLogo = v),
                            fieldLabel: 'Website Logo',
                          ),
                  icon: _uploadingLogo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    _uploadingLogo ? 'Uploading Logo...' : 'Upload Logo Image',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05454),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFFF05454,
                    ).withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (logoUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _logoUrlController.clear()),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Remove Logo',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _logoUrlController,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: _inputDecoration(
                hint:
                    'Or enter direct Logo Image URL (e.g. https://.../logo.png)',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: context.textMuted,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Browser Tab Favicon
            Row(
              children: [
                const Icon(
                  Icons.tab_unselected_rounded,
                  color: Color(0xFFF05454),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Browser Window Tab Favicon',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSpecBanner(
              title: 'Recommended Favicon Specifications:',
              specs: const [
                'Dimensions: 64 × 64 px or 32 × 32 px (Square 1:1 aspect ratio)',
                'Format: PNG or ICO with transparent background',
                'Max File Size: 500 KB',
                'Placement: Displays in visitor browser tabs, bookmark bars, and PWA launch icons',
              ],
            ),
            const SizedBox(height: 12),

            // Mock Browser Tab Preview
            _buildBrowserTabPreview(
              currentName: currentName,
              faviconUrl: faviconUrl,
            ),
            const SizedBox(height: 12),

            // Favicon Upload & URL controls
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadingFavicon
                      ? null
                      : () => uploadImageToController(
                            controller: _faviconUrlController,
                            setUploading: (v) =>
                                setState(() => _uploadingFavicon = v),
                            fieldLabel: 'Browser Favicon',
                          ),
                  icon: _uploadingFavicon
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    _uploadingFavicon
                        ? 'Uploading Favicon...'
                        : 'Upload Favicon Image',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05454),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFFF05454,
                    ).withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (faviconUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _faviconUrlController.clear()),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Remove Favicon',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _faviconUrlController,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: _inputDecoration(
                hint:
                    'Or enter direct Favicon URL (e.g. https://.../favicon.png)',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: context.textMuted,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 2: Playback & Streaming ─────────────────────────────────────────────
  Widget _buildPlaybackTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Streaming Engine & Video Player Policies',
          subtitle:
              'Configure video resolution preferences, playback automation, and buffer strategies.',
          icon: Icons.play_circle_outline_rounded,
          children: [
            // Free Tier Max Streaming Quality Cap
            _buildFieldLabel(
              'Default Streaming Quality Profile',
              'The maximum streaming resolution accessible to guest and free-tier viewers (e.g. 720p HD or 480p SD).',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.elevatedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _freeTierMaxQuality,
                  isExpanded: true,
                  dropdownColor: context.surfaceBg,
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: context.textSecondary,
                  ),
                  items: _qualityOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Row(
                        children: [
                          Icon(
                            opt.contains('4K')
                                ? Icons.four_k_rounded
                                : opt.contains('1080')
                                ? Icons.high_quality_rounded
                                : opt.contains('Auto')
                                ? Icons.auto_awesome_rounded
                                : opt.contains('720')
                                ? Icons.hd_rounded
                                : opt.contains('480')
                                ? Icons.sd_rounded
                                : Icons.speed_rounded,
                            size: 18,
                            color: const Color(0xFFF05454),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            opt,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _freeTierMaxQuality = val;
                        _defaultStreamQuality = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Premium Tier Max Streaming Quality
            _buildFieldLabel(
              'Premium Subscriber Maximum Resolution',
              'The highest streaming resolution unlocked for paying VIP subscribers (e.g. 1080p Full HD or 4K Ultra HD).',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.elevatedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _premiumTierMaxQuality,
                  isExpanded: true,
                  dropdownColor: context.surfaceBg,
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: context.textSecondary,
                  ),
                  items: _qualityOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Row(
                        children: [
                          Icon(
                            opt.contains('4K')
                                ? Icons.four_k_rounded
                                : opt.contains('1080')
                                ? Icons.high_quality_rounded
                                : opt.contains('Auto')
                                ? Icons.auto_awesome_rounded
                                : opt.contains('720')
                                ? Icons.hd_rounded
                                : opt.contains('480')
                                ? Icons.sd_rounded
                                : Icons.speed_rounded,
                            size: 18,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            opt,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _premiumTierMaxQuality = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Autoplay Next Episode
            _buildSwitchCard(
              title: 'Autoplay Next Episode in Series',
              subtitle:
                  'Display a 10-second countdown and automatically launch the next episode upon series playback completion.',
              icon: Icons.skip_next_rounded,
              value: _autoplayNextEpisode,
              onChanged: (v) => setState(() => _autoplayNextEpisode = v),
            ),
            const SizedBox(height: 14),

            // Autoplay Hero Trailers
            _buildSwitchCard(
              title: 'Autoplay Featured Hero Previews',
              subtitle:
                  'Play muted cinematic teaser trailers on the catalog homepage hero banner when visitors land on the site.',
              icon: Icons.movie_filter_outlined,
              value: _autoplayHeroTrailers,
              onChanged: (v) => setState(() => _autoplayHeroTrailers = v),
            ),
            const SizedBox(height: 24),

            // Buffer Profile
            _buildFieldLabel(
              'Video Buffer & Pre-Roll Strategy',
              'Controls segment prefetching behavior on desktop and mobile video players.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.elevatedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _bufferProfile,
                  isExpanded: true,
                  dropdownColor: context.surfaceBg,
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: context.textSecondary,
                  ),
                  items: _bufferOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _bufferProfile = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bunny CDN Pull Zone Hostname
            _buildFieldLabel(
              'Bunny.net CDN Pull Zone Hostname',
              'The CDN hostname used for tier-capped resolution streaming (e.g. vz-xxxx.b-cdn.net). If left empty, automatically inferred from video library settings.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bunnyPullZoneController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. vz-399081.b-cdn.net or stream.yourdomain.com',
                prefixIcon: Icon(
                  Icons.cloud_done_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 3: Catalog & Features ───────────────────────────────────────────────
  Widget _buildFeaturesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Catalog Modules & Community Features',
          subtitle:
              'Enable or disable user-facing feature flags, vertical reels, ratings, and site-wide alerts.',
          icon: Icons.auto_awesome_mosaic_outlined,
          children: [
            // Reels Toggle
            _buildSwitchCard(
              title: 'Reels / Short-Form Video Feed',
              subtitle:
                  'Display the dedicated Reels section in top navigation, mobile bottom bars, and catalog carousels.',
              icon: Icons.video_library_outlined,
              value: _enableReels,
              onChanged: (v) => setState(() => _enableReels = v),
            ),
            const SizedBox(height: 14),

            // Reviews Toggle
            _buildSwitchCard(
              title: 'Audience Reviews & Star Ratings',
              subtitle:
                  'Allow authenticated viewers to rate titles and post public comments on movie and series detail pages.',
              icon: Icons.star_half_rounded,
              value: _enableReviews,
              onChanged: (v) => setState(() => _enableReviews = v),
            ),
            const SizedBox(height: 24),

            // Global Platform Notice Banner
            _buildFieldLabel(
              'Global Platform Announcement Banner',
              'When set, this high-priority alert appears across all visitor sessions (useful for maintenance, new releases, or promotions).',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _platformNoticeController,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              maxLines: 2,
              decoration: _inputDecoration(
                hint:
                    'e.g. Scheduled platform maintenance tonight from 2:00 AM to 4:00 AM UTC. Playback will remain uninterrupted.',
                prefixIcon: Icon(
                  Icons.campaign_outlined,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 4: Legal & Support ──────────────────────────────────────────────────
  Widget _buildLegalTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Legal Compliance & Customer Support',
          subtitle:
              'Provide direct customer helpdesk contacts, terms of service, and copyright notices.',
          icon: Icons.verified_user_outlined,
          children: [
            // Support Email
            _buildFieldLabel(
              'Customer Support / Helpdesk Email',
              'Displayed in billing receipts, account help dialogs, and platform error pages.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _supportEmailController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. support@yourplatform.com',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Terms of Service URL
            _buildFieldLabel(
              'Terms of Service URL',
              'Official terms of agreement link shown on subscription checkout and signup pages.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _termsUrlController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. https://yourplatform.com/terms',
                prefixIcon: Icon(
                  Icons.gavel_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Privacy Policy URL
            _buildFieldLabel(
              'Privacy Policy URL',
              'Data protection and privacy declaration link required by global OTT streaming regulations.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _privacyUrlController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. https://yourplatform.com/privacy',
                prefixIcon: Icon(
                  Icons.privacy_tip_outlined,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Copyright Statement
            _buildFieldLabel(
              'Platform Copyright & Legal Entity Statement',
              'Footer copyright declaration displayed at the bottom of the catalog and legal screens.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _copyrightController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'e.g. © 2026 ReelHouse Inc. All rights reserved.',
                prefixIcon: Icon(
                  Icons.copyright_rounded,
                  color: context.textMuted,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 5: Infrastructure & Security ────────────────────────────────────────
  Widget _buildInfrastructureTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Infrastructure, Cloud Secrets & Security',
          subtitle:
              'Enterprise-grade security model: all API keys, payment webhooks, and CDN tokens are isolated server-side.',
          icon: Icons.shield_outlined,
          children: [
            // Enterprise Security Model Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zero Client-Side Secret Exposure Architecture',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To maintain PCI-DSS compliance and protect your payment gateway and video transcoding credentials, all sensitive keys are securely managed directly in Supabase (Project Settings → Edge Functions → Secrets). No private API keys or IPN webhook secrets are exposed to client-side browsers.',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Server-Side Integrations Checklist
            _buildFieldLabel(
              'Active Server-Side Gateway Integrations',
              'Status of critical backend cloud services connected to your OTT platform:',
            ),
            const SizedBox(height: 10),

            _buildIntegrationRow(
              title: 'NOWPayments Gateway & Webhooks',
              badge: 'Edge Function Managed',
              description:
                  'Crypto subscription billing processed via server-side Edge Functions with cryptographic IPN HMAC verification.',
              icon: Icons.payments_rounded,
              color: const Color(0xFF38BDF8),
            ),
            const SizedBox(height: 10),

            _buildIntegrationRow(
              title: 'Bunny Stream CDN & Video Transcoder',
              badge: 'Vault Secret Protected',
              description:
                  'Direct video uploads and HLS video streaming credentials stored securely in database environment secrets.',
              icon: Icons.ondemand_video_rounded,
              color: const Color(0xFFF05454),
            ),
            const SizedBox(height: 10),

            _buildIntegrationRow(
              title: 'Supabase PostgreSQL & Row Level Security',
              badge: 'RLS Active',
              description:
                  'All catalog queries, user profiles, and subscription records guarded by strict database policies.',
              icon: Icons.storage_rounded,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 24),

            // Cache & Metadata Diagnostics
            _buildFieldLabel(
              'Platform Cache & Metadata Diagnostics',
              'Force an immediate synchronization of platform branding and configuration across local browser caches.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(allSettingsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Local metadata cache cleared. Fresh configuration loaded!',
                    ),
                    backgroundColor: const Color(0xFF38BDF8),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Purge Cache & Re-sync Metadata'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textPrimary,
                side: BorderSide(color: context.borderCol),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntegrationRow({
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.elevatedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Save Action Bar ──────────────────────────────────────────────────
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_outlined,
            color: Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message ??
                  'Changes made to platform settings will take effect instantly across all client sessions.',
              style: TextStyle(
                color: _message != null
                    ? (_message!.startsWith('Error')
                          ? Colors.redAccent
                          : const Color(0xFF10B981))
                    : context.textMuted,
                fontSize: 12,
                fontWeight: _message != null
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Publishing...' : 'Save All Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05454),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFFF05454,
              ).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper UI Components ────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF05454).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFFF05454), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: context.borderCol),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.elevatedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF05454), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFFF05454),
            activeTrackColor: const Color(0xFFF05454).withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(color: context.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildNavbarPreview({
    required String currentName,
    required String logoUrl,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: context.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Live Navigation Bar Preview',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.elevatedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderCol),
            ),
            child: Row(
              children: [
                if (logoUrl.isNotEmpty) ...[
                  AppBrandingLogo(
                    logoUrl: logoUrl,
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    borderRadius: BorderRadius.circular(8),
                    whiteTile: true,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(
                    Icons.play_circle_filled_rounded,
                    color: Color(0xFFF05454),
                    size: 26,
                  ),
                ],
                const SizedBox(width: 10),
                Text(
                  currentName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: logoUrl.isNotEmpty
                        ? const Color(0xFFF05454).withValues(alpha: 0.15)
                        : (context.isDark ? Colors.white10 : Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    logoUrl.isNotEmpty ? 'Custom Logo' : 'Default',
                    style: TextStyle(
                      color: logoUrl.isNotEmpty
                          ? const Color(0xFFF05454)
                          : context.textMuted,
                      fontSize: 10,
                      fontWeight: logoUrl.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserTabPreview({
    required String currentName,
    required String faviconUrl,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.open_in_browser_rounded,
                color: context.textMuted,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Live Browser Tab Simulation',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
            decoration: BoxDecoration(
              color: context.elevatedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderCol),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (faviconUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network(
                            faviconUrl,
                            width: 16,
                            height: 16,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.public,
                              size: 16,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Color(0xFFF05454),
                          size: 16,
                        ),
                      ],
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          currentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.close, size: 12, color: context.textMuted),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.add,
                  size: 16,
                  color: context.textMuted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecBanner({
    required String title,
    required List<String> specs,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark
            ? const Color(0xFF162234)
            : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.isDark
              ? const Color(0xFF23354E)
              : const Color(0xFFBAE6FD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: context.isDark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0284C7),
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: context.isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final spec in specs) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                  ),
                  Expanded(
                    child: Text(
                      spec,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: context.isDark ? Colors.white24 : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: context.elevatedBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.borderCol),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF05454)),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
    );
  }
}

