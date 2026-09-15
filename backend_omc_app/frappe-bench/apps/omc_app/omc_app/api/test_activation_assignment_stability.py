from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import bridge_outbox


class TestActivationAssignmentStability(FrappeTestCase):
    def test_existing_request_assignee_is_preserved(self):
        request = SimpleNamespace(
            assigned_staff="existing@example.com",
            referral_owner="referral@example.com",
        )
        service = SimpleNamespace(name="service-1")

        expected = {
            "candidate": "existing@example.com",
            "source": "explicit",
        }

        with patch.object(
            bridge_outbox.service_assignment,
            "resolve_assignee",
            return_value=expected,
        ) as resolve:
            result = (
                bridge_outbox
                ._resolve_activation_assignment(
                    request,
                    service,
                )
            )

        self.assertEqual(result, expected)

        resolve.assert_called_once_with(
            service,
            explicit_user="existing@example.com",
            referral_owner="referral@example.com",
        )

    def test_unassigned_request_uses_normal_resolution(self):
        request = SimpleNamespace(
            assigned_staff="",
            referral_owner="referral@example.com",
        )
        service = SimpleNamespace(name="service-1")

        expected = {
            "candidate": "resolved@example.com",
            "source": "service_role",
        }

        with patch.object(
            bridge_outbox.service_assignment,
            "resolve_assignee",
            return_value=expected,
        ) as resolve:
            result = (
                bridge_outbox
                ._resolve_activation_assignment(
                    request,
                    service,
                )
            )

        self.assertEqual(result, expected)

        resolve.assert_called_once_with(
            service,
            explicit_user=None,
            referral_owner="referral@example.com",
        )

    def test_bridge_process_uses_stable_assignment_helper(self):
        source = (
            Path(__file__).resolve().parent
            / "bridge_outbox.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "decision = _resolve_activation_assignment(",
            source,
        )

        self.assertNotIn(
            "decision = service_assignment.resolve_assignee(\\n"
            "            service, "
            "referral_owner=request.referral_owner",
            source,
        )
