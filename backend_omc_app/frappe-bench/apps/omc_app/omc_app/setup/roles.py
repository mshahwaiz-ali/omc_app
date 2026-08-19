import frappe

CUSTOMER_ROLE = "OMC Customer"
ADMIN_ROLE = "OMC Admin"
MANAGER_ROLE = "OMC Manager"
SUPPORT_AGENT_ROLE = "OMC Support Agent"
DOCUMENT_REVIEWER_ROLE = "OMC Document Reviewer"
FINANCE_REVIEWER_ROLE = "OMC Finance Reviewer"
SYSTEM_ROLE = "System Manager"

# ERP-owned staff personas. These are identity values from User.omc_user_type,
# not OMC-created Frappe Role records.
ERP_CONSULTANT_PERSONA = "Consultant"
ERP_TAX_ASSOCIATE_PERSONA = "Tax Associates"
ERP_BUSINESS_PARTNER_PERSONA = "Business Partner"
ERP_EMPLOYEE_PERSONA = "Employee"
ERP_STAFF_PERSONAS = {
    ERP_CONSULTANT_PERSONA,
    ERP_TAX_ASSOCIATE_PERSONA,
    ERP_BUSINESS_PARTNER_PERSONA,
    ERP_EMPLOYEE_PERSONA,
}

# Existing OMC code imports these names as capability/persona constants. They
# now resolve directly to the ERP personas instead of duplicate OMC roles.
CONSULTANT_ROLE = ERP_CONSULTANT_PERSONA
TAX_ASSOCIATE_ROLE = ERP_TAX_ASSOCIATE_PERSONA
BUSINESS_PARTNER_ROLE = ERP_BUSINESS_PARTNER_PERSONA
EMPLOYEE_ROLE = ERP_EMPLOYEE_PERSONA

# Kept only for the later controlled cleanup/backfill step. Normal install and
# migrate intentionally do not touch these old assignments yet.
RETIRED_EXTERNAL_OMC_ROLE_TO_PERSONA = {
    "OMC Consultant": ERP_CONSULTANT_PERSONA,
    "OMC Tax Associate": ERP_TAX_ASSOCIATE_PERSONA,
    "OMC Business Partner": ERP_BUSINESS_PARTNER_PERSONA,
    "OMC Employee": ERP_EMPLOYEE_PERSONA,
}
RETIRED_EXTERNAL_OMC_ROLES = set(RETIRED_EXTERNAL_OMC_ROLE_TO_PERSONA)

ACTIVE_PORTAL_ROLES = {CUSTOMER_ROLE}
MANAGED_OMC_STAFF_ROLES = {
    ADMIN_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
}
ACTIVE_STAFF_ROLES = MANAGED_OMC_STAFF_ROLES | ERP_STAFF_PERSONAS
ACTIVE_OMC_ROLES = ACTIVE_PORTAL_ROLES | MANAGED_OMC_STAFF_ROLES

# Explicit allowlists. New OMC DocTypes receive no role permissions until they
# are deliberately classified here. This prevents an unrelated future model
# from becoming writable merely because its name starts with "OMC ".
ADMIN_MUTABLE_DOCTYPES = {
    "OMC Announcement",
    "OMC App Banner",
    "OMC Branding Settings",
    "OMC Customer Preference",
    "OMC Customer Profile",
    "OMC Expense Budget",
    "OMC Expense Category",
    "OMC Expense Entry",
    "OMC FAQ",
    "OMC Knowledge Article",
    "OMC Manual Customer",
    "OMC Mobile Quick Action",
    "OMC Mobile Settings",
    "OMC Onboarding Slide",
    "OMC Payment Account",
    "OMC Reconciliation Review",
    "OMC Referral",
    "OMC Service",
    "OMC Service Category",
    "OMC Service Document",
    "OMC Service Form Field",
    "OMC Service Payment",
    "OMC Service Request",
    "OMC Service Required Document",
    "OMC Service Stage Template",
    "OMC Staff Profile",
    "OMC Support Ticket",
    "OMC Support Ticket Message",
    "OMC Tax Adjustment Rule",
    "OMC Tax Alert",
    "OMC Tax Calculator Settings",
    "OMC Tax Input Field",
    "OMC Tax Result Insight",
    "OMC Tax Slab",
    "OMC Tax Year",
}

# These records are authoritative evidence/security/history. Staff may inspect
# them in Desk, but normal DocPerm must not permit rewriting or deleting them.
# Mutations that are legitimately required are performed by capability-guarded
# OMC APIs with explicit audit trails.
ADMIN_READ_ONLY_DOCTYPES = {
    "OMC Accounting Link",
    "OMC Break Glass Grant",
    "OMC Bridge Operation",
    "OMC Commission Allocation",
    "OMC Customer Account",
    "OMC Notification",
    "OMC Profile Change Log",
    "OMC Referral Attribution",
    "OMC Security Audit Event",
    "OMC Service Timeline",
    "OMC Staff Access",
    "OMC Tax Calculation Log",
}

