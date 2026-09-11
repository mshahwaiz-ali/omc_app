from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import permissions
from omc_app.setup.roles import CONSULTANT_ROLE


class TestServiceDocumentScopeParity(FrappeTestCase):
    def test_field_role_document_scope_includes_parent_assignment(self):
        with patch.object(
            permissions,
            "_roles",
            return_value={CONSULTANT_ROLE},
        ):
            condition = permissions.service_document_query(
                "consultant@example.com"
            )

        self.assertIn("`tabOMC Service Request` sr", condition)
        self.assertIn("sr.assigned_staff", condition)
        self.assertIn("sr.referral_owner", condition)
        self.assertIn("tabToDo", condition)

    def test_guest_document_scope_is_closed(self):
        self.assertEqual(
            permissions.service_document_query("Guest"),
            "1=0",
        )
