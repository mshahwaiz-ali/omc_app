from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import support_ticket_read_guard


class TestSupportTicketReadGuard(FrappeTestCase):
    def _ticket(self, *, name="SUP-TEST"):
        return SimpleNamespace(name=name)

    def test_hooks_route_support_reads_through_guard(self):
        expected = {
            "omc_app.api.mobile.get_support_tickets": (
                "omc_app.api.support_ticket_read_guard.get_support_tickets"
            ),
            "omc_app.api.mobile.get_support_ticket": (
                "omc_app.api.support_ticket_read_guard.get_support_ticket"
            ),
            "omc_app.api.support_chat.get_support_tickets": (
                "omc_app.api.support_ticket_read_guard.get_support_tickets"
            ),
            "omc_app.api.support_chat.get_support_ticket": (
                "omc_app.api.support_ticket_read_guard.get_support_ticket"
            ),
            "omc_app.api.support_chat.get_active_support_ticket": (
                "omc_app.api.support_ticket_read_guard.get_active_support_ticket"
            ),
        }
        for route, target in expected.items():
            self.assertEqual(hooks.override_whitelisted_methods[route], target)

    @patch("omc_app.api.support_ticket_read_guard.support_chat._capabilities")
    @patch(
        "omc_app.api.support_ticket_read_guard.support_chat._can_access_internal_workspace",
        return_value=False,
    )
    def test_customer_reply_uses_customer_support_capability(
        self,
        internal_access,
        capabilities,
    ):
        capabilities.return_value = {"can_create_support_ticket": True}
        payload = {
            "name": "SUP-TEST",
            "status": "Open",
            "assigned_to": "agent@example.com",
            "can_assign": True,
            "can_reply": False,
        }

        result = support_ticket_read_guard._sanitize_ticket_payload(payload)

        self.assertTrue(result["can_reply"])
        self.assertFalse(result["can_assign"])
        self.assertEqual(result["assigned_to"], "")

    @patch("omc_app.api.support_ticket_read_guard.support_chat._capabilities")
    @patch(
        "omc_app.api.support_ticket_read_guard.support_chat._can_access_internal_workspace",
        return_value=False,
    )
    def test_customer_cannot_reply_to_terminal_ticket(
        self,
        internal_access,
        capabilities,
    ):
        capabilities.return_value = {"can_create_support_ticket": True}
        payload = {"name": "SUP-TEST", "status": "Closed", "can_reply": True}

        result = support_ticket_read_guard._sanitize_ticket_payload(payload)

        self.assertFalse(result["can_reply"])

    @patch(
        "omc_app.api.support_ticket_read_guard.support_chat._can_access_internal_workspace",
        return_value=True,
    )
    def test_internal_assignment_projection_is_preserved(self, internal_access):
        payload = {
            "name": "SUP-TEST",
            "status": "Open",
            "assigned_to": "agent@example.com",
            "can_assign": True,
            "can_reply": True,
        }

        result = support_ticket_read_guard._sanitize_ticket_payload(payload)

        self.assertEqual(result["assigned_to"], "agent@example.com")
        self.assertTrue(result["can_assign"])
        self.assertTrue(result["can_reply"])

    @patch("omc_app.api.support_ticket_read_guard.frappe.db.exists", return_value=False)
    def test_stale_service_request_reference_is_cleared(self, exists):
        payload = {
            "name": "SUP-TEST",
            "reference_service_request": "OMC-SR-MISSING",
        }

        result = support_ticket_read_guard._sanitize_ticket_payload(payload)

        self.assertEqual(result["reference_service_request"], "")
        exists.assert_called_once_with("OMC Service Request", "OMC-SR-MISSING")

    @patch("omc_app.api.support_ticket_read_guard.frappe.db.exists")
    def test_valid_service_request_reference_is_preserved(self, exists):
        exists.return_value = True
        payload = {
            "name": "SUP-TEST",
            "reference_service_request": "OMC-SR-TEST",
        }

        result = support_ticket_read_guard._sanitize_ticket_payload(payload)

        self.assertEqual(result["reference_service_request"], "OMC-SR-TEST")

    @patch("omc_app.api.support_ticket_read_guard._load_ticket")
    def test_safe_payload_skips_concurrently_deleted_ticket(self, load_ticket):
        load_ticket.side_effect = frappe.DoesNotExistError("missing")

        self.assertIsNone(support_ticket_read_guard._safe_ticket_payload("SUP-MISSING"))

    @patch("omc_app.api.support_ticket_read_guard._safe_ticket_payload")
    @patch("omc_app.api.support_ticket_read_guard.frappe.get_all")
    @patch(
        "omc_app.api.support_ticket_read_guard.support_chat._support_ticket_filters_for_current_user"
    )
    def test_list_skips_only_stale_rows(self, filters, get_all, safe_payload):
        filters.return_value = ("admin@example.com", None, {})
        get_all.return_value = ["SUP-STALE", "SUP-LIVE"]
        safe_payload.side_effect = [None, {"name": "SUP-LIVE"}]

        result = support_ticket_read_guard.get_support_tickets()

        self.assertEqual(result["tickets"], [{"name": "SUP-LIVE"}])
        self.assertEqual(result["limit_start"], 0)
        self.assertEqual(result["limit_page_length"], 20)
        self.assertIsNone(result["next_start"])
        self.assertFalse(result["has_more"])

    @patch("omc_app.api.support_ticket_read_guard._sanitize_ticket_payload")
    @patch("omc_app.api.support_ticket_read_guard.support_chat._support_ticket_to_dict")
    @patch("omc_app.api.support_ticket_read_guard.support_chat._assert_support_ticket_access")
    @patch("omc_app.api.support_ticket_read_guard._load_ticket")
    def test_detail_preserves_canonical_access_and_serialization(
        self,
        load_ticket,
        assert_access,
        to_dict,
        sanitize,
    ):
        ticket = self._ticket()
        load_ticket.return_value = ticket
        to_dict.return_value = {"name": "SUP-TEST"}
        sanitize.return_value = {"name": "SUP-TEST"}

        result = support_ticket_read_guard.get_support_ticket(ticket_id="SUP-TEST")

        assert_access.assert_called_once_with(ticket)
        to_dict.assert_called_once_with(ticket)
        self.assertEqual(result, {"ticket": {"name": "SUP-TEST"}})

    @patch("omc_app.api.support_ticket_read_guard._sanitize_ticket_payload")
    @patch("omc_app.api.support_ticket_read_guard.support_chat._support_ticket_to_dict")
    @patch("omc_app.api.support_ticket_read_guard.support_chat._assert_support_ticket_access")
    @patch("omc_app.api.support_ticket_read_guard._load_ticket")
    @patch("omc_app.api.support_ticket_read_guard.frappe.get_all")
    @patch(
        "omc_app.api.support_ticket_read_guard.support_chat._support_ticket_filters_for_current_user"
    )
    def test_active_ticket_skips_stale_race_and_returns_next_valid(
        self,
        filters,
        get_all,
        load_ticket,
        assert_access,
        to_dict,
        sanitize,
    ):
        filters.return_value = ("admin@example.com", None, {})
        get_all.return_value = ["SUP-STALE", "SUP-LIVE"]
        live_ticket = self._ticket(name="SUP-LIVE")
        load_ticket.side_effect = [frappe.DoesNotExistError("missing"), live_ticket]
        to_dict.return_value = {"name": "SUP-LIVE"}
        sanitize.return_value = {"name": "SUP-LIVE"}

        result = support_ticket_read_guard.get_active_support_ticket()

        assert_access.assert_called_once_with(live_ticket)
        self.assertEqual(result, {"ticket": {"name": "SUP-LIVE"}})
