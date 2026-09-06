import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A failed status check must never expose the installer as a fallback.
class SetupStatusErrorPage extends StatelessWidget {
  const SetupStatusErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
