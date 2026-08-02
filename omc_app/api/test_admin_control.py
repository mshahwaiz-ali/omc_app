from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

import frappe

from omc_app.api import admin_control, service_assignment


class TestAdminControl(TestCase):
    def test_staff_application_maps_only_supported_public_choices(self):
        for label, role in {
            "Consultant": "OMC Consultant",
            "Tax Associate": "OMC Tax Associate",
            "Business Partner": "OMC Business Partner",
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

    def test_assignment_uses_effective_explicit_roles_not_role_profile(self):
        row = SimpleNamespace(enabled=1, user_type="System User", full_name="Sana Iqbal")
        with (
            patch.object(service_assignment.frappe.db, "get_value", return_value=row),
            patch.object(service_assignment, "user_roles", return_value={"OMC Finance Reviewer", "OMC Tax Associate"}),
        ):
            self.assertEqual(
                service_assignment.active_assignable_user("sana.iqbal@qa.omc.test", required_role="OMC Tax Associate"),
                "sana.iqbal@qa.omc.test",
            )

    def test_administrator_is_never_automatically_assignable(self):
        self.assertIsNone(service_assignment.active_assignable_user("Administrator"))

    def test_role_candidates_come_from_has_role_rows(self):
        with (
            patch.object(service_assignment.frappe, "get_all", return_value=["bilal.ahmed@qa.omc.test"]) as get_all,
            patch.object(service_assignment, "active_assignable_user", side_effect=lambda user, required_role=None: user),
        ):
            self.assertEqual(service_assignment.users_for_role("OMC Consultant"), ["bilal.ahmed@qa.omc.test"])
        self.assertEqual(get_all.call_args.args[0], "Has Role")
        self.assertEqual(get_all.call_args.kwargs["filters"]["role"], "OMC Consultant")

    def test_duplicate_response_exposes_only_backend_allowed_actions(self):
        from omc_app.api import assisted_service

        active = SimpleNamespace(name="OMC-SR-2026-00001", status="In Progress", service="tax-filing", service_title="Tax Filing", modified="2026-08-02")
        blocked = assisted_service._duplicate_response(active, allow_parallel=False)
        allowed = assisted_service._duplicate_response(active, allow_parallel=True)
        self.assertEqual(blocked["allowed_actions"], ["resume_existing"])
        self.assertEqual(allowed["allowed_actions"], ["resume_existing", "start_another"])
