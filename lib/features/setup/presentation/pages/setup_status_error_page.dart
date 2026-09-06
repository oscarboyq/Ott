import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// A failed status check must never expose the installer as a fallback.
class SetupStatusErrorPage extends StatelessWidget {
  const SetupStatusErrorPage({super.key});

  Future<void> _copyDatabaseSql(BuildContext context) async {
    try {
      final sql = await rootBundle.loadString(
        'assets/complete_database_setup.sql',
      );
      await Clipboard.setData(ClipboardData(text: sql));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SQL copied. Paste it into your new Supabase project’s SQL Editor.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not copy SQL. Open assets/complete_database_setup.sql in the project files.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Unable to check installation',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ReelHouse could not read its setup status. Setup has not '
                  'been reset. Check your connection and try again. If this '
                  'continues, the site owner needs to check the database setup '
                  'and access permissions.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Setting up a new Supabase project?'),
                  subtitle: const Text(
                    'Database instructions for the site owner',
                  ),
                  children: [
                    const Text(
                      'For a fresh, empty project, create the database tables first. '
                      'This error can also mean a connection or permission problem; '
                      'it does not automatically mean your database is empty.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '1. Open your Supabase project → SQL Editor → New query.\n\n'
                      '2. Copy the database SQL using the button below and paste it into the editor.\n\n'
                      '3. Click Run and wait for success. If it reports an error, resolve that error before continuing.\n\n'
                      '4. Return here and select Try again. Creating the tables does not require rebuilding Flutter.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _copyDatabaseSql(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy database SQL'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Already have a database? Do not rerun the fresh-install SQL. '
                      'Check connectivity, access permissions, and the setup_completed '
                      'record in app_settings. Use migrations for an existing database.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
