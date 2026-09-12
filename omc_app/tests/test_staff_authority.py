from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import staff_authority, staff_profile
from omc_app.setup.roles import ADMIN_ROLE, BUSINESS_PARTNER_ROLE, CONSULTANT_ROLE


class TestStaffAuthority(FrappeTestCase):
    def test_approved_current_staff_access_persona_is_authoritative(self):
        access = SimpleNamespace(
            access_status="Approved",
            reconciliation_status="Current",
            persona_snapshot=CONSULTANT_ROLE,
        )
        with patch.object(
            staff_authority,
            "access_record",
            return_value=access,
        ):
            has_access, persona = staff_authority.access_persona(
                "staff@example.com"
            )

        self.assertTrue(has_access)
        self.assertEqual(persona, CONSULTANT_ROLE)

    def test_pending_staff_access_blocks_legacy_persona_fallback(self):
        access = SimpleNamespace(
            access_status="Pending Review",
            reconciliation_status="Current",
            persona_snapshot=CONSULTANT_ROLE,
        )
        legacy_profile = SimpleNamespace(
            meta=SimpleNamespace(has_field=lambda field: field == "staff_role"),
            get=lambda field: CONSULTANT_ROLE if field == "staff_role" else None,
        )
        with patch.object(
            staff_authority,
            "access_record",
            return_value=access,
        ), patch.object(
            staff_profile,
            "get_staff_profile",
            return_value=legacy_profile,
        ):
            role = staff_profile.get_staff_role("staff@example.com")

        self.assertEqual(role, "")

    def test_legacy_profile_remains_fallback_without_staff_access(self):
        legacy_profile = SimpleNamespace(
            meta=SimpleNamespace(has_field=lambda field: field == "staff_role"),
            get=lambda field: CONSULTANT_ROLE if field == "staff_role" else None,
        )
        with patch.object(
            staff_authority,
            "access_record",
            return_value=None,
        ):
            role = staff_profile.get_staff_role(
                "legacy@example.com",
                profile=legacy_profile,
            )

        self.assertEqual(role, CONSULTANT_ROLE)

    def test_operational_role_does_not_replace_erp_persona(self):
        persona = staff_authority.reviewed_persona_for_roles(
            [CONSULTANT_ROLE, ADMIN_ROLE]
        )
        self.assertEqual(persona, CONSULTANT_ROLE)

    def test_multiple_erp_personas_require_review(self):
        with self.assertRaises(frappe.ValidationError):
            staff_authority.reviewed_persona_for_roles(
                [CONSULTANT_ROLE, BUSINESS_PARTNER_ROLE]
            )

    def test_operational_only_single_role_remains_supported(self):
        persona = staff_authority.reviewed_persona_for_roles([ADMIN_ROLE])
        self.assertEqual(persona, ADMIN_ROLE)

    def test_canonical_links_use_employee_and_profile_helpers(self):
        with patch.object(
            staff_authority,
            "employee_for_user",
            return_value="EMP-0001",
        ), patch.object(
            staff_authority,
            "profile_for_user",
            return_value="staff@example.com",
        ):
            links = staff_authority.canonical_links("staff@example.com")

        self.assertEqual(links["employee"], "EMP-0001")
        self.assertEqual(links["legacy_staff_profile"], "staff@example.com")
