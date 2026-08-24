from pathlib import Path
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import secured_mobile, service_case_read, service_document_read


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

    def test_secured_mobile_service_cases_forwards_pagination(self):
        expected = {
            "cases": [],
            "limit_start": 11,
            "limit_page_length": 13,
            "next_start": None,
            "has_more": False,
        }

        with patch(
            "omc_app.api.service_case_contract.get_service_cases",
            return_value=expected,
        ) as canonical:
            result = secured_mobile.get_service_cases(
                start=3,
                limit=7,
                limit_start=11,
                limit_page_length=13,
            )

        self.assertIs(result, expected)
        canonical.assert_called_once_with(
            start=3,
            limit=7,
            limit_start=11,
            limit_page_length=13,
        )

    def test_customer_service_document_authorization_uses_session_context(self):
        with (
            patch.object(
                service_document_read.access,
                "is_internal_user",
                return_value=False,
            ),
            patch.object(
                service_document_read.access,
                "get_mobile_capabilities",
                return_value={},
            ),
            patch.object(
                service_document_read.identity,
                "require_customer_context",
            ) as require_customer_context,
        ):
            internal, capabilities = service_document_read._authorized_context(
                "customer@example.com"
            )

        self.assertFalse(internal)
        self.assertEqual(capabilities, {})
        require_customer_context.assert_called_once_with()

    def test_customer_service_case_authorization_uses_session_context(self):
        with (
            patch.object(
                service_case_read.access,
                "is_internal_user",
                return_value=False,
            ),
            patch.object(
                service_case_read.identity,
                "require_customer_context",
            ) as require_customer_context,
        ):
            service_case_read._authorize("customer@example.com")

        require_customer_context.assert_called_once_with()
