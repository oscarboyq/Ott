import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/services/bundled_supabase_config.dart';

void main() {
  String config(String key, {String url = 'https://example.supabase.co/'}) =>
      jsonEncode({'supabaseUrl': url, 'supabaseAnonKey': key});
  String jwt(String role, {String ref = 'example'}) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role, 'ref': ref})))}.signature';

  test('loads and normalizes public configuration', () {
    final result = BundledSupabaseConfig.parse(
      config('sb_publishable_example_public_client_key'),
    );
    expect(result.url, 'https://example.supabase.co');
    expect(result.anonKey, 'sb_publishable_example_public_client_key');
    expect(BundledSupabaseConfig.parse(config(jwt('anon'))).url, result.url);
  });

  test('rejects missing configuration and unexpected fields', () {
    for (final source in [
      '{}',
      'not json',
      '[]',
      '{"supabaseUrl":"","supabaseAnonKey":""}',
      '{"serviceRoleKey":"never bundle secrets"}',
    ]) {
      expect(() => BundledSupabaseConfig.parse(source), throwsFormatException);
    }
  });

  test('rejects secret, service role, and mismatched project keys', () {
    for (final key in [
      'sb_secret_example',
      jwt('service_role'),
      jwt('anon', ref: 'different'),
      'malformed',
    ]) {
      expect(
        () => BundledSupabaseConfig.parse(config(key)),
        throwsFormatException,
      );
    }
  });

  test('rejects unsafe or non-project URLs', () {
    for (final url in [
      'http://example.supabase.co',
      'https://example.com',
      'https://example.supabase.co/path',
      'https://user:password@example.supabase.co',
    ]) {
      expect(
        () => BundledSupabaseConfig.parse(config(jwt('anon'), url: url)),
        throwsFormatException,
      );
    }
  });
}
