import frappe

from omc_app.setup.roles import (
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    SYSTEM_ROLE,
    TAX_ASSOCIATE_ROLE,
)

PRIVILEGED_ROLES = {SYSTEM_ROLE, ADMIN_ROLE, MANAGER_ROLE}
FIELD_ROLES = {CONSULTANT_ROLE, TAX_ASSOCIATE_ROLE, BUSINESS_PARTNER_ROLE}


def _user(user=None):
    return user or frappe.session.user or "Guest"


def _roles(user=None):
    user = _user(user)
    if user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def _privileged(user=None):
    return bool(_roles(user).intersection(PRIVILEGED_ROLES))


def _escaped_user(user=None):
    return frappe.db.escape(_user(user))


def _todo_condition(reference_type, reference_expression, user=None):
    return (
        "exists (select 1 from `tabToDo` todo "
        f"where todo.reference_type = {frappe.db.escape(reference_type)} "
        f"and todo.reference_name = {reference_expression} "
        f"and todo.allocated_to = {_escaped_user(user)} "
        "and ifnull(todo.status, '') not in ('Cancelled', 'Closed'))"
    )


def service_request_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES):
        return ""

    table = "`tabOMC Service Request`"
    conditions = []

    if SUPPORT_AGENT_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Support Ticket` st "
            f"where st.reference_service_request = {table}.name)"
        )
    if DOCUMENT_REVIEWER_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Service Document` sd "
            f"where sd.service_request = {table}.name)"
        )
    if FINANCE_REVIEWER_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Service Payment` sp "
            f"where sp.service_request = {table}.name)"
        )
    if roles.intersection(FIELD_ROLES):
        conditions.append(_todo_condition("OMC Service Request", f"{table}.name", user))

    return " or ".join(f"({condition})" for condition in conditions) or "1=0"


def customer_profile_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES):
        return ""

    table = "`tabOMC Customer Profile`"
    conditions = []

    if SUPPORT_AGENT_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Support Ticket` st "
            f"where st.customer_profile = {table}.name)"
        )
    if DOCUMENT_REVIEWER_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Service Request` sr "
            "inner join `tabOMC Service Document` sd "
            "on sd.service_request = sr.name "
            f"where sr.customer_profile = {table}.name)"
        )
    if FINANCE_REVIEWER_ROLE in roles:
        conditions.append(
            "exists (select 1 from `tabOMC Service Request` sr "
            "inner join `tabOMC Service Payment` sp "
            "on sp.service_request = sr.name "
            f"where sr.customer_profile = {table}.name)"
        )
    if roles.intersection(FIELD_ROLES):
        conditions.append(
            "exists (select 1 from `tabOMC Service Request` sr "
            "inner join `tabToDo` todo "
            "on todo.reference_type = 'OMC Service Request' "
            "and todo.reference_name = sr.name "
            f"where sr.customer_profile = {table}.name "
            f"and todo.allocated_to = {_escaped_user(user)} "
            "and ifnull(todo.status, '') not in ('Cancelled', 'Closed'))"
        )

    return " or ".join(f"({condition})" for condition in conditions) or "1=0"


def task_query(user=None):
    user = _user(user)
    if _privileged(user):
        return ""
    return f"`tabOMC Task`.assigned_to = {_escaped_user(user)}"


def service_document_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {DOCUMENT_REVIEWER_ROLE}):
        return ""
    if roles.intersection(FIELD_ROLES):
        return _todo_condition(
            "OMC Service Request",
            "`tabOMC Service Document`.service_request",
            user,
        )
    return "1=0"


def service_payment_query(user=None):
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {FINANCE_REVIEWER_ROLE}):
        return ""
    return "1=0"


def support_ticket_query(user=None):
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {SUPPORT_AGENT_ROLE}):
        return ""
    return "1=0"


def lead_query(user=None):
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {SUPPORT_AGENT_ROLE}):
        return ""
    return "1=0"


def _record_matches_query(doctype, name, condition):
    if not condition:
        return True
    return bool(
        frappe.db.sql(
            f"select name from `tab{doctype}` where name = %s and ({condition}) limit 1",
            (name,),
        )
    )



def validate_task_assignment(doc, method=None):
    assigned_to = (getattr(doc, "assigned_to", None) or "").strip()
    if not assigned_to:
        return

    user_values = frappe.db.get_value(
        "User",
        assigned_to,
        ["enabled", "user_type"],
        as_dict=True,
    )
    if not user_values:
        frappe.throw("Task assignee does not exist.", frappe.ValidationError)
    if not int(user_values.enabled or 0):
        frappe.throw("Task assignee must be an enabled user.", frappe.ValidationError)
    if (user_values.user_type or "") != "System User":
        frappe.throw("Task assignee must be an internal System User.", frappe.ValidationError)

    assignee_roles = _roles(assigned_to)
    allowed_assignee_roles = PRIVILEGED_ROLES | {
        SUPPORT_AGENT_ROLE,
        DOCUMENT_REVIEWER_ROLE,
        FINANCE_REVIEWER_ROLE,
    } | FIELD_ROLES
    if not assignee_roles.intersection(allowed_assignee_roles):
        frappe.throw(
            "Task assignee must have an active OMC staff role.",
            frappe.ValidationError,
        )

    actor = _user()
    if actor in {"Guest", "Administrator"} or _privileged(actor):
        return

    if getattr(doc, "is_new", lambda: False)():
        frappe.throw(
            "Only OMC Admin or Manager may create tasks.",
            frappe.PermissionError,
        )

    previous_assignee = (
        frappe.db.get_value("OMC Task", doc.name, "assigned_to")
        if getattr(doc, "name", None)
        else None
    )
    if (previous_assignee or "") != assigned_to:
        frappe.throw(
            "Only OMC Admin or Manager may reassign tasks.",
            frappe.PermissionError,
        )


def service_request_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write", "create"}:
        return None
    return _record_matches_query(
        "OMC Service Request",
        doc.name,
        service_request_query(user),
    )


def customer_profile_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read"}:
        return None
    return _record_matches_query(
        "OMC Customer Profile",
        doc.name,
        customer_profile_query(user),
    )


def task_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write", "create"}:
        return None
    return _record_matches_query("OMC Task", doc.name, task_query(user))


def service_document_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write"}:
        return None
    return _record_matches_query(
        "OMC Service Document",
        doc.name,
        service_document_query(user),
    )


def service_payment_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write"}:
        return None
    return _record_matches_query(
        "OMC Service Payment",
        doc.name,
        service_payment_query(user),
    )


def support_ticket_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write", "create"}:
        return None
    return _record_matches_query(
        "OMC Support Ticket",
        doc.name,
        support_ticket_query(user),
    )


def lead_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, "read", "write", "create"}:
        return None
    return _record_matches_query("OMC Lead", doc.name, lead_query(user))
