from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import (
    erp_customer_resolver,
    identity,
    pending_registration,
)


class _FakeField:
    def __init__(
        self,
        fieldname,
        *,
        label="",
        fieldtype="Data",
        reqd=0,
    ):
        self.fieldname = fieldname
        self.label = label
        self.fieldtype = fieldtype
        self.reqd = reqd
        self.unique = 0


class _FakeMeta:
    def __init__(self):
        self._fields = {
            "company": _FakeField(
                "company",
                fieldtype="Link",
                reqd=1,
            ),
            "user_link": _FakeField(
                "user_link",
                fieldtype="Link",
            ),
            "mobile_no": _FakeField(
                "mobile_no",
            ),
            "email_id": _FakeField(
                "email_id",
            ),
            "custom_email_address": _FakeField(
                "custom_email_address",
            ),
            "contact_no": _FakeField(
                "contact_no",
            ),
            "custom_business_name": _FakeField(
                "custom_business_name",
            ),
            "tax_id": _FakeField(
                "tax_id",
                label="CNIC / NTN",
                reqd=1,
            ),
        }

        self.fields = list(
            self._fields.values()
        )

    def get_field(self, fieldname):
        return self._fields.get(
            fieldname
        )


class _FakeCustomer:
    def __init__(self):
        self.meta = _FakeMeta()
        self.inserted = False
        self.name = "ERP-CUST-NEW"

    def set(self, fieldname, value):
        setattr(
            self,
            fieldname,
            value,
        )

    def get(self, fieldname):
        return getattr(
            self,
            fieldname,
            None,
        )

    def insert(self, **_kwargs):
        self.inserted = True
        return self


