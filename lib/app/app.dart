import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/app/router/app_router.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/constants/app_strings.dart';
import 'package:video/core/providers/auth_provider.dart';

class OttApp extends ConsumerWidget {
  const OttApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check auth status on app start
    ref.listen(authProvider, (previous, next) {});

    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
