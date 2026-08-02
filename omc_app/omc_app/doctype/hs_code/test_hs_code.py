import frappe
from frappe.tests.utils import FrappeTestCase


class TestHSCode(FrappeTestCase):
    def test_code_is_normalized_for_stable_link_values(self):
        doc = frappe.get_doc(
            {
                "doctype": "HS Code",
                "hs_code": " qa-12.34 ",
                "description": "Normalization fixture",
            }
        ).insert(ignore_permissions=True)
        self.assertEqual(doc.name, "QA-12.34")
        self.assertEqual(doc.hs_code, "QA-12.34")

    def test_invalid_code_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            frappe.get_doc(
                {"doctype": "HS Code", "hs_code": "invalid/code"}
            ).insert(ignore_permissions=True)
