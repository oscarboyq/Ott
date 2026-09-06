import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/app/app.dart';
import 'package:video/app/bootstrap_failure_app.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/services/bundled_supabase_config.dart';

bool _urlStrategyConfigured = false;

Future<void> main() => _bootstrap();

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && !_urlStrategyConfigured) {
    setUrlStrategy(HashUrlStrategy());
    _urlStrategyConfigured = true;
  }
  try {
    final config = await BundledSupabaseConfig.load();
    AppConstants.loadConfig(webUrl: config.url, webAnonKey: config.anonKey);
    await Supabase.initialize(url: config.url, anonKey: config.anonKey);
  } catch (_) {
    // Do not print configuration values or redirect a broken build to setup.
    runApp(
      BootstrapFailureApp(
        onRetry: _bootstrap,
        message:
            'ReelHouse could not load its Supabase configuration. '
            'The site owner needs to check config/supabase.json and rebuild '
            'the app. Setup has not been reset.',
      ),
    );
    return;
  }
  runApp(const ProviderScope(child: OttApp()));
}
