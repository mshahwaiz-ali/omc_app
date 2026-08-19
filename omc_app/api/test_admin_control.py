from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

import frappe

from omc_app.api import admin_control, service_assignment


class TestAdminControl(TestCase):
    def test_sync_queue_is_exhausted_and_retryable_only(self):
        filters = admin_control._operation_filters("sync")
        self.assertEqual(
            set(filters["erp_sync_status"][1]),
            admin_control.erp_sync_recovery.RETRYABLE_STATUSES,
        )
        self.assertEqual(filters["erp_retry_exhausted_at"], ["is", "set"])

    def test_each_operational_queue_has_a_dedicated_capability(self):
        self.assertEqual(
            admin_control._operation_queue_capability("reassignment"),
            "can_reassign_service_cases",
        )
        self.assertEqual(
            admin_control._operation_queue_capability("sync"),
            "can_retry_sync",
        )
        self.assertEqual(
            admin_control._operation_queue_capability("discount"),
            "can_manage_business_settings",
        )

    def test_discount_rejection_requires_review_remarks(self):
        request = SimpleNamespace(discount_status="Pending Approval")
        request.get = lambda key: getattr(request, key, None)
        with (
            patch.object(admin_control, "_require"),
            patch.object(admin_control.frappe.db, "exists", return_value=True),
            patch.object(admin_control.frappe, "get_doc", return_value=request),
            self.assertRaises(frappe.ValidationError),
        ):
            admin_control.review_discount(
                service_request="OMC-SR-1",
                decision="reject",
                reason="",
            )

    def test_staff_application_maps_only_supported_public_choices(self):
        for label, role in {
            "Consultant": "Consultant",
            "Tax Associate": "Tax Associates",
            "Business Partner": "Business Partner",
        }.items():
            profile = {"register_as": label}
            self.assertEqual(admin_control._requested_staff_role(profile), role)
        self.assertIsNone(admin_control._requested_staff_role({"register_as": "Customer"}))

    def test_staff_role_writer_rejects_empty_or_unknown_roles(self):
        user = SimpleNamespace(roles=[])
        with self.assertRaises(frappe.ValidationError):
            admin_control._set_user_roles(user, [])
        with self.assertRaises(frappe.ValidationError):
            admin_control._set_user_roles(user, ["System Manager"])

    def test_assignment_uses_approved_staff_access_persona(self):
        row = SimpleNamespace(enabled=1, user_type="System User", full_name="Sana Iqbal")
        staff_access = SimpleNamespace(
            access_status="Approved",
            reconciliation_status="Current",
            persona_snapshot="Tax Associates",
        )
        with (
            patch.object(service_assignment.frappe.db, "get_value", return_value=row),
            patch.object(service_assignment.identity, "get_staff_access", return_value=staff_access),
        ):
            self.assertEqual(
                service_assignment.active_assignable_user("sana.iqbal@qa.omc.test", required_role="OMC Tax Associate"),
                "sana.iqbal@qa.omc.test",
            )

    def test_administrator_is_never_automatically_assignable(self):
        self.assertIsNone(service_assignment.active_assignable_user("Administrator"))

    def test_role_candidates_come_from_staff_access(self):
        with (
            patch.object(service_assignment.frappe, "get_all", return_value=["bilal.ahmed@qa.omc.test"]) as get_all,
            patch.object(service_assignment, "active_assignable_user", side_effect=lambda user, required_role=None: user),
        ):
            self.assertEqual(service_assignment.users_for_role("OMC Consultant"), ["bilal.ahmed@qa.omc.test"])
        self.assertEqual(get_all.call_args.args[0], "OMC Staff Access")
        self.assertEqual(get_all.call_args.kwargs["filters"]["persona_snapshot"][0], "in")

    def test_duplicate_response_exposes_only_backend_allowed_actions(self):
        from omc_app.api import assisted_service

        active = SimpleNamespace(name="OMC-SR-2026-00001", status="In Progress", service="tax-filing", service_title="Tax Filing", modified="2026-08-02")
        blocked = assisted_service._duplicate_response(active, allow_parallel=False)
        allowed = assisted_service._duplicate_response(active, allow_parallel=True)
        self.assertEqual(blocked["allowed_actions"], ["resume_existing"])
        self.assertEqual(allowed["allowed_actions"], ["resume_existing", "start_another"])
