import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keys stored in the `app_settings` table.
class SettingKeys {
  static const String bunnyApiKey = 'bunny_cdn_api_key';
  static const String bunnyLibraryId = 'bunny_cdn_library_id';
  static const String bunnyPullZone = 'bunny_cdn_pull_zone';
  static const String nowpaymentsApiKey = 'nowpayments_api_key';
  static const String nowpaymentsIpnSecret = 'nowpayments_ipn_secret';
  static const String nowpaymentsPayCurrency = 'nowpayments_pay_currency';
  static const String appName = 'app_name';
  static const String setupCompleted = 'setup_completed';
}

/// Read/write runtime configuration from the `app_settings` table.
class AppSettingsService {
  final SupabaseClient _client;

  AppSettingsService(this._client);

  /// Check if the database has been set up (tables exist).
  Future<bool> isDatabaseReady() async {
    try {
      await _client.from('app_settings').select('key').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check if initial setup has been completed.
  Future<bool> isSetupCompleted() async {
    try {
      final row = await _client
          .from('app_settings')
          .select('value')
          .eq('key', SettingKeys.setupCompleted)
          .maybeSingle();
      return row?['value'] == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Mark setup as completed.
  Future<void> markSetupCompleted() async {
    await _client
        .from('app_settings')
        .update({
          'value': 'true',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('key', SettingKeys.setupCompleted);
  }

  /// Get a single setting value.
  Future<String?> get(String key) async {
    try {
      final row = await _client
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final value = row?['value'] as String?;
      return (value != null && value.isNotEmpty) ? value : null;
    } catch (e) {
      debugPrint('AppSettingsService.get($key) error: $e');
      return null;
    }
  }

  /// Get all settings as a map (excludes secret values for non-admins).
  Future<Map<String, String>> getAll() async {
    try {
      final rows = await _client.from('app_settings').select();
      final map = <String, String>{};
      for (final row in rows) {
        map[row['key'] as String] = row['value'] as String? ?? '';
      }
      return map;
    } catch (e) {
      debugPrint('AppSettingsService.getAll() error: $e');
      return {};
    }
  }

  /// Update a setting (admin only via RLS).
  Future<void> set(String key, String value) async {
    await _client
        .from('app_settings')
        .update({
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('key', key);
  }

  /// Update multiple settings at once.
  Future<void> setAll(Map<String, String> settings) async {
    for (final entry in settings.entries) {
      await set(entry.key, entry.value);
    }
  }
}

// ── Riverpod providers ──────────────────────────────────────

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService(Supabase.instance.client);
});

/// Async check: is the database ready?
final isDatabaseReadyProvider = FutureProvider<bool>((ref) async {
  return ref.read(appSettingsServiceProvider).isDatabaseReady();
});

/// Async check: has setup been completed?
final isSetupCompletedProvider = FutureProvider<bool>((ref) async {
  return ref.read(appSettingsServiceProvider).isSetupCompleted();
});

/// All settings as a map (for admin settings page).
final allSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.read(appSettingsServiceProvider).getAll();
});
