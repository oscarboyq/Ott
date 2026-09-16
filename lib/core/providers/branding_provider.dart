import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/platform_branding.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/utils/browser_tab_util.dart';

PlatformBranding _currentBranding = () {
  final cached = getCachedBranding();
  return PlatformBranding.fromSettings(cached);
}();

/// Provides current platform branding (app name, tagline, logo URL, favicon URL).
/// Automatically triggers dynamic browser tab updates on Flutter Web.
final platformBrandingProvider = Provider<PlatformBranding>((ref) {
  final settingsAsync = ref.watch(allSettingsProvider);

  final settings = settingsAsync.valueOrNull;

  if (settings != null && settings.isNotEmpty) {
    _currentBranding = PlatformBranding.fromSettings(settings);
    cacheBranding(
      name: _currentBranding.name,
      tagline: _currentBranding.tagline,
      logoUrl: _currentBranding.logoUrl,
      faviconUrl: _currentBranding.faviconUrl,
    );
  } else if (_currentBranding.name == const PlatformBranding().name) {
    final cached = getCachedBranding();
    if (cached.isNotEmpty) {
      _currentBranding = PlatformBranding.fromSettings(cached);
    }
  }

  // Synchronize browser tab title and favicon immediately
  updateBrowserTab(
    title: _currentBranding.tabTitle,
    faviconUrl: _currentBranding.faviconUrl,
  );

  return _currentBranding;
});


