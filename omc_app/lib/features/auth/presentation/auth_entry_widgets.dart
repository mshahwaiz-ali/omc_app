import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/omc_logo.dart';

class AuthEntryScaffold extends StatelessWidget {
  const AuthEntryScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.footer,
    this.compactBrand = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? footer;
  final bool compactBrand;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFBFCFE);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        extendBody: false,
        extendBodyBehindAppBar: false,
        body: SafeArea(
          top: true,
          bottom: true,
          maintainBottomViewPadding: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pageInset = AppLayout.pageInsetFor(constraints.maxWidth);
              return Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    pageInset,
                    AppSpacing.md,
                    pageInset,
                    AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.formMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (leading != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: leading,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        AuthEntryHeader(
                          title: title,
                          subtitle: subtitle,
                          compact: compactBrand,
                        ),
                        SizedBox(
                          height: compactBrand
                              ? AppSpacing.xl
                              : AppSpacing.xxl,
                        ),
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
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
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 72 : 88,
          height: compact ? 72 : 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTheme.border),
          ),
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          child: OmcLogo.symbol(size: compact ? 48 : 56, borderRadius: 0),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        key: key ?? OmcWidgetKeys.loginError,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
