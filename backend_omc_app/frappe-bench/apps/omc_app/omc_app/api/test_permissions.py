from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import permissions
from omc_app.api import mobile
from omc_app.setup.roles import (
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_BLOCKED_DOCTYPES,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    TAX_ASSOCIATE_ROLE,
)


class TestPermissionSchemaContract(FrappeTestCase):
    def test_support_ticket_scope_fields_exist(self):
        meta = frappe.get_meta("OMC Support Ticket")
        for fieldname in (
            "customer_profile",
            "reference_service_request",
            "assigned_to",
        ):
            with self.subTest(fieldname=fieldname):
                self.assertTrue(meta.has_field(fieldname))

    def test_task_scope_fields_exist(self):
        meta = frappe.get_meta("OMC Task")
        for fieldname in (
            "assigned_to",
            "customer_profile",
            "service_request",
            "support_ticket",
        ):
            with self.subTest(fieldname=fieldname):
                self.assertTrue(meta.has_field(fieldname))


class TestPermissionQueryConditions(FrappeTestCase):
    def _query_for(self, query_function, role, user="worker@example.com"):
        with patch.object(permissions, "_roles", return_value={role}):
            return query_function(user=user)

    def test_manager_queries_are_unrestricted(self):
        for query_function in (
            permissions.service_request_query,
            permissions.customer_profile_query,
            permissions.task_query,
            permissions.service_document_query,
            permissions.service_payment_query,
            permissions.support_ticket_query,
            permissions.lead_query,
        ):
            with self.subTest(query=query_function.__name__):
                self.assertEqual(
                    self._query_for(query_function, MANAGER_ROLE),
                    "",
                )

    def test_field_roles_are_assignment_scoped(self):
        for role in (
            CONSULTANT_ROLE,
            TAX_ASSOCIATE_ROLE,
            BUSINESS_PARTNER_ROLE,
        ):
            with self.subTest(role=role):
                service_query = self._query_for(
                    permissions.service_request_query,
                    role,
                )
                document_query = self._query_for(
                    permissions.service_document_query,
                    role,
                )
                task_query = self._query_for(
                    permissions.task_query,
                    role,
                )

                self.assertIn("tabToDo", service_query)
                self.assertIn("allocated_to", service_query)
                self.assertIn("tabToDo", document_query)
                self.assertIn("assigned_to", task_query)

    def test_document_reviewer_has_document_domain_only(self):
        document_query = self._query_for(
            permissions.service_document_query,
            DOCUMENT_REVIEWER_ROLE,
        )
        payment_query = self._query_for(
            permissions.service_payment_query,
            DOCUMENT_REVIEWER_ROLE,
        )

        self.assertEqual(document_query, "")
        self.assertEqual(payment_query, "1=0")

    def test_finance_reviewer_has_payment_domain_only(self):
        payment_query = self._query_for(
            permissions.service_payment_query,
            FINANCE_REVIEWER_ROLE,
        )
        document_query = self._query_for(
            permissions.service_document_query,
            FINANCE_REVIEWER_ROLE,
        )

        self.assertEqual(payment_query, "")
        self.assertEqual(document_query, "1=0")

    def test_support_agent_has_support_and_lead_domains(self):
        support_query = self._query_for(
            permissions.support_ticket_query,
            SUPPORT_AGENT_ROLE,
        )
        lead_query = self._query_for(
            permissions.lead_query,
            SUPPORT_AGENT_ROLE,
        )

        self.assertEqual(support_query, "")
        self.assertEqual(lead_query, "")


class TestManagerConfigurationBoundary(FrappeTestCase):
    def test_manager_blocked_doctypes_cover_configuration_surfaces(self):
        expected = {
            "OMC Branding Settings",
            "OMC Mobile Settings",
            "OMC Mobile Quick Action",
            "OMC Service",
            "OMC Service Category",
            "OMC Service Form Field",
            "OMC Service Required Document",
            "OMC Service Stage Template",
            "OMC App Banner",
            "OMC Onboarding Slide",
            "OMC FAQ",
            "OMC Knowledge Article",
            "OMC Announcement",
            "OMC Expense Category",
            "OMC Payment Account",
            "OMC Tax Adjustment Rule",
            "OMC Tax Calculator Settings",
            "OMC Tax Input Field",
            "OMC Tax Result Insight",
            "OMC Tax Year",
        }
        self.assertTrue(expected.issubset(MANAGER_BLOCKED_DOCTYPES))


class TestMobileServiceCaseScope(FrappeTestCase):
    def test_assigned_service_case_scope_returns_only_assigned_names(self):
        capabilities = {
            "can_view_all_service_cases": False,
            "can_view_relevant_service_cases": False,
            "can_view_assigned_service_cases": True,
        }
        with patch.object(
            mobile,
            "_assigned_record_names",
            return_value=["SR-ASSIGNED-1", "SR-ASSIGNED-2"],
        ):
            names = mobile._service_case_scope_names(
                capabilities,
                user="consultant@example.com",
            )

        self.assertEqual(names, ["SR-ASSIGNED-1", "SR-ASSIGNED-2"])

    def test_unassigned_service_case_status_update_is_rejected(self):
        capabilities = {
            "can_update_service_status": False,
            "can_update_assigned_service_status": True,
        }
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="consultant@example.com",
            ),
            patch.object(
                mobile,
                "_canonical_capabilities",
                return_value=capabilities,
            ),
            patch.object(
                mobile,
                "_assigned_record_names",
                return_value=["SR-ASSIGNED"],
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            mobile._require_service_case_update_scope("SR-UNASSIGNED")


class TestTaskAssignmentBoundary(FrappeTestCase):
    def _task(self, assigned_to, *, name="TASK-1", is_new=False):
        return SimpleNamespace(
            assigned_to=assigned_to,
            name=name,
            is_new=lambda: is_new,
        )

    def test_disabled_task_assignee_is_rejected(self):
        task = self._task("disabled@example.com")
        with (
            patch.object(
                permissions.frappe.db,
                "get_value",
                return_value=SimpleNamespace(
                    enabled=0,
                    user_type="System User",
                ),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            permissions.validate_task_assignment(task)

    def test_website_user_task_assignee_is_rejected(self):
        task = self._task("customer@example.com")
        with (
            patch.object(
                permissions.frappe.db,
                "get_value",
                return_value=SimpleNamespace(
                    enabled=1,
                    user_type="Website User",
                ),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            permissions.validate_task_assignment(task)

    def test_specialist_cannot_reassign_existing_task(self):
        task = self._task("new-assignee@example.com")
        user_values = SimpleNamespace(
            enabled=1,
            user_type="System User",
        )

        def get_value(doctype, name, fieldname, **kwargs):
            if doctype == "User":
                return user_values
            if doctype == "OMC Task":
                return "old-assignee@example.com"
            return None

        with (
            patch.object(permissions.frappe.db, "get_value", side_effect=get_value),
            patch.object(
                permissions,
                "_roles",
                return_value={CONSULTANT_ROLE},
            ),
            patch.object(
                permissions,
                "_user",
                return_value="consultant@example.com",
            ),
            patch.object(
                permissions,
                "_privileged",
                return_value=False,
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            permissions.validate_task_assignment(task)
