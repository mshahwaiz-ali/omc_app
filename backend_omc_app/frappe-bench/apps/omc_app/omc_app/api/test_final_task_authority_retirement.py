from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestFinalTaskAuthorityRetirement(FrappeTestCase):
    def test_runtime_sources_do_not_reference_legacy_task(self):
        app_root = Path(__file__).resolve().parents[1]
        allowed = {
            app_root / "patches" / "remove_legacy_omc_task.py",
            app_root / "api" / "test_legacy_task_doctype_retirement.py",
            app_root / "api" / "test_legacy_task_hook_retirement.py",
            app_root / "api" / "test_legacy_task_permission_code_retirement.py",
            app_root / "api" / "test_legacy_task_role_retirement.py",
            app_root / "api" / "test_workspace_task_retirement.py",
        }

        offenders = []
        for path in app_root.rglob("*"):
            if not path.is_file():
                continue
            if path in allowed:
                continue
            if path.suffix not in {".py", ".json", ".js", ".txt"}:
                continue
            if "__pycache__" in path.parts:
                continue

            source = path.read_text(encoding="utf-8", errors="ignore")
            legacy_name = "OMC" + " Task"
            if legacy_name in source:
                offenders.append(str(path.relative_to(app_root)))

        self.assertEqual(offenders, [])

    def test_flutter_sources_do_not_reference_legacy_task(self):
        current = Path(__file__).resolve()
        repo_root = None
        for candidate in current.parents:
            flutter = candidate / "omc_app" / "lib"
            if flutter.is_dir():
                repo_root = candidate
                break

        self.assertIsNotNone(repo_root)
        flutter_root = repo_root / "omc_app" / "lib"

        offenders = []
        for path in flutter_root.rglob("*.dart"):
            source = path.read_text(encoding="utf-8", errors="ignore")
            legacy_name = "OMC" + " Task"
            if legacy_name in source:
                offenders.append(str(path.relative_to(flutter_root)))

        self.assertEqual(offenders, [])
