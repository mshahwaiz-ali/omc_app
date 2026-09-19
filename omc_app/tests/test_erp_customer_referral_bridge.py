from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_customer_resolver


class _Meta:
    fields = []

    def get_field(self, fieldname):
        if fieldname in {
            "source",
            "sales_person",
            "user_link",
            "mobile_no",
            "email_id",
        }:
            return SimpleNamespace(fieldname=fieldname)
        return None


class _Customer:
    def __init__(self):
        self.meta = _Meta()
        self.inserted = False

    def set(self, fieldname, value):
        setattr(self, fieldname, value)

    def get(self, fieldname):
        return getattr(self, fieldname, None)

    def insert(self, ignore_permissions=False):
        self.inserted = True
        self.ignore_permissions = ignore_permissions


class TestERPNewCustomerReferralBridge(FrappeTestCase):
    def _profile(self, **values):
        base = {
            "name": "OMC-CUST-REFERRAL-TEST",
            "full_name": "Referral Customer",
            "phone": "",
            "email": "customer@example.com",
            "cnic": "",
            "ntn": "",
            "linked_app_user": "customer@example.com",
            "acquisition_source": "Referral",
            "referral_record": "OMC-REF-260823-00020",
            "referred_by": "asif@omchouse.com",
            "referral_code_used": "OMC-ABC123",
        }
        base.update(values)
        return SimpleNamespace(**base)

    def _referral(self, **values):
        base = {
            "name": "OMC-REF-260823-00020",
            "referral_code": "OMC-ABC123",
            "referrer_user": "asif@omchouse.com",
            "owner_persona_snapshot": "Consultant",
        }
        base.update(values)
        return SimpleNamespace(**base)

    def test_referred_new_customer_gets_source_and_dynamic_link(self):
        customer = _Customer()
        profile = self._profile()
        referral = self._referral()

        defaults = {
            "customer_group": "All Customer Groups",
            "territory": "All Territories",
        }

        with patch.object(
            erp_customer_resolver,
            "_default_value",
            side_effect=lambda fieldname: defaults[fieldname],
        ), patch.object(
            erp_customer_resolver.frappe,
            "new_doc",
            return_value=customer,
        ), patch.object(
            erp_customer_resolver,
            "_validated_referral_for_profile",
            return_value=referral,
        ), patch.object(
            erp_customer_resolver,
            "_erp_persona_record_for_user",
            return_value="asif@omchouse.com",
        ):
            created, reason = erp_customer_resolver._create_customer(
                profile,
                "customer@example.com",
            )

        self.assertIs(created, customer)
        self.assertEqual(reason, "")
        self.assertEqual(customer.source, "Consultant")
        self.assertEqual(
            customer.sales_person,
            "asif@omchouse.com",
        )
        self.assertTrue(customer.inserted)

    def test_non_referral_customer_is_unchanged(self):
        customer = _Customer()
        profile = self._profile(
            acquisition_source="Direct",
            referral_record="",
            referred_by="",
            referral_code_used="",
        )

        changed = (
            erp_customer_resolver
            ._set_new_customer_referral_identity(
                customer,
                profile,
            )
        )

        self.assertFalse(changed)
        self.assertFalse(hasattr(customer, "source"))
        self.assertFalse(hasattr(customer, "sales_person"))

    def test_invalid_persona_target_fails_safe(self):
        customer = _Customer()
        profile = self._profile()
        referral = self._referral()

        with patch.object(
            erp_customer_resolver,
            "_validated_referral_for_profile",
            return_value=referral,
        ), patch.object(
            erp_customer_resolver,
            "_erp_persona_record_for_user",
            return_value="",
        ):
            changed = (
                erp_customer_resolver
                ._set_new_customer_referral_identity(
                    customer,
                    profile,
                )
            )

        self.assertFalse(changed)
        self.assertFalse(hasattr(customer, "source"))
        self.assertFalse(hasattr(customer, "sales_person"))

    def test_existing_customer_is_never_overwritten(self):
        profile = self._profile()

        with patch.object(
            erp_customer_resolver,
            "_valid_link",
            return_value="CUST-EXISTING",
        ), patch.object(
            erp_customer_resolver,
            "_create_customer",
        ) as create_customer:
            result = (
                erp_customer_resolver
                .resolve_profile_customer(profile)
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(
            result["customer"],
            "CUST-EXISTING",
        )
        self.assertFalse(result["created"])
        create_customer.assert_not_called()

    def test_profile_referral_revalidates_canonical_record(self):
        profile = self._profile()
        stored = self._referral()
        active = self._referral()

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            erp_customer_resolver.frappe,
            "get_doc",
            return_value=stored,
        ), patch(
            "omc_app.api.referrals.resolve_active_referral",
            return_value=active,
        ):
            resolved = (
                erp_customer_resolver
                ._validated_referral_for_profile(profile)
            )

        self.assertIs(resolved, active)

    def test_mismatched_profile_referrer_fails_closed(self):
        profile = self._profile(
            referred_by="someone-else@omchouse.com",
        )
        stored = self._referral()
        active = self._referral()

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            erp_customer_resolver.frappe,
            "get_doc",
            return_value=stored,
        ), patch(
            "omc_app.api.referrals.resolve_active_referral",
            return_value=active,
        ):
            resolved = (
                erp_customer_resolver
                ._validated_referral_for_profile(profile)
            )

        self.assertIsNone(resolved)

    def test_business_partner_can_resolve_by_user_link(self):
        class PersonaMeta:
            def get_field(self, fieldname):
                if fieldname == "user_link":
                    return SimpleNamespace(fieldname=fieldname)
                return None

        def exists(doctype, name):
            if doctype == "DocType":
                return name == "Business Partner"
            return False

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            side_effect=exists,
        ), patch.object(
            erp_customer_resolver.frappe,
            "get_meta",
            return_value=PersonaMeta(),
        ), patch.object(
            erp_customer_resolver.frappe,
            "get_all",
            return_value=["BP-0001"],
        ):
            target = (
                erp_customer_resolver
                ._erp_persona_record_for_user(
                    "Business Partner",
                    "partner@example.com",
                )
            )

        self.assertEqual(target, "BP-0001")

    def test_employee_mapping_reuses_staff_authority(self):
        def exists(doctype, name):
            return (
                doctype == "DocType"
                and name == "Employee"
            )

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            side_effect=exists,
        ), patch(
            "omc_app.api.staff_authority.employee_for_user",
            return_value="HR-EMP-0001",
        ):
            target = (
                erp_customer_resolver
                ._erp_persona_record_for_user(
                    "Employee",
                    "employee@example.com",
                )
            )

        self.assertEqual(target, "HR-EMP-0001")
