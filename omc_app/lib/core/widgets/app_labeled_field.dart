import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class AppLabeledField extends StatelessWidget {
  const AppLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  final String label;
  final Widget child;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
