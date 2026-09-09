import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        builder: (sheetContext) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose an account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Select which OMC account you want to sign in to, then verify your fingerprint or face.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                for (final account in accounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 10,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(
                      account.identifier,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium,
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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need help signing in?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Use any of the support details below if the app or your account is not working.',
                style: Theme.of(context).textTheme.bodyMedium,
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
        _submitted || _guestSubmissionInFlight || _biometricSubmissionInFlight;
    final loginErrorMessage = _loginError ?? authState.message;

    return AuthEntryScaffold(
      key: OmcWidgetKeys.loginScreen,
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your OMC workspace.',
      footer: _LoginFooter(
        isLoading: isLoading,
        guestLoading: _guestSubmissionInFlight,
        onCreateAccount: () => context.go('/signup'),
        onActivateAccount: () => context.go('/activate-existing-account'),
        onGuest: _continueAsGuest,
        onHelp: _openSupport,
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
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
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
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
                  onPressed: isLoading
                      ? null
                      : () => context.go('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (loginErrorMessage != null &&
                  loginErrorMessage.trim().isNotEmpty) ...[
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
                        style: Theme.of(context).textTheme.bodySmall,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({
    required this.isLoading,
    required this.guestLoading,
    required this.onCreateAccount,
    required this.onActivateAccount,
    required this.onGuest,
    required this.onHelp,
  });

  final bool isLoading;
  final bool guestLoading;
  final VoidCallback onCreateAccount;
  final VoidCallback onActivateAccount;
  final VoidCallback onGuest;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'New to OMC?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: isLoading ? null : onCreateAccount,
              child: const Text('Create account'),
            ),
          ],
        ),
        TextButton(
          onPressed: isLoading ? null : onActivateAccount,
          child: const Text('Activate existing account'),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onGuest,
          icon: guestLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.explore_outlined),
          label: const Text('Continue as guest'),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: isLoading ? null : onHelp,
          icon: const Icon(Icons.support_agent_rounded, size: 19),
          label: const Text('Having trouble? Get help'),
        ),
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
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.infoSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
