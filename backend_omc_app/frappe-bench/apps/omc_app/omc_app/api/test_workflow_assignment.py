from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import assisted_service


class TestWorkflowAssignment(TestCase):
    @patch.object(assisted_service, "_active_system_user")
    def test_explicit_assignee_has_priority(self, active_user):
        active_user.side_effect = lambda value: value if value else None
        service = SimpleNamespace(
            default_assignee="default@example.com",
            default_assignment_role="OMC Consultant",
        )

        result = assisted_service._resolve_request_assignee(
            service,
            explicit_user="explicit@example.com",
            referral_owner="referral@example.com",
        )

        self.assertEqual(result, "explicit@example.com")

    @patch.object(assisted_service, "_active_system_user")
    def test_referral_owner_precedes_service_default(self, active_user):
        active_user.side_effect = lambda value: value if value else None
        service = SimpleNamespace(
            default_assignee="default@example.com",
            default_assignment_role="OMC Consultant",
        )

        result = assisted_service._resolve_request_assignee(
            service,
            referral_owner="referral@example.com",
        )

        self.assertEqual(result, "referral@example.com")

    @patch.object(assisted_service, "_open_assignment_count")
    def test_least_loaded_user_is_selected(self, count):
        count.side_effect = {
            "a@example.com": 4,
            "b@example.com": 1,
            "c@example.com": 1,
        }.get

        result = assisted_service._least_loaded_user(
            ["c@example.com", "a@example.com", "b@example.com"]
        )

        self.assertEqual(result, "b@example.com")

    @patch.object(assisted_service.frappe, "get_all")
    @patch.object(assisted_service.frappe, "new_doc")
    def test_assignment_todo_is_idempotent(self, new_doc, get_all):
        request = SimpleNamespace(
            name="OMC-SR-TEST",
            title="Test Request",
            priority="Medium",
        )
        get_all.return_value = ["TODO-EXISTING"]

        result = assisted_service._ensure_assignment_todo(
            request,
            "staff@example.com",
        )

        self.assertEqual(result, "TODO-EXISTING")
        new_doc.assert_not_called()

    def test_service_role_inference(self):
        tax_service = SimpleNamespace(
            title="Tax Filing Service",
            category="Tax",
            icon="tax_filing",
            default_assignment_role="",
        )
        company_service = SimpleNamespace(
            title="Company Registration",
            category="Business",
            icon="company_registration",
            default_assignment_role="",
        )

        self.assertEqual(
            assisted_service._assignment_role_for_service(tax_service),
            "OMC Tax Associate",
        )
        self.assertEqual(
            assisted_service._assignment_role_for_service(company_service),
            "OMC Consultant",
        )
