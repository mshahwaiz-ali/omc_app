import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/config/support_config.dart';
import '../../../core/widgets/app_button.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../../device_lock/data/device_lock_service.dart';
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
  bool _biometricSubmissionInFlight = false;
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
      context.go(authState.capabilities.isPending ? '/under-review' : '/home');
      return;
    }

    setState(() {
      _submitted = false;
      _loginError = _normalizeLoginError(authState.message);
    });
  }

  Future<void> _signInWithBiometrics() async {
    if (_submitted ||
        _guestSubmissionInFlight ||
        _biometricSubmissionInFlight) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _biometricSubmissionInFlight = true;
      _loginError = null;
    });

    final accounts = await ref.read(deviceLockServiceProvider).accounts();

    if (!mounted) return;

    if (accounts.isEmpty) {
      setState(() {
        _biometricSubmissionInFlight = false;
        _loginError =
            'No account is registered for biometric sign in on this device.';
      });
      return;
    }

    String? selectedIdentifier;

    if (accounts.length == 1) {
      selectedIdentifier = accounts.single.identifier;
    } else {
      selectedIdentifier = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose an account',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select which OMC account you want to sign in to, then verify your fingerprint or face.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                for (final account in accounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(
                      account.identifier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetContext).pop(account.identifier);
                    },
                  ),
              ],
            ),
          );
        },
      );
    }

    if (!mounted) return;

    if (selectedIdentifier == null || selectedIdentifier.trim().isEmpty) {
      setState(() {
        _biometricSubmissionInFlight = false;
      });
      return;
    }

    final authenticated = await ref
        .read(authControllerProvider.notifier)
        .loginWithBiometrics(selectedIdentifier);

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);

    if (authenticated && authState.status == AuthStatus.authenticated) {
      context.go(authState.capabilities.isPending ? '/under-review' : '/home');
      return;
    }

    setState(() {
      _biometricSubmissionInFlight = false;
      _loginError =
          'Biometric sign in was not completed. '
          'Try again or sign in with your password.';
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
      return 'Wrong login details or password. Please try again.';
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
    final biometricAvailable =
        ref.watch(biometricLoginAvailableProvider).value ?? false;
    final isLoading =
        (_submitted && authState.status == AuthStatus.authenticating) ||
        _guestSubmissionInFlight ||
        _biometricSubmissionInFlight;
    final loginErrorMessage = _loginError ?? authState.message;

    return AuthEntryScaffold(
      key: OmcWidgetKeys.loginScreen,
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
              key: OmcWidgetKeys.loginIdentifier,
              controller: _emailController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(
                labelText: 'Email, username, mobile or CNIC',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email, username, mobile or CNIC is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: OmcWidgetKeys.loginPassword,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go('/activate-existing-account'),
                  child: const Text('Activate existing account'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            if (loginErrorMessage != null &&
                loginErrorMessage.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              AuthErrorBanner(message: _normalizeLoginError(loginErrorMessage)),
              const SizedBox(height: 16),
            ],
            AppButton(
              key: OmcWidgetKeys.loginSubmit,
              label: 'Sign in',
              isLoading: isLoading && !_biometricSubmissionInFlight,
              onPressed: isLoading ? null : _submit,
            ),
            if (biometricAvailable) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _signInWithBiometrics,
                icon: _biometricSubmissionInFlight
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: const Text('Sign in with biometrics'),
              ),
            ],
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
