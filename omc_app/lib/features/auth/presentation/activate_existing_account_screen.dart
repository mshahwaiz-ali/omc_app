import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';

class ActivateExistingAccountScreen extends ConsumerStatefulWidget {
  const ActivateExistingAccountScreen({super.key});

  @override
  ConsumerState<ActivateExistingAccountScreen> createState() =>
      _ActivateExistingAccountScreenState();
}

class _ActivateExistingAccountScreenState
    extends ConsumerState<ActivateExistingAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
          .requestCustomerActivation(email: _emailController.text.trim());

      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;

      if (!mounted) return;

      setState(() {
        _submitted = true;
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : 'If an eligible imported OMC customer account matches this email, activation instructions will be sent shortly.';
      });
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Activation request not completed',
        fallbackMessage:
            'Account activation instructions could not be requested right now.',
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
    return AuthEntryScaffold(
      title: _submitted ? 'Check your email' : 'Activate existing account',
      subtitle: _submitted
          ? 'If an eligible imported OMC customer account matches this email, activation instructions will be sent shortly.'
          : 'Already an OMC customer? Enter the email registered with OMC to activate app access.',
      leading: IconButton(
        tooltip: 'Back to login',
        onPressed: _submitting ? null : () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: PremiumCard(
        padding: const EdgeInsets.all(20),
        child: _submitted
            ? Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppTheme.info,
                      size: 40,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Activation request received',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message ??
                          'If an eligible imported OMC customer account matches this email, activation instructions will be sent shortly.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Opening an activation link is still required before app access is created. This screen does not sign you in automatically.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Back to login',
                      icon: Icons.login_rounded,
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Registered email',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the email already attached to your existing OMC customer record.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Registered email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Enter your registered email.';
                        }
                        if (!email.contains('@')) {
                          return 'Enter a valid email address.';
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
                      label: 'Send activation link',
                      icon: Icons.outgoing_mail,
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
