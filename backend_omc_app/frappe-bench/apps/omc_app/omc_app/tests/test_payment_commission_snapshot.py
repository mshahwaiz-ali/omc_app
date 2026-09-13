from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import payment_accounting


class _Field:
    def __init__(self, options=""):
        self.options = options


class _PaymentEntryMeta:
    def __init__(self):
        self._fields = {
            "custom_structure_name": _Field(),
            "custom_source": _Field(
                "Consultant\nBusiness Partner\nTax Associates\nEmployee"
            ),
            "custom_sales_person": _Field(),
            "custom_omc_percentage": _Field(),
            "custom_sales_person_percentage": _Field(),
            "custom_remarks": _Field(),
        }

    def get_field(self, fieldname):
        return self._fields.get(fieldname)


class _FakePaymentEntry:
    def __init__(self, customer):
        self.party_type = "Customer"
        self.party = customer
        self.meta = _PaymentEntryMeta()
        self.flags = SimpleNamespace()
        self.inserted = False
        self.submitted = False
        self.snapshot_at_insert = None

    def insert(self, ignore_permissions=False):
        self.snapshot_at_insert = {
            "structure": getattr(self, "custom_structure_name", None),
            "source": getattr(self, "custom_source", None),
            "sales_person": getattr(self, "custom_sales_person", None),
            "omc_percentage": getattr(self, "custom_omc_percentage", None),
            "sales_person_percentage": getattr(
                self, "custom_sales_person_percentage", None
            ),
        }
        self.inserted = True
        return self

    def submit(self):
        self.submitted = True
        return self


