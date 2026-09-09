part of 'service_request_draft_screen.dart';

class _DynamicFormCard extends StatelessWidget {
  const _DynamicFormCard({
    required this.fields,
    required this.remarksController,
    required this.controllerFor,
    required this.focusNodeFor,
    required this.selectValueFor,
    required this.checkedValueFor,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final List<ServiceTemplateField> fields;
  final TextEditingController remarksController;
  final TextEditingController Function(ServiceTemplateField field)
  controllerFor;
  final FocusNode Function(ServiceTemplateField field) focusNodeFor;
  final String? Function(ServiceTemplateField field) selectValueFor;
  final bool Function(ServiceTemplateField field) checkedValueFor;
  final void Function(ServiceTemplateField field, String? value)
  onSelectChanged;
  final void Function(ServiceTemplateField field, bool? value) onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Service information',
            subtitle: 'Add the information OMC needs to prepare this case.',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 18),
          for (final field in fields) ...[
            _DynamicField(
              field: field,
              controller: controllerFor(field),
              focusNode: focusNodeFor(field),
              selectValue: selectValueFor(field),
              checkedValue: checkedValueFor(field),
              onSelectChanged: (value) => onSelectChanged(field, value),
              onCheckChanged: (value) => onCheckChanged(field, value),
              requiredValidator: requiredValidator,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: remarksController,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Add anything else OMC should know.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.selectValue,
    required this.checkedValue,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final ServiceTemplateField field;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectValue;
  final bool checkedValue;
  final ValueChanged<String?> onSelectChanged;
  final ValueChanged<bool?> onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    final label = field.label.trim().isEmpty
        ? field.fieldname
        : field.label.trim();
    final helperText = field.description.trim().isEmpty
        ? null
        : field.description.trim();
    final theme = Theme.of(context);

    if (_isCheckField(field)) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          value: checkedValue,
          onChanged: onCheckChanged,
          title: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: helperText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    helperText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      );
    }

    if (_isSelectField(field) && field.options.isNotEmpty) {
      final selected = field.options.contains(selectValue) ? selectValue : null;
      return DropdownButtonFormField<String>(
        focusNode: focusNode,
        initialValue: selected,
        isExpanded: true,
        items: field.options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(growable: false),
        onChanged: onSelectChanged,
        decoration: InputDecoration(
          labelText: field.isRequired ? '$label *' : label,
          helperText: helperText,
          prefixIcon: const Icon(Icons.list_alt_outlined),
        ),
        validator: field.isRequired
            ? (value) => requiredValidator(value, label)
            : null,
      );
    }

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      minLines: _isLongTextField(field) ? 3 : 1,
      maxLines: _isLongTextField(field) ? 6 : 1,
      keyboardType: _keyboardTypeFor(field),
      inputFormatters: _inputFormattersFor(field),
      textInputAction: _isLongTextField(field)
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: field.isRequired ? '$label *' : label,
        hintText: field.placeholder.trim().isEmpty
            ? null
            : field.placeholder.trim(),
        helperText: helperText,
        alignLabelWithHint: _isLongTextField(field),
        prefixIcon: Icon(_iconFor(field)),
      ),
      validator: field.isRequired
          ? (value) => requiredValidator(value, label)
          : null,
    );
  }
}

