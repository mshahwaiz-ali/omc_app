import frappe

from omc_app.api import capabilities
from omc_app.setup.roles import ADMIN_ROLE, BUSINESS_PARTNER_ROLE, CONSULTANT_ROLE, DOCUMENT_REVIEWER_ROLE, FINANCE_REVIEWER_ROLE, MANAGER_ROLE, SUPPORT_AGENT_ROLE, SYSTEM_ROLE, TAX_ASSOCIATE_ROLE

PRIVILEGED_ROLES = {ADMIN_ROLE, MANAGER_ROLE}
FIELD_ROLES = {CONSULTANT_ROLE, TAX_ASSOCIATE_ROLE, BUSINESS_PARTNER_ROLE}


def _user(user=None):
    return user or frappe.session.user or 'Guest'


def _roles(user=None):
    user = _user(user)
    if user == 'Guest':
        return set()
    values = capabilities.effective(user)
    roles = set()
    if user == 'Administrator' or values.get('can_view_all_service_cases') or values.get('can_view_all_customers'):
        roles.add(ADMIN_ROLE)
    if values.get('can_view_support_tickets'):
        roles.add(SUPPORT_AGENT_ROLE)
    if values.get('can_view_document_queue') or values.get('can_review_documents'):
        roles.add(DOCUMENT_REVIEWER_ROLE)
    if values.get('can_view_payment_queue') or values.get('can_review_payments'):
        roles.add(FINANCE_REVIEWER_ROLE)
    if values.get('can_view_assigned_service_cases') or values.get('can_manage_assigned_tasks'):
        roles.add(CONSULTANT_ROLE)
    return roles


def _privileged(user=None):
    return bool(_roles(user).intersection(PRIVILEGED_ROLES))


def _escaped_user(user=None):
    return frappe.db.escape(_user(user))


def _todo_condition(reference_type, reference_expression, user=None):
    return f"exists (select 1 from `tabToDo` todo where todo.reference_type = {frappe.db.escape(reference_type)} and todo.reference_name = {reference_expression} and todo.allocated_to = {_escaped_user(user)} and ifnull(todo.status, '') not in ('Cancelled', 'Closed'))"


def _owned_request_condition(request_table, user=None):
    escaped_user = _escaped_user(user)
    return (
        "exists (select 1 from `tabOMC Customer Account` account "
        f"where account.user = {escaped_user} "
        "and account.identity_proof_status = 'Verified' "
        "and account.account_link_status = 'Linked' "
        "and account.service_access_status = 'Approved' "
        f"and ({request_table}.customer_account = account.name "
        f"or (ifnull({request_table}.customer_account, '') = '' "
        f"and {request_table}.customer_profile = account.legacy_customer_profile)))"
    )


