from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import dashboard, identity


class _Request:
    def __init__(
        self,
        *,
        account="",
        erp_customer="",
        profile="",
    ):
        self.values = {
            "customer_account": account,
            "erp_customer": erp_customer,
            "customer_profile": profile,
        }
        self.meta = SimpleNamespace(
            has_field=lambda fieldname: fieldname
            in self.values
        )

    def get(self, fieldname):
        return self.values.get(fieldname)


class TestPhase3CanonicalRequestOwnership(FrappeTestCase):
    def _context(
        self,
        *,
        account="ACCOUNT-1",
        erp_customer="ERP-CUST-1",
        profile="PROFILE-1",
    ):
        return identity.CustomerContext(
            user="customer@example.com",
            account_name=account,
            erp_customer=erp_customer,
            legacy_profile=profile,
        )

    def test_exact_account_match_owns_request(self):
        request = _Request(
            account="ACCOUNT-1",
            erp_customer="ERP-CUST-1",
            profile="PROFILE-1",
        )
        self.assertTrue(
            identity.request_is_owned(
                request,
                self._context(),
            )
        )

    def test_accountless_historical_request_is_owned_by_erp_customer(self):
        request = _Request(
            erp_customer="ERP-CUST-1",
            profile="PROFILE-OLD",
        )
        self.assertTrue(
            identity.request_is_owned(
                request,
                self._context(profile="PROFILE-NEW"),
            )
        )

    def test_conflicting_erp_customer_does_not_fall_back_to_profile(self):
        request = _Request(
            erp_customer="ERP-CUST-OTHER",
            profile="PROFILE-1",
        )
        self.assertFalse(
            identity.request_is_owned(
                request,
                self._context(profile="PROFILE-1"),
            )
        )

    def test_profile_fallback_is_legacy_only(self):
        request = _Request(
            profile="PROFILE-1",
        )
        self.assertTrue(
            identity.request_is_owned(
                request,
                self._context(profile="PROFILE-1"),
            )
        )

    def test_mismatched_account_without_erp_customer_fails_closed(self):
        request = _Request(
            account="ACCOUNT-OTHER",
            profile="PROFILE-1",
        )
        self.assertFalse(
            identity.request_is_owned(
                request,
                self._context(profile="PROFILE-1"),
            )
        )


class TestPhase3DashboardOwnershipScope(FrappeTestCase):
    def test_customer_dashboard_uses_permission_owned_request_names(self):
        profile = SimpleNamespace(name="PROFILE-1")

        with (
            patch.object(
                dashboard,
                "_current_user",
                return_value="customer@example.com",
            ),
            patch.object(
                dashboard.permissions,
                "service_request_query",
                return_value="erp_customer = 'ERP-CUST-1'",
            ) as query,
            patch.object(
                dashboard.frappe.db,
                "sql",
                return_value=[
                    frappe._dict({"name": "REQ-1"}),
                    frappe._dict({"name": "REQ-2"}),
                ],
            ) as sql,
        ):
            names = dashboard._owned_service_names(profile)

        self.assertEqual(names, ["REQ-1", "REQ-2"])
        query.assert_called_once_with(
            "customer@example.com"
        )
        self.assertIn(
            "erp_customer = 'ERP-CUST-1'",
            sql.call_args.args[0],
        )
