import frappe


PORTAL_ROLES = {
    "OMC Customer",
    "OMC Business Partner",
    "OMC Tax Associate",
}

STAFF_ROLES = {
    "OMC Admin",
    "OMC Manager",
}

LEGACY_ROLES = {
    "OMC Customer Applicant",
    "OMC Support Agent",
    "OMC Customer Support",
    "OMC Document Reviewer",
    "OMC Finance Reviewer",
    "OMC Consultant",
}

SYSTEM_ROLE = "System Manager"


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


def _disable_role(role_name):
    if not frappe.db.exists("Role", role_name):
        return

    values = {"desk_access": 0}
    if _role_has_field("disabled"):
        values["disabled"] = 1
    frappe.db.set_value("Role", role_name, values)


def _user_has_active_role(user_id):
    roles = {
        row.role
        for row in frappe.get_all(
            "Has Role",
            filters={"parent": user_id},
            fields=["role"],
        )
    }
    return bool(roles.intersection(PORTAL_ROLES | STAFF_ROLES | {SYSTEM_ROLE}))


def _normalize_users():
    users = frappe.get_all(
        "Has Role",
        filters={"role": ["in", list(PORTAL_ROLES | STAFF_ROLES | LEGACY_ROLES)]},
        pluck="parent",
    )

    for user_id in set(users):
        if user_id in {"Administrator", "Guest"} or not frappe.db.exists("User", user_id):
            continue

        user_doc = frappe.get_doc("User", user_id)
        user_doc.roles = [row for row in user_doc.roles if row.role not in LEGACY_ROLES]

        if _user_has_active_role(user_id):
            active_roles = {row.role for row in user_doc.roles}
            if active_roles.intersection(STAFF_ROLES | {SYSTEM_ROLE}):
                user_doc.user_type = "System User"
            elif active_roles.intersection(PORTAL_ROLES):
                user_doc.user_type = "Website User"

        user_doc.save(ignore_permissions=True)
        frappe.clear_cache(user=user_id)


def _remove_legacy_docperms():
    for role_name in LEGACY_ROLES:
        frappe.db.delete("DocPerm", {"role": role_name})


def _protect_manager_from_delete():
    for perm_name in frappe.get_all("DocPerm", filters={"role": "OMC Manager"}, pluck="name"):
        frappe.db.set_value("DocPerm", perm_name, "delete", 0)
        if frappe.get_meta("DocPerm").has_field("share"):
            frappe.db.set_value("DocPerm", perm_name, "share", 0)


def execute():
    for role_name in sorted(PORTAL_ROLES):
        _set_role(role_name, desk_access=False)

    for role_name in sorted(STAFF_ROLES):
        _set_role(role_name, desk_access=True)

    for role_name in sorted(LEGACY_ROLES):
        _disable_role(role_name)

    _normalize_users()
    _remove_legacy_docperms()
    _protect_manager_from_delete()

    frappe.clear_cache()
    frappe.db.commit()
