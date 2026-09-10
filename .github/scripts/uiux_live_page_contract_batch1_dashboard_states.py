from pathlib import Path

path = Path('omc_app/lib/features/dashboard/presentation/dashboard_screen.dart')
text = path.read_text()
old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
'''
new = '''    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
'''
count = text.count(old)
if count != 2:
    raise SystemExit(f'dashboard state page anchors: expected 2, found {count}')
path.write_text(text.replace(old, new))
