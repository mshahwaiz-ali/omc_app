from pathlib import Path


def add_import(path):
    p = Path(path)
    text = p.read_text()
    imp = "import '../../../core/widgets/app_labeled_field.dart';\n"
    anchor = "import '../../../app/theme.dart';\n"
    if imp in text:
        raise SystemExit(f'{path}: AppLabeledField import already present')
    if text.count(anchor) != 1:
        raise SystemExit(f'{path}: expected one theme import, found {text.count(anchor)}')
    p.write_text(text.replace(anchor, anchor + imp, 1))


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: {label}: expected one anchor, found {count}')
    p.write_text(text.replace(old, new, 1))
    print(f'{path}: {label}')


profile = 'omc_app/lib/features/profile/presentation/profile_v2_screen.dart'
settings = 'omc_app/lib/features/settings/presentation/settings_v2_screen.dart'
add_import(profile)
add_import(settings)

replace_once(
    profile,
    """class _ProfileSupportSheet extends StatelessWidget {
  const _ProfileSupportSheet({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Contact OMC support',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Describe the profile, login or account issue.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'How can OMC help?',
                        hintText:
                            'Example: I need help with my profile, login, or account.',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter at least 10 characters.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(text);
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Submit support request'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
""",
    """class _ProfileSupportSheet extends StatefulWidget {
  const _ProfileSupportSheet({required this.controller});
  final TextEditingController controller;

  @override
  State<_ProfileSupportSheet> createState() => _ProfileSupportSheetState();
}

class _ProfileSupportSheetState extends State<_ProfileSupportSheet> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Contact OMC support',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Describe the profile, login or account issue.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      AppLabeledField(
                        label: 'How can OMC help?',
                        isRequired: true,
                        child: TextFormField(
                          controller: widget.controller,
                          minLines: 4,
                          maxLines: 7,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: I need help with my profile, login, or account.',
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 10) {
                              return 'Enter at least 10 characters.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState?.validate() != true) return;
                          Navigator.of(context).pop(widget.controller.text.trim());
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Submit support request'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
""",
    'profile support inline validation',
)

replace_once(
    settings,
    """  Future<String?> _requestDeviceLockPassword(BuildContext context) async {
    var passwordValue = '';
    var obscure = true;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enable biometric sign in'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm your current OMC password. It will be protected by the device secure storage and used only after successful biometric authentication.',
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: obscure,
                  onChanged: (value) => passwordValue = value,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.of(dialogContext).pop(value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passwordValue.isNotEmpty) {
                  Navigator.of(dialogContext).pop(passwordValue);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
""",
    """  Future<String?> _requestDeviceLockPassword(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var passwordValue = '';
    var obscure = true;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enable biometric sign in'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirm your current OMC password. It will be protected by the device secure storage and used only after successful biometric authentication.',
                  ),
                  const SizedBox(height: 16),
                  AppLabeledField(
                    label: 'Current password',
                    isRequired: true,
                    child: TextFormField(
                      obscureText: obscure,
                      onChanged: (value) => passwordValue = value,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        if (formKey.currentState?.validate() != true) return;
                        Navigator.of(dialogContext).pop(value);
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Current password is required.'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(dialogContext).pop(passwordValue);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
""",
    'biometric password inline validation',
)

replace_once(
    settings,
    """class _AccountRequestSheet extends StatelessWidget {
  const _AccountRequestSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.controller,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: hint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(submitLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
""",
    """class _AccountRequestSheet extends StatefulWidget {
  const _AccountRequestSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.controller,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;
  final TextEditingController controller;

  @override
  State<_AccountRequestSheet> createState() => _AccountRequestSheetState();
}

class _AccountRequestSheetState extends State<_AccountRequestSheet> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      AppLabeledField(
                        label: widget.label,
                        isRequired: true,
                        child: TextFormField(
                          controller: widget.controller,
                          minLines: 4,
                          maxLines: 7,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(hintText: widget.hint),
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? 'Enter a reason or instruction.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState?.validate() != true) return;
                          Navigator.of(context).pop(widget.controller.text);
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
""",
    'account request inline validation',
)

test_path = Path('omc_app/test/features/uiux/live_sheet_validation_contract_test.dart')
if test_path.exists():
    raise SystemExit(f'{test_path}: already exists')
test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live profile and settings sheets use persistent inline validation', () {
    final profile = File(
      'lib/features/profile/presentation/profile_v2_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_v2_screen.dart',
    ).readAsStringSync();

    expect(profile, contains("label: 'How can OMC help?'"));
    expect(profile, contains("return 'Enter at least 10 characters.';"));
    expect(profile, isNot(contains("labelText: 'How can OMC help?'")));

    expect(settings, contains("label: 'Current password'"));
    expect(settings, contains("'Current password is required.'"));
    expect(settings, contains("label: widget.label"));
    expect(settings, contains("'Enter a reason or instruction.'"));
    expect(settings, isNot(contains("labelText: 'Current password'")));
    expect(settings, isNot(contains('labelText: label')));
  });
}
""")
print(f'created {test_path}')
