from pathlib import Path

path = Path("omc_app/test/features/admin_control/admin_operations_contract_test.dart")
text = path.read_text()

old = """      expect(screen, contains('Review remarks (required)'));
"""
new = """      expect(screen, contains("label: 'Review remarks'"));
      expect(screen, contains('isRequired: approve == false'));
      expect(
        screen,
        contains('(approve == false && remarks.text.trim().isEmpty)'),
      );
"""

if text.count(old) != 1:
    raise SystemExit(
        f"stale admin remarks expectation count={text.count(old)}, expected 1"
    )
text = text.replace(old, new, 1)
path.write_text(text)
