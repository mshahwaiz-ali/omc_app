from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.omc_app.doctype.omc_service_document.omc_service_document import (
    OMCServiceDocument,
)
from omc_app.omc_app.doctype.omc_service_request.omc_service_request import (
    OMCServiceRequest,
)


class TestOperationalRecordIntegrity(FrappeTestCase):
    @patch(
        "omc_app.omc_app.doctype.omc_service_document.omc_service_document."
        "_get_service_customer_profile",
        return_value="CUST-AUTH",
    )
    def test_service_document_replaces_stale_customer_profile(self, get_profile):
        document = SimpleNamespace(
            service_request="OMC-SR-1",
            customer_profile="CUST-STALE",
        )

        OMCServiceDocument._sync_customer_profile(document)

        self.assertEqual(document.customer_profile, "CUST-AUTH")
        get_profile.assert_called_once_with("OMC-SR-1")

    @patch(
        "omc_app.omc_app.doctype.omc_service_document.omc_service_document."
        "_get_service_customer_profile",
        return_value="",
    )
    def test_service_document_clears_profile_without_parent_authority(
        self,
        get_profile,
    ):
        document = SimpleNamespace(
            service_request="",
            customer_profile="CUST-STALE",
        )

        OMCServiceDocument._sync_customer_profile(document)

        self.assertEqual(document.customer_profile, "")
        get_profile.assert_called_once_with("")

    def test_terminal_status_is_detected_on_transition(self):
        request = SimpleNamespace(
            status="Completed",
            get_doc_before_save=lambda: SimpleNamespace(status="In Progress"),
        )

        self.assertTrue(OMCServiceRequest._entered_terminal_status(request))

    def test_repeated_terminal_status_does_not_rearchive(self):
        request = SimpleNamespace(
            status="Completed",
            get_doc_before_save=lambda: SimpleNamespace(status="Completed"),
        )

        self.assertFalse(OMCServiceRequest._entered_terminal_status(request))

    def test_non_terminal_status_does_not_archive(self):
        request = SimpleNamespace(
            status="In Progress",
            get_doc_before_save=lambda: SimpleNamespace(status="Open"),
        )

        self.assertFalse(OMCServiceRequest._entered_terminal_status(request))
