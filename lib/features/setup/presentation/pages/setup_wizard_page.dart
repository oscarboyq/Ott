import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/services/setup_persistence_service.dart';

/// Full-screen setup wizard shown the first time the app runs.
/// Guides a non-technical user through Supabase setup.
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _step = 0;
  bool _verifying = false;
  String? _verifyError;
  bool _dbReady = false;
  bool _registering = false;
  String? _registerError;
  bool _awaitingEmailConfirmation = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _supabaseUrlController = TextEditingController();
  final _supabaseKeyController = TextEditingController();
  bool _savingCreds = false;
  String? _credsError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    super.dispose();
  }

  // ── Step titles ──────────────────────────────────────────
  static const _steps = [
    'Connect to Supabase',
    'Run Database SQL',
    'Verify Connection',
    'Create Admin Account',
    'All Done!',
  ];

  String? _buildEmailRedirectTo() {
    if (!kIsWeb) {
      return null;
    }

    final origin = Uri.base.origin;
    if (origin.isEmpty) {
      return null;
    }

    final supabaseUrl = _supabaseUrlController.text.trim();
    final supabaseAnonKey = _supabaseKeyController.text.trim();
    final adminEmail = _emailController.text.trim().toLowerCase();

    // Encode all setup state into the redirect URL so the app can fully
    // restore itself when the confirmation link is opened in any browser
    // context (including incognito or a different device).
    final queryParameters = <String, String>{
      if (supabaseUrl.isNotEmpty) 'supabaseUrl': supabaseUrl,
      if (supabaseAnonKey.isNotEmpty) 'supabaseAnonKey': supabaseAnonKey,
      'setupCompleted': 'true',
      if (adminEmail.isNotEmpty) 'pendingAdminEmail': adminEmail,
    };

    final loginUri = Uri(path: '/login', queryParameters: queryParameters);
    return '$origin/#${loginUri.toString()}';
  }

  // ── Save Supabase credentials and initialize ─────────────
  Future<void> _saveCredentials() async {
    final url = _supabaseUrlController.text.trim();
    final key = _supabaseKeyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(
        () => _credsError = 'Please enter both your Supabase URL and anon key.',
      );
      return;
    }
    if (!url.startsWith('https://')) {
      setState(() => _credsError = 'URL should start with https://');
      return;
    }

    setState(() {
      _savingCreds = true;
      _credsError = null;
    });

    try {
      await SetupPersistenceService.instance.saveSupabaseConfig(
        url: url,
        anonKey: key,
      );

      // Update AppConstants
      AppConstants.loadConfig(webUrl: url, webAnonKey: key);

      // Initialize Supabase with the new credentials
      await Supabase.initialize(url: url, anonKey: key);

      setState(() {
        _savingCreds = false;
        _step = 1;
      });
    } catch (e) {
      setState(() {
        _savingCreds = false;
        _credsError = 'Failed to connect: $e';
      });
    }
  }

  // ── Verify that app_settings table exists ────────────────
  Future<void> _verifyConnection() async {
    if (!AppConstants.isConfigured) {
      setState(() {
        _verifyError =
            'Supabase is not configured yet. Go back to Step 1 and enter your Supabase URL and anon key.';
      });
      return;
    }

    // Ensure Supabase is initialized (in case user navigated here directly)
    try {
      Supabase.instance.client;
    } catch (_) {
      try {
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
      } catch (e) {
        setState(() => _verifyError = 'Failed to connect to Supabase: $e');
        return;
      }
    }

    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    try {
      final ready = await ref
          .read(appSettingsServiceProvider)
          .isDatabaseReady();
      if (ready) {
        setState(() {
          _dbReady = true;
          _verifying = false;
          _step = 3;
        });
      } else {
        setState(() {
          _verifying = false;
          _verifyError =
              'Could not find the database tables. Make sure you ran the SQL in Step 2.';
        });
      }
    } catch (e) {
      setState(() {
        _verifying = false;
        _verifyError = e.toString();
      });
    }
  }

  // ── Register first admin account ─────────────────────────
  Future<void> _registerAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _registerError = 'Please fill in all fields.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _registerError = 'Password must be at least 6 characters.',
      );
      return;
    }

    setState(() {
      _registering = true;
      _registerError = null;
    });

    try {
      final client = Supabase.instance.client;

      // Sign up
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'full_name': username},
        emailRedirectTo: _buildEmailRedirectTo(),
      );

      await SetupPersistenceService.instance.setPendingAdminEmail(email);

      final userId = authResponse.user?.id;
      if (userId == null) {
        setState(() {
          _registering = false;
          _registerError =
              'Registration succeeded but no user ID returned. Check your Supabase email confirmation settings.';
        });
        return;
      }

      if (authResponse.session == null) {
        // Admin account was created but email confirmation is still required.
        // Mark setup locally complete so the router guard lets the user
        // navigate to the login page.  We keep pendingAdminEmail intact so
        // _finalizePendingSetupAdmin can promote this account on first login.
        await SetupPersistenceService.instance.markSetupAwaitingConfirmation();
        setState(() {
          _registering = false;
          _awaitingEmailConfirmation = true;
          _step = 4;
        });
        return;
      }

      // Sign in immediately so auth.uid() works for the RPC call
      await client.auth.signInWithPassword(email: email, password: password);

      // Small delay to let the handle_new_user trigger create the profile
      await Future.delayed(const Duration(seconds: 1));

      // Promote to admin via SECURITY DEFINER function (bypasses RLS)
      await client.rpc('promote_first_admin');

      // Mark setup as completed
      await ref.read(appSettingsServiceProvider).markSetupCompleted();
      await SetupPersistenceService.instance.markSetupCompleted();

      setState(() {
        _registering = false;
        _awaitingEmailConfirmation = false;
        _step = 4;
      });
    } on AuthException catch (e) {
      setState(() {
        _registering = false;
        _registerError = e.message;
      });
    } catch (e) {
      setState(() {
        _registering = false;
        _registerError = e.toString();
      });
    }
  }

  // ── Copy SQL to clipboard ────────────────────────────────
  Future<void> _copySql() async {
    final sql = await rootBundle.loadString(
      'assets/complete_database_setup.sql',
    );
    await Clipboard.setData(ClipboardData(text: sql));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SQL copied to clipboard!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: Container(
          width: 660,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05454),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ReelHouse Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Progress bar
                _ProgressBar(current: _step, total: _steps.length),
                const SizedBox(height: 8),
                Text(
                  'Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 28),

                // Step content
                if (_step == 0) _buildStep0(),
                if (_step == 1) _buildStep1(),
                if (_step == 2) _buildStep2(),
                if (_step == 3) _buildStep3(),
                if (_step == 4) _buildStep4(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 0: Create Supabase project ──────────────────────
  Widget _buildStep0() {
    final alreadyConfigured = AppConstants.isConfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect to Supabase',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _instruction(
          '1',
          'Go to supabase.com and sign in (or create a free account).',
        ),
        _instruction('2', 'Click "New Project" and pick a name and password.'),
        _instruction(
          '3',
          'Wait for the project to finish provisioning (~1 minute).',
        ),
        _instruction(
          '4',
          'Go to Project Settings → API and copy your Project URL and anon key.',
        ),
        const SizedBox(height: 20),
        _field(
          controller: _supabaseUrlController,
          label: 'Supabase Project URL',
          hint: 'https://your-project-id.supabase.co',
        ),
        const SizedBox(height: 12),
        _field(
          controller: _supabaseKeyController,
          label: 'Supabase Anon Key',
          hint: 'eyJhbGciOi...',
        ),
        if (_credsError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _credsError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (alreadyConfigured)
          _nextButton(onPressed: () => setState(() => _step = 1))
        else
          ElevatedButton(
            onPressed: _savingCreds ? null : _saveCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ECF8E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _savingCreds
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save & Continue'),
          ),
      ],
    );
  }

  // ── Step 1: Run database SQL ─────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Up Your Database',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _instruction(
          '1',
          'In your Supabase dashboard, click "SQL Editor" in the left sidebar.',
        ),
        _instruction('2', 'Click "+ New Query".'),
        _instruction(
          '3',
          'Click the button below to copy the database setup SQL.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copySql,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Database SQL to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ECF8E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _instruction('4', 'Paste the SQL into the query editor.'),
        _instruction('5', 'Click the green "Run" button.'),
        _instruction(
          '6',
          'Wait until it says "Success". If you see errors, run it again — some are harmless "already exists" warnings.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _backButton(onPressed: () => setState(() => _step = 0)),
            const SizedBox(width: 12),
            _nextButton(onPressed: () => setState(() => _step = 2)),
          ],
        ),
      ],
    );
  }

  // ── Step 2: Verify connection ────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify Database Connection',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Let\'s make sure everything is connected properly.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (_verifyError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _verifyError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_dbReady)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3ECF8E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3ECF8E).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF3ECF8E), size: 20),
                SizedBox(width: 10),
                Text(
                  'Database is ready!',
                  style: TextStyle(color: Color(0xFF3ECF8E), fontSize: 14),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            _backButton(onPressed: () => setState(() => _step = 1)),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _verifying ? null : _verifyConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05454),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify Connection'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Create admin account ─────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Your Admin Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This will be the Super Admin account that manages everything.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _field(
          controller: _usernameController,
          label: 'Username',
          hint: 'admin',
        ),
        const SizedBox(height: 12),
        _field(
          controller: _emailController,
          label: 'Email',
          hint: 'admin@example.com',
        ),
        const SizedBox(height: 12),
        _field(
          controller: _passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          obscure: true,
        ),
        if (_registerError != null) ...[
          const SizedBox(height: 12),
          Text(
            _registerError!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            _backButton(onPressed: () => setState(() => _step = 2)),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _registering ? null : _registerAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05454),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _registering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Admin & Finish Setup'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: Done! ────────────────────────────────────────
  Widget _buildStep4() {
    final title = _awaitingEmailConfirmation
        ? 'Confirm Your Email'
        : 'Setup Complete!';
    final subtitle = _awaitingEmailConfirmation
        ? 'Your admin account was created, but Supabase requires email confirmation before it can become the admin login.'
        : 'Your platform is ready. You can now:';
    final buttonLabel = _awaitingEmailConfirmation
        ? 'Go to Login'
        : 'Go to Login';

    final savedUrl = AppConstants.supabaseUrl;
    final savedKey = AppConstants.supabaseAnonKey;
    final configJs =
        'window.APP_CONFIG = {\n'
        '  supabaseUrl: "$savedUrl",\n'
        '  supabaseAnonKey: "$savedKey",\n'
        '};';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.celebration_rounded,
          color: Color(0xFFF05454),
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_awaitingEmailConfirmation) ...[
          _instruction(
            '1',
            'Open the confirmation email you received from Supabase.',
          ),
          _instruction(
            '2',
            'Click the confirmation link, then come back and sign in with the same email and password.',
          ),
          _instruction(
            '3',
            'The app will automatically finish setup and grant that account admin access on first confirmed login.',
          ),
        ] else ...[
          _instruction('1', 'Log in with the admin account you just created.'),
          _instruction(
            '2',
            'Go to Admin Panel → Settings to configure Bunny CDN and NowPayments API keys.',
          ),
          _instruction('3', 'Start uploading videos and managing content!'),
        ],

        // ── Permanent config.js update notice ───────────────
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'IMPORTANT — Make setup permanent',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Your credentials are currently saved only in this browser. '
                'On any other device or browser the setup wizard will appear again.\n\n'
                'To make setup permanent across all devices, replace the contents of '
                'web/config.js in your project with the snippet below, then restart the app.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E17),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  configJs,
                  style: const TextStyle(
                    color: Color(0xFF3ECF8E),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: configJs));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'config.js content copied — paste it into web/config.js and restart.',
                          ),
                          backgroundColor: Color(0xFF3ECF8E),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy web/config.js content'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF05454),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _instruction(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFF05454).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFFF05454),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A3A4E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A3A4E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF05454)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _nextButton({required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF05454),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Next'),
    );
  }

  Widget _backButton({required VoidCallback onPressed}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white60,
        side: const BorderSide(color: Color(0xFF2A3A4E)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Back'),
    );
  }
}

// ── Progress bar widget ──────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: i <= current
                  ? const Color(0xFFF05454)
                  : const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
