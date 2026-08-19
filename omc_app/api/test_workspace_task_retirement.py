import json
from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestWorkspaceTaskRetirement(FrappeTestCase):
    def test_desk_metadata_no_longer_exposes_legacy_task(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "setup" / "desk_metadata.py").read_text(
            encoding="utf-8"
        )
        self.assertNotIn('"OMC Task"', source)
        self.assertNotIn("'OMC Task'", source)

    def test_workspace_files_no_longer_link_to_legacy_task(self):
        app_root = Path(__file__).resolve().parents[1]
        candidates = [
            app_root / "fixtures" / "workspace.json",
            app_root / "omc_app" / "fixtures" / "workspace.json",
            app_root
            / "omc_app"
            / "workspace"
            / "omc_app"
            / "omc_app.json",
        ]

        found = 0
        for path in candidates:
            if not path.exists():
                continue

            found += 1
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertNotIn(
                '"link_to": "OMC Task"',
                json.dumps(data, ensure_ascii=False),
            )

        self.assertGreater(found, 0)

    def test_onboarding_shortcut_uses_explicit_desk_sync(self):
        app_root = Path(__file__).resolve().parents[1]
        desk_metadata = (app_root / "setup" / "desk_metadata.py").read_text(
            encoding="utf-8"
        )
        lifecycle = (app_root / "setup" / "lifecycle.py").read_text(
            encoding="utf-8"
        )
        operations = (app_root / "setup" / "operations.py").read_text(
            encoding="utf-8"
        )
        hooks = (app_root / "hooks.py").read_text(encoding="utf-8")

        self.assertIn("OMC Onboarding Slide", desk_metadata)
        self.assertNotIn("def after_sync():", lifecycle)
        self.assertNotIn("after_sync =", hooks)
        self.assertIn("def sync_desk_configuration", operations)
        self.assertIn("sync_desk_metadata()", operations)
