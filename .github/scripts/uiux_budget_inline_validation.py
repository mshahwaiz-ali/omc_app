from pathlib import Path

path = Path("omc_app/lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart")
text = path.read_text()


def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 anchor, found {count}")
    text = text.replace(old, new, 1)


replace_once(
    "    final dirtyFormController = DirtyFormController();\n",
    "    final dirtyFormController = DirtyFormController();\n"
    "    final amountFieldKey = GlobalKey<FormFieldState<String>>();\n",
    "amount field key",
)

old = """                          child: TextField(
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
                          ),"""
new = """                          child: TextFormField(
                            key: amountFieldKey,
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
                            validator: (value) {
                              final amount =
                                  double.tryParse(value?.trim() ?? '') ?? 0;
                              return amount <= 0
                                  ? 'Enter a valid budget amount.'
                                  : null;
                            },
                          ),"""
replace_once(old, new, "budget amount TextFormField")

old = """                          onPressed: () async {
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                0;
                            final threshold =
                                double.tryParse(
                                  thresholdController.text.trim(),
                                ) ??
                                80;
                            if (amount <= 0) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid budget amount.'),
                                ),
                              );
                              return;
                            }

                            final payload = <String, dynamic>{"""
new = """                          onPressed: () async {
                            if (!(amountFieldKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                0;
                            final threshold =
                                double.tryParse(
                                  thresholdController.text.trim(),
                                ) ??
                                80;

                            final payload = <String, dynamic>{"""
replace_once(old, new, "budget submit validation")

if text.count("Enter a valid budget amount.") != 1:
    raise SystemExit("budget amount error must exist exactly once as inline validator")
if "amountFieldKey.currentState?.validate()" not in text:
    raise SystemExit("budget submit is not validating the inline amount field")
if "limit_amount': amount" not in text or "'alert_threshold': threshold.clamp(1, 100)" not in text:
    raise SystemExit("budget payload semantics were unexpectedly changed")

path.write_text(text)