class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.stages});

  final List<ServiceStageTemplate> stages;

  @override
  Widget build(BuildContext context) {
    final visibleStages =
        stages.where((stage) => stage.isCustomerVisible).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visibleStages.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.route_outlined,
            color: AppTheme.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          'What happens after submission',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${visibleStages.length} customer-visible service stage${visibleStages.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        children: [
          for (var index = 0; index < visibleStages.length; index++)
            _CompactStageRow(
              number: index + 1,
              stage: visibleStages[index],
              isLast: index == visibleStages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CompactStageRow extends StatelessWidget {
  const _CompactStageRow({
    required this.number,
    required this.stage,
    required this.isLast,
  });

  final int number;
  final ServiceStageTemplate stage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: AppTheme.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (stage.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      stage.description.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({required this.documents});

  final List<String> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Review before submit',
            subtitle:
                'This form creates the request only. Required documents are collected from the case screen after submission.',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No document upload happens on this form. Submit first, then follow the document requirements shown on the request.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Documents OMC may request',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < documents.length; index++) ...[
            _DocumentGuidanceRow(label: documents[index]),
            if (index != documents.length - 1)
              const Divider(height: 20, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _DocumentGuidanceRow extends StatelessWidget {
  const _DocumentGuidanceRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.description_outlined,
            color: AppTheme.textSecondary,
            size: 17,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitRequestBar extends StatelessWidget {
  const _SubmitRequestBar({
    required this.service,
    required this.completedFields,
    required this.totalFields,
    required this.attachmentCount,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final ServiceItem service;
  final int completedFields;
  final int totalFields;
  final int attachmentCount;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final _ = service;
    final remaining = (totalFields - completedFields).clamp(0, totalFields);
    final statusText = remaining == 0
        ? attachmentCount == 0
              ? 'Ready to submit'
              : '$attachmentCount file${attachmentCount == 1 ? '' : 's'} attached'
        : '$remaining detail${remaining == 1 ? '' : 's'} remaining';
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useStackedLayout =
                    constraints.maxWidth < 390 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.35;
                final status = Semantics(
                  liveRegion: true,
                  child: Text(
                    statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                );
                final button = AppButton(
                  label: 'Submit request',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onSubmit,
                );

                if (useStackedLayout) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [status, const SizedBox(height: 10), button],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 16),
                    SizedBox(width: 190, child: button),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _serviceIcon(String? key) {
  return switch ((key ?? '').trim().toLowerCase()) {
    'business_setup' => Icons.domain_add_outlined,
    'company_registration' => Icons.apartment_outlined,
    'tax_filing' => Icons.receipt_long_outlined,
    'tax_registration' => Icons.how_to_reg_outlined,
    'gst' => Icons.request_quote_outlined,
    'accounting' => Icons.calculate_outlined,
    'audit' => Icons.fact_check_outlined,
    'payroll' => Icons.groups_outlined,
    'legal' => Icons.gavel_outlined,
    _ => Icons.work_outline_rounded,
  };
}

bool _isSelectField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'select' || type == 'autocomplete' || type == 'link';
}

bool _isCheckField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'check' || type == 'checkbox' || type == 'boolean';
}

bool _isLongTextField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type.contains('text') ||
      type == 'textarea' ||
      type == 'long text' ||
      type == 'small text';
}

TextInputType _keyboardTypeFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('email') || name.contains('email')) {
    return TextInputType.emailAddress;
  }
  if (type.contains('phone') ||
      name.contains('phone') ||
      name.contains('mobile')) {
    return TextInputType.phone;
  }
  if (type.contains('int') ||
      type.contains('currency') ||
      type.contains('float') ||
      type.contains('number')) {
    return TextInputType.number;
  }
  if (_isLongTextField(field)) return TextInputType.multiline;
  return TextInputType.text;
}

List<TextInputFormatter> _inputFormattersFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  if (type.contains('int') || type == 'number') {
    return [FilteringTextInputFormatter.digitsOnly];
  }
  return const [];
}

IconData _iconFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('date') || name.contains('date')) {
    return Icons.event_outlined;
  }
  if (type.contains('email') || name.contains('email')) {
    return Icons.email_outlined;
  }
  if (type.contains('phone') || name.contains('phone')) {
    return Icons.phone_outlined;
  }
  if (type.contains('currency') ||
      name.contains('amount') ||
      name.contains('fee')) {
    return Icons.payments_outlined;
  }
  if (type.contains('int') || type.contains('number')) {
    return Icons.numbers_outlined;
  }
  if (_isLongTextField(field)) return Icons.notes_outlined;
  return Icons.edit_outlined;
}
