import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/providers/auth_provider.dart';

class PlatformPendingPage extends ConsumerWidget {
  const PlatformPendingPage({super.key});

  Future<void> _copyOwnerSql(BuildContext context) async {
    try {
      final sql = await rootBundle.loadString('setup/designate_owner.sql');
      await Clipboard.setData(ClipboardData(text: sql));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Owner SQL copied. Replace the UUID placeholder before running it in Supabase.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not copy. Open setup/designate_owner.sql in the project files.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isAuthenticated;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Platform being configured',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The owner is preparing ReelHouse. Please check back soon.',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Check again'),
                ),
                TextButton(
                  onPressed: () async {
                    if (signedIn) {
                      await ref.read(authProvider.notifier).logout();
                    }
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(
                    signedIn
                        ? 'Sign out and sign in as owner'
                        : 'Owner sign in',
                  ),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('How to set up the owner account'),
                  subtitle: const Text('For the person installing ReelHouse'),
                  children: [
                    const Text(
                      '1. Open your Supabase project → Authentication → Users. '
                      'Create your account, or use an existing one. Make sure its email is confirmed.\n\n'
                      '2. Open that user and copy its User UID (UUID). This is the account ID, not an API key.\n\n'
                      '3. Copy the owner SQL below. Open SQL Editor → New query and paste it.\n\n'
                      '4. Replace REPLACE_WITH_YOUR_AUTH_USER_UUID with your copied UUID. '
                      'Keep the single quotes around it, then click Run.\n\n'
                      '5. After it succeeds, select Owner sign in on this page and use that account’s email and password. '
                      'You can then choose the platform name and complete setup.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _copyOwnerSql(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy owner setup SQL'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Already designated your owner? Just sign in. If SQL reports an error, '
                      'resolve it before continuing. Owner designation requires access to '
                      'your Supabase SQL Editor; this page does not grant admin access.',
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
