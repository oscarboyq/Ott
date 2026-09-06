import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/features/setup/presentation/pages/setup_wizard_page.dart';

class TestSettings implements AppSettingsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  bool fail = true;
  int calls = 0;
  String? savedName;
  @override
  Future<void> markSetupCompleted({String platformName = 'ReelHouse'}) async {
    calls++;
    if (fail) throw StateError('denied');
    savedName = platformName;
  }
}

void main() {
  testWidgets('owner can retry a failure without account creation or tokens', (
    tester,
  ) async {
    final settings = TestSettings();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, state) => const SetupWizardPage()),
        GoRoute(
          path: '/',
          builder: (_, state) => const Scaffold(body: Text('Home destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsServiceProvider.overrideWithValue(settings)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My Cinema');
    await tester.tap(find.text('Complete setup'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Setup could not be completed.'),
      findsOneWidget,
    );
    settings.fail = false;
    await tester.tap(find.text('Complete setup'));
    await tester.pumpAndSettle();
    expect(settings.calls, 2);
    expect(settings.savedName, 'My Cinema');
    expect(find.text('Home destination'), findsOneWidget);
  });
}
