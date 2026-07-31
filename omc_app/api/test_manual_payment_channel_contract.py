from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import payments


class TestManualPaymentChannelContract(FrappeTestCase):
    def test_support_url_is_explicitly_not_an_online_gateway(self):
        account = SimpleNamespace(
            account_title="",
            bank_name="",
            account_number="",
            iban="",
            branch="",
            whatsapp_number="923001234567",
            instructions="",
            currency="PKR",
        )
        payment = SimpleNamespace(
            name="OMC-PAY-1",
            service_request="OMC-SR-1",
            amount=5000,
            currency="PKR",
        )
        service_case = SimpleNamespace(name="OMC-SR-1")

        with patch.object(
            payments,
            "_first_payment_account",
            return_value=account,
        ):
            payload = payments._payment_support_payload(
                payment,
                service_case,
            )

        self.assertEqual(
            payload["payment_channel"],
            "whatsapp_support",
        )
        self.assertEqual(
            payload["payment_action_label"],
            "Contact OMC on WhatsApp",
        )
        self.assertFalse(payload["online_gateway_available"])
        self.assertEqual(payload["gateway_url"], "")
        self.assertTrue(
            payload["payment_url"].startswith("https://wa.me/")
        )
        self.assertEqual(
            payload["payment_link"],
            payload["payment_url"],
        )