class TestPaymentEntryCommissionSnapshot(FrappeTestCase):
    @staticmethod
    def _receipt(amount):
        return SimpleNamespace(
            verified_amount=amount,
            submitted_reference="BANK-REF-001",
            gateway_transaction_id="",
            name="OMC-PAY-TEST-00001",
            service_request="OMC-SR-TEST-00001",
        )

    @staticmethod
    def _invoice(customer="CUST-TEST-00001"):
        return SimpleNamespace(
            name="SINV-TEST-00001",
            customer=customer,
        )

    @staticmethod
    def _account():
        return {
            "erp_account": "Bank - TEST",
            "mode_of_payment": "Bank",
        }

    @staticmethod
    def _valid_exists(doctype, name):
        return (
            (doctype == "DocType" and name == "Consultant")
            or (
                doctype == "Consultant"
                and name == "asif@omchouse.com"
            )
        )

    def test_snapshot_uses_customer_identity_and_structure_fields_before_insert(self):
        payment_entry = _FakePaymentEntry("CUST-TEST-00001")

        def get_value(doctype, name, fields, as_dict=False):
            if doctype == "Customer":
                return {
                    "structure_name": "80 / 20",
                    "source": "Consultant",
                    "sales_person": "asif@omchouse.com",
                }
            if doctype == "Sales Team Commission Structure":
                self.assertEqual(name, "80 / 20")
                return {
                    "omc": 50,
                    "sales_person": 50,
                }
            self.fail(f"Unexpected get_value call: {doctype} {name}")

        with (
            patch(
                "erpnext.accounts.doctype.payment_entry.payment_entry.get_payment_entry",
                return_value=payment_entry,
            ) as get_payment_entry,
            patch.object(
                payment_accounting.frappe.db,
                "get_value",
                side_effect=get_value,
            ),
            patch.object(
                payment_accounting.frappe.db,
                "exists",
                side_effect=self._valid_exists,
            ),
        ):
            result = payment_accounting._create_payment_entry(
                self._receipt(4000),
                self._invoice(),
                self._account(),
            )

        self.assertIs(result, payment_entry)
        self.assertTrue(payment_entry.inserted)
        self.assertTrue(payment_entry.submitted)

        self.assertEqual(
            payment_entry.snapshot_at_insert,
            {
                "structure": "80 / 20",
                "source": "Consultant",
                "sales_person": "asif@omchouse.com",
                "omc_percentage": 50.0,
                "sales_person_percentage": 50.0,
            },
        )

        # The structure name must never be parsed for percentages.
        self.assertEqual(payment_entry.custom_structure_name, "80 / 20")
        self.assertEqual(payment_entry.custom_omc_percentage, 50.0)
        self.assertEqual(payment_entry.custom_sales_person_percentage, 50.0)

        # Accounting amount remains the individual verified installment.
        _, kwargs = get_payment_entry.call_args
        self.assertEqual(kwargs["party_amount"], 4000)

        # Snapshot phase does not manufacture commission amount fields.
        self.assertFalse(hasattr(payment_entry, "custom_sales_person_amount"))

    def test_missing_commission_config_does_not_block_payment_entry(self):
        payment_entry = _FakePaymentEntry("CUST-TEST-00001")

        with (
            patch(
                "erpnext.accounts.doctype.payment_entry.payment_entry.get_payment_entry",
                return_value=payment_entry,
            ),
            patch.object(
                payment_accounting.frappe.db,
                "get_value",
                return_value={
                    "structure_name": "",
                    "source": "Consultant",
                    "sales_person": "asif@omchouse.com",
                },
            ),
            patch.object(payment_accounting.frappe.db, "exists") as exists,
        ):
            result = payment_accounting._create_payment_entry(
                self._receipt(3000),
                self._invoice(),
                self._account(),
            )

        self.assertIs(result, payment_entry)
        self.assertTrue(payment_entry.inserted)
        self.assertTrue(payment_entry.submitted)
        self.assertIsNone(payment_entry.snapshot_at_insert["structure"])
        self.assertIsNone(payment_entry.snapshot_at_insert["source"])
        self.assertIsNone(payment_entry.snapshot_at_insert["sales_person"])
        exists.assert_not_called()

    def test_later_installment_gets_its_own_current_snapshot(self):
        first = _FakePaymentEntry("CUST-TEST-00001")
        second = _FakePaymentEntry("CUST-TEST-00001")
        entries = [first, second]

        customer_snapshots = iter(
            [
                {
                    "structure_name": "50 / 50",
                    "source": "Consultant",
                    "sales_person": "asif@omchouse.com",
                },
                {
                    "structure_name": "70 / 30",
                    "source": "Consultant",
                    "sales_person": "asif@omchouse.com",
                },
            ]
        )

        def get_value(doctype, name, fields, as_dict=False):
            if doctype == "Customer":
                return next(customer_snapshots)
            if doctype == "Sales Team Commission Structure":
                if name == "50 / 50":
                    return {"omc": 50, "sales_person": 50}
                if name == "70 / 30":
                    return {"omc": 70, "sales_person": 30}
            self.fail(f"Unexpected get_value call: {doctype} {name}")

        with (
            patch(
                "erpnext.accounts.doctype.payment_entry.payment_entry.get_payment_entry",
                side_effect=entries,
            ),
            patch.object(
                payment_accounting.frappe.db,
                "get_value",
                side_effect=get_value,
            ),
            patch.object(
                payment_accounting.frappe.db,
                "exists",
                side_effect=self._valid_exists,
            ),
        ):
            payment_accounting._create_payment_entry(
                self._receipt(4000),
                self._invoice(),
                self._account(),
            )
            payment_accounting._create_payment_entry(
                self._receipt(3000),
                self._invoice(),
                self._account(),
            )

        self.assertEqual(first.snapshot_at_insert["structure"], "50 / 50")
        self.assertEqual(first.snapshot_at_insert["omc_percentage"], 50.0)
        self.assertEqual(first.snapshot_at_insert["sales_person_percentage"], 50.0)

        self.assertEqual(second.snapshot_at_insert["structure"], "70 / 30")
        self.assertEqual(second.snapshot_at_insert["omc_percentage"], 70.0)
        self.assertEqual(second.snapshot_at_insert["sales_person_percentage"], 30.0)

        # The first Payment Entry remains its original immutable snapshot.
        self.assertEqual(first.custom_structure_name, "50 / 50")
        self.assertEqual(first.custom_omc_percentage, 50.0)
