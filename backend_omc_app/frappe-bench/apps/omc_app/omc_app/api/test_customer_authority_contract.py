from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestCustomerAuthorityContract(FrappeTestCase):
    def _repo_root(self):
        current = Path(__file__).resolve()
        for candidate in current.parents:
            if (
                candidate
                / "backend_omc_app/frappe-bench/apps/omc_app"
            ).is_dir():
                return candidate
        self.fail("Repository root not found")

    def test_omc_customer_profile_is_canonical_app_identity(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        mobile = (api / "mobile.py").read_text(encoding="utf-8")
        profile = (api / "profile.py").read_text(encoding="utf-8")
        assisted = (api / "assisted_service.py").read_text(
            encoding="utf-8"
        )

        self.assertIn('frappe.new_doc("OMC Customer Profile")', mobile)
        self.assertIn('"OMC Customer Profile"', profile)
        self.assertIn('"OMC Manual Customer"', assisted)

    def test_erp_customer_is_downstream_bridge_only(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        resolver = (api / "erp_customer_resolver.py").read_text(
            encoding="utf-8"
        )
        adapter = (api / "erp_service_task_adapter.py").read_text(
            encoding="utf-8"
        )

        self.assertIn('frappe.new_doc("Customer")', resolver)
        self.assertIn('"OMC Customer Account"', adapter)
        self.assertNotIn('frappe.new_doc("Customer")', adapter)
        self.assertNotIn(
            'frappe.new_doc("OMC Customer Profile")',
            resolver,
        )

    def test_customer_duplicate_guards_remain_active(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        resolver = (api / "erp_customer_resolver.py").read_text(
            encoding="utf-8"
        )
        assisted = (api / "assisted_service.py").read_text(
            encoding="utf-8"
        )

        for marker in (
            '("user_link", user)',
            '("email_id", getattr(profile, "email", None))',
            '("mobile_no", getattr(profile, "phone", None))',
            'tax_identity = (',
            'getattr(profile, "ntn", None)',
            'getattr(profile, "cnic", None)',
            '("tax_id", tax_identity)',
            '"status": "Ambiguous"',
        ):
            self.assertIn(marker, resolver)

        self.assertIn(
            "def _manual_customer_duplicate_matches(",
            assisted,
        )
        self.assertIn(
            "A matching walk-in customer already exists.",
            assisted,
        )

    def test_service_request_uses_canonical_customer_links(self):
        root = self._repo_root()
        schema = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/"
            "omc_app/doctype/omc_service_request/"
            "omc_service_request.json"
        ).read_text(encoding="utf-8")

        self.assertIn('"fieldname": "customer_profile"', schema)
        self.assertIn('"options": "OMC Customer Profile"', schema)
        self.assertIn('"fieldname": "manual_customer"', schema)
        self.assertIn('"options": "OMC Manual Customer"', schema)
        self.assertIn('"fieldname": "erp_customer"', schema)
