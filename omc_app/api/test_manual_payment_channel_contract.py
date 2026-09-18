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

    def test_bank_account_contract_comes_from_active_desk_configuration(self):
        account = SimpleNamespace(
            title="Primary PKR Account",
            account_title="OMC Services Pvt Ltd",
            bank_name="Meezan Bank",
            account_number="00123456789",
            iban="PK00MEZN001234567890",
            branch="Gulberg",
            whatsapp_number="923001234567",
            instructions="Transfer the amount and upload the receipt.",
            currency="PKR",
        )
        payment = SimpleNamespace(
            name="OMC-PAY-2",
            service_request="OMC-SR-2",
            amount=2500,
            currency="PKR",
        )
        service_case = SimpleNamespace(name="OMC-SR-2")

        with patch.object(payments, "_first_payment_account", return_value=account):
            payload = payments._payment_support_payload(payment, service_case)

        self.assertEqual(
            payload["bank_account"],
            {
                "title": "Primary PKR Account",
                "bank_name": "Meezan Bank",
                "account_title": "OMC Services Pvt Ltd",
                "account_number": "00123456789",
                "iban": "PK00MEZN001234567890",
                "branch": "Gulberg",
                "currency": "PKR",
            },
        )
        self.assertIn("Meezan Bank", payload["bank_account_details"])
        self.assertIn("00123456789", payload["bank_account_details"])
        self.assertIn("PK00MEZN001234567890", payload["bank_account_details"])
        self.assertIn("Currency: PKR", payload["bank_account_details"])
