import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/common/widgets/branding_logo.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/branding_provider.dart';
import 'package:video/core/providers/theme_provider.dart';
import 'package:video/core/utils/validation_helper.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (mounted && ref.read(authProvider).isAuthenticated) {
      context.go(widget.redirectTo ?? '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final branding = ref.watch(platformBrandingProvider);
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 800;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Row(
        children: [
          // Left panel - branding (only on wide screens)
          if (isWide)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: context.isDark
                        ? const [Color(0xFF101826), Color(0xFF0B111C)]
                        : const [Color(0xFFFFFFFF), Color(0xFFEDF2F7)],
                  ),
                  border: Border(
                    right: BorderSide(color: context.borderCol),
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                              ),
                          itemCount: 200,
                          itemBuilder: (_, _) => Icon(
                            Icons.movie_outlined,
                            color: context.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    // Centered brand
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (branding.hasCustomLogo)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: AppBrandingLogo(
                                logoUrl: branding.logoUrl!,
                                height: 64,
                                padding: const EdgeInsets.all(8),
                                borderRadius: BorderRadius.circular(16),
                                whiteTile: true,
                              ),
                            )
                          else
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF05454),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 46,
                              ),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            branding.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            branding.tagline,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 40),
                          const _FeatureRow(
                            icon: Icons.hd_rounded,
                            label: 'HD & 4K Quality',
                          ),
                          const SizedBox(height: 12),
                          const _FeatureRow(
                            icon: Icons.devices_rounded,
                            label: 'Watch on any device',
                          ),
                          const SizedBox(height: 12),
                          const _FeatureRow(
                            icon: Icons.download_rounded,
                            label: 'Download & watch offline',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right panel - form
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top action bar (back button + theme toggle)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: context.textSecondary,
                                ),
                                tooltip: 'Back to Home',
                                onPressed: () => context.go('/'),
                              ),
                              const ThemeToggleButton(compact: true),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (!isWide) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (branding.hasCustomLogo)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: AppBrandingLogo(
                                      logoUrl: branding.logoUrl!,
                                      height: 36,
                                      padding: const EdgeInsets.all(4),
                                      borderRadius: BorderRadius.circular(10),
                                      whiteTile: true,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF05454),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        branding.name,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (branding.tagline.isNotEmpty)
                                        Text(
                                          branding.tagline,
                                          style: TextStyle(
                                            color: context.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                          ],

                          Text(
                            'Welcome back',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue watching',
                            style: TextStyle(color: context.textSecondary, fontSize: 15),
                          ),
                          const SizedBox(height: 32),

                          // Email field
                          _buildLabel(context, 'Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: ValidationHelper.validateEmail,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: _inputDecoration(
                              context: context,
                              hint: 'you@example.com',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          _buildLabel(context, 'Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            validator: ValidationHelper.validatePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: _inputDecoration(
                              context: context,
                              hint: '••••••••',
                              icon: Icons.lock_outlined,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureText = !_obscureText),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Error
                          if (authState.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF05454,
                                ).withValues(alpha: 0.12),
                                border: Border.all(
                                  color: const Color(
                                    0xFFF05454,
                                  ).withValues(alpha: 0.4),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFF05454),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFF05454),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Sign in button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF05454),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFF05454,
                                ).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: TextStyle(color: context.textSecondary),
                              ),
                              TextButton(
                                onPressed: () {
                                  final registerUri = Uri(
                                    path: '/register',
                                    queryParameters: widget.redirectTo == null
                                        ? null
                                        : {'redirectTo': widget.redirectTo!},
                                  );
                                  context.push(registerUri.toString());
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Color(0xFF1F9DCC),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: context.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textMuted),
      prefixIcon: Icon(icon, color: context.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.borderCol),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF1F9DCC), width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFF05454)),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFF05454), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFF05454)),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFF05454), size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
