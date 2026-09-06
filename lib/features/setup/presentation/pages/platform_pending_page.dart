import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/providers/auth_provider.dart';

class PlatformPendingPage extends ConsumerWidget {
  const PlatformPendingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isAuthenticated;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  if (signedIn) await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Text(
                  signedIn ? 'Sign out and sign in as owner' : 'Owner sign in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