# Session/token/idempotency internals intentionally have no staff DocPerm.
# They are accessed only by guarded application code (Administrator remains a
# framework-level superuser and is handled separately by Frappe itself).
INTERNAL_ONLY_DOCTYPES = {
    "OMC Customer Activation",
    "OMC Guest Session",
    "OMC Idempotency Record",
    "OMC Password Reset",
    "OMC Pending Registration",
    "OMC Push Token",
}

MANAGER_BLOCKED_DOCTYPES = {
    "OMC Branding Settings",
    "OMC Mobile Settings",
    "OMC Mobile Quick Action",
    "OMC Service",
    "OMC Service Category",
    "OMC Service Form Field",
    "OMC Service Required Document",
    "OMC Service Stage Template",
    "OMC App Banner",
    "OMC Onboarding Slide",
    "OMC FAQ",
    "OMC Knowledge Article",
    "OMC Announcement",
    "OMC Expense Category",
    "OMC Payment Account",
    "OMC Tax Adjustment Rule",
    "OMC Tax Calculator Settings",
    "OMC Tax Input Field",
    "OMC Tax Result Insight",
    "OMC Tax Year",
}
MANAGER_MUTABLE_DOCTYPES = ADMIN_MUTABLE_DOCTYPES - MANAGER_BLOCKED_DOCTYPES
MANAGER_READ_ONLY_DOCTYPES = {
    "OMC Accounting Link",
    "OMC Bridge Operation",
    "OMC Commission Allocation",
    "OMC Customer Account",
    "OMC Notification",
    "OMC Profile Change Log",
    "OMC Referral Attribution",
    "OMC Service Timeline",
    "OMC Tax Calculation Log",
}

