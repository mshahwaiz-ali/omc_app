from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import request_lifecycle


class TestCancellationPaymentSafety(TestCase):
    @staticmethod
    def _payment(
        name,
        *,
        status="Pending",
        linked_payment_entry="",
        accounting_status="Unmatched",
        accounted_amount=0,
    ):
        return SimpleNamespace(
            name=name,
            status=status,
            linked_payment_entry=linked_payment_entry,
            accounting_status=accounting_status,
            accounted_amount=accounted_amount,
        )

    @staticmethod
    def _link(
        payment_entry,
        *,
        payment_docstatus=1,
        allocated_amount=100,
    ):
        return SimpleNamespace(
            payment_entry=payment_entry,
            payment_docstatus=payment_docstatus,
            allocated_amount=allocated_amount,
        )

    def test_unaccounted_child_is_cancelled(self):
        payment = self._payment("OMC-PAY-UNACCOUNTED")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[payment], []],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
            ) as get_value,
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-1")

        get_value.assert_not_called()
        set_value.assert_called_once_with(
            "OMC Service Payment",
            "OMC-PAY-UNACCOUNTED",
            {"status": "Cancelled", "visible_to_customer": 0},
            update_modified=False,
        )

    def test_repeat_cleanup_is_idempotent(self):
        payment = self._payment("OMC-PAY-ONCE")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[
                    [payment],
                    [],
                    [],
                ],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-1")
            request_lifecycle._cancel_open_payments("OMC-SR-1")

        self.assertEqual(set_value.call_count, 1)

    def test_direct_child_accounting_evidence_is_preserved(self):
        rows = [
            self._payment(
                "OMC-PAY-LINKED",
                linked_payment_entry="ACC-PAY-1",
            ),
            self._payment(
                "OMC-PAY-PARTIAL",
                accounting_status="Partially Settled",
            ),
            self._payment(
                "OMC-PAY-SETTLED",
                accounting_status="Settled",
            ),
            self._payment(
                "OMC-PAY-AMOUNT",
                accounted_amount=50,
            ),
        ]

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                return_value=rows,
            ) as get_all,
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-1")

        self.assertEqual(get_all.call_count, 1)
        set_value.assert_not_called()

    def test_submitted_accounting_link_preserves_stale_child_projection(self):
        payment = self._payment("OMC-PAY-STALE")
        link = self._link("ACC-PAY-SUBMITTED")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[payment], [link]],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
                return_value=1,
            ) as get_value,
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-1")

        get_value.assert_called_once_with(
            "Payment Entry",
            "ACC-PAY-SUBMITTED",
            "docstatus",
        )
        set_value.assert_not_called()

    def test_cancelled_erp_payment_does_not_protect_unaccounted_child(self):
        payment = self._payment("OMC-PAY-UNACCOUNTED")
        stale_link = self._link("ACC-PAY-CANCELLED")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[payment], [stale_link]],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
                return_value=2,
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-1")

        set_value.assert_called_once_with(
            "OMC Service Payment",
            "OMC-PAY-UNACCOUNTED",
            {"status": "Cancelled", "visible_to_customer": 0},
            update_modified=False,
        )

    def test_mixed_request_cancels_only_unaccounted_child(self):
        accounted = self._payment(
            "OMC-PAY-ACCOUNTED",
            linked_payment_entry="ACC-PAY-1",
        )
        unaccounted = self._payment("OMC-PAY-UNACCOUNTED")
        link = self._link("ACC-PAY-1")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[accounted, unaccounted], [link]],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
                return_value=1,
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-MIXED")

        set_value.assert_called_once_with(
            "OMC Service Payment",
            "OMC-PAY-UNACCOUNTED",
            {"status": "Cancelled", "visible_to_customer": 0},
            update_modified=False,
        )

        # Operational cleanup must never alter ERP Payment Entry records.
        for call in set_value.call_args_list:
            self.assertEqual(call.args[0], "OMC Service Payment")

    def test_paid_sibling_claims_its_submitted_accounting_link(self):
        paid = self._payment(
            "OMC-PAY-PAID",
            status="Paid",
            linked_payment_entry="ACC-PAY-PAID",
            accounting_status="Settled",
            accounted_amount=100,
        )
        unaccounted = self._payment(
            "OMC-PAY-UNACCOUNTED",
            status="Pending",
        )
        link = self._link(
            "ACC-PAY-PAID",
            payment_docstatus=1,
            allocated_amount=100,
        )

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[paid, unaccounted], [link]],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
                return_value=1,
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments(
                "OMC-SR-PAID-SIBLING"
            )

        set_value.assert_called_once_with(
            "OMC Service Payment",
            "OMC-PAY-UNACCOUNTED",
            {
                "status": "Cancelled",
                "visible_to_customer": 0,
            },
            update_modified=False,
        )

    def test_ambiguous_request_level_accounting_fails_closed(self):
        first = self._payment("OMC-PAY-1")
        second = self._payment("OMC-PAY-2")
        link = self._link("ACC-PAY-UNKNOWN-CHILD")

        with (
            patch.object(
                request_lifecycle.frappe,
                "get_all",
                side_effect=[[first, second], [link]],
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "get_value",
                return_value=1,
            ),
            patch.object(
                request_lifecycle.frappe.db,
                "set_value",
            ) as set_value,
        ):
            request_lifecycle._cancel_open_payments("OMC-SR-AMBIGUOUS")

        set_value.assert_not_called()
