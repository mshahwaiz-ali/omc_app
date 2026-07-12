import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/omc_logo.dart';

class AuthEntryScaffold extends StatelessWidget {
  const AuthEntryScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null) ...[
                    Align(alignment: Alignment.centerLeft, child: leading),
                    const SizedBox(height: 8),
                  ],
                  AuthEntryHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: 24),
                  child,
                  if (footer != null) ...[const SizedBox(height: 18), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthEntryHeader extends StatelessWidget {
  const AuthEntryHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE8EDF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: const OmcLogo.symbol(size: 90, borderRadius: 0),
        ),
        const SizedBox(height: 18),
        const OmcLogo.full(width: 174, height: 56),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 31,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            AuthPill(icon: Icons.verified_user_outlined, label: 'Secure'),
            AuthPill(icon: Icons.work_outline_rounded, label: 'Services'),
            AuthPill(icon: Icons.support_agent_rounded, label: 'Support'),
          ],
        ),
      ],
    );
  }
}

class AuthPill extends StatelessWidget {
  const AuthPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EAF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
