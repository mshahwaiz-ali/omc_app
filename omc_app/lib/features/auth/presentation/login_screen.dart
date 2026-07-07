import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/omc_logo.dart';
import '../../../core/config/support_config.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

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

    final message = _normalizeLoginError(authState.message);

    setState(() {
      _submitted = false;
      _loginError = message;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(message),
        ),
      );
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
                    fontSize: 20,
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

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHeader(
                    title: 'Welcome back',
                    subtitle:
                        'Access your OMC services, requests and tax dashboard.',
                  ),
                  const SizedBox(height: 30),
                  PremiumCard(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
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
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
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
                              onPressed: isLoading
                                  ? null
                                  : _openForgotPasswordSupport,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (loginErrorMessage != null &&
                              loginErrorMessage.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _ErrorBanner(
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
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New to OMC?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.go('/signup'),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
        Icon(icon, size: 20, color: AppTheme.primaryRed),
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

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 172,
            height: 172,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(44),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.10),
                  blurRadius: 44,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: const OmcLogo.symbol(size: 148, borderRadius: 0),
          ),
        ),
        const SizedBox(height: 38),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 34,
            height: 1.06,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
