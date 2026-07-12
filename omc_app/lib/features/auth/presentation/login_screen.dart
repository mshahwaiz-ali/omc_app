import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/support_config.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'auth_entry_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitted = false;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _submitted = true;
      _loginError = null;
    });

    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go('/home');
      return;
    }

    setState(() {
      _submitted = false;
      _loginError = _normalizeLoginError(authState.message);
    });
  }

  String _normalizeLoginError(String? message) {
    final value = message?.trim() ?? '';
    final lower = value.toLowerCase();

    if (value.isEmpty ||
        lower.contains('authentication') ||
        lower.contains('unauthorized') ||
        lower.contains('incorrect') ||
        lower.contains('invalid') ||
        lower.contains('not permitted') ||
        lower.contains('login failed')) {
      return 'Wrong email or password. Please try again.';
    }

    return value;
  }

  void _openForgotPasswordSupport() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help signing in?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contact OMC support to reset your password or secure your account.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _SupportContactRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: SupportConfig.email,
                ),
                const SizedBox(height: 10),
                _SupportContactRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone / WhatsApp',
                  value: SupportConfig.phoneNumber,
                ),
                const SizedBox(height: 10),
                _SupportContactRow(
                  icon: Icons.schedule_rounded,
                  label: 'Business hours',
                  value: SupportConfig.businessHours,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _continueAsGuest() async {
    await ref.read(authControllerProvider.notifier).continueAsGuest();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading =
        _submitted && authState.status == AuthStatus.authenticating;
    final loginErrorMessage = _loginError ?? authState.message;

    return AuthEntryScaffold(
      title: 'Welcome back',
      subtitle: 'Access your services, documents, payments and OMC updates.',
      footer: _AuthFooter(
        text: 'New to OMC?',
        action: 'Create account',
        onTap: isLoading ? null : () => context.go('/signup'),
      ),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AuthModeHeader(),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Email or username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email or username is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _openForgotPasswordSupport,
                  child: const Text('Forgot password?'),
                ),
              ),
              if (loginErrorMessage != null &&
                  loginErrorMessage.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                AuthErrorBanner(
                  message: _normalizeLoginError(loginErrorMessage),
                ),
                const SizedBox(height: 14),
              ],
              AppButton(
                label: 'Login',
                icon: Icons.login_rounded,
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _continueAsGuest,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Continue as Guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeHeader extends StatelessWidget {
  const _AuthModeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: const Row(
        children: [
          _ModeIcon(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure account access',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Login to manage active work and protected tools.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.shield_outlined, color: AppTheme.primary),
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter({
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _SupportContactRow extends StatelessWidget {
  const _SupportContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
