from pathlib import Path

tracker = Path("omc_app/lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart")
budget = Path("omc_app/lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 anchor, found {count}")
    return text.replace(old, new, 1)


def add_import(text, anchor, new_import, label):
    if new_import in text:
        return text
    return replace_once(text, anchor, anchor + new_import, label)


# ---------------- Tracker V2 ----------------
t = tracker.read_text()

t = add_import(
    t,
    "import '../../../core/widgets/app_button.dart';\n",
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "tracker AppLabeledField import",
)

old = """          content: SizedBox(
            width: AppLayout.formMaxWidth,
            child: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 12,
              enabled: !importing,
              decoration: const InputDecoration(
                labelText: 'Backup JSON',
                hintText: 'Paste exported JSON here...',
                alignLabelWithHint: true,
              ),
            ),
          ),"""
new = """          content: SizedBox(
            width: AppLayout.formMaxWidth,
            child: AppLabeledField(
              label: 'Backup JSON',
              child: TextField(
                controller: controller,
                minLines: 8,
                maxLines: 12,
                enabled: !importing,
                decoration: const InputDecoration(
                  hintText: 'Paste exported JSON here...',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),"""
t = replace_once(t, old, new, "tracker backup JSON field")

handle = """                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
"""
t = replace_once(t, handle, "", "tracker custom drag handle")

old = """                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          value?.replaceAll(',', '').trim() ?? '',
                        );
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount.';
                        }
                        return null;
                      },
                    ),"""
new = """                    AppLabeledField(
                      label: 'Amount',
                      isRequired: true,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) {
                          final amount = double.tryParse(
                            value?.replaceAll(',', '').trim() ?? '',
                          );
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount.';
                          }
                          return null;
                        },
                      ),
                    ),"""
t = replace_once(t, old, new, "tracker amount field")

old = """                    TextFormField(
                      controller: _categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _type == ExpenseTransactionType.income
                            ? 'Income category'
                            : 'Expense category',
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Category is required.'
                          : null,
                    ),"""
new = """                    AppLabeledField(
                      label: _type == ExpenseTransactionType.income
                          ? 'Income category'
                          : 'Expense category',
                      isRequired: true,
                      child: TextFormField(
                        controller: _categoryController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Category is required.'
                            : null,
                      ),
                    ),"""
t = replace_once(t, old, new, "tracker category field")

old = """                          DropdownButtonFormField<String>(
                            initialValue: _accountController.text.trim().isEmpty
                                ? 'Cash'
                                : _accountController.text.trim(),
                            decoration: const InputDecoration(
                              labelText: 'Account',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),"""
new = """                          AppLabeledField(
                            label: 'Account',
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _accountController.text.trim().isEmpty
                                  ? 'Cash'
                                  : _accountController.text.trim(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),"""
t = replace_once(t, old, new, "tracker account field start")

old = """                            onChanged: (value) {
                              if (value == null) return;
                              _markDirty();
                              _accountController.text = value;
                            },
                          ),
                          const SizedBox(height: 12),"""
new = """                              onChanged: (value) {
                                if (value == null) return;
                                _markDirty();
                                _accountController.text = value;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),"""
t = replace_once(t, old, new, "tracker account field end")

old = """                          DropdownButtonFormField<String>(
                            initialValue:
                                _paymentMethodController.text.trim().isEmpty
                                ? 'Cash'
                                : _paymentMethodController.text.trim(),
                            decoration: const InputDecoration(
                              labelText: 'Payment method',
                              prefixIcon: Icon(Icons.credit_card_rounded),
                            ),"""
new = """                          AppLabeledField(
                            label: 'Payment method',
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _paymentMethodController.text.trim().isEmpty
                                  ? 'Cash'
                                  : _paymentMethodController.text.trim(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.credit_card_rounded),
                              ),"""
t = replace_once(t, old, new, "tracker payment method field start")

old = """                            onChanged: (value) {
                              if (value == null) return;
                              _markDirty();
                              _paymentMethodController.text = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          _DatePickerField("""
new = """                              onChanged: (value) {
                                if (value == null) return;
                                _markDirty();
                                _paymentMethodController.text = value;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DatePickerField("""
t = replace_once(t, old, new, "tracker payment method field end")

old = """                          TextFormField(
                            controller: _merchantController,
                            decoration: const InputDecoration(
                              labelText: 'Merchant optional',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                          ),"""
new = """                          AppLabeledField(
                            label: 'Merchant optional',
                            child: TextFormField(
                              controller: _merchantController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                            ),
                          ),"""
t = replace_once(t, old, new, "tracker merchant field")

old = """                          TextFormField(
                            controller: _noteController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Note optional',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),"""
new = """                          AppLabeledField(
                            label: 'Note optional',
                            child: TextFormField(
                              controller: _noteController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),
                          ),"""
t = replace_once(t, old, new, "tracker note field")

old = """    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );"""
new = """    return AppLabeledField(
      label: 'Date',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          child: Text(
            DateFormat('dd MMM yyyy').format(date),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );"""
t = replace_once(t, old, new, "tracker date field")

if "labelText:" in t:
    raise SystemExit("tracker still contains floating InputDecoration labelText")
if t.count("AppLabeledField(") != 8:
    raise SystemExit(
        f"tracker AppLabeledField count={t.count('AppLabeledField(')}, expected 8"
    )
if "width: 42,\n                        height: 4," in t:
    raise SystemExit("tracker custom drag handle still present")

tracker.write_text(t)

# ---------------- Budget V2 ----------------
b = budget.read_text()

b = add_import(
    b,
    "import '../../../core/widgets/app_button.dart';\n",
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "budget AppLabeledField import",
)

handle = """                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
"""
b = replace_once(b, handle, "", "budget custom drag handle")

old = """                        TextField(
                          controller: categoryController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'Leave blank for overall budget',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),"""
new = """                        AppLabeledField(
                          label: 'Category',
                          child: TextField(
                            controller: categoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Leave blank for overall budget',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                          ),
                        ),"""
b = replace_once(b, old, new, "budget category field")

old = """                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Budget limit',
                            prefixText: 'PKR ',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ),"""
new = """                        AppLabeledField(
                          label: 'Budget limit',
                          isRequired: true,
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'PKR ',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                          ),
                        ),"""
b = replace_once(b, old, new, "budget amount field")

old = """                        TextField(
                          controller: thresholdController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Warning threshold',
                            suffixText: '%',
                            prefixIcon: Icon(Icons.warning_amber_rounded),
                            helperText:
                                'The saved threshold remains between 1% and 100%.',
                          ),
                        ),"""
new = """                        AppLabeledField(
                          label: 'Warning threshold',
                          child: TextField(
                            controller: thresholdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              suffixText: '%',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                              helperText:
                                  'The saved threshold remains between 1% and 100%.',
                            ),
                          ),
                        ),"""
b = replace_once(b, old, new, "budget threshold field")

if "labelText:" in b:
    raise SystemExit("budget still contains floating InputDecoration labelText")
if b.count("AppLabeledField(") != 3:
    raise SystemExit(
        f"budget AppLabeledField count={b.count('AppLabeledField(')}, expected 3"
    )
if "width: 42,\n                            height: 4," in b:
    raise SystemExit("budget custom drag handle still present")

budget.write_text(b)
