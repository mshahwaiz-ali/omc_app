from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload


class TestDocumentUploadBoundaries(FrappeTestCase):
    def _service_case(self):
        return SimpleNamespace(name="OMC-SR-TEST")

    @patch("omc_app.api.document_upload.frappe.db.count", return_value=0)
    @patch("omc_app.api.document_upload._find_uploaded_file", return_value=None)
    def test_unknown_attachment_reference_is_rejected(
        self,
        _find_uploaded_file,
        _count,
    ):
        with self.assertRaises(frappe.DoesNotExistError):
            document_upload._validate_uploaded_document(
                self._service_case(),
                "/private/files/unverified.pdf",
            )

    @patch("omc_app.api.document_upload._current_user", return_value="owner@example.com")
    @patch("omc_app.api.document_upload.frappe.db.count", return_value=0)
    @patch("omc_app.api.document_upload._find_uploaded_file")
    def test_file_owned_by_another_user_is_rejected(
        self,
        find_uploaded_file,
        _count,
        _current_user,
    ):
        find_uploaded_file.return_value = SimpleNamespace(
            file_name="receipt.pdf",
            file_url="/private/files/receipt.pdf",
            file_size=128,
            owner="attacker@example.com",
            attached_to_doctype="",
            attached_to_name="",
        )

        with self.assertRaises(frappe.PermissionError):
            document_upload._validate_uploaded_document(
                self._service_case(),
                "/private/files/receipt.pdf",
            )

    @patch("omc_app.api.document_upload._current_user", return_value="owner@example.com")
    @patch("omc_app.api.document_upload.frappe.db.count", return_value=0)
    @patch("omc_app.api.document_upload._find_uploaded_file")
    def test_owned_unattached_file_is_accepted(
        self,
        find_uploaded_file,
        _count,
        _current_user,
    ):
        uploaded_file = SimpleNamespace(
            file_name="receipt.pdf",
            file_url="/private/files/receipt.pdf",
            file_size=128,
            owner="owner@example.com",
            attached_to_doctype="",
            attached_to_name="",
        )
        find_uploaded_file.return_value = uploaded_file

        attachment, resolved_file = document_upload._validate_uploaded_document(
            self._service_case(),
            "/private/files/receipt.pdf",
        )

        self.assertEqual(attachment, "/private/files/receipt.pdf")
        self.assertIs(resolved_file, uploaded_file)
