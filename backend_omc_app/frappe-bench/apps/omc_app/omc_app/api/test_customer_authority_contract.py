import json
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

    def test_omc_customer_profile_is_application_projection(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )
        doctype_root = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/"
            "omc_app/doctype"
        )

        mobile = (api / "mobile.py").read_text(encoding="utf-8")
        profile = (api / "profile.py").read_text(encoding="utf-8")
        profile_resolver = (
            api / "customer_profile_resolver.py"
        ).read_text(encoding="utf-8")
        manual_controller = (
            doctype_root
            / "omc_manual_customer/omc_manual_customer.py"
        ).read_text(encoding="utf-8")
        legacy_conversion = (
            api / "manual_customer_conversion.py"
        ).read_text(encoding="utf-8")

        self.assertIn('frappe.new_doc("OMC Customer Profile")', mobile)
        self.assertIn('"OMC Customer Profile"', profile)
        self.assertIn(
            'PROFILE_DOCTYPE = "OMC Customer Profile"',
            profile_resolver,
        )
        self.assertIn(
            "No User, password or Customer Account is created here.",
            profile_resolver,
        )
        self.assertIn(
            "profile.user = None",
            profile_resolver,
        )
        self.assertIn(
            "profile.linked_app_user = None",
            profile_resolver,
        )
        self.assertIn("OMC Manual Customer is retired", manual_controller)
        self.assertIn('"OMC Manual Customer"', legacy_conversion)

    def test_erp_customer_is_canonical_business_identity(self):
        root = self._repo_root()
        api = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api"
        )

        resolver = (api / "erp_customer_resolver.py").read_text(
            encoding="utf-8"
        )
        profile_resolver = (
            api / "customer_profile_resolver.py"
        ).read_text(encoding="utf-8")
        authority = (api / "customer_authority.py").read_text(
            encoding="utf-8"
        )
        adapter = (api / "erp_service_task_adapter.py").read_text(
            encoding="utf-8"
        )
        hooks = (
            root
            / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/hooks.py"
        ).read_text(encoding="utf-8")

        # Profile -> Customer creation still exists for approved app flows.
        self.assertIn('frappe.new_doc("Customer")', resolver)

        # ERP Customer is now explicitly the canonical business identity.
        self.assertIn(
            "ERP Customer is the canonical business identity.",
            authority,
        )

        # A Desk-created ERP Customer can gain an OMC Profile without
        # creating an application User or Customer Account.
        self.assertIn(
            "def resolve_for_erp_customer(",
            profile_resolver,
        )
        self.assertIn(
            "def _create_business_profile(",
            profile_resolver,
        )
        self.assertIn(
            "'Customer': {",
            hooks,
        )
        self.assertIn(
            "customer_profile_resolver.sync_from_erp_customer",
            hooks,
        )

        # ERP operational bridge continues to consume centralized customer
        # authority rather than creating Customers independently.
        self.assertIn(
            "customer_authority.resolve_request_customer",
            adapter,
        )
        self.assertNotIn(
            'frappe.new_doc("Customer")',
            adapter,
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
        admin_control = (api / "admin_control.py").read_text(
            encoding="utf-8"
        )
        pending_registration = (
            api / "pending_registration.py"
        ).read_text(encoding="utf-8")

        # ERP Customer identity must come from deterministic customer
        # evidence, never the legacy shared Customer.user_link field.
        for marker in (
            "def _customer_identity_rows(",
            "def _normalise_tax_id(",
            '"custom_email_address"',
            '"contact_no"',
            '"custom_reference_lead"',
            '"custom_cnic"',
            "del user",
            '"status": "Ambiguous"',
        ):
            self.assertIn(marker, resolver)

        self.assertNotIn(
            '("user_link", user)',
            resolver,
        )

        # Reviewers must be able to distinguish new-customer signup from
        # an existing-customer claim in the pending application queue.
        self.assertIn(
            'fields=["name", "full_name", "email", "phone", '
            '"register_as", "customer_type", "onboarding_mode", '
            '"customer_status", "approval_status", "creation"]',
            admin_control,
        )

        # New customer creation remains protected by the verified registration
        # flow. Phase 2 centralizes Profile/business identity collision checks
        # in activation_profile_state so business-only historical Profiles can
        # be claimed without allowing duplicate customer acquisition.
        self.assertIn(
            'frappe.db.exists("User", email)',
            pending_registration,
        )
        self.assertIn(
            "identity.activation_profile_state(",
            pending_registration,
        )
        self.assertIn(
            'profile_state in {',
            pending_registration,
        )
        self.assertIn(
            '"ambiguous",',
            pending_registration,
        )
        self.assertIn(
            '"activated",',
            pending_registration,
        )
        self.assertIn(
            'profile_state == "claimable"',
            pending_registration,
        )
        self.assertIn(
            "and not claim_profile_name",
            pending_registration,
        )

    def test_service_request_uses_canonical_customer_links(self):
        root = self._repo_root()
        schema = json.loads(
            (
                root
                / "backend_omc_app/frappe-bench/apps/omc_app/omc_app/"
                "omc_app/doctype/omc_service_request/"
                "omc_service_request.json"
            ).read_text(encoding="utf-8")
        )
        fields = {
            field["fieldname"]: field
            for field in schema["fields"]
            if field.get("fieldname")
        }

        self.assertEqual(
            fields["customer_profile"].get("options"),
            "OMC Customer Profile",
        )
        self.assertEqual(
            fields["customer_account"].get("options"),
            "OMC Customer Account",
        )
        self.assertIn("erp_customer", fields)

        # The manual-customer link is retained only as hidden historical
        # evidence until local/prod data reconciliation proves it can be dropped.
        self.assertEqual(
            fields["manual_customer"].get("options"),
            "OMC Manual Customer",
        )
        self.assertEqual(
            fields["manual_customer"].get("description"),
            "Legacy walk-in customer reference retained only for historical request reconciliation.",
        )