def _service_request_scope_conditions(table, user=None, roles=None):
    user = _user(user)
    roles = roles if roles is not None else _roles(user)
    escaped_user = frappe.db.escape(user)
    conditions = [_owned_request_condition(table, user)]
    if SUPPORT_AGENT_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Support Ticket` st where st.reference_service_request = {table}.name)')
    if DOCUMENT_REVIEWER_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Service Document` sd where sd.service_request = {table}.name)')
    if FINANCE_REVIEWER_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Service Payment` sp where sp.service_request = {table}.name)')
    if roles.intersection(FIELD_ROLES):
        conditions.extend([_todo_condition('OMC Service Request', f'{table}.name', user), f'{table}.assigned_staff = {escaped_user}', f'{table}.referral_owner = {escaped_user} and exists (select 1 from `tabOMC Customer Profile` customer where customer.name = {table}.customer_profile and customer.referred_by = {escaped_user} and customer.referral_record = {table}.referral_record and ifnull(customer.referral_assistance_consent, 0) = 1 and ifnull(customer.is_active, 0) = 1)'])
    return conditions


def service_request_query(user=None):
    user = _user(user)
    if user == 'Guest':
        return '1=0'
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES):
        return ''
    table = '`tabOMC Service Request`'
    conditions = _service_request_scope_conditions(table, user, roles)
    return ' or '.join((f'({condition})' for condition in conditions)) or '1=0'


def customer_profile_query(user=None):
    user = _user(user)
    if user == 'Guest':
        return '1=0'
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES):
        return ''
    table = '`tabOMC Customer Profile`'
    conditions = [
        (
            "exists (select 1 from `tabOMC Customer Account` account "
            f"where account.user = {_escaped_user(user)} "
            "and account.identity_proof_status = 'Verified' "
            "and account.account_link_status = 'Linked' "
            "and account.service_access_status = 'Approved' "
            f"and account.legacy_customer_profile = {table}.name)"
        ),
    ]
    if SUPPORT_AGENT_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Support Ticket` st where st.customer_profile = {table}.name)')
    if DOCUMENT_REVIEWER_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Service Request` sr inner join `tabOMC Service Document` sd on sd.service_request = sr.name where sr.customer_profile = {table}.name)')
    if FINANCE_REVIEWER_ROLE in roles:
        conditions.append(f'exists (select 1 from `tabOMC Service Request` sr inner join `tabOMC Service Payment` sp on sp.service_request = sr.name where sr.customer_profile = {table}.name)')
    if roles.intersection(FIELD_ROLES):
        conditions.append(f"exists (select 1 from `tabOMC Service Request` sr inner join `tabToDo` todo on todo.reference_type = 'OMC Service Request' and todo.reference_name = sr.name where sr.customer_profile = {table}.name and todo.allocated_to = {_escaped_user(user)} and ifnull(todo.status, '') not in ('Cancelled', 'Closed'))")
    return ' or '.join((f'({condition})' for condition in conditions)) or '1=0'


def referral_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES):
        return ''
    if roles.intersection(FIELD_ROLES):
        return f'`tabOMC Referral`.referrer_user = {_escaped_user(user)}'
    return '1=0'


def referral_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read'}:
        return None
    return _record_matches_query('OMC Referral', doc.name, referral_query(user))


def service_document_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {DOCUMENT_REVIEWER_ROLE}):
        return ''
    if roles.intersection(FIELD_ROLES):
        return _todo_condition('OMC Service Request', '`tabOMC Service Document`.service_request', user)
    return (
        "exists (select 1 from `tabOMC Service Request` sr "
        "where sr.name = `tabOMC Service Document`.service_request and "
        f"{_owned_request_condition('sr', user)})"
    )


def service_payment_query(user=None):
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {FINANCE_REVIEWER_ROLE}):
        return ''
    return (
        "exists (select 1 from `tabOMC Service Request` sr "
        "where sr.name = `tabOMC Service Payment`.service_request and "
        f"{_owned_request_condition('sr', user)})"
    )


def support_ticket_query(user=None):
    user = _user(user)
    roles = _roles(user)
    if roles.intersection(PRIVILEGED_ROLES | {SUPPORT_AGENT_ROLE}):
        return ''
    escaped_user = _escaped_user(user)
    return (
        "exists (select 1 from `tabOMC Customer Account` account "
        f"where account.user = {escaped_user} "
        "and account.identity_proof_status = 'Verified' "
        "and account.account_link_status = 'Linked' "
        "and account.service_access_status = 'Approved' "
        "and account.legacy_customer_profile = `tabOMC Support Ticket`.customer_profile)"
    )


def _record_matches_query(doctype, name, condition):
    if not condition:
        return True
    return bool(frappe.db.sql(f'select name from `tab{doctype}` where name = %s and ({condition}) limit 1', (name,)))


def service_request_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read', 'write', 'create'}:
        return None
    return _record_matches_query('OMC Service Request', doc.name, service_request_query(user))


def customer_profile_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read'}:
        return None
    return _record_matches_query('OMC Customer Profile', doc.name, customer_profile_query(user))


def service_document_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read', 'write'}:
        return None
    return _record_matches_query('OMC Service Document', doc.name, service_document_query(user))


def service_payment_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read', 'write'}:
        return None
    return _record_matches_query('OMC Service Payment', doc.name, service_payment_query(user))


def support_ticket_has_permission(doc, user=None, permission_type=None):
    if permission_type not in {None, 'read', 'write', 'create'}:
        return None
    return _record_matches_query('OMC Support Ticket', doc.name, support_ticket_query(user))
