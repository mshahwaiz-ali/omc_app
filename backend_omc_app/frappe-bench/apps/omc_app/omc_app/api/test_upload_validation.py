import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import upload_validation


class TestUploadValidation(FrappeTestCase):
    def test_accepts_matching_pdf_signature(self):
        name = upload_validation.validate_upload_bytes(
            filename="receipt.pdf",
            content=b"%PDF-1.7\ncontent",
            allowed_extensions={"pdf"},
            max_size_bytes=1024,
        )
        self.assertEqual(name, "receipt.pdf")

    def test_rejects_forged_extension(self):
        with self.assertRaises(frappe.ValidationError):
            upload_validation.validate_upload_bytes(
                filename="receipt.pdf",
                content=b"not a pdf",
                allowed_extensions={"pdf"},
                max_size_bytes=1024,
            )

    def test_rejects_oversized_content(self):
        with self.assertRaises(frappe.ValidationError):
            upload_validation.validate_upload_bytes(
                filename="receipt.png",
                content=b"\x89PNG\r\n\x1a\nmore",
                allowed_extensions={"png"},
                max_size_bytes=8,
            )
