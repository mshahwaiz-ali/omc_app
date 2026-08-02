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

QA_SMTP_ACCOUNT = "OMC QA SMTP Capture"
QA_HTTP_ADMIN = "zain.abbas.http@qa.omc.test"


def setup_qa_smtp_account(commit=False):
    """Create a localhost-only outgoing account for an isolated email E2E."""
    existing_defaults = frappe.get_all(
        "Email Account",
        filters={"enable_outgoing": 1, "default_outgoing": 1},
        pluck="name",
    )
    if existing_defaults and QA_SMTP_ACCOUNT not in existing_defaults:
        frappe.throw(
            "A real default outgoing Email Account already exists; refusing to replace it.",
            frappe.ValidationError,
        )
    if frappe.db.exists("Email Account", QA_SMTP_ACCOUNT):
        frappe.delete_doc("Email Account", QA_SMTP_ACCOUNT, force=True, ignore_permissions=True)
    doc = frappe.get_doc(
        {
            "doctype": "Email Account",
            "email_account_name": QA_SMTP_ACCOUNT,
            "email_id": "qa-smtp@qa.omc.test",
            "enable_outgoing": 1,
            "default_outgoing": 1,
            "smtp_server": "127.0.0.1",
            "smtp_port": "1025",
            "use_tls": 0,
            "use_ssl_for_outgoing": 0,
            "no_smtp_authentication": 1,
            "always_use_account_email_id_as_sender": 1,
            "always_use_account_name_as_sender_name": 1,
        }
    ).insert(ignore_permissions=True)
    frappe.clear_cache()
    if commit:
        frappe.db.commit()
    return {"name": doc.name, "email_id": doc.email_id, "smtp": "127.0.0.1:1025"}


def cleanup_qa_smtp_account(commit=False):
    removed = False
    if frappe.db.exists("Email Account", QA_SMTP_ACCOUNT):
        frappe.delete_doc("Email Account", QA_SMTP_ACCOUNT, force=True, ignore_permissions=True)
        removed = True
    frappe.clear_cache()
    if commit:
        frappe.db.commit()
    return {"removed": removed, "name": QA_SMTP_ACCOUNT}


def setup_reserved_http_admin(password="OmcQaAdmin2026!", commit=False):
    """Create the fixed OMC Admin identity used only by local HTTP smoke."""
    if frappe.db.exists("User", QA_HTTP_ADMIN):
        frappe.delete_doc("User", QA_HTTP_ADMIN, force=True, ignore_permissions=True)
    user = frappe.get_doc(
        {
            "doctype": "User",
            "email": QA_HTTP_ADMIN,
            "first_name": "Zain",
            "last_name": "Abbas",
            "enabled": 1,
            "user_type": "System User",
            "send_welcome_email": 0,
            "roles": [{"role": ADMIN_ROLE}],
        }
    ).insert(ignore_permissions=True)
    user.new_password = password
    user.save(ignore_permissions=True)
    frappe.clear_cache(user=QA_HTTP_ADMIN)
    if commit:
        frappe.db.commit()
    return {"user": user.name, "roles": sorted(frappe.get_roles(user.name))}


def cleanup_reserved_http_admin(commit=False):
    removed = False
    if frappe.db.exists("User", QA_HTTP_ADMIN):
        frappe.delete_doc("User", QA_HTTP_ADMIN, force=True, ignore_permissions=True)
        removed = True
    frappe.clear_cache(user=QA_HTTP_ADMIN)
    if commit:
        frappe.db.commit()
    return {"removed": removed, "user": QA_HTTP_ADMIN}


def cleanup_reserved_personas(commit=False):
    """Remove only the fixed reserved-domain identities owned by this suite."""
    removed = []
    frappe.set_user("Administrator")
    for _full_name, email, _roles, _user_type in reversed(list(PERSONAS.values())):
        if frappe.db.exists("User", email):
            frappe.delete_doc("User", email, force=True, ignore_permissions=True)
            removed.append(email)
    reserved_emails = set(
        frappe.get_all(
            "OMC Customer Profile",
            filters={"email": ["like", "%@qa.omc.test"]},
            pluck="email",
        )
    )
    reserved_emails.update(
        frappe.get_all(
            "OMC Pending Registration",
            filters={"email": ["like", "%@qa.omc.test"]},
            pluck="email",
        )
    )
    for email in sorted(value for value in reserved_emails if value):
        cleanup_reserved_http_signup(email=email, commit=False)
    frappe.clear_cache()
    if commit:
        frappe.db.commit()
    return {"removed": sorted(removed), "count": len(removed)}


