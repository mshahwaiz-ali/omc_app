import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';

class CompleteCustomerActivationScreen extends ConsumerStatefulWidget {
  const CompleteCustomerActivationScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<CompleteCustomerActivationScreen> createState() =>
      _CompleteCustomerActivationScreenState();
}

class _CompleteCustomerActivationScreenState
    extends ConsumerState<CompleteCustomerActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _message = 'This activation link is invalid or has expired.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .completeCustomerActivation(
            token: token,
            password: _passwordController.text,
            confirmPassword: _confirmController.text,
          );

      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;

      final ok =
          data['ok'] == true ||
          data['ok'] == 1 ||
          data['ok']?.toString().toLowerCase() == 'true';

      if (!mounted) return;

      setState(() {
        _completed = ok;
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : ok
            ? 'Your OMC account is activated. You can sign in now.'
            : 'This activation link is invalid or has expired.';
      });
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Account not activated',
        fallbackMessage:
            'Your account could not be activated. Check the link and try again.',
      );

      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = widget.token.trim().isNotEmpty;

    if (!hasToken) {
      return AuthEntryScaffold(
        title: 'Invalid activation link',
        subtitle: 'This activation link is missing or no longer valid.',
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        child: PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link_off_rounded, size: 44),
              const SizedBox(height: 18),
              const Text(
                'Request a new activation email to continue securely.',
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Request New Link',
                icon: Icons.outgoing_mail,
                onPressed: () => context.go('/activate-existing-account'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return AuthEntryScaffold(
      title: _completed ? 'Account activated' : 'Create your password',
      subtitle: _completed
          ? 'Your existing OMC customer record is now linked to the app.'
          : 'Choose a secure password to finish activating your OMC account.',
      leading: IconButton(
        tooltip: 'Back to login',
        onPressed: _submitting ? null : () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: _completed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 44),
                  const SizedBox(height: 18),
                  Text(
                    _message ??
                        'Your OMC account is activated. You can sign in now.',
                  ),
                  const SizedBox(height: 22),
                  AppButton(
                    label: 'Continue to Login',
                    icon: Icons.login_rounded,
                    onPressed: () => context.go('/login'),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
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
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final required = _passwordValidator(value);
                        if (required != null) return required;

                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      AuthErrorBanner(message: _message!),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Activate Account',
                      icon: Icons.verified_user_outlined,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
