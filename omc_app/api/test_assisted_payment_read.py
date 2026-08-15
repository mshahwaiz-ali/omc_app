from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payment_read_guard


class TestAssistedPaymentRead(FrappeTestCase):
    @patch.object(payment_read_guard, "_safe_payment_payload")
    @patch.object(payment_read_guard.frappe, "get_all")
    @patch.object(
        payment_read_guard.customer_service_access,
        "accessible_assisted_service_request_names",
        return_value={"OMC-SR-1"},
    )
    @patch.object(
        payment_read_guard.access,
        "get_mobile_capabilities",
        return_value={"can_view_customer_payments": True},
    )
    @patch.object(
        payment_read_guard.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_assisted_list_is_scoped_and_customer_view(
        self,
        _internal,
        _capabilities,
        allowed,
        get_all,
        safe_payload,
    ):
        payment_row = SimpleNamespace(
            name="OMC-PAY-1",
            payment_title="Service Payment",
            payment_reference="",
            status="Pending",
            service_request="OMC-SR-1",
        )
        payment_row.get = lambda key: getattr(payment_row, key, None)

        case_row = SimpleNamespace(
            name="OMC-SR-1",
            customer_name="Ahmed",
            customer_profile="OMC-CUST-1",
            service_title="Tax Filing",
            service="TAX",
        )
        case_row.get = lambda key: getattr(case_row, key, None)

        get_all.side_effect = [
            [payment_row],
            [case_row],
        ]
        safe_payload.return_value = {"payment_id": "OMC-PAY-1"}

        result = payment_read_guard.get_payments(
            service_request="OMC-SR-1",
            assisted=1,
        )

        allowed.assert_called_once_with(
            internal_capability="can_view_customer_payments",
        )
        safe_payload.assert_called_once_with(
            "OMC-PAY-1",
            capabilities={"can_view_customer_payments": True},
            customer_view=True,
        )
        self.assertEqual(result["total"], 1)

    @patch.object(
        payment_read_guard.customer_service_access,
        "accessible_assisted_service_request_names",
        return_value={"OMC-SR-OTHER"},
    )
    @patch.object(
        payment_read_guard.access,
        "get_mobile_capabilities",
        return_value={"can_view_customer_payments": True},
    )
    @patch.object(
        payment_read_guard.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_assisted_list_rejects_out_of_scope_request(
        self,
        _internal,
        _capabilities,
        _allowed,
    ):
        with self.assertRaises(frappe.PermissionError):
            payment_read_guard.get_payments(
                service_request="OMC-SR-1",
                assisted=1,
            )

    @patch.object(payment_read_guard.payments, "_payment_dict")
    @patch.object(
        payment_read_guard.customer_service_access,
        "assert_service_request_action",
    )
    @patch.object(
        payment_read_guard.access,
        "get_mobile_capabilities",
        return_value={"can_view_customer_payments": True},
    )
    @patch.object(
        payment_read_guard.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    @patch.object(payment_read_guard, "_load_readable_payment")
    def test_assisted_detail_uses_customer_view(
        self,
        load_payment,
        _internal,
        _capabilities,
        assert_action,
        payment_dict,
    ):
        payment = SimpleNamespace(
            name="OMC-PAY-1",
            service_request="OMC-SR-1",
            visible_to_customer=1,
        )
        load_payment.return_value = payment
        payment_dict.return_value = {"payment_id": "OMC-PAY-1"}

        payment_read_guard.get_payment(
            payment_id="OMC-PAY-1",
            assisted=1,
        )

        assert_action.assert_called_once_with(
            "OMC-SR-1",
            internal_capability="can_view_customer_payments",
        )
        payment_dict.assert_called_once_with(
            payment,
            capabilities={"can_view_customer_payments": True},
            customer_view=True,
        )

    @patch.object(
        payment_read_guard.access,
        "get_mobile_capabilities",
        return_value={},
    )
    @patch.object(
        payment_read_guard.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_normal_internal_payment_list_still_requires_reviewer_access(
        self,
        _internal,
        _capabilities,
    ):
        with self.assertRaises(frappe.PermissionError):
            payment_read_guard.get_payments()
