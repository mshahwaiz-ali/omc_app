import frappe

CUSTOMER_ROLE = "OMC Customer"
ADMIN_ROLE = "OMC Admin"
MANAGER_ROLE = "OMC Manager"
SUPPORT_AGENT_ROLE = "OMC Support Agent"
DOCUMENT_REVIEWER_ROLE = "OMC Document Reviewer"
FINANCE_REVIEWER_ROLE = "OMC Finance Reviewer"
CONSULTANT_ROLE = "OMC Consultant"
TAX_ASSOCIATE_ROLE = "OMC Tax Associate"
BUSINESS_PARTNER_ROLE = "OMC Business Partner"
SYSTEM_ROLE = "System Manager"

ACTIVE_PORTAL_ROLES = {CUSTOMER_ROLE}
ACTIVE_STAFF_ROLES = {
    ADMIN_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    CONSULTANT_ROLE,
    TAX_ASSOCIATE_ROLE,
    BUSINESS_PARTNER_ROLE,
}
ACTIVE_OMC_ROLES = ACTIVE_PORTAL_ROLES | ACTIVE_STAFF_ROLES

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

SPECIALIST_DOCTYPE_ACCESS = {
    SUPPORT_AGENT_ROLE: {
        "OMC Lead": {"read": 1, "write": 1, "create": 1},
        "OMC Support Ticket": {"read": 1, "write": 1, "create": 1},
        "OMC Support Ticket Message": {"read": 1, "write": 1, "create": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Request": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1, "create": 1},
        "OMC Notification": {"read": 1, "create": 1},
    },
    DOCUMENT_REVIEWER_ROLE: {
        "OMC Service Document": {"read": 1, "write": 1},
        "OMC Service Required Document": {"read": 1},
        "OMC Service Request": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1},
    },
    FINANCE_REVIEWER_ROLE: {
        "OMC Service Payment": {"read": 1, "write": 1},
        "OMC Payment Account": {"read": 1},
        "OMC Service Request": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1},
    },
    CONSULTANT_ROLE: {
        "OMC Service Request": {"read": 1, "write": 1},
        "OMC Service Document": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1},
    },
    TAX_ASSOCIATE_ROLE: {
        "OMC Service Request": {"read": 1, "write": 1},
        "OMC Service Document": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1},
    },
    BUSINESS_PARTNER_ROLE: {
        "OMC Service Request": {"read": 1, "write": 1},
        "OMC Service Document": {"read": 1},
        "OMC Customer Profile": {"read": 1},
        "OMC Service Timeline": {"read": 1, "create": 1},
        "OMC Task": {"read": 1, "write": 1},
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


def _mobile_quick_action_admin_permission():
    values = _admin_permission(is_submittable=False)
    values.update({"report": 0, "import": 0, "select": 0})
    return values


def _mobile_quick_action_manager_permission():
    return {
        "read": 0,
        "write": 0,
        "create": 0,
        "delete": 0,
        "submit": 0,
        "cancel": 0,
        "amend": 0,
        "report": 0,
        "export": 0,
        "import": 0,
        "print": 0,
        "email": 0,
        "share": 0,
        "if_owner": 0,
        "select": 0,
    }


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


def _omc_doctypes():
    rows = frappe.get_all(
        "DocType",
        filters={"name": ["like", "OMC %"]},
        fields=["name", "istable", "is_submittable"],
        order_by="name asc",
    )
    return [row for row in rows if not int(row.istable or 0)]


def _remove_role_docperms(role_names):
    if not role_names:
        return
    for name in frappe.get_all(
        "DocPerm", filters={"role": ["in", sorted(role_names)]}, pluck="name"
    ):
        frappe.delete_doc("DocPerm", name, ignore_permissions=True, force=True)


def _apply_permissions():
    # Rebuild every OMC role baseline idempotently. API capabilities remain the
    # authoritative action layer; these DocPerms only expose the matching Desk
    # records and are further restricted by permission query hooks.
    _remove_role_docperms(ACTIVE_OMC_ROLES | LEGACY_ROLES)

    for row in _omc_doctypes():
        doctype = row.name
        is_submittable = bool(int(row.is_submittable or 0))

        admin_values = (
            _mobile_quick_action_admin_permission()
            if doctype == "OMC Mobile Quick Action"
            else _admin_permission(is_submittable)
        )
        _upsert_docperm(doctype, ADMIN_ROLE, admin_values)

        if doctype not in MANAGER_BLOCKED_DOCTYPES:
            _upsert_docperm(
                doctype,
                MANAGER_ROLE,
                _manager_permission(is_submittable),
            )

    for role, doctype_map in SPECIALIST_DOCTYPE_ACCESS.items():
        for doctype, values in doctype_map.items():
            _upsert_docperm(
                doctype,
                role,
                _specialist_permission(values),
            )


def sync_canonical_roles():
    """Synchronize canonical OMC roles without committing the transaction."""
    for role_name in sorted(ACTIVE_PORTAL_ROLES):
        _ensure_role(role_name, desk_access=False, disabled=False)

    for role_name in sorted(ACTIVE_STAFF_ROLES):
        _ensure_role(role_name, desk_access=True, disabled=False)

    for role_name in sorted(LEGACY_ROLES):
        _ensure_role(role_name, desk_access=False, disabled=True)

    _apply_permissions()
    frappe.clear_cache()


def after_install():
    sync_canonical_roles()


def after_migrate():
    sync_canonical_roles()
