import frappe


CUSTOMER_ROLE = "OMC Customer"
ADMIN_ROLE = "OMC Admin"
MANAGER_ROLE = "OMC Manager"
SUPPORT_ROLE = "OMC Customer Support"
SYSTEM_ROLE = "System Manager"

ACTIVE_PORTAL_ROLES = {CUSTOMER_ROLE}
ACTIVE_STAFF_ROLES = {ADMIN_ROLE, MANAGER_ROLE, SUPPORT_ROLE}

LEGACY_CLIENT_ROLES = {"OMC Customer Applicant"}
LEGACY_STAFF_ROLES = {
    "OMC Support Agent",
    "OMC Document Reviewer",
    "OMC Finance Reviewer",
    "OMC Consultant",
    "OMC Business Partner",
    "OMC Tax Associate",
}
LEGACY_ROLES = LEGACY_CLIENT_ROLES | LEGACY_STAFF_ROLES

PERMISSION_FIELDS = {
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
}

SETTINGS_KEYWORDS = {
    "Settings",
    "Quick Action",
    "Tax Year",
    "Tax Slab",
    "Tax Result Insight",
    "Tax Calculator",
    "Service Category",
    "Service Form Field",
    "Service Required Document",
    "Service Stage Template",
    "Mobile Shortcut",
    "Mobile Banner",
}

SUPPORT_WRITE_DOCTYPES = {
    "OMC Support Ticket",
    "OMC Support Ticket Message",
}

SUPPORT_READ_KEYWORDS = {
    "Customer Profile",
    "Service Request",
    "Service Document",
    "Service Timeline",
    "Support Ticket",
    "Support Ticket Message",
    "Service Payment",
}

PAYMENT_KEYWORDS = {"Payment"}


def _role_has_field(fieldname):
    try:
        return frappe.get_meta("Role").has_field(fieldname)
    except Exception:
        return False


def _set_role(role_name, desk_access):
    if not frappe.db.exists("Role", role_name):
        role = frappe.new_doc("Role")
        role.role_name = role_name
        role.is_custom = 1
        role.insert(ignore_permissions=True)

    values = {"desk_access": 1 if desk_access else 0}
    if _role_has_field("disabled"):
        values["disabled"] = 0
    frappe.db.set_value("Role", role_name, values)


def _disable_legacy_role(role_name):
    if not frappe.db.exists("Role", role_name):
        return

    values = {"desk_access": 0}
    if _role_has_field("disabled"):
        values["disabled"] = 1
    frappe.db.set_value("Role", role_name, values)


def _user_roles(user_id):
    return {
        row.role
        for row in frappe.get_all(
            "Has Role",
            filters={"parent": user_id},
            fields=["role"],
        )
    }


def _append_role(user_doc, role_name):
    if not role_name or not frappe.db.exists("Role", role_name):
        return
    existing = {row.role for row in (user_doc.roles or [])}
    if role_name not in existing:
        user_doc.append("roles", {"role": role_name})


def _normalize_existing_user_assignments():
    parents = frappe.get_all(
        "Has Role",
        filters={"role": ["in", list(LEGACY_ROLES | ACTIVE_PORTAL_ROLES | ACTIVE_STAFF_ROLES)]},
        pluck="parent",
    )

    for user_id in set(parents):
        if user_id in {"Administrator", "Guest"} or not frappe.db.exists("User", user_id):
            continue

        roles = _user_roles(user_id)
        user_doc = frappe.get_doc("User", user_id)

        if roles.intersection(LEGACY_CLIENT_ROLES):
            _append_role(user_doc, CUSTOMER_ROLE)

        if "OMC Support Agent" in roles:
            _append_role(user_doc, SUPPORT_ROLE)

        user_doc.roles = [row for row in user_doc.roles if row.role not in LEGACY_ROLES]

        final_roles = {row.role for row in user_doc.roles}
        if final_roles.intersection(ACTIVE_STAFF_ROLES | {SYSTEM_ROLE}):
            user_doc.user_type = "System User"
        elif CUSTOMER_ROLE in final_roles:
            user_doc.user_type = "Website User"

        user_doc.save(ignore_permissions=True)
        frappe.clear_cache(user=user_id)


def _docperm_has_field(fieldname):
    try:
        return frappe.get_meta("DocPerm").has_field(fieldname)
    except Exception:
        return False


def _clean_perm_values(values):
    return {
        fieldname: value
        for fieldname, value in values.items()
        if fieldname in PERMISSION_FIELDS and _docperm_has_field(fieldname)
    }


def _set_docperm(doctype, role, values):
    values = _clean_perm_values(values)
    if not values or not frappe.db.exists("DocType", doctype) or not frappe.db.exists("Role", role):
        return

    perm_name = frappe.db.get_value(
        "DocPerm",
        {"parent": doctype, "role": role, "permlevel": 0},
        "name",
    )

    if perm_name:
        frappe.db.set_value("DocPerm", perm_name, values)
        return

    docperm = frappe.new_doc("DocPerm")
    docperm.parent = doctype
    docperm.parenttype = "DocType"
    docperm.parentfield = "permissions"
    docperm.permlevel = 0
    docperm.role = role
    for fieldname, value in values.items():
        setattr(docperm, fieldname, value)
    docperm.insert(ignore_permissions=True)


def _base_read():
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


def _admin_perm(is_submittable):
    values = _base_read()
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


def _manager_perm(is_submittable):
    values = _admin_perm(is_submittable)
    values["delete"] = 0
    values["share"] = 0
    return values


def _support_perm(doctype):
    values = _base_read()
    if doctype in SUPPORT_WRITE_DOCTYPES:
        values.update({"write": 1, "create": 1})
    if any(keyword in doctype for keyword in PAYMENT_KEYWORDS):
        values.update({"write": 0, "create": 0, "submit": 0, "cancel": 0, "amend": 0})
    return values


def _is_support_visible_doctype(doctype):
    return any(keyword in doctype for keyword in SUPPORT_READ_KEYWORDS)


def _is_settings_doctype(doctype):
    return any(keyword in doctype for keyword in SETTINGS_KEYWORDS)


def _omc_doctypes():
    rows = frappe.get_all(
        "DocType",
        filters={"name": ["like", "OMC %"]},
        fields=["name", "istable", "issingle", "is_submittable"],
    )
    return [row for row in rows if not int(row.istable or 0)]


def _apply_permissions():
    for row in _omc_doctypes():
        doctype = row.name
        is_submittable = int(row.is_submittable or 0) == 1

        _set_docperm(doctype, ADMIN_ROLE, _admin_perm(is_submittable))
        _set_docperm(doctype, MANAGER_ROLE, _manager_perm(is_submittable))

        if _is_support_visible_doctype(doctype) and not _is_settings_doctype(doctype):
            _set_docperm(doctype, SUPPORT_ROLE, _support_perm(doctype))

    # Customer role is intentionally not given broad DocPerms here. Customer
    # access remains API-owned and approval-state gated.


def _remove_legacy_docperms():
    for role_name in LEGACY_ROLES:
        frappe.db.delete("DocPerm", {"role": role_name})


def execute():
    for role_name in sorted(ACTIVE_PORTAL_ROLES):
        _set_role(role_name, desk_access=False)

    for role_name in sorted(ACTIVE_STAFF_ROLES):
        _set_role(role_name, desk_access=True)

    _normalize_existing_user_assignments()

    for role_name in sorted(LEGACY_ROLES):
        _disable_legacy_role(role_name)

    _remove_legacy_docperms()
    _apply_permissions()

    frappe.clear_cache()
    frappe.db.commit()
