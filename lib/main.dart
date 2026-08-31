import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/app/app.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/services/setup_persistence_service.dart';
import 'package:video/core/services/web_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    setUrlStrategy(HashUrlStrategy());
  }

  final persistedSetup = await SetupPersistenceService.instance.load();

  // Load config from web/config.js, persisted local setup, or built-in defaults.
  AppConstants.loadConfig(
    webUrl: persistedSetup.supabaseUrl ?? getWebConfigValue('supabaseUrl'),
    webAnonKey:
        persistedSetup.supabaseAnonKey ?? getWebConfigValue('supabaseAnonKey'),
  );

  // Initialize Supabase only if credentials are provided.
  if (AppConstants.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully');

      // If the setupCompleted flag was never written to localStorage (e.g. the
      // app was set up with an older build before this flag existed), we can
      // safely infer setup is done: credentials are already saved in
      // localStorage (written by the wizard on step 0) and Supabase
      // initialized without error above.  No DB query needed — the wizard
      // requires passing a DB connectivity check before it ever saves anything.
      if (!persistedSetup.setupCompleted) {
        await SetupPersistenceService.instance.markSetupAwaitingConfirmation();
        debugPrint('✅ Saved credentials found — setup marked complete');
      }
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
    }
  } else {
    debugPrint('⚠️ No Supabase credentials — Setup Wizard will be shown');
  }

  runApp(const ProviderScope(child: OttApp()));
}
