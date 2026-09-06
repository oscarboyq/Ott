import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/services/app_settings_service.dart';

/// Only the designated owner can enter this page; the RPC enforces that again.
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});
  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _name = TextEditingController(text: 'ReelHouse');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 80) {
      setState(
        () => _error = 'Enter a platform name between 1 and 80 characters.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(appSettingsServiceProvider)
          .markSetupCompleted(platformName: name);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Setup could not be completed. Check your connection and '
              'owner access, then try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.settings_outlined, size: 48),
                const SizedBox(height: 20),
                const Text(
                  'Finish setting up your platform',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account has been designated as the installation '
                  'owner. Choose a platform name and complete setup. '
                  'Visitors will then be able to sign in.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Platform name'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(_saving ? 'Saving…' : 'Complete setup'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
