import 'browser_tab_util_stub.dart'
    if (dart.library.html) 'browser_tab_util_web.dart' as impl;

/// Dynamically updates the browser tab title and favicon (on web).
/// Safe no-op on iOS, Android, macOS, Linux, and Windows.
void updateBrowserTab({required String title, String? faviconUrl}) {
  impl.updateBrowserTab(title: title, faviconUrl: faviconUrl);
}

/// Reads cached branding settings from localStorage (on web).
Map<String, String> getCachedBranding() {
  return impl.getCachedBranding();
}

/// Persists branding settings to localStorage (on web).
void cacheBranding({
  required String name,
  required String tagline,
  String? logoUrl,
  String? faviconUrl,
}) {
  impl.cacheBranding(
    name: name,
    tagline: tagline,
    logoUrl: logoUrl,
    faviconUrl: faviconUrl,
  );
}

