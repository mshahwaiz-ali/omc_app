from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import support_ticket_guard


class TestSupportTicketGuard(FrappeTestCase):
    def _ticket(self, *, status="Open", assigned_to=""):
        return SimpleNamespace(
            name="OMC-SUP-TEST",
            status=status,
            assigned_to=assigned_to,
            subject="Support request",
            customer_profile="OMC-CUST-TEST",
        )

    def test_hooks_route_support_mutations_through_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.update_support_ticket_status"
            ],
            "omc_app.api.support_ticket_guard.update_support_ticket_status",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.support_chat.update_support_ticket_status"
            ],
            "omc_app.api.support_ticket_guard.update_support_ticket_status",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.support_chat.assign_support_ticket"
            ],
            "omc_app.api.support_ticket_guard.assign_support_ticket",
        )

    @patch("omc_app.api.support_ticket_guard.support_chat._assert_support_ticket_access")
    @patch("omc_app.api.support_ticket_guard.support_chat._can_access_internal_workspace")
    @patch("omc_app.api.support_ticket_guard.frappe.get_doc")
    @patch("omc_app.api.support_ticket_guard.frappe.db.exists", return_value=True)
    def test_load_authorized_ticket_rejects_non_internal_user(
        self,
        exists,
        get_doc,
        can_access_internal,
        assert_access,
    ):
        ticket = self._ticket()
        get_doc.return_value = ticket
        assert_access.return_value = ("customer@example.com", SimpleNamespace())
        can_access_internal.return_value = False

        with self.assertRaises(frappe.PermissionError):
            support_ticket_guard._load_authorized_ticket(ticket.name)

    @patch("omc_app.api.support_ticket_guard.support_chat._support_ticket_to_dict")
    @patch("omc_app.api.support_ticket_guard.support_chat._require_capability")
    @patch("omc_app.api.support_ticket_guard._load_authorized_ticket")
    @patch("omc_app.api.support_ticket_guard.support_chat.update_support_ticket_status")
    def test_duplicate_status_returns_noop_without_delegation(
        self,
        update_status,
        load_ticket,
        require_capability,
        to_dict,
    ):
        ticket = self._ticket(status="In Progress")
        load_ticket.return_value = ticket
        to_dict.return_value = {"name": ticket.name, "status": ticket.status}

        result = support_ticket_guard.update_support_ticket_status(
            ticket_id=ticket.name,
            status="In Progress",
        )

        update_status.assert_not_called()
        require_capability.assert_called_once()
        self.assertFalse(result["updated"])

    @patch("omc_app.api.support_ticket_guard.support_chat.update_support_ticket_status")
    @patch("omc_app.api.support_ticket_guard.support_chat._require_capability")
    @patch("omc_app.api.support_ticket_guard._load_authorized_ticket")
    def test_changed_status_delegates_to_canonical_handler(
        self,
        load_ticket,
        require_capability,
        update_status,
    ):
        load_ticket.return_value = self._ticket(status="Open")
        update_status.return_value = {"updated": True}

        result = support_ticket_guard.update_support_ticket_status(
            ticket_id="OMC-SUP-TEST",
            status="In Progress",
            remarks="Started",
        )

        update_status.assert_called_once_with(
            ticket_id="OMC-SUP-TEST",
            status="In Progress",
            remarks="Started",
        )
        self.assertTrue(result["updated"])

    @patch("omc_app.api.support_ticket_guard.support_chat._require_capability")
    @patch("omc_app.api.support_ticket_guard._load_authorized_ticket")
    def test_terminal_ticket_cannot_be_assigned(self, load_ticket, require_capability):
        load_ticket.return_value = self._ticket(status="Closed")

        with self.assertRaises(frappe.ValidationError):
            support_ticket_guard.assign_support_ticket(
                ticket_id="OMC-SUP-TEST",
                assigned_to="agent@example.com",
            )

    @patch("omc_app.api.support_ticket_guard.support_chat._support_ticket_to_dict")
    @patch("omc_app.api.support_ticket_guard.support_chat._require_capability")
    @patch("omc_app.api.support_ticket_guard._load_authorized_ticket")
    @patch("omc_app.api.support_ticket_guard.support_chat.assign_support_ticket")
    def test_duplicate_assignment_returns_noop_without_delegation(
        self,
        assign_ticket,
        load_ticket,
        require_capability,
        to_dict,
    ):
        ticket = self._ticket(assigned_to="agent@example.com")
        load_ticket.return_value = ticket
        to_dict.return_value = {"name": ticket.name}

        result = support_ticket_guard.assign_support_ticket(
            ticket_id=ticket.name,
            assigned_to="agent@example.com",
        )

        assign_ticket.assert_not_called()
        self.assertFalse(result["updated"])

    @patch("omc_app.api.support_ticket_guard.support_chat.assign_support_ticket")
    @patch("omc_app.api.support_ticket_guard.support_chat._require_capability")
    @patch("omc_app.api.support_ticket_guard._load_authorized_ticket")
    def test_changed_assignment_delegates_to_canonical_handler(
        self,
        load_ticket,
        require_capability,
        assign_ticket,
    ):
        load_ticket.return_value = self._ticket(assigned_to="old@example.com")
        assign_ticket.return_value = {"updated": True}

        result = support_ticket_guard.assign_support_ticket(
            ticket_id="OMC-SUP-TEST",
            assigned_to="new@example.com",
        )

        assign_ticket.assert_called_once_with(
            ticket_id="OMC-SUP-TEST",
            assigned_to="new@example.com",
        )
        self.assertTrue(result["updated"])
