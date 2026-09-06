import 'dart:convert';
import 'package:flutter/services.dart';

/// Public client configuration bundled with Flutter. Never put secrets here.
class BundledSupabaseConfig {
  final String url;
  final String anonKey;
  const BundledSupabaseConfig._(this.url, this.anonKey);

  static Future<BundledSupabaseConfig> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      'config/supabase.json',
      cache: false,
    );
    return BundledSupabaseConfig.parse(source);
  }

  factory BundledSupabaseConfig.parse(String source) {
    final Object? data = jsonDecode(source);
    if (data is! Map<String, dynamic> ||
        data.keys.any(
          (key) => !['supabaseUrl', 'supabaseAnonKey'].contains(key),
        )) {
      throw const FormatException('Invalid public configuration file.');
    }
    final rawUrl = data['supabaseUrl'];
    final rawKey = data['supabaseAnonKey'];
    if (rawUrl is! String || rawKey is! String) {
      throw const FormatException('Supabase URL and client key are required.');
    }
    final url = Uri.tryParse(rawUrl.trim());
    final key = rawKey.trim();
    if (url == null ||
        url.scheme != 'https' ||
        !url.host.endsWith('.supabase.co') ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.hasQuery ||
        url.hasFragment ||
        (url.path.isNotEmpty && url.path != '/')) {
      throw const FormatException('Use a hosted HTTPS Supabase project URL.');
    }
    if (key.startsWith('sb_publishable_') && key.length >= 30) {
      return BundledSupabaseConfig._(url.origin, key);
    }
    // Decode only to reject privileged keys; Supabase verifies authentication.
    try {
      final parts = key.split('.');
      if (parts.length == 3) {
        final Object? payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (payload is Map &&
            payload['role'] == 'anon' &&
            (payload['ref'] == null ||
                payload['ref'] == url.host.split('.')[0])) {
          return BundledSupabaseConfig._(url.origin, key);
        }
      }
    } on FormatException {
      // Return a fixed message without including the submitted key.
    }
    throw const FormatException('Use a publishable or legacy anon key only.');
  }
}
