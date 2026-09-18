from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_business_projection, profile as profile_api


class _Meta:
    def __init__(self, fields):
        self._fields = set(fields)

    def has_field(self, fieldname):
        return fieldname in self._fields


def _doc(**values):
    doc = SimpleNamespace(**values)
    doc.meta = _Meta(values.keys())
    doc.get = lambda fieldname, default=None: getattr(doc, fieldname, default)
    doc.set = lambda fieldname, value: setattr(doc, fieldname, value)
    return doc


class TestPhase4CustomerBusinessProjection(FrappeTestCase):
    def test_tax_identity_kind_uses_existing_erp_tax_id(self):
        self.assertEqual(
            customer_business_projection.tax_identity_kind(
                "35202-1234567-1"
            ),
            "cnic",
        )
        self.assertEqual(
            customer_business_projection.tax_identity_kind("1234567-8"),
            "ntn",
        )

    def test_snapshot_prefers_erp_customer_business_fields(self):
        profile = _doc(
            name="PROFILE-1",
            linked_erpnext_customer="ERP-CUST-1",
            full_name="Old Profile Name",
            email="login@example.com",
            phone="03000000000",
            address="Old Profile Address",
            company_name="Old Profile Company",
            cnic="3520212345671",
            ntn="",
        )
        customer = _doc(
            name="ERP-CUST-1",
            customer_name="ERP Customer Name",
            customer_type="Individual",
            customer_primary_contact="",
            customer_primary_address="",
            primary_address="",
            contact_no="03001234567",
            custom_email_address="erp@example.com",
            custom_business_name="ERP Business",
            address="ERP Address",
            mobile_no="",
            email_id="",
            tax_id="3520212345671",
        )

        with (
            patch.object(
                customer_business_projection.frappe.db,
                "exists",
                side_effect=lambda doctype, name_or_filters: (
                    doctype == "Customer"
                    and name_or_filters == "ERP-CUST-1"
                ),
            ),
            patch.object(
                customer_business_projection,
                "_linked_contact_names",
                return_value=[],
            ),
        ):
            snapshot = customer_business_projection.business_snapshot(
                profile,
                user="login@example.com",
                customer_doc=customer,
            )

        self.assertTrue(snapshot["erp_backed"])
        self.assertEqual(snapshot["full_name"], "ERP Customer Name")
        self.assertEqual(snapshot["email"], "erp@example.com")
        self.assertEqual(snapshot["phone"], "03001234567")
        self.assertEqual(snapshot["address"], "ERP Address")
        self.assertEqual(snapshot["company_name"], "ERP Business")
        self.assertEqual(snapshot["cnic"], "3520212345671")
        self.assertEqual(snapshot["tax_id_kind"], "cnic")

    def test_conflicting_tax_identity_is_not_overwritten(self):
        customer = _doc(
            tax_id="3520212345671",
        )
        with self.assertRaises(frappe.ValidationError):
            customer_business_projection._apply_tax_identity(
                customer,
                {"ntn": "1234567-8"},
            )

        self.assertEqual(customer.tax_id, "3520212345671")

    def test_profile_policy_hides_second_tax_identity_when_tax_id_occupied(self):
        profile = _doc(
            cnic="3520212345671",
            ntn="",
            company_name="",
        )
        policy = profile_api._profile_edit_policy(
            profile,
            {
                "cnic": "3520212345671",
                "ntn": "",
                "company_name": "",
                "tax_id_kind": "cnic",
            },
        )

        self.assertEqual(
            policy["cnic"],
            {"can_edit": False, "mode": "locked"},
        )
        self.assertEqual(
            policy["ntn"],
            {"can_edit": False, "mode": "unavailable"},
        )
        self.assertEqual(
            policy["company_name"],
            {"can_edit": True, "mode": "add"},
        )

    def test_sync_updates_only_compatibility_business_projection(self):
        profile = _doc(
            name="PROFILE-1",
            linked_erpnext_customer="ERP-CUST-1",
            full_name="Old",
            phone="",
            address="",
            company_name="",
            cnic="",
            ntn="",
            referral_record="REF-1",
        )
        customer = _doc(
            name="ERP-CUST-1",
            customer_name="ERP Name",
            customer_type="Individual",
            customer_primary_contact="",
            customer_primary_address="",
            primary_address="",
            contact_no="03001234567",
            custom_email_address="",
            custom_business_name="Business",
            address="Address",
            mobile_no="",
            email_id="",
            tax_id="12345678",
        )

        with (
            patch.object(
                customer_business_projection.frappe.db,
                "exists",
                side_effect=lambda doctype, name_or_filters: (
                    doctype == "Customer"
                    and name_or_filters == "ERP-CUST-1"
                ),
            ),
            patch.object(
                customer_business_projection,
                "_linked_contact_names",
                return_value=[],
            ),
            patch.object(
                customer_business_projection.frappe.db,
                "set_value",
            ) as set_value,
        ):
            changed = (
                customer_business_projection.sync_profile_projection(
                    profile,
                    customer_doc=customer,
                )
            )

        self.assertIn("full_name", changed)
        self.assertIn("ntn", changed)
        values = set_value.call_args.args[2]
        self.assertEqual(values["full_name"], "ERP Name")
        self.assertEqual(values["ntn"], "12345678")
        self.assertNotIn("referral_record", values)

    def test_contact_ambiguity_fails_closed_for_write(self):
        customer = _doc(
            name="ERP-CUST-1",
            customer_primary_contact="",
        )

        with (
            patch.object(
                customer_business_projection,
                "_linked_contact_names",
                return_value=["CONTACT-1", "CONTACT-2"],
            ),
            patch.object(
                customer_business_projection.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_business_projection.frappe,
                "get_all",
                return_value=[],
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            customer_business_projection._primary_contact_name(
                customer,
                fail_on_ambiguity=True,
            )
