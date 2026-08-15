from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_documents, customer_service_access, document_upload


class TestDocumentMutationAuthority(FrappeTestCase):
    def test_completed_request_rejects_document_upload(self):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_service_request_accepts_documents(
                SimpleNamespace(status="Completed")
            )

    def test_cancelled_request_rejects_document_upload(self):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_service_request_accepts_documents(
                SimpleNamespace(status="Cancelled")
            )

    def test_open_request_accepts_document_upload(self):
        document_upload._assert_service_request_accepts_documents(
            SimpleNamespace(status="Open")
        )

    @patch.object(
        customer_service_access.access,
        "get_mobile_capabilities",
        return_value={
            "can_manage_customer_service_flow": True,
            "can_upload_customer_documents": True,
        },
    )
    @patch.object(
        customer_service_access.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    @patch.object(
        customer_service_access,
        "_current_user",
        return_value="associate@example.com",
    )
    @patch.object(customer_service_access.frappe, "get_doc")
    @patch.object(customer_service_access.frappe.db, "exists", return_value=True)
    def test_internal_can_manage_own_referral_request(
        self,
        _exists,
        get_doc,
        _current_user,
        _is_internal,
        _capabilities,
    ):
        service_case = SimpleNamespace(
            name="OMC-SR-1",
            customer_mode="My Referral",
            referral_owner="associate@example.com",
            customer_profile="OMC-CUST-1",
            created_on_behalf=1,
            submitted_by_internal_user="associate@example.com",
        )
        profile = SimpleNamespace(name="OMC-CUST-1")
        get_doc.side_effect = [service_case, profile]

        authority = customer_service_access.assert_service_request_action(
            "OMC-SR-1",
            internal_capability="can_upload_customer_documents",
        )

        self.assertTrue(authority["is_internal"])
        self.assertEqual(authority["scope_type"], "my_referral")
        self.assertEqual(authority["service_case"], service_case)
        self.assertEqual(authority["profile"], profile)

    @patch.object(
        customer_service_access.access,
        "get_mobile_capabilities",
        return_value={
            "can_manage_customer_service_flow": True,
            "can_upload_customer_documents": True,
        },
    )
    @patch.object(
        customer_service_access.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    @patch.object(
        customer_service_access,
        "_current_user",
        return_value="associate@example.com",
    )
    @patch.object(customer_service_access.frappe, "get_doc")
    @patch.object(customer_service_access.frappe.db, "exists", return_value=True)
    def test_internal_cannot_manage_someone_elses_referral(
        self,
        _exists,
        get_doc,
        _current_user,
        _is_internal,
        _capabilities,
    ):
        get_doc.return_value = SimpleNamespace(
            name="OMC-SR-OTHER",
            customer_mode="My Referral",
            referral_owner="other@example.com",
            customer_profile="OMC-CUST-2",
            created_on_behalf=1,
            submitted_by_internal_user="other@example.com",
        )

        with self.assertRaises(frappe.PermissionError):
            customer_service_access.assert_service_request_action(
                "OMC-SR-OTHER",
                internal_capability="can_upload_customer_documents",
            )

    @patch.object(
        customer_service_access.access,
        "get_mobile_capabilities",
        return_value={
            "can_manage_customer_service_flow": True,
            "can_upload_customer_documents": True,
        },
    )
    @patch.object(
        customer_service_access.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    @patch.object(
        customer_service_access,
        "_current_user",
        return_value="associate@example.com",
    )
    @patch.object(customer_service_access.frappe, "get_doc")
    @patch.object(customer_service_access.frappe.db, "exists", return_value=True)
    def test_internal_can_manage_own_walk_in_request(
        self,
        _exists,
        get_doc,
        _current_user,
        _is_internal,
        _capabilities,
    ):
        service_case = SimpleNamespace(
            name="OMC-SR-WALKIN",
            customer_mode="Walk-in Customer",
            referral_owner="",
            customer_profile="",
            created_on_behalf=1,
            submitted_by_internal_user="associate@example.com",
        )
        get_doc.return_value = service_case

        authority = customer_service_access.assert_service_request_action(
            "OMC-SR-WALKIN",
            internal_capability="can_upload_customer_documents",
        )

        self.assertTrue(authority["is_internal"])
        self.assertEqual(authority["scope_type"], "walk_in_assisted")
        self.assertIsNone(authority["profile"])

    @patch.object(
        customer_service_access.access,
        "get_mobile_capabilities",
        return_value={
            "can_manage_customer_service_flow": False,
            "can_upload_customer_documents": False,
            "can_review_documents": True,
        },
    )
    @patch.object(
        customer_service_access.mobile,
        "_can_access_internal_workspace",
        return_value=True,
    )
    @patch.object(
        customer_service_access,
        "_current_user",
        return_value="reviewer@example.com",
    )
    @patch.object(customer_service_access.frappe, "get_doc")
    @patch.object(customer_service_access.frappe.db, "exists", return_value=True)
    def test_document_reviewer_without_assisted_capability_cannot_upload_for_customer(
        self,
        _exists,
        get_doc,
        _current_user,
        _is_internal,
        _capabilities,
    ):
        get_doc.return_value = SimpleNamespace(
            name="OMC-SR-1",
            customer_mode="My Referral",
            referral_owner="reviewer@example.com",
            customer_profile="OMC-CUST-1",
            created_on_behalf=1,
            submitted_by_internal_user="reviewer@example.com",
        )

        with self.assertRaises(frappe.PermissionError):
            customer_service_access.assert_service_request_action(
                "OMC-SR-1",
                internal_capability="can_upload_customer_documents",
            )


    def test_reviewer_cannot_review_own_uploaded_document(self):
        doc = SimpleNamespace(
            uploaded_by="reviewer@example.com",
        )

        with patch.object(
            customer_documents.frappe,
            "session",
            SimpleNamespace(user="reviewer@example.com"),
        ):
            with self.assertRaises(frappe.PermissionError):
                customer_documents._assert_reviewer_did_not_upload_document(doc)

    def test_reviewer_can_review_document_uploaded_by_another_user(self):
        doc = SimpleNamespace(
            uploaded_by="associate@example.com",
        )

        with patch.object(
            customer_documents.frappe,
            "session",
            SimpleNamespace(user="reviewer@example.com"),
        ):
            customer_documents._assert_reviewer_did_not_upload_document(doc)

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
        side_effect=frappe.PermissionError,
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    def test_review_enforces_canonical_service_case_scope(
        self,
        _exists,
        get_doc,
        require_scope,
        _review_access,
    ):
        get_doc.return_value = SimpleNamespace(
            name="OMC-DOC-1",
            service_request="OMC-SR-OTHER",
        )

        with self.assertRaises(frappe.PermissionError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
            )

        require_scope.assert_called_once_with("OMC-SR-OTHER")

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
        return_value=(
            "reviewer@example.com",
            {"can_review_documents": True},
            ["OMC-SR-1"],
        ),
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    def test_terminal_request_rejects_document_review(
        self,
        _exists,
        get_doc,
        _require_scope,
        _review_access,
    ):
        get_doc.side_effect = [
            SimpleNamespace(
                name="OMC-DOC-1",
                service_request="OMC-SR-1",
                status="Uploaded",
            ),
            SimpleNamespace(
                name="OMC-SR-1",
                status="Completed",
            ),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
            )
