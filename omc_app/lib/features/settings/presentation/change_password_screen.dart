import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_entry_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _message;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredPassword(String? value, String label) {
    if (value == null || value.isEmpty) {
      return '$label is required.';
    }
    if (value.length > 128) {
      return '$label must be 128 characters or fewer.';
    }
    return null;
  }

  String? _newPasswordValidator(String? value) {
    final required = _requiredPassword(value, 'New password');
    if (required != null) return required;

    if (value!.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (value == _currentPasswordController.text) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          );

      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;
      final changed =
          data['changed'] == true ||
          data['changed'] == 1 ||
          data['changed']?.toString().toLowerCase() == 'true';

      if (!changed) {
        throw StateError(
          data['message']?.toString() ?? 'Password was not changed.',
        );
      }

      await ref.read(authControllerProvider.notifier).logout();

      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Password not changed',
        fallbackMessage:
            'Your password could not be changed. Check the current password and try again.',
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

  InputDecoration _passwordDecoration({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: _submitting ? null : onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _submitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 44),
                      const SizedBox(height: 16),
                      Text(
                        'Protect your OMC account',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your current password, then choose a new password. You will be signed out after the change.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        decoration: _passwordDecoration(
                          label: 'Current password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscureCurrent,
                          onToggle: () {
                            setState(() => _obscureCurrent = !_obscureCurrent);
                          },
                        ),
                        validator: (value) =>
                            _requiredPassword(value, 'Current password'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _passwordDecoration(
                          label: 'New password',
                          icon: Icons.password_rounded,
                          obscure: _obscureNew,
                          onToggle: () {
                            setState(() => _obscureNew = !_obscureNew);
                          },
                        ),
                        validator: _newPasswordValidator,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use at least 8 characters.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _passwordDecoration(
                          label: 'Confirm new password',
                          icon: Icons.lock_reset_outlined,
                          obscure: _obscureConfirm,
                          onToggle: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                        validator: (value) {
                          final required = _requiredPassword(
                            value,
                            'Password confirmation',
                          );
                          if (required != null) return required;
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        AuthErrorBanner(message: _message!),
                      ],
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'Change Password',
                        icon: Icons.lock_reset_rounded,
                        isLoading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
