from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestLeadAppRetirementContract(FrappeTestCase):
    def _repo_root(self):
        current = Path(__file__).resolve()
        for candidate in current.parents:
            if (candidate / "backend_omc_app/frappe-bench/apps/omc_app").is_dir():
                return candidate
        self.fail("Repository root not found")

    def test_omc_runtime_has_no_lead_app_dependency(self):
        root = self._repo_root()
        scan_roots = [
            root / "backend_omc_app/frappe-bench/apps/omc_app",
            root / "omc_app/lib",
        ]
        suffixes = {".py", ".dart", ".js", ".json", ".yaml", ".yml"}
        forbidden = (
            "lead_app.apis.",
            "lead_app.lead_app.",
            "/api/method/lead_app.",
            "from lead_app",
            "import lead_app",
            "EPG Payment Transaction",
            "EPG Settings",
        )
        violations = []

        for scan_root in scan_roots:
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in suffixes:
                    continue
                if path == Path(__file__).resolve():
                    continue
                if "__pycache__" in path.parts:
                    continue

                text = path.read_text(encoding="utf-8", errors="ignore")
                for marker in forbidden:
                    if marker in text:
                        violations.append(
                            f"{path.relative_to(root)} contains {marker!r}"
                        )

        self.assertEqual([], violations)

    def test_omc_lead_remains_canonical(self):
        root = self._repo_root()
        mobile = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/mobile.py"
        ).read_text(encoding="utf-8")
        guard = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/lead_read_guard.py"
        ).read_text(encoding="utf-8")

        self.assertIn('frappe.new_doc("OMC Lead")', mobile)
        self.assertIn('frappe.get_all(\n        "OMC Lead"', guard)
        self.assertNotIn('frappe.new_doc("Lead")', mobile)

    def test_lead_app_source_and_bench_registration_removed(self):
        root = self._repo_root()
        bench = root / "backend_omc_app/frappe-bench"

        self.assertFalse((bench / "apps/lead_app").exists())

        registered_apps = {
            line.strip()
            for line in (bench / "sites/apps.txt").read_text(
                encoding="utf-8"
            ).splitlines()
            if line.strip()
        }

        self.assertNotIn("lead_app", registered_apps)
        self.assertTrue(
            {"frappe", "erpnext", "omc_app"}.issubset(
                registered_apps
            )
        )
