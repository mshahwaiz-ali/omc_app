from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload


class TestDeskDocumentWorkflow(FrappeTestCase):
    @patch.object(
        document_upload,
        "_current_user",
        return_value="Guest",
    )
    def test_guest_cannot_use_desk_document_upload(
        self,
        _current_user,
    ):
        with self.assertRaises(frappe.PermissionError):
            document_upload._require_internal_document_upload_access(
                "OMC-SR-TEST"
            )

    @patch.object(
        document_upload.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(
        document_upload.access,
        "get_mobile_capabilities",
        return_value={
            "can_access_internal_workspace": True,
            "can_create_service_for_customer": False,
        },
    )
    @patch.object(
        document_upload.frappe.db,
        "exists",
        return_value=True,
    )
    @patch.object(
        document_upload,
        "_current_user",
        return_value="limited@example.com",
    )
    def test_desk_upload_requires_assisted_creation_capability(
        self,
        _current_user,
        _exists,
        _capabilities,
        require_scope,
    ):
        with self.assertRaises(frappe.PermissionError):
            document_upload._require_internal_document_upload_access(
                "OMC-SR-TEST"
            )

        require_scope.assert_not_called()

    @patch.object(
        document_upload.security,
        "enforce_rate_limit",
    )
    @patch.object(
        document_upload.frappe,
        "get_doc",
    )
    @patch.object(
        document_upload.mobile,
        "_require_service_case_read_scope",
        return_value=(
            "staff@example.com",
            {},
            ["OMC-SR-TEST"],
        ),
    )
    @patch.object(
        document_upload.access,
        "get_mobile_capabilities",
        return_value={
            "can_access_internal_workspace": True,
            "can_create_service_for_customer": True,
        },
    )
    @patch.object(
        document_upload.frappe.db,
        "exists",
        return_value=True,
    )
    @patch.object(
        document_upload,
        "_current_user",
        return_value="staff@example.com",
    )
    def test_authorized_desk_upload_enforces_case_scope_and_rate_limit(
        self,
        _current_user,
        _exists,
        _capabilities,
        require_scope,
        get_doc,
        enforce_rate_limit,
    ):
        request = SimpleNamespace(
            name="OMC-SR-TEST",
            service="service-test",
        )
        get_doc.return_value = request

        actor, loaded_request = (
            document_upload
            ._require_internal_document_upload_access(
                "OMC-SR-TEST",
                mutation=True,
            )
        )

        self.assertEqual(actor, "staff@example.com")
        self.assertIs(loaded_request, request)

        require_scope.assert_called_once_with(
            "OMC-SR-TEST"
        )
        enforce_rate_limit.assert_called_once_with(
            "staff_mutation",
            actor="staff@example.com",
        )

    @patch.object(
        document_upload,
        "_register_service_document",
        return_value={
            "uploaded": True,
            "document": {
                "name": "OMC-DOC-TEST",
            },
        },
    )
    @patch.object(
        document_upload,
        "_require_internal_document_upload_access",
    )
    def test_desk_upload_uses_shared_guarded_registration_core(
        self,
        require_access,
        register_document,
    ):
        request = SimpleNamespace(
            name="OMC-SR-TEST"
        )
        require_access.return_value = (
            "staff@example.com",
            request,
        )

        response = (
            document_upload.desk_upload_service_document(
                service_request="OMC-SR-TEST",
                document_key="utility_bill",
                document_title="Utility Bill",
                document_type="Utility Bill",
                attachment="/private/files/test.pdf",
                idempotency_key=(
                    "desk-doc:OMC-SR-TEST:1234567890"
                ),
            )
        )

        self.assertTrue(response["uploaded"])

        require_access.assert_called_once_with(
            "OMC-SR-TEST",
            mutation=True,
        )

        args, kwargs = register_document.call_args
        payload = args[0]

        self.assertEqual(
            payload["service_request"],
            "OMC-SR-TEST",
        )
        self.assertEqual(
            payload["document_key"],
            "utility_bill",
        )
        self.assertIs(
            kwargs["service_case"],
            request,
        )
        self.assertTrue(
            kwargs["uploaded_by_staff"]
        )

    @patch.object(
        document_upload,
        "_has_field",
        return_value=True,
    )
    @patch.object(
        document_upload.frappe,
        "get_all",
        return_value=[],
    )
    @patch.object(
        document_upload,
        "_service_required_documents",
        return_value=[
            {
                "document_key": "utility_bill",
                "document_title": "Utility Bill",
                "document_type": "Utility Bill",
            }
        ],
    )
    @patch.object(
        document_upload,
        "_require_internal_document_upload_access",
    )
    def test_desk_context_returns_authoritative_requirements(
        self,
        require_access,
        _requirements,
        _get_all,
        _has_field,
    ):
        request = SimpleNamespace(
            name="OMC-SR-TEST",
            service="service-test",
            status="Waiting for Documents",
        )
        require_access.return_value = (
            "staff@example.com",
            request,
        )

        result = (
            document_upload.get_desk_upload_context(
                service_request="OMC-SR-TEST"
            )
        )

        self.assertEqual(
            result["service_request"],
            "OMC-SR-TEST",
        )
        self.assertEqual(
            result["requirements"][0][
                "document_key"
            ],
            "utility_bill",
        )
        self.assertEqual(
            result["maximum_file_size_mb"],
            10,
        )
        self.assertEqual(
            result["maximum_files_per_request"],
            20,
        )
        self.assertIn(
            "pdf",
            result["allowed_extensions"],
        )
