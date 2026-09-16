void updateBrowserTab({required String title, String? faviconUrl}) {
  // No-op on non-web platforms and in unit/widget test environments.
}

Map<String, String> getCachedBranding() => const {};

void cacheBranding({
  required String name,
  required String tagline,
  String? logoUrl,
  String? faviconUrl,
}) {}

