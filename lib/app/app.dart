import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/app/router/app_router.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/branding_provider.dart';
import 'package:video/core/providers/theme_provider.dart';

class OttApp extends ConsumerWidget {
  const OttApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check auth status on app start
    ref.listen(authProvider, (previous, next) {});

    final branding = ref.watch(platformBrandingProvider);
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: branding.tabTitle,
      onGenerateTitle: (_) => branding.tabTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
