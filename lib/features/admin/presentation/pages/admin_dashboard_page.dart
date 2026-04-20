import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/subscription_plan_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/admin_provider.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/utils/image_picker_service.dart';

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

InputDecoration _adminFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFF162235),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  );
}

Widget _adminGenreDropdownField(
  TextEditingController ctrl, {
  String hint = 'Select genre',
  String? Function(String?)? validator,
}) {
  final genreItems = _genreDropdownItems(ctrl.text);
  return DropdownButtonFormField<String>(
    value: _genreDropdownValue(ctrl.text),
    validator: validator,
    dropdownColor: const Color(0xFF162235),
    iconEnabledColor: Colors.white70,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: _adminFieldDecoration(hint),
    items: genreItems
        .map(
          (genre) => DropdownMenuItem<String>(value: genre, child: Text(genre)),
        )
        .toList(),
    onChanged: (value) {
      if (value == null) {
        return;
      }
      ctrl.text = value;
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
                      : _section == _AdminSection.series
                      ? _SeriesSection(adminState: adminState)
                      : _section == _AdminSection.subscriptions
                      ? _SubscriptionsSection(adminState: adminState)
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

enum _AdminSection { videos, series, subscriptions, users }

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
    final title = switch (section) {
      _AdminSection.videos => 'Video Management',
      _AdminSection.series => 'Series Management',
      _AdminSection.subscriptions => 'Subscription Plans',
      _AdminSection.users => 'User Management',
    };
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search plans...',
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
                color: const Color(0xFF0D1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2840)),
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
                            separatorBuilder: (_, __) => const Divider(
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'PLAN',
              style: TextStyle(
                color: Colors.white38,
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
                color: Colors.white38,
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
                color: Colors.white38,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (plan.description.isNotEmpty)
                  Text(
                    plan.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
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
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              plan.yearlyPrice <= 0 ? '-' : plan.yearlyPrice.toStringAsFixed(2),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
      backgroundColor: const Color(0xFF0D1520),
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
                    const Text(
                      'Edit Subscription Plan',
                      style: TextStyle(
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search series...',
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
                color: const Color(0xFF0D1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2840)),
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
                            separatorBuilder: (_, __) => const Divider(
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
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Series',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${series.title}" and all seasons and episodes under it?',
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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
            width: 120,
            child: Text(
              'STRUCTURE',
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
            width: 140,
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
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF162235),
                              child: const Icon(
                                Icons.live_tv_rounded,
                                color: Colors.white24,
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF162235),
                            child: const Icon(
                              Icons.live_tv_rounded,
                              color: Colors.white24,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (series.tagline.isNotEmpty)
                        Text(
                          series.tagline,
                          style: const TextStyle(
                            color: Colors.white38,
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
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '${series.seasonCount} seasons / ${series.episodeCount} eps',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
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
            child: video.isReel
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'N/A',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : Switch(
                    key: ValueKey<String>(
                      'featured-${video.id}-${video.isFeatured}',
                    ),
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
                        child: _adminGenreDropdownField(
                          _genreCtrl,
                          hint: 'Select genre',
                        ),
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
                            side: const BorderSide(color: Colors.white38),
                          ),
                          const Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
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
      decoration: _adminFieldDecoration(hint),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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

class _AdminImageUploadField extends StatelessWidget {
  const _AdminImageUploadField({
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
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(isUploading ? 'Uploading...' : 'Pick Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF243247)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload to Supabase Storage or paste a public image URL manually.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
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
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF162235),
                          alignment: Alignment.center,
                          child: Text(
                            previewUnavailableText,
                            style: const TextStyle(color: Colors.white38),
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
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
                _FormField(
                  label: 'Trailer URL',
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
      backgroundColor: const Color(0xFF0D1520),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage seasons and episodes',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
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
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF1A2840)),
              const SizedBox(height: 16),
              if (_loadingSeasons)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFF05454)),
                  ),
                )
              else ...[
                const Text(
                  'Seasons',
                  style: TextStyle(
                    color: Colors.white,
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
                                : const Color(0xFF162235),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF1F9DCC)
                                  : const Color(0xFF243247),
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
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showEditSeason(season),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.white54,
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
                      style: const TextStyle(
                        color: Colors.white,
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
                      ? const Center(
                          child: Text(
                            'Add a season to start managing episodes',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : _episodes.isEmpty
                      ? const Center(
                          child: Text(
                            'No episodes in this season yet',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _episodes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final episode = _episodes[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF162235),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF243247),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF0D1520),
                                  child: Text(
                                    episode.episodeNumber.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  episode.title,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${episode.duration ~/ 60} min • ${episode.requiresPremium ? 'Premium' : 'Free'}',
                                  style: const TextStyle(color: Colors.white54),
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
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: const Text(
          'Delete Season',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete Season ${season.seasonNumber} and all its episodes?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
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
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: const Text(
          'Delete Episode',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${episode.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
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
      backgroundColor: const Color(0xFF0D1520),
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
                  style: const TextStyle(
                    color: Colors.white,
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
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
    _videoUrlCtrl = TextEditingController(text: existing?.videoUrl ?? '');
    _durationCtrl = TextEditingController(
      text: existing?.duration.toString() ?? '',
    );
    _releaseDateCtrl = TextEditingController(
      text:
          existing?.releaseDate?.toIso8601String().substring(0, 10) ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    _isFree = existing != null ? !existing.requiresPremium : false;
  }

  @override
  void dispose() {
    _episodeNumberCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _thumbnailCtrl.dispose();
    _videoUrlCtrl.dispose();
    _durationCtrl.dispose();
    _releaseDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      child: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Episode to Season ${widget.season.seasonNumber}'
                      : 'Edit Episode',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
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
                        label: 'Duration (seconds) *',
                        child: _adminTextField(
                          _durationCtrl,
                          '2700',
                          keyboardType: TextInputType.number,
                          validator: _positiveNumberField,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Title *',
                  child: _adminTextField(
                    _titleCtrl,
                    'Episode title',
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: 'Description',
                  child: _adminTextField(
                    _descriptionCtrl,
                    'Episode description',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),
                _AdminImageUploadField(
                  label: 'Thumbnail URL *',
                  controller: _thumbnailCtrl,
                  hint: 'https://...episode.jpg',
                  validator: _requiredField,
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
                _FormField(
                  label: 'Video URL *',
                  child: _adminTextField(
                    _videoUrlCtrl,
                    'https://...episode.mp4',
                    validator: _requiredField,
                  ),
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
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
                                  ? 'Add Episode'
                                  : 'Save Episode',
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
        ? await notifier.addEpisode(
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
          )
        : await notifier.updateEpisode(
            id: widget.existing!.id,
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
}

Widget _adminTextField(
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
    decoration: _adminFieldDecoration(hint),
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