class TestSignupActivationPhase2(
    FrappeTestCase
):
    @staticmethod
    def _profile(
        *,
        cnic="3520212345671",
        ntn="",
    ):
        return SimpleNamespace(
            doctype="OMC Customer Profile",
            name="OMC-CUST-PHASE2",
            full_name="Phase Two Customer",
            email="phase2@example.com",
            phone="03001234567",
            company_name="Customer Business",
            cnic=cnic,
            ntn=ntn,
            referral_record="",
            acquisition_source="Website",
            referred_by="",
            referral_code_used="",
        )

    @staticmethod
    def _setting_value(
        doctype,
        fieldname,
    ):
        values = {
            (
                "Selling Settings",
                "customer_group",
            ): "All Customer Groups",
            (
                "Selling Settings",
                "territory",
            ): "All Territories",
            (
                "Global Defaults",
                "default_company",
            ): "Omc House",
        }

        return values.get(
            (
                doctype,
                fieldname,
            ),
            "",
        )

    @staticmethod
    def _required_record_exists(
        doctype,
        name=None,
        *_args,
        **_kwargs,
    ):
        expected = {
            "Customer Group":
                "All Customer Groups",
            "Territory":
                "All Territories",
            "Company":
                "Omc House",
        }

        if doctype in expected:
            return (
                name
                if name == expected[doctype]
                else None
            )

        return None

    def test_new_customer_creation_uses_live_erp_defaults_and_tax_identity(
        self,
    ):
        profile = self._profile()
        customer = _FakeCustomer()

        with (
            patch.object(
                erp_customer_resolver.frappe.db,
                "get_single_value",
                side_effect=self._setting_value,
            ),
            patch.object(
                erp_customer_resolver.frappe.db,
                "exists",
                side_effect=(
                    self._required_record_exists
                ),
            ),
            patch.object(
                erp_customer_resolver.frappe,
                "new_doc",
                return_value=customer,
            ),
            patch.object(
                erp_customer_resolver,
                "_set_new_customer_referral_identity",
                return_value=False,
            ),
        ):
            created, error = (
                erp_customer_resolver
                ._create_customer(
                    profile,
                    "phase2@example.com",
                )
            )

        self.assertIs(
            created,
            customer,
        )
        self.assertEqual(
            error,
            "",
        )
        self.assertTrue(
            customer.inserted
        )

        self.assertEqual(
            customer.customer_name,
            "Phase Two Customer",
        )
        self.assertEqual(
            customer.customer_type,
            "Individual",
        )
        self.assertEqual(
            customer.customer_group,
            "All Customer Groups",
        )
        self.assertEqual(
            customer.territory,
            "All Territories",
        )
        self.assertEqual(
            customer.company,
            "Omc House",
        )
        self.assertEqual(
            customer.tax_id,
            "3520212345671",
        )
        self.assertEqual(
            customer.user_link,
            "phase2@example.com",
        )
        self.assertEqual(
            customer.custom_email_address,
            "phase2@example.com",
        )
        self.assertEqual(
            customer.contact_no,
            "03001234567",
        )
        self.assertEqual(
            customer.custom_business_name,
            "Customer Business",
        )

    def test_new_customer_creation_fails_cleanly_without_required_tax_identity(
        self,
    ):
        profile = self._profile(
            cnic="",
            ntn="",
        )

        customer = _FakeCustomer()

        with (
            patch.object(
                erp_customer_resolver.frappe.db,
                "get_single_value",
                side_effect=self._setting_value,
            ),
            patch.object(
                erp_customer_resolver.frappe.db,
                "exists",
                side_effect=(
                    self._required_record_exists
                ),
            ),
            patch.object(
                erp_customer_resolver.frappe,
                "new_doc",
                return_value=customer,
            ),
            patch.object(
                erp_customer_resolver,
                "_set_new_customer_referral_identity",
                return_value=False,
            ),
        ):
            created, error = (
                erp_customer_resolver
                ._create_customer(
                    profile,
                    "phase2@example.com",
                )
            )

        self.assertIsNone(
            created
        )
        self.assertIn(
            "CNIC or NTN is required",
            error,
        )
        self.assertFalse(
            customer.inserted
        )

    def test_new_customer_multiple_matches_are_ambiguous_not_duplicate_creation(
        self,
    ):
        profile = SimpleNamespace(
            doctype="OMC Customer Profile",
            name="OMC-CUST-PHASE2",
            linked_erpnext_customer="",
            linked_app_user=(
                "phase2@example.com"
            ),
            user="phase2@example.com",
            full_name="Phase Two Customer",
            email="phase2@example.com",
            phone="03001234567",
            cnic="3520212345671",
            ntn="",
            customer_origin="App Signup",
            approval_status="Approved",
            is_active=1,
        )

        profile.set = MagicMock()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[
                    "ERP-CUST-1",
                    "ERP-CUST-2",
                ],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = (
                erp_customer_resolver
                .resolve_profile_customer(
                    profile,
                    resolution_mode=(
                        "new_customer"
                    ),
                )
            )

        self.assertEqual(
            result["status"],
            "Ambiguous",
        )
        self.assertFalse(
            result["created"]
        )
        create_customer.assert_not_called()

    def test_existing_customer_activation_reuses_business_only_profile_via_erp(
        self,
    ):
        profile_row = frappe._dict({
            "name":
                "OMC-CUST-BUSINESS",
            "user": "",
            "linked_app_user": "",
            "linked_erpnext_customer":
                "ERP-CUST-EXISTING",
        })

        def get_all_side_effect(
            doctype,
            *args,
            **kwargs,
        ):
            filters = (
                kwargs.get("filters")
                or {}
            )

            if (
                doctype
                == "OMC Customer Profile"
                and "email" in filters
            ):
                return []

            if (
                doctype
                == "OMC Customer Profile"
                and filters.get(
                    "linked_erpnext_customer"
                )
                == "ERP-CUST-EXISTING"
            ):
                return [
                    "OMC-CUST-BUSINESS"
                ]

            return []

        def get_value_side_effect(
            doctype,
            *_args,
            **_kwargs,
        ):
            if (
                doctype
                == "OMC Customer Profile"
            ):
                return profile_row

            if (
                doctype
                == "OMC Customer Account"
            ):
                return None

            return None

        with (
            patch.object(
                identity.frappe,
                "get_all",
                side_effect=get_all_side_effect,
            ),
            patch.object(
                identity.frappe.db,
                "get_value",
                side_effect=get_value_side_effect,
            ),
            patch.object(
                identity,
                "_doctype_exists",
                return_value=True,
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[
                    "ERP-CUST-EXISTING"
                ],
            ),
        ):
            result = (
                identity
                .activation_profile_state(
                    "customer@example.com",
                    phone="03001234567",
                    cnic="3520212345671",
                )
            )

        self.assertEqual(
            result["status"],
            "claimable",
        )
        self.assertEqual(
            result["profile"],
            "OMC-CUST-BUSINESS",
        )
        self.assertEqual(
            result["customer"],
            "ERP-CUST-EXISTING",
        )

    def test_activation_profile_state_fails_closed_on_ambiguous_erp_identity(
        self,
    ):
        with (
            patch.object(
                identity.frappe,
                "get_all",
                return_value=[],
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[
                    "ERP-CUST-1",
                    "ERP-CUST-2",
                ],
            ),
        ):
            result = (
                identity
                .activation_profile_state(
                    "customer@example.com",
                    cnic="3520212345671",
                )
            )

        self.assertEqual(
            result["status"],
            "customer_ambiguous",
        )
        self.assertEqual(
            result["profile"],
            "",
        )
        self.assertEqual(
            result["customer"],
            "",
        )

    def test_clean_verified_customer_becomes_active_and_approved(
        self,
    ):
        profile = SimpleNamespace(
            name="OMC-CUST-CLEAN",
            approval_status=(
                "Pending Review"
            ),
            customer_status="Pending",
            is_active=1,
            onboarding_mode="New Customer",
        )

        profile.save = MagicMock()

        account = SimpleNamespace(
            name="OMC-ACCOUNT-CLEAN"
        )

        resolution = {
            "status": "Created",
            "customer": "ERP-CUST-CLEAN",
            "created": True,
            "reason": "",
        }

        doc = SimpleNamespace(
            email="clean@example.com"
        )

        with (
            patch.object(
                pending_registration.frappe.db,
                "get_value",
                return_value=(
                    "OMC-CUST-CLEAN"
                ),
            ),
            patch.object(
                pending_registration.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                erp_customer_resolver,
                "resolve_profile_customer",
                return_value=resolution,
            ) as resolve_customer,
            patch.object(
                pending_registration,
                "_ensure_activation_account",
                return_value=account,
            ) as ensure_account,
            patch.object(
                pending_registration,
                "_create_profile_acquisition_attribution",
            ) as attribution,
        ):
            result = (
                pending_registration
                ._activate_verified_customer(
                    doc
                )
            )

        self.assertTrue(
            result["activated"]
        )
        self.assertEqual(
            result["profile"],
            "OMC-CUST-CLEAN",
        )
        self.assertEqual(
            result["account"],
            "OMC-ACCOUNT-CLEAN",
        )

        self.assertEqual(
            profile.approval_status,
            "Approved",
        )
        self.assertEqual(
            profile.customer_status,
            "Active",
        )
        self.assertEqual(
            profile.is_active,
            1,
        )

        profile.save.assert_called_once_with(
            ignore_permissions=True,
        )

        resolve_customer.assert_called_once()
        ensure_account.assert_called_once()
        attribution.assert_called_once_with(
            profile,
            account,
        )

    def test_unresolved_verified_customer_stays_pending_and_gets_no_attribution(
        self,
    ):
        profile = SimpleNamespace(
            name="OMC-CUST-REVIEW",
            approval_status=(
                "Pending Review"
            ),
            customer_status="Pending",
            is_active=1,
            onboarding_mode="New Customer",
        )

        profile.save = MagicMock()

        account = SimpleNamespace(
            name="OMC-ACCOUNT-REVIEW"
        )

        resolution = {
            "status":
                "Existing Customer Detected",
            "customer": "",
            "created": False,
            "reason": (
                "an existing ERP Customer "
                "matches this customer identity"
            ),
        }

        doc = SimpleNamespace(
            email="review@example.com"
        )

        with (
            patch.object(
                pending_registration.frappe.db,
                "get_value",
                return_value=(
                    "OMC-CUST-REVIEW"
                ),
            ),
            patch.object(
                pending_registration.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                erp_customer_resolver,
                "resolve_profile_customer",
                return_value=resolution,
            ),
            patch.object(
                pending_registration,
                "_ensure_activation_account",
                return_value=account,
            ),
            patch.object(
                pending_registration,
                "_create_profile_acquisition_attribution",
            ) as attribution,
        ):
            result = (
                pending_registration
                ._activate_verified_customer(
                    doc
                )
            )

        self.assertFalse(
            result["activated"]
        )

        self.assertEqual(
            profile.approval_status,
            "Pending Review",
        )
        self.assertEqual(
            profile.customer_status,
            "Pending",
        )
        self.assertEqual(
            profile.is_active,
            1,
        )

        profile.save.assert_not_called()
        attribution.assert_not_called()
