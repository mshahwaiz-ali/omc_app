from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import permissions
from omc_app.setup.roles import (
    ADMIN_ROLE,
    CONSULTANT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
)


class TestAuthorizationContracts(FrappeTestCase):
    def _query_for(self, function, *, user="user@example.com", roles=()):
        with (
            patch.object(permissions, "_user", return_value=user),
            patch.object(permissions, "_roles", return_value=set(roles)),
            patch.object(permissions.frappe.db, "escape", side_effect=lambda value: f"'{value}'"),
        ):
            return function(user)

    def test_guest_service_request_scope_is_closed(self):
        query = self._query_for(
            permissions.service_request_query,
            user="Guest",
            roles=(),
        )
        self.assertEqual(query, "1=0")

    def test_customer_service_request_scope_uses_canonical_account_ownership(self):
        user = "customer@example.com"
        query = self._query_for(
            permissions.service_request_query,
            user=user,
            roles=(),
        )
        self.assertIn("tabOMC Customer Account", query)
        self.assertIn(f"account.user = '{user}'", query)
        self.assertIn("customer_account = account.name", query)
        self.assertNotIn("requested_for_customer", query)
        self.assertNotIn("submitted_by_user", query)

    def test_customer_profile_scope_uses_canonical_account_ownership(self):
        user = "customer@example.com"
        query = self._query_for(
            permissions.customer_profile_query,
            user=user,
            roles=(),
        )
        self.assertIn("tabOMC Customer Account", query)
        self.assertIn(f"account.user = '{user}'", query)
        self.assertIn("account.legacy_customer_profile", query)
        self.assertNotIn(f"email = '{user}'", query)

    def test_consultant_service_request_scope_requires_assignment_or_consent(self):
        user = "consultant@example.com"
        query = self._query_for(
            permissions.service_request_query,
            user=user,
            roles=(CONSULTANT_ROLE,),
        )
        self.assertIn("tabToDo", query)
        self.assertIn(f"assigned_staff = '{user}'", query)
        self.assertIn("referral_assistance_consent", query)

    def test_reviewer_roles_are_domain_scoped(self):
        document_query = self._query_for(
            permissions.service_document_query,
            roles=(DOCUMENT_REVIEWER_ROLE,),
        )
        payment_query = self._query_for(
            permissions.service_payment_query,
            roles=(DOCUMENT_REVIEWER_ROLE,),
        )
        support_query = self._query_for(
            permissions.support_ticket_query,
            roles=(DOCUMENT_REVIEWER_ROLE,),
        )
        self.assertEqual(document_query, "")
        self.assertIn("tabOMC Customer Account", payment_query)
        self.assertIn("tabOMC Customer Account", support_query)

        finance_payment_query = self._query_for(
            permissions.service_payment_query,
            roles=(FINANCE_REVIEWER_ROLE,),
        )
        finance_document_query = self._query_for(
            permissions.service_document_query,
            roles=(FINANCE_REVIEWER_ROLE,),
        )
        self.assertEqual(finance_payment_query, "")
        self.assertIn("tabOMC Customer Account", finance_document_query)

        support_ticket_query = self._query_for(
            permissions.support_ticket_query,
            roles=(SUPPORT_AGENT_ROLE,),
        )
        support_payment_query = self._query_for(
            permissions.service_payment_query,
            roles=(SUPPORT_AGENT_ROLE,),
        )
        self.assertEqual(support_ticket_query, "")
        self.assertIn("tabOMC Customer Account", support_payment_query)

    def test_privileged_roles_have_unrestricted_query_scope(self):
        for role in (ADMIN_ROLE, MANAGER_ROLE):
            self.assertEqual(
                self._query_for(
                    permissions.service_request_query,
                    roles=(role,),
                ),
                "",
            )

    def test_customer_profile_write_is_not_granted_by_record_scope_hook(self):
        doc = SimpleNamespace(name="PROFILE-0001")
        result = permissions.customer_profile_has_permission(
            doc,
            user="customer@example.com",
            permission_type="write",
        )
        self.assertIsNone(result)

    def test_referral_non_read_permissions_are_deferred(self):
        doc = SimpleNamespace(name="REF-0001")
        for permission_type in ("write", "create", "delete", "submit"):
            self.assertIsNone(
                permissions.referral_has_permission(
                    doc,
                    user="consultant@example.com",
                    permission_type=permission_type,
                )
            )

    def test_restricted_doctype_write_hooks_return_valid_permission_values(self):
        doc = SimpleNamespace(name="DOC-0001")
        checks = (
            permissions.service_request_has_permission,
            permissions.service_document_has_permission,
            permissions.service_payment_has_permission,
            permissions.support_ticket_has_permission,
        )
        with patch.object(
            permissions,
            "_record_matches_query",
            return_value=True,
        ):
            for function in checks:
                result = function(
                    doc,
                    user="user@example.com",
                    permission_type="write",
                )
                self.assertIn(
                    result,
                    (None, True),
                    f"{function.__name__} returned an invalid permission result.",
                )
