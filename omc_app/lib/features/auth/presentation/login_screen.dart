import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/support_config.dart';
import '../../../core/widgets/app_button.dart';
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
  bool _guestSubmissionInFlight = false;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitted || _guestSubmissionInFlight) return;

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
        lower.contains('wrong') ||
        lower.contains('credential') ||
        lower.contains('user not found') ||
        lower.contains('unknown user') ||
        lower.contains('does not exist') ||
        lower.contains('account disabled') ||
        lower.contains('user disabled') ||
        lower.contains('not permitted') ||
        lower.contains('login failed')) {
      return 'Wrong email or password. Please try again.';
    }
    return 'Sign in could not be completed right now. Please try again.';
  }

  Future<void> _continueAsGuest() async {
    if (_submitted || _guestSubmissionInFlight) return;

    setState(() {
      _guestSubmissionInFlight = true;
      _loginError = null;
    });

    final started = await ref
        .read(authControllerProvider.notifier)
        .continueAsGuest();

    if (!mounted) return;
    if (started) {
      context.go('/home');
      return;
    }

    final authState = ref.read(authControllerProvider);
    setState(() {
      _guestSubmissionInFlight = false;
      _loginError =
          authState.message ??
          'Guest access could not be started right now. Please try again.';
    });
  }

  void _openSupport() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use any of the support details below if the app or your account is not working.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading =
        (_submitted && authState.status == AuthStatus.authenticating) ||
        _guestSubmissionInFlight;
    final loginErrorMessage = _loginError ?? authState.message;

    return AuthEntryScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your OMC workspace.',
      footer: _AuthFooter(
        text: 'New to OMC?',
        action: 'Create account',
        onTap: isLoading ? null : () => context.go('/signup'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
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
                onPressed: isLoading ? null : _openSupport,
                child: const Text('Forgot password?'),
              ),
            ),
            if (loginErrorMessage != null &&
                loginErrorMessage.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              AuthErrorBanner(message: _normalizeLoginError(loginErrorMessage)),
              const SizedBox(height: 16),
            ],
            AppButton(
              label: 'Sign in',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: isLoading ? null : _continueAsGuest,
              child: const Text('Continue as guest'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isLoading ? null : _openSupport,
              icon: const Icon(Icons.support_agent_rounded, size: 19),
              label: const Text('Having trouble? Get help'),
            ),
          ],
        ),
      ),
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
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primary),
          ),
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
      ),
    );
  }
}
