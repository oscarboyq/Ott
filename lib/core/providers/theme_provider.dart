import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefKey = 'app_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved != null) {
        switch (saved) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
            state = ThemeMode.system;
            break;
        }
      }
    } catch (e) {
      debugPrint('[ThemeModeNotifier] Failed to load theme mode: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode.name);
    } catch (e) {
      debugPrint('[ThemeModeNotifier] Failed to save theme mode: $e');
    }
  }

  Future<void> toggleTheme([BuildContext? context]) async {
    final isCurrentlyDark = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        context != null
            ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
            : true,
    };

    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// A modern, professional theme switcher button with smooth transitions and tooltips.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({
    super.key,
    this.compact = false,
    this.showTooltip = true,
  });

  final bool compact;
  final bool showTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => brightness == Brightness.dark,
    };

    final tooltip = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              size: compact ? 18 : 20,
              color: isDark ? const Color(0xFFFFB44C) : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );

    if (!showTooltip) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
