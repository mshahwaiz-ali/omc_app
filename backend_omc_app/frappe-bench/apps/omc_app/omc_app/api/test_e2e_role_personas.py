"""Database-backed role personas for the mobile workflow security contract."""

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, service_assignment
from omc_app.setup.roles import (
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    CUSTOMER_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    TAX_ASSOCIATE_ROLE,
)


PERSONAS = {
    "customer": ("Ayesha Khan", "ayesha.khan@qa.omc.test", [CUSTOMER_ROLE], "Website User"),
    "consultant": ("Bilal Ahmed", "bilal.ahmed@qa.omc.test", [CONSULTANT_ROLE], "System User"),
    "tax_associate": ("Sana Iqbal", "sana.iqbal@qa.omc.test", [TAX_ASSOCIATE_ROLE], "System User"),
    "business_partner": ("Hamza Siddiqui", "hamza.siddiqui@qa.omc.test", [BUSINESS_PARTNER_ROLE], "System User"),
    "document_reviewer": ("Mariam Raza", "mariam.raza@qa.omc.test", [DOCUMENT_REVIEWER_ROLE], "System User"),
    "finance_reviewer": ("Farhan Malik", "farhan.malik@qa.omc.test", [FINANCE_REVIEWER_ROLE], "System User"),
    "support_agent": ("Noor Fatima", "noor.fatima@qa.omc.test", [SUPPORT_AGENT_ROLE], "System User"),
    "manager": ("Usman Sheikh", "usman.sheikh@qa.omc.test", [MANAGER_ROLE], "System User"),
    "omc_admin": ("Zain Abbas", "zain.abbas@qa.omc.test", [ADMIN_ROLE], "System User"),
    "combined": (
        "Hira Qureshi",
        "hira.qureshi@qa.omc.test",
        [DOCUMENT_REVIEWER_ROLE, FINANCE_REVIEWER_ROLE],
        "System User",
    ),
    "disabled_consultant": (
        "Danish Mirza",
        "danish.mirza@qa.omc.test",
        [CONSULTANT_ROLE],
        "System User",
    ),
}


def cleanup_reserved_personas(commit=False):
    """Remove only the fixed reserved-domain identities owned by this suite."""
    removed = []
    frappe.set_user("Administrator")
    for _full_name, email, _roles, _user_type in reversed(list(PERSONAS.values())):
        if frappe.db.exists("User", email):
            frappe.delete_doc("User", email, force=True, ignore_permissions=True)
            removed.append(email)
    frappe.clear_cache()
    if commit:
        frappe.db.commit()
    return {"removed": sorted(removed), "count": len(removed)}


class TestEndToEndRolePersonas(FrappeTestCase):
    def setUp(self):
        super().setUp()
        cleanup_reserved_personas(commit=True)
        for key, (full_name, email, roles, user_type) in PERSONAS.items():
            user = frappe.get_doc(
                {
                    "doctype": "User",
                    "email": email,
                    "first_name": full_name.split()[0],
                    "last_name": " ".join(full_name.split()[1:]),
                    "full_name": full_name,
                    "enabled": 0 if key == "disabled_consultant" else 1,
                    "user_type": user_type,
                    "send_welcome_email": 0,
                    "roles": [{"role": role} for role in roles],
                }
            )
            user.insert(ignore_permissions=True)
        frappe.clear_cache()

    def tearDown(self):
        cleanup_reserved_personas(commit=True)
        super().tearDown()

    def _caps(self, key):
        return access.get_mobile_capabilities(user=PERSONAS[key][1])

    def test_named_persona_allowed_and_forbidden_capability_matrix(self):
        expected = {
            "consultant": ("can_update_assigned_service_status", "can_review_payments"),
            "tax_associate": ("can_update_assigned_service_status", "can_manage_staff"),
            "business_partner": ("can_create_service_for_customer", "can_review_documents"),
            "document_reviewer": ("can_review_documents", "can_review_payments"),
            "finance_reviewer": ("can_review_payments", "can_review_documents"),
            "support_agent": ("can_reply_support_tickets", "can_review_payments"),
            "manager": ("can_reassign_service_cases", "can_manage_staff"),
            "omc_admin": ("can_manage_staff", None),
        }
        for key, (allowed, forbidden) in expected.items():
            with self.subTest(persona=PERSONAS[key][0]):
                capabilities = self._caps(key)
                self.assertTrue(capabilities[allowed])
                if forbidden:
                    self.assertFalse(capabilities[forbidden])

    def test_guest_and_customer_cannot_enter_internal_workspace(self):
        guest = access.get_mobile_capabilities(user="Guest")
        customer = self._caps("customer")
        self.assertTrue(guest["can_view_public_catalogue"])
        self.assertFalse(guest["can_create_service_request"])
        self.assertFalse(guest["can_access_internal_workspace"])
        self.assertFalse(customer["can_access_internal_workspace"])

    def test_combined_role_receives_safe_union_only(self):
        capabilities = self._caps("combined")
        self.assertTrue(capabilities["can_review_documents"])
        self.assertTrue(capabilities["can_review_payments"])
        self.assertFalse(capabilities["can_manage_staff"])
        self.assertFalse(capabilities["can_manage_business_settings"])

    def test_role_removal_revokes_capability_after_refresh(self):
        email = PERSONAS["combined"][1]
        self.assertTrue(self._caps("combined")["can_review_payments"])
        frappe.db.delete("Has Role", {"parent": email, "role": FINANCE_REVIEWER_ROLE})
        frappe.clear_cache(user=email)
        self.assertFalse(self._caps("combined")["can_review_payments"])
        self.assertTrue(self._caps("combined")["can_review_documents"])

    def test_assignment_rejects_disabled_website_and_administrator_users(self):
        self.assertIsNone(service_assignment.active_assignable_user(PERSONAS["customer"][1]))
        self.assertIsNone(service_assignment.active_assignable_user(PERSONAS["disabled_consultant"][1]))
        self.assertIsNone(service_assignment.active_assignable_user("Administrator"))
        self.assertEqual(
            service_assignment.active_assignable_user(PERSONAS["consultant"][1]),
            PERSONAS["consultant"][1],
        )

    def test_persona_records_use_reserved_domain_and_realistic_names(self):
        for full_name, email, _roles, _user_type in PERSONAS.values():
            self.assertTrue(email.endswith("@qa.omc.test"))
            self.assertNotIn("test user", full_name.lower())
            self.assertGreaterEqual(len(full_name.split()), 2)
