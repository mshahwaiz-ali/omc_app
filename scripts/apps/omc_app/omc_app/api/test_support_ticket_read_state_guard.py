from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import support_ticket_read_state_guard as guard


class TestSupportTicketReadStateGuard(FrappeTestCase):
    def test_hooks_route_read_state_authority(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.support_chat.get_support_unread_count"
            ],
            "omc_app.api.support_ticket_read_state_guard.get_support_unread_count",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.support_chat.mark_support_ticket_read"
            ],
            "omc_app.api.support_ticket_read_state_guard.mark_support_ticket_read",
        )

    @patch("omc_app.api.support_ticket_read_state_guard.support_chat.get_support_unread_count")
    def test_unread_count_delegates_to_canonical(self, canonical):
        canonical.return_value = {"count": 3}
        self.assertEqual(guard.get_support_unread_count(), {"count": 3})
        canonical.assert_called_once_with()

    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.commit")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._support_message_read_filters")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._ensure_initial_message_record")
    @patch("omc_app.api.support_ticket_read_state_guard._load_accessible_ticket")
    def test_no_read_filters_is_idempotent(
        self,
        load_ticket,
        ensure_initial,
        read_filters,
        commit,
    ):
        ticket = SimpleNamespace(name="SUP-0001")
        load_ticket.return_value = (ticket, "user@example.com", None)
        read_filters.return_value = None

        self.assertEqual(guard.mark_support_ticket_read(ticket_id=ticket.name), {"updated": 0})
        ensure_initial.assert_called_once_with(ticket)
        commit.assert_not_called()

    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.commit")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.get_all")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._support_message_read_filters")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._ensure_initial_message_record")
    @patch("omc_app.api.support_ticket_read_state_guard._load_accessible_ticket")
    def test_no_unread_rows_does_not_commit(
        self,
        load_ticket,
        ensure_initial,
        read_filters,
        get_all,
        commit,
    ):
        ticket = SimpleNamespace(name="SUP-0001")
        load_ticket.return_value = (ticket, "user@example.com", None)
        read_filters.return_value = {"read_by_customer": 0}
        get_all.return_value = []

        self.assertEqual(guard.mark_support_ticket_read(ticket_id=ticket.name), {"updated": 0})
        commit.assert_not_called()

    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.commit")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.set_value")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.exists")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.get_all")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._can_access_internal_workspace")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._support_message_read_filters")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._ensure_initial_message_record")
    @patch("omc_app.api.support_ticket_read_state_guard._load_accessible_ticket")
    def test_stale_rows_are_skipped_and_valid_rows_commit_once(
        self,
        load_ticket,
        ensure_initial,
        read_filters,
        can_internal,
        get_all,
        exists,
        set_value,
        commit,
    ):
        ticket = SimpleNamespace(name="SUP-0001")
        load_ticket.return_value = (ticket, "agent@example.com", None)
        read_filters.return_value = {"read_by_staff": 0}
        can_internal.return_value = True
        get_all.return_value = ["MSG-STALE", "MSG-VALID"]
        exists.side_effect = [False, True]

        result = guard.mark_support_ticket_read(ticket_id=ticket.name)

        self.assertEqual(result, {"updated": 1})
        set_value.assert_called_once_with(
            guard.support_chat.SUPPORT_MESSAGE_DOCTYPE,
            "MSG-VALID",
            "read_by_staff",
            1,
            update_modified=False,
        )
        commit.assert_called_once_with()

    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.commit")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.set_value")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.exists")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.get_all")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._can_access_internal_workspace")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._support_message_read_filters")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._ensure_initial_message_record")
    @patch("omc_app.api.support_ticket_read_state_guard._load_accessible_ticket")
    def test_all_stale_rows_do_not_commit(
        self,
        load_ticket,
        ensure_initial,
        read_filters,
        can_internal,
        get_all,
        exists,
        set_value,
        commit,
    ):
        ticket = SimpleNamespace(name="SUP-0001")
        load_ticket.return_value = (ticket, "user@example.com", None)
        read_filters.return_value = {"read_by_customer": 0}
        can_internal.return_value = False
        get_all.return_value = ["MSG-STALE"]
        exists.return_value = False

        self.assertEqual(guard.mark_support_ticket_read(ticket_id=ticket.name), {"updated": 0})
        set_value.assert_not_called()
        commit.assert_not_called()

    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.commit")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.set_value")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.db.exists")
    @patch("omc_app.api.support_ticket_read_state_guard.frappe.get_all")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._can_access_internal_workspace")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._support_message_read_filters")
    @patch("omc_app.api.support_ticket_read_state_guard.support_chat._ensure_initial_message_record")
    @patch("omc_app.api.support_ticket_read_state_guard._load_accessible_ticket")
    def test_customer_read_field_is_preserved(
        self,
        load_ticket,
        ensure_initial,
        read_filters,
        can_internal,
        get_all,
        exists,
        set_value,
        commit,
    ):
        ticket = SimpleNamespace(name="SUP-0001")
        load_ticket.return_value = (ticket, "customer@example.com", object())
        read_filters.return_value = {"read_by_customer": 0}
        can_internal.return_value = False
        get_all.return_value = ["MSG-0001"]
        exists.return_value = True

        result = guard.mark_support_ticket_read(ticket_id=ticket.name)

        self.assertEqual(result, {"updated": 1})
        set_value.assert_called_once_with(
            guard.support_chat.SUPPORT_MESSAGE_DOCTYPE,
            "MSG-0001",
            "read_by_customer",
            1,
            update_modified=False,
        )
        commit.assert_called_once_with()
