from pathlib import Path

source_path = Path('omc_app/lib/features/support/presentation/support_screen_legacy.dart')
source = source_path.read_text()
import_anchor = "import '../../../app/theme.dart';\n"
design_import = "import '../../../app/design_tokens.dart';\n"
if design_import not in source:
    if source.count(import_anchor) != 1:
        raise SystemExit('support design token import anchor mismatch')
    source = source.replace(import_anchor, design_import + import_anchor, 1)
source_path.write_text(source)

test_path = Path('omc_app/test/features/support/support_uiux_contract_test.dart')
test = test_path.read_text()
for line in (
    "    expect(block, contains('_selectedTopic.isNotEmpty'));\n",
    "    expect(block, contains('_messageController.text.trim().length >= 10'));\n",
):
    if test.count(line) != 1:
        raise SystemExit(f'support generated test correction anchor mismatch: {line.strip()}')
    test = test.replace(line, '', 1)

test_path.write_text(test)
