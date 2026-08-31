import 'dart:html' as html;
import 'dart:js' as js;

const _webConfigStoragePrefix = 'reelhouse_v2_';

// ── Cookie helpers ────────────────────────────────────────────────────────────
// Cookies on localhost are domain-scoped, NOT port-scoped.
// This means credentials saved as cookies survive flutter run restarts that
// use a different random port — unlike localStorage which is port-scoped.

String? _readCookie(String key) {
  try {
    final cookieName = '$_webConfigStoragePrefix$key=';
    final all = html.document.cookie ?? '';
    for (final part in all.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith(cookieName)) {
        final raw = trimmed.substring(cookieName.length);
        if (raw.isNotEmpty) return Uri.decodeComponent(raw);
      }
    }
  } catch (_) {}
  return null;
}

void _writeCookie(String key, String value) {
  try {
    // 5-year expiry — effectively permanent for our purposes.
    final expires = DateTime.now().add(const Duration(days: 365 * 5));
    // RFC 1123 date format required by the cookie spec.
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final utc = expires.toUtc();
    final expiresStr =
        '${days[utc.weekday - 1]}, '
        '${utc.day.toString().padLeft(2, '0')} '
        '${months[utc.month - 1]} '
        '${utc.year} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')} GMT';
    html.document.cookie =
        '$_webConfigStoragePrefix$key=${Uri.encodeComponent(value)};'
        ' expires=$expiresStr; path=/; SameSite=Lax';
  } catch (_) {}
}

// ── URL helpers ───────────────────────────────────────────────────────────────

String? _readFromUrl(String key) {
  try {
    final direct = Uri.base.queryParameters[key];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    // With HashUrlStrategy, redirect query params are usually inside fragment.
    final fragment = Uri.base.fragment;
    final queryStart = fragment.indexOf('?');
    if (queryStart == -1 || queryStart == fragment.length - 1) {
      return null;
    }

    final query = fragment.substring(queryStart + 1);
    final params = Uri.splitQueryString(query);
    final value = params[key];
    if (value != null && value.isNotEmpty) {
      return value;
    }
  } catch (_) {
    // Ignore malformed URLs and fall through.
  }
  return null;
}

/// Read temporary bootstrap value from URL query/fragment.
String? getBootstrapConfigValue(String key) => _readFromUrl(key);

/// Read a config value.  Priority order:
///   1. URL query/fragment  (email confirmation redirects)
///   2. Cookie              (port-independent, survives flutter run restarts)
///   3. localStorage        (port-scoped, used for same-session persistence)
///   4. config.js           (hardcoded defaults at build time)
String? getWebConfigValue(String key) {
  try {
    // 1. URL
    final fromUrl = _readFromUrl(key);
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;

    // 2. Cookie — survives across different flutter run ports on localhost.
    final fromCookie = _readCookie(key);
    if (fromCookie != null && fromCookie.isNotEmpty) return fromCookie;

    // 3. localStorage
    final stored = html.window.localStorage['$_webConfigStoragePrefix$key'];
    if (stored != null && stored.isNotEmpty) return stored;

    // 4. config.js
    final config = js.context['APP_CONFIG'];
    if (config != null) {
      final value = config[key];
      if (value != null) {
        final str = value.toString();
        if (str.isNotEmpty) return str;
      }
    }

    return null;
  } catch (_) {
    return null;
  }
}

/// Persist a config value to both localStorage AND a cookie.
/// localStorage is used for same-session fast access.
/// Cookie is used to survive flutter run port changes during development.
void setWebConfigValue(String key, String value) {
  try {
    html.window.localStorage['$_webConfigStoragePrefix$key'] = value;
  } catch (_) {}
  _writeCookie(key, value);
}
