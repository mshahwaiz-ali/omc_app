from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload


class TestDocumentResubmissionIntegrity(FrappeTestCase):
    def _case(self):
        return SimpleNamespace(name="OMC-SR-1")

    @patch.object(document_upload.frappe, "get_all", return_value=[])
    def test_first_submission_is_allowed(self, _get_all):
        document_upload._assert_document_submission_available(
            self._case(),
            "CNIC Front",
            "CNIC",
        )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-1",
                document_title="CNIC Front",
                document_type="CNIC",
                status="Uploaded",
                is_archived=0,
            )
        ],
    )
    def test_uploaded_duplicate_is_rejected(self, _get_all):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_document_submission_available(
                self._case(),
                "CNIC Front",
                "CNIC",
            )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-1",
                document_title="CNIC Front",
                document_type="CNIC",
                status="Approved",
                is_archived=0,
            )
        ],
    )
    def test_approved_duplicate_is_rejected(self, _get_all):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_document_submission_available(
                self._case(),
                "CNIC Front",
                "CNIC",
            )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-OLD",
                document_title="CNIC Front",
                document_type="CNIC",
                status="Rejected",
                is_archived=0,
            )
        ],
    )
    def test_rejected_document_allows_corrected_resubmission(
        self,
        _get_all,
    ):
        document_upload._assert_document_submission_available(
            self._case(),
            "CNIC Front",
            "CNIC",
        )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-OLD",
                document_title="  cnic   front ",
                document_type="cnic",
                status="Pending",
                is_archived=0,
            )
        ],
    )
    def test_document_identity_is_case_and_space_normalized(
        self,
        _get_all,
    ):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_document_submission_available(
                self._case(),
                "CNIC Front",
                "CNIC",
            )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-ARCHIVED",
                document_title="CNIC Front",
                document_type="CNIC",
                status="Approved",
                is_archived=1,
            )
        ],
    )
    def test_archived_history_does_not_block_new_submission(
        self,
        _get_all,
    ):
        document_upload._assert_document_submission_available(
            self._case(),
            "CNIC Front",
            "CNIC",
        )

    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[
            SimpleNamespace(
                name="OMC-DOC-OTHER",
                document_title="CNIC Back",
                document_type="CNIC",
                status="Uploaded",
                is_archived=0,
            )
        ],
    )
    def test_different_document_identity_is_allowed(self, _get_all):
        document_upload._assert_document_submission_available(
            self._case(),
            "CNIC Front",
            "CNIC",
        )
