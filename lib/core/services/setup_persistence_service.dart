import 'package:shared_preferences/shared_preferences.dart';
import 'package:video/core/services/web_config.dart';

class SetupPersistenceSnapshot {
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final bool setupCompleted;
  final String? pendingAdminEmail;

  const SetupPersistenceSnapshot({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.setupCompleted,
    required this.pendingAdminEmail,
  });
}

class SetupPersistenceService {
  SetupPersistenceService._();

  static final SetupPersistenceService instance = SetupPersistenceService._();

  // Versioned keys to avoid reusing stale setup data from older app builds.
  static const _supabaseUrlKey = 'reelhouse_supabase_url_v2';
  static const _supabaseAnonKeyKey = 'reelhouse_supabase_anon_key_v2';
  static const _setupCompletedKey = 'reelhouse_setup_completed_v2';
  static const _pendingAdminEmailKey = 'reelhouse_pending_admin_email_v2';

  Future<SetupPersistenceSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();

    final bootstrapUrl = getBootstrapConfigValue('supabaseUrl');
    final bootstrapAnonKey = getBootstrapConfigValue('supabaseAnonKey');

    if (bootstrapUrl != null && bootstrapUrl.isNotEmpty) {
      await prefs.setString(_supabaseUrlKey, bootstrapUrl);
      setWebConfigValue('supabaseUrl', bootstrapUrl);
    }
    if (bootstrapAnonKey != null && bootstrapAnonKey.isNotEmpty) {
      await prefs.setString(_supabaseAnonKeyKey, bootstrapAnonKey);
      setWebConfigValue('supabaseAnonKey', bootstrapAnonKey);
    }

    // When the email confirmation link carries setupCompleted=true, persist it
    // so the router guard doesn't send the user back to the setup wizard.
    // We deliberately do NOT call markSetupCompleted() here because that would
    // also delete pendingAdminEmail, which we need to promote the admin.
    final bootstrapSetupCompleted = getBootstrapConfigValue('setupCompleted');
    if (bootstrapSetupCompleted == 'true') {
      await prefs.setBool(_setupCompletedKey, true);
    }

    // Restore pendingAdminEmail from URL so _finalizePendingSetupAdmin works
    // even when the confirmation link is opened in a fresh browser session.
    final bootstrapPendingEmail = getBootstrapConfigValue('pendingAdminEmail');
    if (bootstrapPendingEmail != null && bootstrapPendingEmail.isNotEmpty) {
      final existing = prefs.getString(_pendingAdminEmailKey);
      if (existing == null || existing.isEmpty) {
        await prefs.setString(_pendingAdminEmailKey, bootstrapPendingEmail);
      }
    }

    // Also treat a cookie-persisted setupCompleted as authoritative so the
    // flag survives localStorage being cleared or a different browser profile.
    final cookieSetupCompleted = getWebConfigValue('setupCompleted') == 'true';
    if (cookieSetupCompleted) {
      await prefs.setBool(_setupCompletedKey, true);
    }

    return SetupPersistenceSnapshot(
      supabaseUrl:
          bootstrapUrl ??
          getWebConfigValue('supabaseUrl') ??
          prefs.getString(_supabaseUrlKey),
      supabaseAnonKey:
          bootstrapAnonKey ??
          getWebConfigValue('supabaseAnonKey') ??
          prefs.getString(_supabaseAnonKeyKey),
      setupCompleted:
          cookieSetupCompleted || (prefs.getBool(_setupCompletedKey) ?? false),
      pendingAdminEmail: prefs.getString(_pendingAdminEmailKey),
    );
  }

  Future<void> saveSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supabaseUrlKey, url);
    await prefs.setString(_supabaseAnonKeyKey, anonKey);

    setWebConfigValue('supabaseUrl', url);
    setWebConfigValue('supabaseAnonKey', anonKey);
  }

  Future<bool> isSetupCompleted() async {
    // Check cookie first — it survives port changes and localStorage clears.
    if (getWebConfigValue('setupCompleted') == 'true') return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompletedKey) ?? false;
  }

  Future<String?> getPendingAdminEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_pendingAdminEmailKey);
    if (email == null || email.isEmpty) {
      return null;
    }
    return email;
  }

  Future<void> setPendingAdminEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAdminEmailKey, email.trim().toLowerCase());
  }

  Future<void> clearPendingAdminEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingAdminEmailKey);
  }

  /// Sets the local setup-completed flag WITHOUT removing pendingAdminEmail.
  /// Use this when email confirmation is still pending: setup credentials are
  /// saved and the admin account was created, but the user has not confirmed
  /// yet.  The router guard will see setup as done and let the user proceed to
  /// the login page.  [markSetupCompleted] is called later (by auth_provider)
  /// after the confirmed user logs in and admin promotion succeeds.
  Future<void> markSetupAwaitingConfirmation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompletedKey, true);
    // Also persist to cookie so it survives port changes (flutter run) and
    // localStorage clears.  Intentionally keep _pendingAdminEmailKey so
    // _finalizePendingSetupAdmin can promote the account on first login.
    setWebConfigValue('setupCompleted', 'true');
  }

  Future<void> markSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompletedKey, true);
    await prefs.remove(_pendingAdminEmailKey);
    // Also persist to cookie so the flag survives port changes and
    // localStorage clears.
    setWebConfigValue('setupCompleted', 'true');
  }
}
