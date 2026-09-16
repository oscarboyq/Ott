import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppTheme.useGoogleFonts = false;
  });

  group('AppTheme', () {
    test('darkTheme has Brightness.dark and dark scaffold background', () {
      final dark = AppTheme.darkTheme();
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF070B12));
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.surface, const Color(0xFF101826));
    });

    test('lightTheme has Brightness.light and light scaffold background', () {
      final light = AppTheme.lightTheme();
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(light.colorScheme.brightness, Brightness.light);
      expect(light.colorScheme.surface, Colors.white);
    });

    testWidgets('ThemeContext extension resolves dark and light properties', (
      tester,
    ) async {
      late BuildContext darkContext;
      late BuildContext lightContext;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme(),
          child: Builder(
            builder: (ctx) {
              darkContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(darkContext.isDark, isTrue);
      expect(darkContext.scaffoldBg, const Color(0xFF070B12));
      expect(darkContext.surfaceBg, const Color(0xFF101826));
      expect(darkContext.textPrimary, Colors.white);

      await tester.pumpWidget(
        Theme(
          data: AppTheme.lightTheme(),
          child: Builder(
            builder: (ctx) {
              lightContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(lightContext.isDark, isFalse);
      expect(lightContext.scaffoldBg, const Color(0xFFF8FAFC));
      expect(lightContext.surfaceBg, Colors.white);
      expect(lightContext.textPrimary, const Color(0xFF0F172A));
    });
  });

  group('ThemeModeNotifier & Provider', () {
    test('defaults to ThemeMode.dark when no preference is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger load
      final mode = container.read(themeModeProvider);
      expect(mode, ThemeMode.dark);
    });

    test('loads saved light mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
      final notifier = ThemeModeNotifier();
      // Allow async load to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, ThemeMode.light);
    });

    test('toggles from dark to light and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.toggleTheme();
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'light');

      await notifier.toggleTheme();
      expect(notifier.state, ThemeMode.dark);
      expect(prefs.getString('app_theme_mode'), 'dark');
    });

    test('explicitly sets theme mode', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'light');
    });
  });

  group('ThemeToggleButton Widget', () {
    testWidgets('renders button and switches theme on tap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: const ThemeToggleButton(),
            ),
          ),
        ),
      );

      // Initially dark mode -> displays light_mode icon to switch to light
      expect(find.byType(ThemeToggleButton), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      // Tap the button
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      // State is now light
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });
  });
}
