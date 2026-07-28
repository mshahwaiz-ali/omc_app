import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _loading = true;
  bool _activated = false;
  bool _canRetry = false;
  String _message = 'Verifying your email...';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_verify);
  }

  Future<void> _verify() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _canRetry = false;
        _message = 'This verification link is invalid or has expired.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _canRetry = false;
      _message = 'Verifying your email...';
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .verifyRegistration(token: token);
      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;
      final status = data['status']?.toString().trim().toLowerCase() ?? '';
      final ok =
          data['ok'] == true ||
          data['ok'] == 1 ||
          data['ok']?.toString().toLowerCase() == 'true';

      if (!mounted) return;

      setState(() {
        _loading = false;
        _activated = ok && status == 'activated';
        _canRetry = false;
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : _activated
            ? 'Your email is verified. You can sign in now.'
            : 'This verification link is invalid or has expired.';
      });
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Verification failed',
        fallbackMessage:
            'The verification link could not be processed. It may be invalid or expired.',
      );

      setState(() {
        _loading = false;
        _canRetry = true;
        _message = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthEntryScaffold(
      title: _activated ? 'Email verified' : 'Verify your email',
      subtitle: _activated
          ? 'Your OMC account is ready for sign in.'
          : 'We are checking the security link from your email.',
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Icon(
                _activated
                    ? Icons.mark_email_read_outlined
                    : Icons.link_off_rounded,
                size: 44,
                color: _activated
                    ? const Color(0xFF15803D)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(height: 18),
              Text(
                _message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              if (_canRetry) ...[
                AppButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _verify,
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(_activated ? 'Continue to Login' : 'Back to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