def cleanup_reserved_http_signup(email="layla.hussain.http@qa.omc.test", commit=False):
    """Remove the fixed HTTP-smoke identity and all workflow evidence it owns."""
    email = str(email or "").strip().lower()
    if not email.endswith("@qa.omc.test"):
        frappe.throw("Cleanup is restricted to the reserved QA domain.", frappe.ValidationError)
    removed = []
    frappe.set_user("Administrator")
    profile_names = frappe.get_all(
        "OMC Customer Profile",
        filters={"email": email},
        pluck="name",
    )
    case_names = (
        frappe.get_all(
            "OMC Service Request",
            filters={"customer_profile": ["in", profile_names]},
            pluck="name",
        )
        if profile_names
        else []
    )
    task_names = []
    if case_names:
        task_names = frappe.get_all(
            "OMC Service Request",
            filters={"name": ["in", case_names]},
            pluck="erp_task",
        )
        task_names = [name for name in task_names if name]

    for doctype, reference_names in (
        ("OMC Service Payment", case_names),
        ("OMC Service Document", case_names),
        ("OMC Service Timeline", case_names),
        ("OMC Support Ticket", case_names),
    ):
        if not reference_names or not frappe.db.exists("DocType", doctype):
            continue
        fieldname = (
            "reference_service_request"
            if doctype == "OMC Support Ticket"
            else "service_request"
        )
        for name in frappe.get_all(
            doctype,
            filters={fieldname: ["in", reference_names]},
            pluck="name",
        ):
            frappe.delete_doc(doctype, name, force=True, ignore_permissions=True)
            removed.append(f"{doctype}:{name}")

    todo_targets = list(case_names) + list(task_names)
    if todo_targets:
        for name in frappe.get_all(
            "ToDo",
            filters={"reference_name": ["in", todo_targets]},
            pluck="name",
        ):
            frappe.delete_doc("ToDo", name, force=True, ignore_permissions=True)
            removed.append(f"ToDo:{name}")

    for name in case_names:
        if frappe.db.exists("OMC Service Request", name):
            frappe.delete_doc("OMC Service Request", name, force=True, ignore_permissions=True)
            removed.append(f"OMC Service Request:{name}")
    for name in task_names:
        if frappe.db.exists("Task", name):
            frappe.delete_doc("Task", name, force=True, ignore_permissions=True)
            removed.append(f"Task:{name}")

    for name in frappe.get_all("File", filters={"owner": email}, pluck="name"):
        frappe.delete_doc("File", name, force=True, ignore_permissions=True)
        removed.append(f"File:{name}")
    for name in frappe.get_all(
        "OMC Pending Registration",
        filters={"email": email},
        pluck="name",
    ):
        frappe.delete_doc("OMC Pending Registration", name, force=True, ignore_permissions=True)
        removed.append(f"OMC Pending Registration:{name}")
    for name in profile_names:
        frappe.delete_doc("OMC Customer Profile", name, force=True, ignore_permissions=True)
        removed.append(f"OMC Customer Profile:{name}")
    if frappe.db.exists("User", email):
        frappe.delete_doc("User", email, force=True, ignore_permissions=True)
        removed.append(f"User:{email}")
    if commit:
        frappe.db.commit()
    return {"removed": removed, "count": len(removed)}


def inspect_hs_code_state():
    """Read-only evidence for the broken client ERP Link target."""
    table_exists = frappe.db.table_exists("HS Code", cached=False)
    value_evidence = {}
    for doctype, fieldname in (
        ("Item", "hs_code"),
        ("Purchase Invoice Item", "hs_code"),
        ("Purchase Order Item", "hs_code"),
        ("Sales Invoice Item", "custom_hs_code"),
    ):
        if frappe.db.has_column(doctype, fieldname):
            values = frappe.get_all(
                doctype,
                filters={fieldname: ["is", "set"]},
                pluck=fieldname,
                distinct=True,
                limit_page_length=20,
            )
            value_evidence[f"{doctype}.{fieldname}"] = {
                "distinct_nonempty_count": len(values),
                "sample_values": sorted(str(value) for value in values),
            }
    return {
        "doctype_exists": bool(frappe.db.exists("DocType", "HS Code")),
        "table_exists": table_exists,
        "table_columns": frappe.db.get_table_columns("HS Code") if table_exists else [],
        "docfields": frappe.get_all(
            "DocField",
            filters={"options": "HS Code"},
            fields=["parent", "fieldname", "label", "fieldtype"],
            limit_page_length=100,
        ),
        "custom_fields": frappe.get_all(
            "Custom Field",
            filters={"options": "HS Code"},
            fields=["name", "dt", "fieldname", "label", "fieldtype"],
            limit_page_length=100,
        ),
        "value_evidence": value_evidence,
    }


def inspect_reserved_qa_state():
    """Read-only proof that deterministic reserved-domain cleanup completed."""
    return {
        "users": frappe.get_all(
            "User",
            filters={"email": ["like", "%@qa.omc.test"]},
            pluck="name",
        ),
        "customer_profiles": frappe.get_all(
            "OMC Customer Profile",
            filters={"email": ["like", "%@qa.omc.test"]},
            pluck="name",
        ),
        "service_requests": frappe.get_all(
            "OMC Service Request",
            filters={"contact_email": ["like", "%@qa.omc.test"]},
            pluck="name",
        ),
        "smtp_account_exists": bool(
            frappe.db.exists("Email Account", QA_SMTP_ACCOUNT)
        ),
    }


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
