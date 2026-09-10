import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import 'auth_entry_widgets.dart';

class SignupProgress extends StatelessWidget {
  const SignupProgress({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Access type',
      'Basic details',
      'Preferences',
      'Verification',
    ];
    final active = labels[step];

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Step ${step + 1} of ${labels.length}: $active',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Step ${step + 1} of ${labels.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(active, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (step + 1) / labels.length,
                minHeight: 7,
                backgroundColor: AppTheme.processingSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignupRoleStep extends StatelessWidget {
  const SignupRoleStep({
    super.key,
    required this.formKey,
    required this.roles,
    required this.selectedRole,
    required this.selectedOnboardingMode,
    required this.onOnboardingModeChanged,
    required this.onRoleChanged,
  });

  final GlobalKey<FormState> formKey;
  final List<String> roles;
  final String selectedRole;
  final String selectedOnboardingMode;
  final ValueChanged<String> onOnboardingModeChanged;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'Choose account access',
            subtitle:
                'Select the account type that matches how you will use OMC.',
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final role in roles) ...[
            SignupRoleCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => onRoleChanged(role),
            ),
            if (role == 'Customer' && selectedRole == 'Customer') ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Customer relationship',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'New Customer',
                    label: Text('New to OMC'),
                  ),
                  ButtonSegment(
                    value: 'Existing Customer Claim',
                    label: Text('Existing customer'),
                  ),
                ],
                selected: {selectedOnboardingMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onOnboardingModeChanged(selection.first);
                  }
                },
              ),
            ],
            if (role != roles.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class SignupDetailsStep extends StatelessWidget {
  const SignupDetailsStep({
    super.key,
    required this.formKey,
    required this.selectedRole,
    required this.selectedOnboardingMode,
    required this.fullNameController,
    required this.emailController,
    required this.usernameController,
    required this.onUsernameChanged,
    required this.onSuggestUsername,
    required this.onCheckUsername,
    required this.usernameValidator,
    required this.usernameAvailable,
    required this.usernameMessage,
    required this.isCheckingUsername,
    required this.mobileController,
    required this.whatsappController,
    required this.cnicController,
    required this.ntnController,
    required this.addressController,
    required this.educationController,
    required this.experienceController,
    required this.remarksController,
    required this.whatsappSameAsMobile,
    required this.onWhatsappSameAsMobileChanged,
    required this.onMobileChanged,
    required this.requiredValidator,
    required this.emailValidator,
    required this.phoneValidator,
    required this.cnicValidator,
    required this.ntnValidator,
  });

  final GlobalKey<FormState> formKey;
  final String selectedRole;
  final String selectedOnboardingMode;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final ValueChanged<String> onUsernameChanged;
  final VoidCallback onSuggestUsername;
  final Future<bool> Function() onCheckUsername;
  final String? Function(String?) usernameValidator;
  final bool? usernameAvailable;
  final String? usernameMessage;
  final bool isCheckingUsername;
  final TextEditingController mobileController;
  final TextEditingController whatsappController;
  final TextEditingController cnicController;
  final TextEditingController ntnController;
  final TextEditingController addressController;
  final TextEditingController educationController;
  final TextEditingController experienceController;
  final TextEditingController remarksController;
  final bool whatsappSameAsMobile;
  final ValueChanged<bool> onWhatsappSameAsMobileChanged;
  final ValueChanged<String> onMobileChanged;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?, String) phoneValidator;
  final String? Function(String?) cnicValidator;
  final String? Function(String?) ntnValidator;

  @override
  Widget build(BuildContext context) {
    final isTaxAssociate = selectedRole == 'Tax Associate';
    final isExistingCustomerClaim =
        selectedOnboardingMode == 'Existing Customer Claim';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'Basic information',
            subtitle: 'Enter the details OMC needs to identify your account.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SignupFieldLabel('Full name'),
          TextFormField(
            controller: fullNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Full name'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SignupFieldLabel('Email'),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'Enter your email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: emailValidator,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SignupFieldLabel('Username'),
          TextFormField(
            controller: usernameController,
            onChanged: onUsernameChanged,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'ali.khan',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: usernameController.text.trim().isEmpty
                          ? 'Suggest username'
                          : 'Check username',
                      onPressed: usernameController.text.trim().isEmpty
                          ? onSuggestUsername
                          : () => onCheckUsername(),
                      icon: Icon(
                        usernameAvailable == true
                            ? Icons.check_circle_rounded
                            : Icons.verified_outlined,
                      ),
                    ),
            ),
            validator: usernameValidator,
          ),
          if (usernameMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InlineValidationMessage(
              message: usernameMessage!,
              success: usernameAvailable == true,
              error: usernameAvailable == false,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SignupFieldLabel('Mobile number'),
          TextFormField(
            controller: mobileController,
            keyboardType: TextInputType.phone,
            onChanged: onMobileChanged,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(
              hintText: '300 1234567',
              counterText: '',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+92 ',
            ),
            validator: (value) => phoneValidator(value, 'Mobile number'),
          ),
          const SizedBox(height: AppSpacing.xs),
          CheckboxListTile(
            value: whatsappSameAsMobile,
            onChanged: (value) => onWhatsappSameAsMobileChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use this number for WhatsApp'),
          ),
          if (!whatsappSameAsMobile) ...[
            const SizedBox(height: AppSpacing.xs),
            const _SignupFieldLabel('WhatsApp number'),
            TextFormField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: const InputDecoration(
                hintText: '300 1234567',
                counterText: '',
                prefixIcon: Icon(Icons.chat_outlined),
                prefixText: '+92 ',
              ),
              validator: (value) => phoneValidator(value, 'WhatsApp number'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SignupFieldLabel('CNIC'),
          TextFormField(
            controller: cnicController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(
              hintText: '35202-1234567-1',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            validator: cnicValidator,
          ),
          if (isExistingCustomerClaim) ...[
            const SizedBox(height: AppSpacing.md),
            const _SignupFieldLabel('NTN'),
            TextFormField(
              controller: ntnController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              maxLength: 7,
              decoration: const InputDecoration(
                hintText: '1234567',
                counterText: '',
                prefixIcon: Icon(Icons.business_outlined),
                helperText:
                    'Existing customers may use either CNIC or 7-digit NTN.',
              ),
              validator: ntnValidator,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SignupFieldLabel('Address'),
          TextFormField(
            controller: addressController,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter your address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Address'),
          ),
          if (isTaxAssociate) ...[
            const SizedBox(height: AppSpacing.xl),
            const SignupStepTitle(
              title: 'Professional details',
              subtitle: 'These details support OMC’s access review.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _SignupFieldLabel('Education'),
            TextFormField(
              controller: educationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Enter education details',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Education'),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SignupFieldLabel('Experience'),
            TextFormField(
              controller: experienceController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Enter experience details',
                prefixIcon: Icon(Icons.timeline_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Experience'),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SignupFieldLabel('Remarks'),
            TextFormField(
              controller: remarksController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add relevant remarks',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Remarks'),
            ),
          ],
        ],
      ),
    );
  }
}

class SignupPreferencesStep extends StatelessWidget {
  const SignupPreferencesStep({
    super.key,
    required this.formKey,
    required this.isCustomer,
    required this.acquisitionSources,
    required this.selectedAcquisitionSource,
    required this.onAcquisitionSourceChanged,
    required this.referralExpanded,
    required this.onReferralExpandedChanged,
    required this.referralCodeController,
    required this.acquisitionSourceDetailController,
    required this.referralAssistanceConsent,
    required this.onReferralConsentChanged,
    required this.referralCodeValid,
    required this.referralValidationMessage,
    required this.isValidatingReferral,
    required this.onValidateReferral,
    required this.requiredValidator,
  });

  final GlobalKey<FormState> formKey;
  final bool isCustomer;
  final List<String> acquisitionSources;
  final String? selectedAcquisitionSource;
  final ValueChanged<String?> onAcquisitionSourceChanged;
  final bool referralExpanded;
  final ValueChanged<bool> onReferralExpandedChanged;
  final TextEditingController referralCodeController;
  final TextEditingController acquisitionSourceDetailController;
  final bool referralAssistanceConsent;
  final ValueChanged<bool> onReferralConsentChanged;
  final bool? referralCodeValid;
  final String? referralValidationMessage;
  final bool isValidatingReferral;
  final Future<bool> Function() onValidateReferral;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignupStepTitle(
            title: isCustomer
                ? 'Referral and preferences'
                : 'Staff access review',
            subtitle: isCustomer
                ? 'Add a referral if you have one, then tell us how you heard about OMC.'
                : 'This is an application. Email verification does not approve or grant staff access.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!isCustomer)
            const SignupReviewNotice()
          else ...[
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: referralExpanded,
                onExpansionChanged: onReferralExpandedChanged,
                tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppTheme.border),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppTheme.border),
                ),
                title: Text(
                  'Have a referral code?',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: const Text('Add and verify it here.'),
                children: [
                  const _SignupFieldLabel('Referral code'),
                  TextFormField(
                    controller: referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 -]'),
                      ),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: (value) {
                      final compact = value.toUpperCase().replaceAll(
                        RegExp(r'[^A-Z0-9]'),
                        '',
                      );
                      final normalized = compact.length <= 3
                          ? compact
                          : '${compact.substring(0, 3)}-${compact.substring(3)}';
                      if (normalized != value) {
                        referralCodeController.value = TextEditingValue(
                          text: normalized,
                          selection: TextSelection.collapsed(
                            offset: normalized.length,
                          ),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'OMC-XXXXXX',
                      prefixIcon: const Icon(
                        Icons.confirmation_number_outlined,
                      ),
                      suffixIcon: isValidatingReferral
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Verify referral code',
                              onPressed: () => onValidateReferral(),
                              icon: const Icon(Icons.verified_outlined),
                            ),
                    ),
                    validator: referralExpanded
                        ? (value) => requiredValidator(value, 'Referral code')
                        : null,
                  ),
                  if (referralValidationMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _InlineValidationMessage(
                      message: referralValidationMessage!,
                      success: referralCodeValid == true,
                      error: referralCodeValid != true,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  CheckboxListTile(
                    value: referralAssistanceConsent,
                    onChanged: (value) =>
                        onReferralConsentChanged(value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Allow the referring OMC staff member to assist with my service requests.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SignupFieldLabel('How did you hear about OMC?'),
            DropdownButtonFormField<String>(
              initialValue: selectedAcquisitionSource,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Choose a source',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
              items: acquisitionSources
                  .map(
                    (source) => DropdownMenuItem<String>(
                      value: source,
                      child: Text(source),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onAcquisitionSourceChanged,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please select a source.'
                  : null,
            ),
            if (selectedAcquisitionSource == 'Other') ...[
              const SizedBox(height: AppSpacing.md),
              const _SignupFieldLabel('Please specify'),
              TextFormField(
                controller: acquisitionSourceDetailController,
                decoration: const InputDecoration(
                  hintText: 'Tell us how you heard about OMC',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
                validator: (value) =>
                    requiredValidator(value, 'Source details'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class SignupSecurityStep extends StatelessWidget {
  const SignupSecurityStep({
    super.key,
    required this.formKey,
    required this.isCustomer,
    required this.acceptedTerms,
    required this.onTermsChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool isCustomer;
  final bool acceptedTerms;
  final ValueChanged<bool?>? onTermsChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignupStepTitle(
            title: isCustomer
                ? 'Review and verify your email'
                : 'Verify and submit your application',
            subtitle: isCustomer
                ? 'OMC will email a single-use verification link. You will create your password only after opening that verified link.'
                : 'OMC will email a single-use verification link. After verification, your staff access application is submitted for separate OMC review.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SecurityNotice(),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: AppTheme.cardSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: acceptedTerms,
              onChanged: onTermsChanged,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                isCustomer
                    ? 'I confirm my details are correct and agree to verify my email before my OMC customer account is created.'
                    : 'I confirm my details are correct and understand that email verification submits my staff access application for OMC review; it does not grant staff permissions.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          if (!isCustomer) ...[
            const SizedBox(height: AppSpacing.sm),
            const SignupReviewNotice(),
          ],
        ],
      ),
    );
  }
}

class SignupBottomActions extends StatelessWidget {
  const SignupBottomActions({
    super.key,
    required this.step,
    required this.isSubmitting,
    required this.onBack,
    required this.onContinue,
  });

  final int step;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isLast = step == 3;
    final stack =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final primary = AppButton(
      label: isLast ? 'Send verification email' : 'Continue',
      icon: isLast
          ? Icons.mark_email_unread_outlined
          : Icons.arrow_forward_rounded,
      isLoading: isSubmitting,
      onPressed: isSubmitting ? null : onContinue,
    );

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = AppLayout.pageInsetFor(constraints.maxWidth);
          return Container(
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpacing.sm,
              inset,
              AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
                child: step == 0
                    ? primary
                    : stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          primary,
                          const SizedBox(height: AppSpacing.xs),
                          TextButton(
                            onPressed: isSubmitting ? null : onBack,
                            child: const Text('Back'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : onBack,
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(flex: 2, child: primary),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SignupStepTitle extends StatelessWidget {
  const SignupStepTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class SignupRoleCard extends StatelessWidget {
  const SignupRoleCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final data = switch (role) {
      'Consultant' => (
        Icons.support_agent_rounded,
        'Apply for consultant staff access.',
      ),
      'Business Partner' => (
        Icons.handshake_outlined,
        'Apply for business partner staff access.',
      ),
      'Tax Associate' => (
        Icons.calculate_outlined,
        'Apply for tax associate staff access.',
      ),
      _ => (
        Icons.person_outline_rounded,
        'Create an account to request and track OMC services.',
      ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '$role. ${data.$2}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: AppMotion.durationFor(context, AppMotion.quick),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.07)
                : AppTheme.cardSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? accent : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data.$1,
                color: selected ? accent : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(data.$2, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupReviewNotice extends StatelessWidget {
  const SignupReviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'This is a staff access application. OMC reviews it separately after email verification, and protected staff permissions are never enabled automatically.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignupLoginFooter extends StatelessWidget {
  const SignupLoginFooter({super.key, required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Already registered?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: isSubmitting ? null : () => context.go('/login'),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key, required this.isCustomer});

  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    return AuthEntryScaffold(
      title: isCustomer
          ? 'Customer account created'
          : 'Staff access application submitted',
      subtitle: isCustomer
          ? 'Your customer account is active. You can sign in now.'
          : 'OMC will review your application before protected staff access is enabled.',
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.success,
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isCustomer
                  ? 'Your account is ready.'
                  : 'We received your application.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isCustomer
                  ? 'Sign in to request services, upload documents and track your cases.'
                  : 'Staff permissions remain disabled until OMC completes its access review.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Go to login',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupFieldLabel extends StatelessWidget {
  const _SignupFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _InlineValidationMessage extends StatelessWidget {
  const _InlineValidationMessage({
    required this.message,
    required this.success,
    required this.error,
  });

  final String message;
  final bool success;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? AppTheme.success
        : error
        ? AppTheme.danger
        : AppTheme.textSecondary;
    final icon = success
        ? Icons.check_circle_outline_rounded
        : error
        ? Icons.error_outline_rounded
        : Icons.info_outline_rounded;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.success,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'No password is collected or stored before email verification. After verification, the secure link asks you to set and confirm a new password.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