# Only genuinely OMC-owned operational roles receive OMC DocPerm rows here.
# ERP personas are authorized through approved OMC Staff Access capabilities.
SPECIALIST_DOCTYPE_ACCESS = {
    SUPPORT_AGENT_ROLE: {
        "OMC Support Ticket": {"read": 1, "write": 1, "create": 1},
        "OMC Support Ticket Message": {"read": 1, "write": 1, "create": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Referral": {"read": 1, "create": 1},
        "OMC Manual Customer": {"read": 1, "write": 1, "create": 1},
        "OMC Service Request": {"read": 1, "create": 1},
        "OMC Notification": {"read": 1, "create": 1},
    },
    DOCUMENT_REVIEWER_ROLE: {
        "OMC Service Document": {"read": 1, "write": 1},
        "OMC Service Required Document": {"read": 1},
        "OMC Service Request": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Referral": {"read": 1},
        "OMC Manual Customer": {"read": 1, "write": 1, "create": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
    },
    FINANCE_REVIEWER_ROLE: {
        "OMC Service Payment": {"read": 1, "write": 1},
        "OMC Payment Account": {"read": 1},
        "OMC Service Request": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Referral": {"read": 1},
        "OMC Manual Customer": {"read": 1, "write": 1, "create": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Accounting Link": {"read": 1},
    },
}

LEGACY_CLIENT_ROLES = {"OMC Customer Applicant"}
LEGACY_STAFF_ROLES = {"OMC Customer Support"}
LEGACY_ROLES = LEGACY_CLIENT_ROLES | LEGACY_STAFF_ROLES
PERMISSION_FIELDS = (
    "read",
    "write",
    "create",
    "delete",
    "submit",
    "cancel",
    "amend",
    "report",
    "export",
    "import",
    "print",
    "email",
    "share",
    "if_owner",
    "select",
)


def _meta_has_field(doctype, fieldname):
    try:
        return bool(frappe.get_meta(doctype).has_field(fieldname))
    except Exception:
        return False


def _ensure_role(role_name, *, desk_access, disabled):
    if not frappe.db.exists("Role", role_name):
        role = frappe.new_doc("Role")
        role.role_name = role_name
        role.is_custom = 1
        role.insert(ignore_permissions=True)
    values = {"desk_access": 1 if desk_access else 0, "is_custom": 1}
    if _meta_has_field("Role", "disabled"):
        values["disabled"] = 1 if disabled else 0
    frappe.db.set_value("Role", role_name, values, update_modified=False)


def _available_permission_values(values):
    return {
        fieldname: int(value or 0)
        for fieldname, value in values.items()
        if fieldname in PERMISSION_FIELDS and _meta_has_field("DocPerm", fieldname)
    }


def _upsert_docperm(doctype, role, values):
    if not frappe.db.exists("DocType", doctype):
        return
    values = _available_permission_values(values)
    names = frappe.get_all(
        "DocPerm",
        filters={"parent": doctype, "role": role, "permlevel": 0},
        pluck="name",
        order_by="creation asc",
    )
    if names:
        frappe.db.set_value("DocPerm", names[0], values, update_modified=False)
        for duplicate_name in names[1:]:
            frappe.delete_doc("DocPerm", duplicate_name, ignore_permissions=True, force=True)
        return
    permission = frappe.new_doc("DocPerm")
    permission.parent = doctype
    permission.parenttype = "DocType"
    permission.parentfield = "permissions"
    permission.permlevel = 0
    permission.role = role
    for fieldname, value in values.items():
        setattr(permission, fieldname, value)
    permission.insert(ignore_permissions=True)


def _base_permission():
    return {
        "read": 1,
        "write": 0,
        "create": 0,
        "delete": 0,
        "submit": 0,
        "cancel": 0,
        "amend": 0,
        "report": 1,
        "export": 1,
        "import": 0,
        "print": 1,
        "email": 1,
        "share": 0,
        "if_owner": 0,
        "select": 1,
    }


def _admin_permission(is_submittable):
    values = _base_permission()
    values.update(
        {
            "write": 1,
            "create": 1,
            "delete": 1,
            "submit": 1 if is_submittable else 0,
            "cancel": 1 if is_submittable else 0,
            "amend": 1 if is_submittable else 0,
            "import": 1,
            "share": 1,
        }
    )
    return values


def _manager_permission(is_submittable):
    values = _admin_permission(is_submittable)
    values["delete"] = 0
    values["share"] = 0
    return values


def _read_only_evidence_permission():
    values = _base_permission()
    values.update({"export": 0, "email": 0, "share": 0, "import": 0})
    return values


def _mobile_quick_action_admin_permission():
    values = _admin_permission(is_submittable=False)
    values.update({"report": 0, "import": 0, "select": 0})
    return values


def _specialist_permission(values):
    permission = _base_permission()
    permission.update(
        {
            "read": int(values.get("read", 0)),
            "write": int(values.get("write", 0)),
            "create": int(values.get("create", 0)),
            "delete": 0,
            "submit": 0,
            "cancel": 0,
            "amend": 0,
            "report": int(values.get("read", 0)),
            "export": 0,
            "import": 0,
            "print": int(values.get("read", 0)),
            "email": 0,
            "share": 0,
            "if_owner": 0,
            "select": int(values.get("read", 0)),
        }
    )
    return permission


def _remove_role_docperms(role_names):
    if not role_names:
        return
    for name in frappe.get_all(
        "DocPerm", filters={"role": ["in", sorted(role_names)]}, pluck="name"
    ):
        frappe.delete_doc("DocPerm", name, ignore_permissions=True, force=True)


def _migrate_legacy_user_roles():
    """Retired compatibility seam; Has Role migration requires separate approval."""
    return {"disabled": True, "reason": "staff_access_is_authoritative"}


def _is_submittable(doctype):
    return bool(int(frappe.db.get_value("DocType", doctype, "is_submittable") or 0))


def _apply_permissions():
    # Remove all managed OMC, legacy and System Manager rows first. Any model
    # omitted from the explicit allowlists below intentionally remains denied.
    _remove_role_docperms(ACTIVE_OMC_ROLES | LEGACY_ROLES | {SYSTEM_ROLE})

    for doctype in sorted(ADMIN_MUTABLE_DOCTYPES):
        if not frappe.db.exists("DocType", doctype):
            continue
        values = (
            _mobile_quick_action_admin_permission()
            if doctype == "OMC Mobile Quick Action"
            else _admin_permission(_is_submittable(doctype))
        )
        _upsert_docperm(doctype, ADMIN_ROLE, values)

    for doctype in sorted(ADMIN_READ_ONLY_DOCTYPES):
        _upsert_docperm(doctype, ADMIN_ROLE, _read_only_evidence_permission())

    for doctype in sorted(MANAGER_MUTABLE_DOCTYPES):
        if frappe.db.exists("DocType", doctype):
            _upsert_docperm(doctype, MANAGER_ROLE, _manager_permission(_is_submittable(doctype)))

    for doctype in sorted(MANAGER_READ_ONLY_DOCTYPES):
        _upsert_docperm(doctype, MANAGER_ROLE, _read_only_evidence_permission())

    for role, doctype_map in SPECIALIST_DOCTYPE_ACCESS.items():
        for doctype, values in doctype_map.items():
            _upsert_docperm(doctype, role, _specialist_permission(values))

    # INTERNAL_ONLY_DOCTYPES is intentionally referenced as an invariant: none
    # of the managed staff roles may retain a DocPerm row for these models.
    for doctype in sorted(INTERNAL_ONLY_DOCTYPES):
        for name in frappe.get_all(
            "DocPerm",
            filters={
                "parent": doctype,
                "role": ["in", sorted(ACTIVE_OMC_ROLES | LEGACY_ROLES | {SYSTEM_ROLE})],
            },
            pluck="name",
        ):
            frappe.delete_doc("DocPerm", name, ignore_permissions=True, force=True)


def sync_canonical_roles():
    """Synchronize OMC-owned roles; ERP personas remain ERP-owned."""
    for role_name in sorted(ACTIVE_PORTAL_ROLES):
        _ensure_role(role_name, desk_access=False, disabled=False)
    for role_name in sorted(MANAGED_OMC_STAFF_ROLES):
        _ensure_role(role_name, desk_access=True, disabled=False)
    for role_name in sorted(LEGACY_ROLES):
        _ensure_role(role_name, desk_access=False, disabled=True)
    _apply_permissions()
    frappe.clear_cache()


def after_install():
    sync_canonical_roles()


def after_migrate():
    sync_canonical_roles()
