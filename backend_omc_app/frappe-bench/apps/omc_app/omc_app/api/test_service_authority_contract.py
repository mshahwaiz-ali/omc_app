from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestServiceAuthorityContract(FrappeTestCase):
    def _repo_root(self):
        current = Path(__file__).resolve()
        for candidate in current.parents:
            if (
                candidate
                / "backend_omc_app/frappe-bench/apps/omc_app"
            ).is_dir():
                return candidate
        self.fail("Repository root not found")

    def test_omc_service_is_canonical_catalogue_authority(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        catalogue = (api / "public_catalogue.py").read_text(
            encoding="utf-8"
        )
        request_guard = (api / "service_request_guard.py").read_text(
            encoding="utf-8"
        )
        templates = (api / "service_templates.py").read_text(
            encoding="utf-8"
        )

        self.assertIn('"OMC Service"', catalogue)
        self.assertIn('"OMC Service"', request_guard)
        self.assertIn('"OMC Service"', templates)

    def test_erp_service_is_created_only_by_bridge_adapter(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        adapter = (api / "erp_service_task_adapter.py").read_text(
            encoding="utf-8"
        )

        self.assertIn('frappe.new_doc("Service")', adapter)
        self.assertIn("OMC Service Request remains", adapter)

        for path in api.glob("*.py"):
            if (
                path.name == "erp_service_task_adapter.py"
                or path.name.startswith("test_")
            ):
                continue
            source = path.read_text(encoding="utf-8")
            self.assertNotIn(
                'frappe.new_doc("Service")',
                source,
                msg=f"Unexpected ERP Service writer: {path.name}",
            )

    def test_partial_and_stale_bridge_links_require_repair(self):
        root = self._repo_root()
        adapter = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/"
            "erp_service_task_adapter.py"
        ).read_text(encoding="utf-8")

        self.assertIn('"status": "Repair Required"', adapter)
        self.assertIn("ERP Service link is missing", adapter)
        self.assertIn("ERP Task link is missing", adapter)
        self.assertIn("linked ERP Service does not exist", adapter)
        self.assertIn("linked ERP Task does not exist", adapter)

    def test_service_request_keeps_canonical_and_bridge_links(self):
        root = self._repo_root()
        schema = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/"
            "omc_app/doctype/omc_service_request/"
            "omc_service_request.json"
        ).read_text(encoding="utf-8")

        self.assertIn('"fieldname": "service"', schema)
        self.assertIn('"options": "OMC Service"', schema)
        self.assertIn('"fieldname": "erp_service"', schema)
        self.assertIn('"options": "Service"', schema)
        self.assertIn('"fieldname": "erp_task"', schema)
        self.assertIn('"options": "Task"', schema)

    def test_valid_complete_bridge_remains_idempotent(self):
        root = self._repo_root()
        adapter = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/"
            "erp_service_task_adapter.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "if erp_service and erp_task and service_exists and task_exists:",
            adapter,
        )
        self.assertIn('"created": False', adapter)
