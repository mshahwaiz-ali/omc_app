from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload, mobile


class TestPrivateFileIntegrity(FrappeTestCase):
    @patch.object(mobile.frappe, "get_doc")
    @patch.object(mobile.frappe.db, "exists", return_value="FILE-1")
    def test_exact_url_is_preferred(self, exists, get_doc):
        get_doc.return_value = SimpleNamespace(name="FILE-1")

        result = mobile._find_uploaded_file(
            "/private/files/a.pdf"
        )

        self.assertEqual(result.name, "FILE-1")
        exists.assert_called_once_with(
            "File",
            {"file_url": "/private/files/a.pdf"},
        )

    @patch.object(mobile.frappe, "get_doc")
    @patch.object(mobile.frappe, "get_all")
    @patch.object(mobile.frappe.db, "exists", return_value=None)
    def test_filename_fallback_is_owner_scoped(
        self,
        _exists,
        get_all,
        get_doc,
    ):
        get_all.return_value = [SimpleNamespace(name="FILE-2")]
        get_doc.return_value = SimpleNamespace(name="FILE-2")

        with patch.object(
            mobile,
            "_current_user",
            return_value="u@example.com",
        ):
            result = mobile._find_uploaded_file("a.pdf")

        self.assertEqual(result.name, "FILE-2")
        get_all.assert_called_once_with(
            "File",
            filters={
                "file_name": "a.pdf",
                "owner": "u@example.com",
            },
            fields=["name"],
            order_by="creation desc",
            limit_page_length=2,
        )

    @patch.object(mobile.frappe, "get_all")
    @patch.object(mobile.frappe.db, "exists", return_value=None)
    def test_ambiguous_filename_is_rejected(
        self,
        _exists,
        get_all,
    ):
        get_all.return_value = [
            SimpleNamespace(name="A"),
            SimpleNamespace(name="B"),
        ]

        with patch.object(
            mobile,
            "_current_user",
            return_value="u@example.com",
        ):
            with self.assertRaises(frappe.ValidationError):
                mobile._find_uploaded_file("a.pdf")

    @patch.object(document_upload.frappe, "delete_doc")
    def test_unlinked_current_user_file_is_cleaned(self, delete_doc):
        file_doc = SimpleNamespace(
            name="FILE-X",
            owner="u@example.com",
            attached_to_doctype="",
            attached_to_name="",
        )

        with patch.object(
            document_upload,
            "_current_user",
            return_value="u@example.com",
        ):
            result = document_upload._cleanup_failed_unlinked_upload(
                file_doc
            )

        self.assertTrue(result)
        delete_doc.assert_called_once_with(
            "File",
            "FILE-X",
            ignore_permissions=True,
            force=True,
        )

    @patch.object(document_upload.frappe, "delete_doc")
    def test_linked_file_is_preserved(self, delete_doc):
        file_doc = SimpleNamespace(
            name="FILE-X",
            owner="u@example.com",
            attached_to_doctype="OMC Service Document",
            attached_to_name="DOC-1",
        )

        with patch.object(
            document_upload,
            "_current_user",
            return_value="u@example.com",
        ):
            result = document_upload._cleanup_failed_unlinked_upload(
                file_doc
            )

        self.assertFalse(result)
        delete_doc.assert_not_called()

    @patch.object(document_upload.frappe, "delete_doc")
    def test_other_user_file_is_preserved(self, delete_doc):
        file_doc = SimpleNamespace(
            name="FILE-X",
            owner="other@example.com",
            attached_to_doctype="",
            attached_to_name="",
        )

        with patch.object(
            document_upload,
            "_current_user",
            return_value="u@example.com",
        ):
            result = document_upload._cleanup_failed_unlinked_upload(
                file_doc
            )

        self.assertFalse(result)
        delete_doc.assert_not_called()
