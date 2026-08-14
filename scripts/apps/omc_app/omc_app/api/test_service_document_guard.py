from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import service_document_guard


class TestServiceDocumentGuard(FrappeTestCase):
    def _document(self, *, status="Uploaded", service_request="OMC-SR-TEST"):
        return SimpleNamespace(
            name="OMC-DOC-TEST",
            service_request=service_request,
            status=status,
            remarks="",
            review_remarks="",
        )

    def test_hooks_route_document_detail_and_reviews_through_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.customer_documents.get_document"
            ],
            "omc_app.api.service_document_guard.get_document",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.customer_documents.update_service_document_status"
            ],
            "omc_app.api.service_document_guard.update_service_document_status",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.update_service_document_status"
            ],
            "omc_app.api.service_document_guard.update_service_document_status",
        )

    @patch("omc_app.api.service_document_guard.frappe.get_doc")
    @patch("omc_app.api.service_document_guard.frappe.db.get_value", return_value="Open")
    @patch("omc_app.api.service_document_guard.frappe.db.exists")
    def test_load_document_requires_existing_parent(self, exists, get_value, get_doc):
        exists.side_effect = [True, False]
        get_doc.return_value = self._document()

        with self.assertRaises(frappe.DoesNotExistError):
            service_document_guard._load_document_with_parent("OMC-DOC-TEST")

        get_value.assert_not_called()

    @patch("omc_app.api.service_document_guard.frappe.get_doc")
    @patch("omc_app.api.service_document_guard.frappe.db.exists", return_value=True)
    def test_blank_parent_is_rejected(self, exists, get_doc):
        get_doc.return_value = self._document(service_request="")

        with self.assertRaises(frappe.DoesNotExistError):
            service_document_guard._load_document_with_parent("OMC-DOC-TEST")

    @patch("omc_app.api.service_document_guard.customer_documents.get_document")
    @patch("omc_app.api.service_document_guard._load_document_with_parent")
    def test_detail_delegates_only_after_parent_guard(self, load_document, get_document):
        load_document.return_value = (self._document(), "OMC-SR-TEST", "Open")
        get_document.return_value = {"name": "OMC-DOC-TEST"}

        result = service_document_guard.get_document(document_id="OMC-DOC-TEST")

        load_document.assert_called_once_with("OMC-DOC-TEST")
        get_document.assert_called_once_with(document_id="OMC-DOC-TEST")
        self.assertEqual(result["name"], "OMC-DOC-TEST")

    @patch("omc_app.api.service_document_guard.customer_documents.update_service_document_status")
    @patch("omc_app.api.service_document_guard._load_document_with_parent")
    @patch("omc_app.api.service_document_guard.customer_documents._require_document_review_access")
    def test_terminal_parent_rejects_review_before_delegation(
        self,
        require_access,
        load_document,
        update_status,
    ):
        load_document.return_value = (
            self._document(),
            "OMC-SR-TEST",
            "Completed",
        )

        with self.assertRaises(frappe.ValidationError):
            service_document_guard.update_service_document_status(
                document_id="OMC-DOC-TEST",
                status="Approved",
            )

        require_access.assert_called_once_with()
        update_status.assert_not_called()

    @patch("omc_app.api.service_document_guard.customer_documents.update_service_document_status")
    @patch("omc_app.api.service_document_guard._load_document_with_parent")
    @patch("omc_app.api.service_document_guard.customer_documents._require_document_review_access")
    def test_duplicate_review_returns_noop_without_side_effects(
        self,
        require_access,
        load_document,
        update_status,
    ):
        document = self._document(status="Approved")
        document.review_remarks = "Verified"
        load_document.return_value = (document, "OMC-SR-TEST", "In Progress")

        result = service_document_guard.update_service_document_status(
            document_id="OMC-DOC-TEST",
            status="Approved",
            remarks="Verified",
        )

        update_status.assert_not_called()
        self.assertFalse(result["updated"])
        self.assertEqual(result["case_status"], "In Progress")

    @patch("omc_app.api.service_document_guard.customer_documents.update_service_document_status")
    @patch("omc_app.api.service_document_guard._load_document_with_parent")
    @patch("omc_app.api.service_document_guard.customer_documents._require_document_review_access")
    def test_changed_review_delegates_to_canonical_handler(
        self,
        require_access,
        load_document,
        update_status,
    ):
        load_document.return_value = (
            self._document(status="Uploaded"),
            "OMC-SR-TEST",
            "In Progress",
        )
        update_status.return_value = {"updated": True, "status": "Approved"}

        result = service_document_guard.update_service_document_status(
            document_id="OMC-DOC-TEST",
            status="Approved",
            remarks="Verified",
        )

        update_status.assert_called_once_with(
            document_id="OMC-DOC-TEST",
            status="Approved",
            remarks="Verified",
        )
        self.assertTrue(result["updated"])
