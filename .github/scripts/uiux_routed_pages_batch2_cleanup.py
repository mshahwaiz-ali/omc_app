from pathlib import Path

path = Path('omc_app/lib/features/documents/presentation/documents_screen.dart')
text = path.read_text()
line = "import '../../../app/design_tokens.dart';\n"
if text.count(line) != 1:
    raise SystemExit(f'documents design-token import: expected 1, found {text.count(line)}')
path.write_text(text.replace(line, '', 1))
