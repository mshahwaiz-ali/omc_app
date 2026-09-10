from pathlib import Path

path = Path('omc_app/lib/features/notifications/presentation/notifications_screen.dart')
text = path.read_text()
anchor = "import '../../../core/widgets/app_state.dart';\n"
addition = anchor + "import '../../../core/widgets/omc_premium.dart';\n"
if "import '../../../core/widgets/omc_premium.dart';" not in text:
    if text.count(anchor) != 1:
        raise SystemExit('notifications import anchor mismatch')
    text = text.replace(anchor, addition, 1)
path.write_text(text)
