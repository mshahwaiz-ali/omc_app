from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import referral_attribution


class TestHistoricalReferralAttribution(FrappeTestCase):
    def _registry(self):
        return frappe._dict({
            "name": "REF-HIST-ADNAN",
            "referrer_user": "adnan@omchouse.com",
            "referral_code": "ADNAN001",
            "modified": "2026-08-22 12:00:00",
        })

    def _staff(self):
        return frappe._dict({
            "name": "ACCESS-ADNAN",
            "access_status": "Approved",
            "reconciliation_status": "Current",
            "persona_snapshot": "Business Partner",
            "source_version": "staff-source-v1",
        })

    def test_consent_schema_supports_not_applicable(self):
        field = frappe.get_meta(
            "OMC Referral Attribution"
        ).get_field("consent_status")

        self.assertIn(
            "Not Applicable",
            (field.options or "").splitlines(),
        )

    def test_historical_acquisition_uses_erp_customer_without_account_or_fake_consent(self):
        registry = self._registry()
        staff = self._staff()
        created = {}

        def fake_get_doc(doctype, name=None):
            if doctype == "OMC Referral":
                self.assertEqual(
                    name,
                    "REF-HIST-ADNAN",
                )
                return registry

            if isinstance(doctype, dict):
                doc = frappe._dict(doctype)
                doc.insert = MagicMock()
                created["doc"] = doc
                return doc

            self.fail(
                f"Unexpected get_doc call: {doctype} {name}"
            )

        with (
            patch.object(
                referral_attribution.frappe.db,
                "exists",
                side_effect=lambda doctype, name: (
                    doctype == "Customer"
                    and name == "ERP-CUST-HIST-1"
                ),
            ),
            patch.object(
                referral_attribution.frappe,
                "get_all",
                return_value=[],
            ),
            patch.object(
                referral_attribution,
                "now_datetime",
                return_value="2026-08-22 12:00:00",
            ),
            patch.object(
                referral_attribution.frappe,
                "get_doc",
                side_effect=fake_get_doc,
            ),
            patch.object(
                referral_attribution.identity,
                "get_staff_access",
                return_value=staff,
            ),
        ):
            result = (
                referral_attribution
                .create_historical_acquisition_snapshot(
                    referral_registry="REF-HIST-ADNAN",
                    erp_customer="ERP-CUST-HIST-1",
                    historical_persona="Consultant",
                )
            )

        self.assertIs(result, created["doc"])
        self.assertEqual(result.attribution_type, "Acquisition")
        self.assertEqual(
            result.referral_registry,
            "REF-HIST-ADNAN",
        )
        self.assertEqual(
            result.owner_user,
            "adnan@omchouse.com",
        )
        self.assertEqual(
            result.owner_persona_snapshot,
            "Consultant",
        )
        self.assertEqual(
            result.erp_customer,
            "ERP-CUST-HIST-1",
        )
        self.assertFalse(result.get("customer_account"))

        self.assertEqual(
            result.consent_status,
            "Not Applicable",
        )
        self.assertEqual(
            result.consent_version,
            "historical-erp-referral-v1",
        )

        result.insert.assert_called_once_with(
            ignore_permissions=True,
        )

    def test_historical_acquisition_is_idempotent_for_same_customer_relationship(self):
        registry = self._registry()
        staff = self._staff()

        existing = frappe._dict({
            "name": "ATTR-HIST-1",
            "attribution_type": "Acquisition",
            "referral_registry": "REF-HIST-ADNAN",
            "owner_user": "adnan@omchouse.com",
            "owner_persona_snapshot": "Consultant",
            "erp_customer": "ERP-CUST-HIST-1",
            "customer_account": None,
            "consent_status": "Not Applicable",
        })

        def fake_get_doc(doctype, name=None):
            if doctype == "OMC Referral":
                return registry

            if (
                doctype == "OMC Referral Attribution"
                and name == "ATTR-HIST-1"
            ):
                return existing

            self.fail(
                f"Unexpected get_doc call: {doctype} {name}"
            )

        with (
            patch.object(
                referral_attribution.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                referral_attribution.frappe,
                "get_all",
                return_value=[
                    frappe._dict({"name": "ATTR-HIST-1"}),
                ],
            ),
            patch.object(
                referral_attribution.frappe,
                "get_doc",
                side_effect=fake_get_doc,
            ),
            patch.object(
                referral_attribution.identity,
                "get_staff_access",
                return_value=staff,
            ),
        ):
            result = (
                referral_attribution
                .create_historical_acquisition_snapshot(
                    referral_registry="REF-HIST-ADNAN",
                    erp_customer="ERP-CUST-HIST-1",
                    historical_persona="Consultant",
                )
            )

        self.assertIs(result, existing)

    def test_conflicting_existing_acquisition_is_rejected_not_duplicated(self):
        registry = self._registry()
        staff = self._staff()

        conflicting = frappe._dict({
            "name": "ATTR-CONFLICT",
            "attribution_type": "Acquisition",
            "referral_registry": "REF-OTHER",
            "owner_user": "someone@example.com",
            "owner_persona_snapshot": "Business Partner",
            "erp_customer": "ERP-CUST-HIST-1",
            "customer_account": None,
            "consent_status": "Granted",
        })

        def fake_get_doc(doctype, name=None):
            if doctype == "OMC Referral":
                return registry

            if (
                doctype == "OMC Referral Attribution"
                and name == "ATTR-CONFLICT"
            ):
                return conflicting

            self.fail(
                f"Unexpected get_doc call: {doctype} {name}"
            )

        with (
            patch.object(
                referral_attribution.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                referral_attribution.frappe,
                "get_all",
                return_value=[
                    frappe._dict({"name": "ATTR-CONFLICT"}),
                ],
            ),
            patch.object(
                referral_attribution.frappe,
                "get_doc",
                side_effect=fake_get_doc,
            ),
            patch.object(
                referral_attribution.identity,
                "get_staff_access",
                return_value=staff,
            ),
        ):
            with self.assertRaises(frappe.ValidationError):
                (
                    referral_attribution
                    .create_historical_acquisition_snapshot(
                        referral_registry="REF-HIST-ADNAN",
                        erp_customer="ERP-CUST-HIST-1",
                        historical_persona="Consultant",
                    )
                )


class TestHistoricalServiceRequestAttribution(FrappeTestCase):
    def test_request_snapshot_inherits_historical_acquisition_persona(self):
        request = frappe._dict({
            "name": "REQ-HIST-1",
        })
        account = frappe._dict({
            "name": "ACCOUNT-1",
            "erp_customer": "ERP-CUST-HIST-1",
        })

        acquisition = frappe._dict({
            "name": "ATTR-ACQ-HIST-1",
            "owner_persona_snapshot": "Consultant",
        })

        with (
            patch.object(
                referral_attribution.frappe,
                "get_all",
                return_value=[
                    frappe._dict({"name": acquisition.name}),
                ],
            ),
            patch.object(
                referral_attribution.frappe,
                "get_doc",
                return_value=acquisition,
            ),
            patch.object(
                referral_attribution,
                "create_snapshot",
            ) as create_snapshot,
        ):
            referral_attribution.request_snapshot(
                request=request,
                account=account,
                referral_registry="REF-ADNAN",
            )

        create_snapshot.assert_called_once_with(
            referral_registry="REF-ADNAN",
            customer_account="ACCOUNT-1",
            attribution_type="Service Request",
            service_request="REQ-HIST-1",
            owner_persona_snapshot="Consultant",
        )
