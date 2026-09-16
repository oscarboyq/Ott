import 'dart:html' as html;
import 'package:flutter/services.dart';

String? _lastSetTitle;
String? _lastSetFaviconUrl;

void updateBrowserTab({required String title, String? faviconUrl}) {
  try {
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty &&
        (_lastSetTitle != cleanTitle || html.document.title != cleanTitle)) {
      _lastSetTitle = cleanTitle;
      html.document.title = cleanTitle;
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: cleanTitle),
      );
    }

    final trimmedFavicon = faviconUrl?.trim();
    if (trimmedFavicon != null && trimmedFavicon.isNotEmpty) {
      if (_lastSetFaviconUrl != trimmedFavicon) {
        _lastSetFaviconUrl = trimmedFavicon;
        _updateFavicon(trimmedFavicon);
      }
    }
  } catch (_) {
    // Ignore DOM update errors in restricted environments
  }
}

void _updateFavicon(String url) {
  try {
    // Target only the favicon link elements, NEVER touch apple-touch-icon
    final existingIcons = html.document.querySelectorAll(
      "link[rel='icon'], link[rel='shortcut icon']",
    );
    for (final node in existingIcons) {
      node.remove();
    }

    final link = html.LinkElement()
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = url;
    html.document.head?.append(link);
  } catch (_) {
    // Ignore DOM errors
  }
}

Map<String, String> getCachedBranding() {
  try {
    final storage = html.window.localStorage;
    final map = <String, String>{};
    final name = storage['app_branding_name']?.trim();
    final tagline = storage['app_branding_tagline']?.trim();
    final logo = storage['app_branding_logo']?.trim();
    final favicon = storage['app_branding_favicon']?.trim();

    if (name != null && name.isNotEmpty) map['app_name'] = name;
    if (tagline != null && tagline.isNotEmpty) map['app_tagline'] = tagline;
    if (logo != null && logo.isNotEmpty) map['app_logo_url'] = logo;
    if (favicon != null && favicon.isNotEmpty) map['app_favicon_url'] = favicon;
    return map;
  } catch (_) {
    return const {};
  }
}

void cacheBranding({
  required String name,
  required String tagline,
  String? logoUrl,
  String? faviconUrl,
}) {
  try {
    final storage = html.window.localStorage;
    if (name.trim().isNotEmpty) {
      storage['app_branding_name'] = name.trim();
    }
    if (tagline.trim().isNotEmpty) {
      storage['app_branding_tagline'] = tagline.trim();
    }
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      storage['app_branding_logo'] = logoUrl.trim();
    }
    if (faviconUrl != null && faviconUrl.trim().isNotEmpty) {
      storage['app_branding_favicon'] = faviconUrl.trim();
    }
  } catch (_) {
    // Ignore storage errors
  }
}

