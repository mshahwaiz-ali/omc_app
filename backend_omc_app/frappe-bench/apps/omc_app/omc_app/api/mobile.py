import frappe


def _items_response(key, items=None):
    return {key: items or []}


def _message(message="OK", **extra):
    data = {"message": message}
    data.update(extra)
    return data


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"

def _has_doctype(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _doctype_has_field(doctype, fieldname):
    try:
        return _has_doctype(doctype) and frappe.get_meta(doctype).has_field(fieldname)
    except Exception:
        return False


def _service_fee_label(service):
    fee_label = (getattr(service, "fee_label", None) or "").strip()
    bad_fee_labels = {"Contact OMCfor pricing", "Contact OMC for pricing"}

    if fee_label and fee_label not in bad_fee_labels:
        return fee_label

    amount = getattr(service, "base_price", None) or 0
    currency = getattr(service, "currency", None) or "PKR"
    try:
        amount_value = float(amount)
    except (TypeError, ValueError):
        amount_value = 0

    if amount_value <= 0:
        return "Contact OMC for pricing"

    if amount_value.is_integer():
        amount_value = int(amount_value)

    return f"{currency} {amount_value}"


def _service_completion_time(service):
    return (
        (getattr(service, "completion_time", None) or "").strip()
        or (getattr(service, "estimated_duration", None) or "").strip()
    )


def _service_required_documents(service_name):
    if not service_name or not _has_doctype("OMC Service Required Document"):
        return []

    rows = frappe.get_all(
        "OMC Service Required Document",
        filters={
            "service": service_name,
            "is_active": 1,
        },
        fields=[
            "name",
            "document_title",
            "document_type",
            "is_required",
            "instructions",
            "allowed_extensions",
            "max_size_mb",
            "sort_order",
        ],
        order_by="sort_order asc, creation asc",
    )

    return [
        {
            "name": row.name,
            "title": row.document_title or "",
            "document_title": row.document_title or "",
            "type": row.document_type or "",
            "document_type": row.document_type or "",
            "is_required": int(row.is_required or 0),
            "instructions": row.instructions or "",
            "allowed_extensions": row.allowed_extensions or "",
            "max_size_mb": row.max_size_mb or 10,
            "sort_order": row.sort_order or 0,
            "status": "Required" if row.is_required else "Optional",
            "file_url": "",
        }
        for row in rows
    ]


def _service_to_catalogue_dict(service, include_required_documents=False):
    required_documents = (
        _service_required_documents(service.name)
        if include_required_documents
        else []
    )

    return {
        "id": service.service_id or service.name,
        "name": service.name,
        "title": service.title or "",
        "description": service.description or "",
        "short_description": getattr(service, "short_description", None) or "",
        "category": service.category or "",
        "icon": service.icon or "",
        "estimated_duration": service.estimated_duration or "",
        "completion_time": _service_completion_time(service),
        "completionTime": _service_completion_time(service),
        "base_price": service.base_price or 0,
        "currency": service.currency or "PKR",
        "fee_label": _service_fee_label(service),
        "feeLabel": _service_fee_label(service),
        "government_fee_label": getattr(service, "government_fee_label", None) or "",
        "support_message": getattr(service, "support_message", None) or "",
        "wizard_type": getattr(service, "wizard_type", None) or "",
        "wizardType": getattr(service, "wizard_type", None) or "",
        "wizard_config": getattr(service, "wizard_config", None) or "",
        "is_featured": int(service.is_featured or 0),
        "required_documents": [
            doc.get("title") or doc.get("document_title") or ""
            for doc in required_documents
            if doc.get("title") or doc.get("document_title")
        ],
        "required_document_details": required_documents,
    }


SYSTEM_OVERRIDE_ROLES = {"System Manager"}
OMC_ADMIN_ROLES = {"OMC Admin", "OMC Manager"}
OMC_SUPPORT_ROLES = {"OMC Support Agent"}
OMC_DOCUMENT_ROLES = {"OMC Document Reviewer"}
OMC_FINANCE_ROLES = {"OMC Finance Reviewer"}
OMC_FIELD_ROLES = {"OMC Consultant", "OMC Business Partner", "OMC Tax Associate"}
INTERNAL_WORKSPACE_ROLES = (
    SYSTEM_OVERRIDE_ROLES
    | OMC_ADMIN_ROLES
    | OMC_SUPPORT_ROLES
    | OMC_DOCUMENT_ROLES
    | OMC_FINANCE_ROLES
    | OMC_FIELD_ROLES
)
SERVICE_STATUS_ROLES = SYSTEM_OVERRIDE_ROLES | OMC_ADMIN_ROLES | OMC_FIELD_ROLES
DOCUMENT_REVIEW_ROLES = SYSTEM_OVERRIDE_ROLES | OMC_ADMIN_ROLES | OMC_DOCUMENT_ROLES
PAYMENT_REVIEW_ROLES = SYSTEM_OVERRIDE_ROLES | OMC_ADMIN_ROLES | OMC_FINANCE_ROLES
SUPPORT_STAFF_ROLES = SYSTEM_OVERRIDE_ROLES | OMC_ADMIN_ROLES | OMC_SUPPORT_ROLES


def _current_user_roles(user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return set()

    return set(frappe.get_roles(user))


def _can_access_internal_workspace(user=None):
    return bool(_current_user_roles(user).intersection(INTERNAL_WORKSPACE_ROLES))


def _has_any_role(user=None, roles=None):
    return bool(_current_user_roles(user).intersection(set(roles or [])))


def _profile_status(profile):
    if not profile:
        return "", ""

    customer_status = (profile.customer_status or "").strip()
    approval_status = (profile.approval_status or "").strip()
    return customer_status, approval_status


def _is_approved_customer(profile):
    customer_status, approval_status = _profile_status(profile)
    return customer_status.lower() == "active" and approval_status.lower() == "approved"


def is_customer_approved(profile=None, user=None):
    return _is_approved_customer(profile or _get_customer_profile_for_user(user))


def _is_pending_customer(profile):
    customer_status, approval_status = _profile_status(profile)
    pending_statuses = {"pending", "pending review", "under review", ""}
    return customer_status.lower() in pending_statuses or approval_status.lower() in pending_statuses


def _customer_access_state(user=None, profile=None):
    user = user or _current_user()

    if not user or user == "Guest":
        return "guest"

    if _can_access_internal_workspace(user):
        return "internal"

    if not profile:
        profile = _get_customer_profile_for_user(user)

    if _is_approved_customer(profile):
        return "approved"

    customer_status, approval_status = _profile_status(profile)
    if customer_status.lower() == "rejected" or approval_status.lower() == "rejected":
        return "rejected"

    return "pending"


def _get_mobile_capabilities(user=None, profile=None):
    user = user or _current_user()
    roles = _current_user_roles(user)
    is_guest = not user or user == "Guest"
    is_internal = bool(roles.intersection(INTERNAL_WORKSPACE_ROLES))
    is_admin = bool(roles.intersection(SYSTEM_OVERRIDE_ROLES | OMC_ADMIN_ROLES))
    is_support = bool(roles.intersection(SUPPORT_STAFF_ROLES))
    is_document_reviewer = bool(roles.intersection(DOCUMENT_REVIEW_ROLES))
    is_finance_reviewer = bool(roles.intersection(PAYMENT_REVIEW_ROLES))
    can_update_service_status = bool(roles.intersection(SERVICE_STATUS_ROLES))

    if not is_guest and profile is None and not is_internal:
        profile = _get_customer_profile_for_user(user)

    is_approved = _is_approved_customer(profile)
    access_state = _customer_access_state(user=user, profile=profile)
    payments_enabled = _settings_bool(_get_single_settings("OMC Mobile Settings"), "payments_enabled", True)

    return {
        "access_state": access_state,
        "is_guest": is_guest,
        "is_pending": access_state == "pending",
        "is_approved_customer": is_approved,
        "can_view_public_catalogue": True,
        "can_view_public_content": True,
        "can_use_tax_calculator": True,
        "can_create_service_request": is_approved,
        "can_upload_documents": is_approved,
        "can_track_requests": is_approved,
        "can_view_documents": is_approved,
        "can_view_payments": is_approved,
        "can_upload_payment_receipt": is_approved and payments_enabled,
        "can_upload_payment_receipts": is_approved and payments_enabled,
        "can_create_support_ticket": is_approved,
        "can_view_support_tickets": is_approved,
        "can_view_customer_dashboard": is_approved,
        "can_access_customer_dashboard": is_approved,
        "can_view_customer_notifications": is_approved,
        "can_access_internal_workspace": is_internal,
        "can_update_service_status": can_update_service_status,
        "can_review_documents": is_document_reviewer,
        "can_review_payments": is_finance_reviewer,
        "can_update_support_ticket_status": is_support,
        "can_manage_customers": is_admin,
        "can_manage_leads": is_admin or is_support,
        "can_manage_tasks": is_internal,
        "can_view_internal_notes": is_internal,
    }


def _approved_customer_required_message(profile=None):
    if profile and _is_pending_customer(profile):
        return "Your account is under review. OMC team will verify your profile before enabling service access."

    return "Please create an approved OMC customer account to access this feature."


def _assert_approved_customer():
    user = _current_user()

    if user == "Guest":
        frappe.throw("Please create an account or subscribe to access this feature.", frappe.PermissionError)

    profile = _get_customer_profile_for_user(user)
    if not _is_approved_customer(profile):
        frappe.throw(_approved_customer_required_message(profile), frappe.PermissionError)

    return profile


def get_current_customer_profile():
    return _get_customer_profile_for_user()


def require_approved_customer():
    return _assert_approved_customer()


def _set_if_has_field(doc, fieldname, value):
    if value is None:
        return

    if not doc.meta.has_field(fieldname):
        return

    if isinstance(value, str):
        value = value.strip()

    if value != "":
        doc.set(fieldname, value)


def _assign_role_if_exists(user_doc, role_name):
    if not user_doc or not role_name:
        return

    if not frappe.db.exists("Role", role_name):
        return

    existing_roles = {row.role for row in (user_doc.roles or [])}
    if role_name in existing_roles:
        return

    user_doc.append("roles", {"role": role_name})
    user_doc.save(ignore_permissions=True)


def _assert_internal_workspace_access():
    user = _current_user()

    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    user_roles = set(frappe.get_roles(user) or [])
    if not user_roles.intersection(INTERNAL_WORKSPACE_ROLES):
        frappe.throw("You do not have permission to access internal workspace data.", frappe.PermissionError)

    return user


def require_omc_staff(required_roles=None, message=None):
    user = _assert_internal_workspace_access()
    roles = _current_user_roles(user)
    allowed_roles = set(required_roles or INTERNAL_WORKSPACE_ROLES)

    if not roles.intersection(allowed_roles):
        frappe.throw(
            message or "You do not have permission to perform this OMC staff action.",
            frappe.PermissionError,
        )

    return user


def get_mobile_capabilities():
    return _get_mobile_capabilities()


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    email = (kwargs.get("email") or kwargs.get("user") or "").strip().lower()
    password = kwargs.get("password") or kwargs.get("new_password")
    full_name = (kwargs.get("full_name") or kwargs.get("name") or "").strip()
    phone = (kwargs.get("phone") or kwargs.get("mobile") or "").strip()
    whatsapp_no = (kwargs.get("whatsapp_no") or kwargs.get("whatsapp") or "").strip()
    company_name = (kwargs.get("company_name") or kwargs.get("company") or "").strip()
    cnic = (kwargs.get("cnic") or "").strip()
    ntn = (kwargs.get("ntn") or "").strip()
    register_as = (kwargs.get("register_as") or kwargs.get("customer_type") or "Customer").strip()
    customer_type = (kwargs.get("customer_type") or register_as or "Customer").strip()
    address = (kwargs.get("address") or "").strip()
    education = (kwargs.get("education") or "").strip()
    experience = (kwargs.get("experience") or "").strip()
    remarks = (kwargs.get("remarks") or kwargs.get("notes") or "").strip()

    if not email:
        frappe.throw("email is required")

    if "@" not in email:
        frappe.throw("A valid email address is required")

    if not full_name:
        full_name = email

    user_created = False
    profile_created = False

    if not frappe.db.exists("User", email):
        user = frappe.new_doc("User")
        user.email = email
        user.first_name = full_name
        user.full_name = full_name
        user.enabled = 1
        user.send_welcome_email = 0
        user.user_type = "Website User"
        user.insert(ignore_permissions=True)

        if password:
            user.new_password = password
            user.save(ignore_permissions=True)

        user_created = True
    else:
        user = frappe.get_doc("User", email)

    _assign_role_if_exists(user, "OMC Customer Applicant")

    profile_name = frappe.db.get_value("OMC Customer Profile", {"user": email}, "name")
    if not profile_name:
        profile_name = frappe.db.get_value("OMC Customer Profile", {"email": email}, "name")

    if profile_name:
        profile = frappe.get_doc("OMC Customer Profile", profile_name)
    else:
        profile = frappe.new_doc("OMC Customer Profile")
        profile.user = email
        profile.email = email
        profile.full_name = full_name
        profile.customer_status = "Pending"
        profile.approval_status = "Pending Review"
        profile.is_active = 1
        profile_created = True

    profile.full_name = full_name or profile.full_name
    profile.email = email
    profile.user = email
    if phone:
        profile.phone = phone
    if company_name:
        profile.company_name = company_name
    if cnic:
        profile.cnic = cnic
    if ntn:
        profile.ntn = ntn
    _set_if_has_field(profile, "whatsapp_no", whatsapp_no)
    _set_if_has_field(profile, "register_as", register_as)
    _set_if_has_field(profile, "customer_type", customer_type)
    _set_if_has_field(profile, "address", address)
    _set_if_has_field(profile, "education", education)
    _set_if_has_field(profile, "experience", experience)
    _set_if_has_field(profile, "remarks", remarks)

    if profile.is_new():
        profile.insert(ignore_permissions=True)
    else:
        profile.save(ignore_permissions=True)

    preferences = _get_customer_preferences(profile)

    frappe.db.commit()

    return {
        "message": "Signup completed.",
        "created": user_created or profile_created,
        "user_created": user_created,
        "profile_created": profile_created,
        "user": {
            "email": user.email or email,
            "full_name": user.full_name or full_name,
            "enabled": int(user.enabled or 0),
        },
        "profile": {
            "customer_id": profile.name,
            "full_name": profile.full_name or "",
            "email": profile.email or "",
            "phone": profile.phone or "",
            "whatsapp_no": profile.get("whatsapp_no") or "",
            "company_name": profile.company_name or "",
            "cnic": profile.cnic or "",
            "ntn": profile.ntn or "",
            "register_as": profile.get("register_as") or "",
            "customer_type": profile.get("customer_type") or "",
            "address": profile.get("address") or "",
            "education": profile.get("education") or "",
            "experience": profile.get("experience") or "",
            "remarks": profile.get("remarks") or "",
            "customer_status": profile.customer_status or "",
            "approval_status": profile.approval_status or "",
        },
        "access_state": _customer_access_state(user=email, profile=profile),
        "capabilities": _get_mobile_capabilities(user=email, profile=profile),
        "preferences": _settings_preferences_to_dict(preferences),
    }


@frappe.whitelist(allow_guest=True)
def google_mobile_login(id_token=None, **kwargs):
    id_token = (id_token or kwargs.get("token") or "").strip()

    if not id_token:
        frappe.throw("id_token is required")

    frappe.throw(
        "Google mobile login is not configured on this OMC backend yet. "
        "Use email/password login until verified Google token validation is enabled.",
        frappe.AuthenticationError,
    )


@frappe.whitelist()
def get_session_user():
    user = _current_user()
    roles = sorted(_current_user_roles(user))
    profile = None
    if user and user != "Guest" and not _can_access_internal_workspace(user):
        profile = _get_customer_profile_for_user(user)
    capabilities = _get_mobile_capabilities(user=user, profile=profile)

    return {
        "user": user,
        "is_guest": user == "Guest",
        "roles": roles,
        "access_state": capabilities["access_state"],
        "capabilities": capabilities,
        **capabilities,
    }


def _get_customer_profile_for_user(user=None):
    user = user or _current_user()

    if not user or user == "Guest":
        return None

    profile_name = frappe.db.get_value("OMC Customer Profile", {"user": user}, "name")
    if not profile_name:
        profile_name = frappe.db.get_value("OMC Customer Profile", {"email": user}, "name")

    if profile_name:
        return frappe.get_doc("OMC Customer Profile", profile_name)

    full_name = frappe.db.get_value("User", user, "full_name") or user
    profile = frappe.new_doc("OMC Customer Profile")
    profile.user = user
    profile.email = user
    profile.full_name = full_name
    profile.customer_status = "Pending"
    profile.approval_status = "Pending Review"
    profile.is_active = 1
    profile.insert(ignore_permissions=True)
    frappe.db.commit()

    return profile


@frappe.whitelist()
def get_profile():
    user = _current_user()

    if user == "Guest":
        capabilities = _get_mobile_capabilities(user=user)
        return {
            "full_name": "",
            "email": "",
            "phone": "",
            "avatar_url": "",
            "customer_id": "",
            "customer_status": "Guest",
            "approval_status": "",
            "access_state": "guest",
            "capabilities": capabilities,
            **capabilities,
        }

    profile = _get_customer_profile_for_user(user)
    capabilities = _get_mobile_capabilities(user=user, profile=profile)

    return {
        "full_name": profile.full_name or "",
        "email": profile.email or user,
        "phone": profile.phone or "",
        "whatsapp_no": profile.get("whatsapp_no") or "",
        "avatar_url": "",
        "customer_id": profile.name,
        "customer_status": profile.customer_status or "",
        "approval_status": profile.approval_status or "",
        "company_name": profile.company_name or "",
        "cnic": profile.cnic or "",
        "ntn": profile.ntn or "",
        "register_as": profile.get("register_as") or "",
        "customer_type": profile.get("customer_type") or "",
        "address": profile.get("address") or "",
        "education": profile.get("education") or "",
        "experience": profile.get("experience") or "",
        "remarks": profile.get("remarks") or "",
        "access_state": capabilities["access_state"],
        "capabilities": capabilities,
        **capabilities,
    }


@frappe.whitelist()
def update_profile(**kwargs):
    profile = _get_customer_profile_for_user()

    allowed_fields = ["full_name", "phone", "cnic", "ntn", "company_name"]
    updated_fields = []

    for fieldname in allowed_fields:
        if fieldname in kwargs:
            profile.set(fieldname, kwargs.get(fieldname))
            updated_fields.append(fieldname)

    if updated_fields:
        profile.save(ignore_permissions=True)
        frappe.db.commit()

    return {
        "message": "Profile updated." if updated_fields else "No profile fields changed.",
        "updated": bool(updated_fields),
        "updated_fields": updated_fields,
    }


@frappe.whitelist()
def update_contact_info(**kwargs):
    profile = _get_customer_profile_for_user()

    field_map = {
        "full_name": "full_name",
        "name": "full_name",
        "phone": "phone",
        "mobile": "phone",
        "email": "email",
        "cnic": "cnic",
        "ntn": "ntn",
        "company_name": "company_name",
        "company": "company_name",
    }

    updated_fields = []

    for incoming_field, profile_field in field_map.items():
        if incoming_field not in kwargs:
            continue

        value = kwargs.get(incoming_field)
        if value is None:
            continue

        value = str(value).strip()
        if profile.get(profile_field) != value:
            profile.set(profile_field, value)
            if profile_field not in updated_fields:
                updated_fields.append(profile_field)

    if updated_fields:
        profile.save(ignore_permissions=True)
        frappe.db.commit()

    return {
        "message": "Contact information updated." if updated_fields else "No contact information changed.",
        "updated": bool(updated_fields),
        "updated_fields": updated_fields,
        "profile": {
            "customer_id": profile.name,
            "full_name": profile.full_name or "",
            "email": profile.email or "",
            "phone": profile.phone or "",
            "company_name": profile.company_name or "",
            "cnic": profile.cnic or "",
            "ntn": profile.ntn or "",
        },
    }


@frappe.whitelist()
def get_dashboard_data():
    user = _current_user()
    profile = None

    if _can_access_internal_workspace(user):
        profile = None
    else:
        profile = _assert_approved_customer()

    service_filters = {}
    document_filters = {"visible_to_customer": 1}
    payment_filters = {"visible_to_customer": 1}
    notification_filters = {"visible_to_customer": 1, "is_read": 0}
    timeline_filters = {"visible_to_customer": 1}

    if profile:
        service_filters["customer_profile"] = profile.name
        notification_filters["customer_profile"] = profile.name

        service_names = frappe.get_all(
            "OMC Service Request",
            filters={"customer_profile": profile.name},
            pluck="name",
        )

        if service_names:
            document_filters["service_request"] = ["in", service_names]
            payment_filters["service_request"] = ["in", service_names]
            timeline_filters["service_request"] = ["in", service_names]
        else:
            document_filters["service_request"] = "__no_service_requests__"
            payment_filters["service_request"] = "__no_service_requests__"
            timeline_filters["service_request"] = "__no_service_requests__"

    open_service_filters = dict(service_filters)
    open_service_filters["status"] = ["not in", ["Completed", "Cancelled"]]

    open_services = frappe.db.count("OMC Service Request", open_service_filters)
    documents = frappe.db.count("OMC Service Document", document_filters)

    pending_payment_filters = dict(payment_filters)
    pending_payment_filters["status"] = "Pending"
    payments_due = frappe.db.count("OMC Service Payment", pending_payment_filters)

    notifications = frappe.db.count("OMC Notification", notification_filters)

    recent_rows = frappe.get_all(
        "OMC Service Timeline",
        filters=timeline_filters,
        fields=[
            "name",
            "service_request",
            "event_type",
            "title",
            "description",
            "event_time",
            "created_by",
        ],
        order_by="event_time desc, creation desc",
        limit_page_length=10,
    )

    return {
        "open_services": open_services,
        "documents": documents,
        "payments_due": payments_due,
        "notifications": notifications,
        "recent_activity": [
            {
                "id": row.name,
                "service_request": row.service_request,
                "event_type": row.event_type,
                "title": row.title or row.event_type or "Update",
                "description": row.description or "",
                "event_time": row.event_time,
                "created_by": row.created_by or "",
            }
            for row in recent_rows
        ],
    }


@frappe.whitelist(allow_guest=True)
def get_service_catalogue():
    services = frappe.get_all(
        "OMC Service",
        filters={"is_active": 1},
        fields=[
            "name",
            "service_id",
            "title",
            "category",
            "description",
            "short_description",
            "icon",
            "estimated_duration",
            "completion_time",
            "base_price",
            "currency",
            "fee_label",
            "government_fee_label",
            "support_message",
            "wizard_type",
            "wizard_config",
            "is_featured",
        ],
        order_by="sort_order asc, modified desc",
    )

    return {
        "services": [
            _service_to_catalogue_dict(service, include_required_documents=True)
            for service in services
        ]
    }


@frappe.whitelist(allow_guest=True)
def get_service_detail(service_id=None):
    if not service_id:
        return {
            "name": "",
            "id": "",
            "title": "",
            "description": "",
            "category": "",
            "required_documents": [],
        }

    name = frappe.db.get_value("OMC Service", {"service_id": service_id}, "name") or service_id

    if not frappe.db.exists("OMC Service", name):
        frappe.throw("Service not found", frappe.DoesNotExistError)

    service = frappe.get_doc("OMC Service", name)

    return _service_to_catalogue_dict(service, include_required_documents=True)


def _create_service_timeline_entry(
    service_request,
    title,
    description="",
    event_type="Update",
    visible_to_customer=1,
):
    entry = frappe.new_doc("OMC Service Timeline")
    entry.service_request = service_request
    entry.event_type = event_type
    entry.title = title
    entry.description = description or ""
    entry.event_time = frappe.utils.now_datetime()
    entry.visible_to_customer = 1 if visible_to_customer else 0
    entry.insert(ignore_permissions=True)
    return entry


def _get_service_timeline(service_request):
    entries = frappe.get_all(
        "OMC Service Timeline",
        filters={
            "service_request": service_request,
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "event_type",
            "title",
            "description",
            "event_time",
            "created_by",
        ],
        order_by="event_time asc, creation asc",
    )

    return [
        {
            "name": entry.name,
            "type": entry.event_type or "",
            "title": entry.title or "",
            "description": entry.description or "",
            "created_at": str(entry.event_time) if entry.event_time else "",
            "created_by": entry.created_by or "",
        }
        for entry in entries
    ]


@frappe.whitelist()
def create_service(**kwargs):
    profile = _assert_approved_customer()

    service_id = kwargs.get("service_id") or kwargs.get("service")
    service_name = ""
    service_title = ""

    if service_id:
        service_name = frappe.db.get_value("OMC Service", {"service_id": service_id}, "name") or service_id
        if frappe.db.exists("OMC Service", service_name):
            service_title = frappe.db.get_value("OMC Service", service_name, "title") or ""

    title = kwargs.get("title") or service_title or "Service Request"

    doc = frappe.new_doc("OMC Service Request")
    doc.service = service_name if service_name and frappe.db.exists("OMC Service", service_name) else None
    doc.service_title = service_title
    doc.title = title
    doc.description = kwargs.get("description") or ""
    doc.priority = kwargs.get("priority") or "Medium"
    doc.status = "Open"
    doc.customer_profile = profile.name if profile else ""
    doc.customer_name = profile.full_name if profile else ""
    doc.contact_email = kwargs.get("contact_email") or (profile.email if profile else "")
    doc.contact_phone = kwargs.get("contact_phone") or (profile.phone if profile else "")
    doc.insert(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=doc.name,
        event_type="Request Created",
        title="Request Created",
        description="Your service request has been created successfully.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "name": doc.name,
        "status": doc.status,
        "created": True,
        "message": "Service request created.",
    }


def _get_service_documents(service_request):
    docs = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": service_request,
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "document_title",
            "document_type",
            "attachment",
            "status",
            "uploaded_on",
            "uploaded_by",
            "remarks",
        ],
        order_by="uploaded_on asc, creation asc",
    )

    return [
        {
            "name": doc.name,
            "title": doc.document_title or "",
            "type": doc.document_type or "",
            "file_url": doc.attachment or "",
            "status": doc.status or "",
            "uploaded_at": str(doc.uploaded_on) if doc.uploaded_on else "",
            "uploaded_by": doc.uploaded_by or "",
            "remarks": doc.remarks or "",
        }
        for doc in docs
    ]



def _service_case_progress(status):
    normalized = (status or "").strip().lower()
    mapping = {
        "open": 0.10,
        "waiting for customer": 0.35,
        "in progress": 0.60,
        "under review": 0.80,
        "completed": 1.00,
        "cancelled": 0.00,
    }
    return mapping.get(normalized, 0.10)


def _service_case_next_step(status, missing_documents=None):
    if missing_documents:
        return "Please upload the missing required document(s)."

    normalized = (status or "").strip().lower()
    if normalized == "open":
        return "OMC team will review your request shortly."
    if normalized == "waiting for customer":
        return "OMC is waiting for your response or required documents."
    if normalized == "in progress":
        return "OMC team is working on your service request."
    if normalized == "under review":
        return "Your request is under final review."
    if normalized == "completed":
        return "Your service request has been completed."
    if normalized == "cancelled":
        return "This service request has been cancelled."
    return "OMC team will update this service request shortly."


def _split_service_documents(documents, required_document_templates=None):
    submitted_statuses = {"submitted", "approved", "under review", "accepted", "uploaded"}
    missing_statuses = {"missing", "required", "rejected", "expired"}

    required_documents = []
    submitted_documents = []
    missing_documents = []

    for template in required_document_templates or []:
        required_documents.append(template)
        if template.get("is_required"):
            missing_documents.append(template)

    for document in documents:
        required_documents.append(document)
        status = (document.get("status") or "").strip().lower()
        has_file = bool(document.get("file_url") or document.get("attachment"))

        if has_file or status in submitted_statuses:
            submitted_documents.append(document)

            doc_title = (document.get("title") or document.get("document_title") or "").strip().lower()
            doc_type = (document.get("type") or document.get("document_type") or "").strip().lower()

            missing_documents = [
                missing
                for missing in missing_documents
                if (
                    (missing.get("title") or missing.get("document_title") or "").strip().lower() != doc_title
                    and (missing.get("type") or missing.get("document_type") or "").strip().lower() != doc_type
                )
            ]
        elif status in missing_statuses or not has_file:
            missing_documents.append(document)

    return required_documents, submitted_documents, missing_documents

@frappe.whitelist()
def get_service_cases():
    if _can_access_internal_workspace():
        profile = None
    else:
        profile = _assert_approved_customer()

    filters = {}
    if profile:
        filters["customer_profile"] = profile.name

    cases = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=[
            "name",
            "title",
            "status",
            "priority",
            "service",
            "service_title",
            "description",
            "creation",
            "modified",
            "expected_completion_date",
        ],
        order_by="modified desc",
    )

    return {
        "cases": [
            {
                "name": case.name,
                "title": case.title or case.service_title or "Service Request",
                "status": case.status or "",
                "priority": case.priority or "",
                "service": case.service_title or case.service or "",
                "description": case.description or "",
                "created_at": str(case.creation.date()) if case.creation else "",
                "updated_at": str(case.modified.date()) if case.modified else "",
                "expected_completion_date": str(case.expected_completion_date) if case.expected_completion_date else "",
            }
            for case in cases
        ]
    }




@frappe.whitelist()
def update_service_case_status(case_id=None, status=None, note=None, expected_completion_date=None):
    require_omc_staff(SERVICE_STATUS_ROLES, "You do not have permission to update service case status.")

    if not case_id:
        frappe.throw("case_id is required")

    if not status:
        frappe.throw("status is required")

    allowed_statuses = [
        "Open",
        "In Progress",
        "Waiting for Customer",
        "Completed",
        "Cancelled",
    ]

    if status not in allowed_statuses:
        frappe.throw("Invalid status")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Request", case_id)
    old_status = doc.status or ""

    doc.status = status

    if expected_completion_date is not None:
        doc.expected_completion_date = expected_completion_date or None

    if status in ["Completed", "Cancelled"] and not doc.closed_on:
        doc.closed_on = frappe.utils.now_datetime()

    if status not in ["Completed", "Cancelled"]:
        doc.closed_on = None

    doc.save(ignore_permissions=True)

    if old_status != status:
        description = note or f"Status changed from {old_status or 'Unknown'} to {status}."

        _create_service_timeline_entry(
            service_request=doc.name,
            event_type="Status Updated",
            title=f"Status Updated: {status}",
            description=description,
            visible_to_customer=1,
        )
    elif note:
        _create_service_timeline_entry(
            service_request=doc.name,
            event_type="Update",
            title="Case Updated",
            description=note,
            visible_to_customer=1,
        )

    frappe.db.commit()

    return {
        "name": doc.name,
        "status": doc.status,
        "updated": True,
        "message": "Service case updated.",
    }

@frappe.whitelist()
def get_service_case(case_id=None):
    if not case_id:
        frappe.throw("case_id is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service request not found", frappe.DoesNotExistError)

    service_case = frappe.get_doc("OMC Service Request", case_id)
    can_access_internal_workspace = _can_access_internal_workspace()
    profile = None if can_access_internal_workspace else _assert_approved_customer()

    if not can_access_internal_workspace:
        if not profile:
            frappe.throw("Login is required", frappe.PermissionError)

        if service_case.customer_profile and service_case.customer_profile != profile.name:
            frappe.throw("You do not have permission to access this service request", frappe.PermissionError)

    documents = _get_service_documents(service_case.name)
    required_document_templates = _service_required_documents(service_case.service)
    required_documents, submitted_documents, missing_documents = _split_service_documents(
        documents,
        required_document_templates,
    )

    timeline = _get_service_timeline(service_case.name)
    progress = _service_case_progress(service_case.status)
    missing_documents_count = len(missing_documents)
    submitted_documents_count = len(submitted_documents)
    required_documents_count = len(required_documents)
    customer_action_required = missing_documents_count > 0 or (
        (service_case.status or "").strip().lower() == "waiting for customer"
    )

    return {
        "case": {
            "name": service_case.name,
            "service_id": service_case.service,
            "service_title": service_case.service_title or "",
            "status": service_case.status or "",
            "priority": service_case.priority or "",
            "progress": progress,
            "progress_percent": int(progress * 100),
            "current_stage": service_case.status or "",
            "next_step": _service_case_next_step(service_case.status, missing_documents),
            "customer_action_required": customer_action_required,
            "required_documents_count": required_documents_count,
            "submitted_documents_count": submitted_documents_count,
            "missing_documents_count": missing_documents_count,
            "submitted_on": str(getattr(service_case, "submitted_on", None) or service_case.creation or ""),
            "expected_completion_date": str(getattr(service_case, "expected_completion_date", None) or ""),
            "description": service_case.description or "",
            "remarks": getattr(service_case, "remarks", None) or "",
            "required_documents": required_documents,
            "submitted_documents": submitted_documents,
            "missing_documents": missing_documents,
            "timeline": timeline,
            "attachments": submitted_documents,
            "can_update_status": can_access_internal_workspace,
            "can_review_documents": can_access_internal_workspace,
            "can_view_internal_notes": can_access_internal_workspace,
        }
    }


@frappe.whitelist()
def add_service_case_comment(case_id=None, message=None):
    if not case_id:
        frappe.throw("case_id is required")

    if not message:
        frappe.throw("message is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    profile = _assert_approved_customer()
    doc = frappe.get_doc("OMC Service Request", case_id)

    if profile and doc.customer_profile and doc.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this service case", frappe.PermissionError)

    entry = _create_service_timeline_entry(
        service_request=doc.name,
        event_type="Customer Message",
        title="Customer Message",
        description=message,
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "name": entry.name,
        "case_id": doc.name,
        "created": True,
        "message": "Comment added.",
    }




ALLOWED_DOCUMENT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png", "doc", "docx"}
ALLOWED_PAYMENT_RECEIPT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png"}
MAX_DOCUMENT_SIZE_BYTES = 10 * 1024 * 1024
MAX_PAYMENT_RECEIPT_SIZE_BYTES = 10 * 1024 * 1024
MAX_FILES_PER_CASE = 20


def _clean_file_reference(value):
    text_value = (value or "").strip()
    if not text_value:
        return ""
    return text_value.split("?")[0].strip()


def _document_extension(value):
    file_name = _clean_file_reference(value).rsplit("/", 1)[-1]
    if "." not in file_name:
        return ""
    return file_name.rsplit(".", 1)[-1].strip().lower()


def _find_uploaded_file(attachment):
    clean_attachment = _clean_file_reference(attachment)
    if not clean_attachment:
        return None

    file_name = clean_attachment.rsplit("/", 1)[-1]
    filters = [
        {"file_url": clean_attachment},
        {"file_name": file_name},
    ]

    for file_filter in filters:
        file_name_value = frappe.db.exists("File", file_filter)
        if file_name_value:
            return frappe.get_doc("File", file_name_value)

    return None


def _assert_service_document_upload_allowed(service_case, attachment):
    clean_attachment = _clean_file_reference(attachment)
    if not clean_attachment:
        frappe.throw("attachment is required")

    extension = _document_extension(clean_attachment)
    if extension not in ALLOWED_DOCUMENT_EXTENSIONS:
        frappe.throw("Unsupported document type. Please upload PDF, JPG, PNG, DOC or DOCX files only.")

    existing_count = frappe.db.count(
        "OMC Service Document",
        {
            "service_request": service_case.name,
            "visible_to_customer": 1,
        },
    )
    if existing_count >= MAX_FILES_PER_CASE:
        frappe.throw("Maximum document limit reached for this service request.")

    uploaded_file = _find_uploaded_file(clean_attachment)
    if not uploaded_file:
        return clean_attachment

    file_extension = _document_extension(uploaded_file.file_name or uploaded_file.file_url or clean_attachment)
    if file_extension not in ALLOWED_DOCUMENT_EXTENSIONS:
        frappe.throw("Unsupported document type. Please upload PDF, JPG, PNG, DOC or DOCX files only.")

    file_size = int(uploaded_file.file_size or 0)
    if file_size <= 0:
        frappe.throw("Uploaded file is empty.")
    if file_size > MAX_DOCUMENT_SIZE_BYTES:
        frappe.throw("Document is too large. Maximum allowed size is 10 MB.")

    current_user = _current_user()
    if uploaded_file.owner and uploaded_file.owner != current_user:
        frappe.throw("You do not have permission to use this uploaded file.", frappe.PermissionError)

    if uploaded_file.attached_to_doctype and uploaded_file.attached_to_doctype != "OMC Service Request":
        frappe.throw("Uploaded file is attached to another document.", frappe.PermissionError)

    if uploaded_file.attached_to_name and uploaded_file.attached_to_name != service_case.name:
        frappe.throw("Uploaded file is attached to another service request.", frappe.PermissionError)

    if not uploaded_file.is_private:
        uploaded_file.is_private = 1
        uploaded_file.save(ignore_permissions=True)

    return uploaded_file.file_url or clean_attachment


def _assert_payment_receipt_upload_allowed(payment, receipt_attachment):
    clean_attachment = _clean_file_reference(receipt_attachment)
    if not clean_attachment:
        frappe.throw("receipt_attachment is required")

    extension = _document_extension(clean_attachment)
    if extension not in ALLOWED_PAYMENT_RECEIPT_EXTENSIONS:
        frappe.throw("Unsupported receipt type. Please upload PDF, JPG or PNG files only.")

    uploaded_file = _find_uploaded_file(clean_attachment)
    if not uploaded_file:
        return clean_attachment

    file_extension = _document_extension(uploaded_file.file_name or uploaded_file.file_url or clean_attachment)
    if file_extension not in ALLOWED_PAYMENT_RECEIPT_EXTENSIONS:
        frappe.throw("Unsupported receipt type. Please upload PDF, JPG or PNG files only.")

    file_size = int(uploaded_file.file_size or 0)
    if file_size <= 0:
        frappe.throw("Uploaded receipt is empty.")
    if file_size > MAX_PAYMENT_RECEIPT_SIZE_BYTES:
        frappe.throw("Receipt is too large. Maximum allowed size is 10 MB.")

    current_user = _current_user()
    if uploaded_file.owner and uploaded_file.owner != current_user:
        frappe.throw("You do not have permission to use this uploaded receipt.", frappe.PermissionError)

    allowed_doctypes = {"", "OMC Service Payment"}
    if uploaded_file.attached_to_doctype and uploaded_file.attached_to_doctype not in allowed_doctypes:
        frappe.throw("Uploaded receipt is attached to another document.", frappe.PermissionError)

    if uploaded_file.attached_to_name and uploaded_file.attached_to_name != payment.name:
        frappe.throw("Uploaded receipt is attached to another payment record.", frappe.PermissionError)

    if not uploaded_file.is_private:
        uploaded_file.is_private = 1
        uploaded_file.save(ignore_permissions=True)

    if uploaded_file.attached_to_doctype != "OMC Service Payment" or uploaded_file.attached_to_name != payment.name:
        uploaded_file.attached_to_doctype = "OMC Service Payment"
        uploaded_file.attached_to_name = payment.name
        uploaded_file.save(ignore_permissions=True)

    return uploaded_file.file_url or clean_attachment

@frappe.whitelist()
def upload_service_document(**kwargs):
    case_id = kwargs.get("case_id") or kwargs.get("service_request")
    document_title = (kwargs.get("document_title") or kwargs.get("title") or "").strip()
    document_type = (kwargs.get("document_type") or kwargs.get("type") or "General").strip()
    attachment = kwargs.get("attachment") or kwargs.get("file_url") or kwargs.get("file")
    remarks = kwargs.get("remarks") or ""

    if not case_id:
        frappe.throw("case_id is required")

    if not document_title:
        frappe.throw("document_title is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service request not found", frappe.DoesNotExistError)

    service_case = frappe.get_doc("OMC Service Request", case_id)
    profile = _assert_approved_customer()

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to upload documents for this service request", frappe.PermissionError)

    attachment = _assert_service_document_upload_allowed(service_case, attachment)

    doc = frappe.new_doc("OMC Service Document")
    doc.service_request = service_case.name
    doc.document_title = document_title
    doc.document_type = document_type
    doc.attachment = attachment
    doc.status = "Uploaded"
    doc.visible_to_customer = 1
    doc.uploaded_by = _current_user()
    doc.uploaded_on = frappe.utils.now_datetime()
    doc.remarks = remarks
    doc.insert(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Document Uploaded",
        title="Document Uploaded",
        description=remarks or f"{document_title} uploaded by customer.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "uploaded": True,
        "document": {
            "name": doc.name,
            "case_id": doc.service_request,
            "title": doc.document_title or "",
            "document_title": doc.document_title or "",
            "type": doc.document_type or "",
            "document_type": doc.document_type or "",
            "status": doc.status or "",
            "file_url": doc.attachment or "",
            "attachment": doc.attachment or "",
            "uploaded_on": str(doc.uploaded_on) if doc.uploaded_on else "",
            "uploaded_by": doc.uploaded_by or "",
            "remarks": doc.remarks or "",
        },
    }


@frappe.whitelist()
def update_service_document_status(document_id=None, status=None, remarks=None):
    require_omc_staff(DOCUMENT_REVIEW_ROLES, "You do not have permission to review service documents.")

    if not document_id:
        frappe.throw("document_id is required")

    if not status:
        frappe.throw("status is required")

    allowed_statuses = ["Pending", "Uploaded", "Approved", "Rejected"]

    if status not in allowed_statuses:
        frappe.throw("Invalid document status")

    if not frappe.db.exists("OMC Service Document", document_id):
        frappe.throw("Service document not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Document", document_id)
    old_status = doc.status or ""

    doc.status = status

    if remarks is not None:
        doc.remarks = remarks or ""

    doc.save(ignore_permissions=True)

    if old_status != status:
        timeline_title = f"Document {status}"
        timeline_description = remarks or f"{doc.document_title or 'Document'} marked as {status}."

        _create_service_timeline_entry(
            service_request=doc.service_request,
            event_type="Document Uploaded" if status == "Uploaded" else "Update",
            title=timeline_title,
            description=timeline_description,
            visible_to_customer=1,
        )
    elif remarks:
        _create_service_timeline_entry(
            service_request=doc.service_request,
            event_type="Update",
            title="Document Updated",
            description=remarks,
            visible_to_customer=1,
        )

    frappe.db.commit()

    return {
        "name": doc.name,
        "case_id": doc.service_request,
        "status": doc.status,
        "updated": True,
        "message": "Service document updated.",
    }



@frappe.whitelist()
def get_documents():
    profile = None if _can_access_internal_workspace() else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)

    service_filters = {}
    if profile:
        service_filters["customer_profile"] = profile.name

    service_request_names = [
        row.name
        for row in frappe.get_all(
            "OMC Service Request",
            filters=service_filters,
            fields=["name"],
        )
    ]

    if not service_request_names:
        return {"documents": []}

    docs = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": ["in", service_request_names],
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "service_request",
            "document_title",
            "document_type",
            "attachment",
            "status",
            "uploaded_on",
            "uploaded_by",
            "remarks",
        ],
        order_by="uploaded_on desc, creation desc",
    )

    return {
        "documents": [
            {
                "name": doc.name,
                "case_id": doc.service_request,
                "title": doc.document_title or "",
                "type": doc.document_type or "",
                "status": doc.status or "",
                "file_url": doc.attachment or "",
                "created_at": str(doc.uploaded_on) if doc.uploaded_on else "",
                "uploaded_by": doc.uploaded_by or "",
                "remarks": doc.remarks or "",
                "can_review_documents": capabilities["can_review_documents"],
            }
            for doc in docs
        ]
    }


@frappe.whitelist()
def get_document(document_id=None):
    if not document_id:
        frappe.throw("document_id is required")

    if not frappe.db.exists("OMC Service Document", document_id):
        frappe.throw("Document not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Document", document_id)

    if not doc.visible_to_customer:
        frappe.throw("Document not found", frappe.DoesNotExistError)

    profile = None if _can_access_internal_workspace() else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)
    service_case = frappe.get_doc("OMC Service Request", doc.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this document", frappe.PermissionError)

    return {
        "name": doc.name,
        "case_id": doc.service_request,
        "title": doc.document_title or "",
        "type": doc.document_type or "",
        "status": doc.status or "",
        "file_url": doc.attachment or "",
        "created_at": str(doc.uploaded_on) if doc.uploaded_on else "",
        "uploaded_by": doc.uploaded_by or "",
        "remarks": doc.remarks or "",
        "can_review_documents": capabilities["can_review_documents"],
    }


@frappe.whitelist()
def get_payments():
    profile = None if _can_access_internal_workspace() else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)

    service_filters = {}
    if profile:
        service_filters["customer_profile"] = profile.name

    service_request_names = [
        row.name
        for row in frappe.get_all(
            "OMC Service Request",
            filters=service_filters,
            fields=["name"],
        )
    ]

    if not service_request_names:
        return {"payments": []}

    payments = frappe.get_all(
        "OMC Service Payment",
        filters={
            "service_request": ["in", service_request_names],
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "service_request",
            "payment_title",
            "amount",
            "currency",
            "status",
            "due_date",
            "paid_on",
            "payment_reference",
            "receipt_attachment",
            "remarks",
        ],
        order_by="due_date desc, creation desc",
    )

    return {
        "payments": [
            {
                "name": payment.name,
                "case_id": payment.service_request,
                "title": payment.payment_title or "",
                "amount": payment.amount or 0,
                "currency": payment.currency or "PKR",
                "status": payment.status or "",
                "due_date": str(payment.due_date) if payment.due_date else "",
                "paid_on": str(payment.paid_on) if payment.paid_on else "",
                "payment_reference": payment.payment_reference or "",
                "receipt_url": payment.receipt_attachment or "",
                "remarks": payment.remarks or "",
                "can_review_payments": capabilities["can_review_payments"],
            }
            for payment in payments
        ]
    }


@frappe.whitelist()
def get_payment(payment_id=None):
    if not payment_id:
        frappe.throw("payment_id is required")

    if not frappe.db.exists("OMC Service Payment", payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc("OMC Service Payment", payment_id)

    if not payment.visible_to_customer:
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    profile = None if _can_access_internal_workspace() else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this payment", frappe.PermissionError)

    return {
        "name": payment.name,
        "case_id": payment.service_request,
        "title": payment.payment_title or "",
        "amount": payment.amount or 0,
        "currency": payment.currency or "PKR",
        "status": payment.status or "",
        "due_date": str(payment.due_date) if payment.due_date else "",
        "paid_on": str(payment.paid_on) if payment.paid_on else "",
        "payment_reference": payment.payment_reference or "",
        "receipt_url": payment.receipt_attachment or "",
        "remarks": payment.remarks or "",
        "can_review_payments": capabilities["can_review_payments"],
    }


@frappe.whitelist()
def upload_payment_receipt(**kwargs):
    payment_id = kwargs.get("payment_id")
    receipt_attachment = kwargs.get("receipt_attachment") or kwargs.get("receipt_url") or kwargs.get("file_url") or kwargs.get("file")
    payment_reference = kwargs.get("payment_reference") or kwargs.get("reference") or ""
    remarks = kwargs.get("remarks") or ""

    if not payment_id:
        frappe.throw("payment_id is required")

    if not receipt_attachment:
        frappe.throw("receipt_attachment is required")

    if not frappe.db.exists("OMC Service Payment", payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc("OMC Service Payment", payment_id)

    profile = _assert_approved_customer()
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this payment", frappe.PermissionError)

    receipt_attachment = _assert_payment_receipt_upload_allowed(payment, receipt_attachment)

    payment.receipt_attachment = receipt_attachment
    payment.payment_reference = payment_reference or payment.payment_reference
    payment.remarks = remarks or payment.remarks
    payment.status = "Receipt Submitted"
    payment.save(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title="Payment Receipt Submitted",
        description=remarks or f"Receipt submitted for {payment.payment_title or 'payment'} and is waiting for OMC review.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "updated": True,
        "name": payment.name,
        "case_id": payment.service_request,
        "status": payment.status,
        "receipt_url": payment.receipt_attachment or "",
        "payment_reference": payment.payment_reference or "",
        "remarks": payment.remarks or "",
    }



@frappe.whitelist()
def review_payment_receipt(payment_id=None, status=None, remarks=None, payment_reference=None):
    require_omc_staff(PAYMENT_REVIEW_ROLES, "You do not have permission to review payments.")

    if not payment_id:
        frappe.throw("payment_id is required")

    if not status:
        frappe.throw("status is required")

    allowed_statuses = ["Under Review", "Paid", "Rejected", "Cancelled"]
    if status not in allowed_statuses:
        frappe.throw("status must be one of: Under Review, Paid, Rejected, Cancelled")

    if not frappe.db.exists("OMC Service Payment", payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc("OMC Service Payment", payment_id)
    old_status = payment.status or ""

    if status in ["Paid", "Rejected"] and not payment.receipt_attachment:
        frappe.throw("A receipt must be uploaded before marking this payment as Paid or Rejected.")

    payment.status = status

    if payment_reference is not None:
        payment.payment_reference = payment_reference or ""

    if remarks is not None:
        payment.remarks = remarks or ""

    if status == "Paid":
        payment.paid_on = frappe.utils.now_datetime()
    elif status in ["Rejected", "Cancelled"]:
        payment.paid_on = None

    payment.save(ignore_permissions=True)

    timeline_title = f"Payment {status}"
    timeline_description = remarks or f"{payment.payment_title or 'Payment'} marked as {status}."

    _create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title=timeline_title,
        description=timeline_description,
        visible_to_customer=1,
    )

    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    _create_customer_notification(
        customer_profile=service_case.customer_profile,
        title=timeline_title,
        message=timeline_description,
        notification_type="Payment",
        reference_doctype="OMC Service Payment",
        reference_name=payment.name,
    )

    frappe.db.commit()

    return {
        "updated": True,
        "name": payment.name,
        "case_id": payment.service_request,
        "old_status": old_status,
        "status": payment.status,
        "paid_on": str(payment.paid_on) if payment.paid_on else "",
        "receipt_url": payment.receipt_attachment or "",
        "payment_reference": payment.payment_reference or "",
        "remarks": payment.remarks or "",
        "message": "Payment receipt reviewed.",
    }



def _knowledge_article_from_service(service):
    return {
        "id": service.name,
        "name": service.name,
        "title": service.title or "",
        "summary": service.description or "",
        "body": service.description or "",
        "content": service.description or "",
        "description": service.description or "",
        "category": service.category or "",
        "type": "Guide",
        "is_featured": int(service.is_featured or 0),
        "published_on": str(service.modified) if service.modified else "",
        "created_at": str(service.creation) if service.creation else "",
        "updated_at": str(service.modified) if service.modified else "",
        "source_doctype": "OMC Service",
    }


def _is_content_visible(record):
    starts_on = getattr(record, "starts_on", None)
    ends_on = getattr(record, "ends_on", None)
    now = frappe.utils.now_datetime()

    if starts_on and frappe.utils.get_datetime(starts_on) > now:
        return False
    if ends_on and frappe.utils.get_datetime(ends_on) < now:
        return False

    return True


def _safe_published_records(doctype, fields, order_by, limit=100):
    if not _has_doctype(doctype):
        return []

    try:
        rows = frappe.get_all(
            doctype,
            filters={"status": "Published"},
            fields=fields,
            order_by=order_by,
            limit_page_length=limit,
        )
    except Exception:
        frappe.log_error(frappe.get_traceback(), f"Mobile content lookup failed: {doctype}")
        return []

    return [row for row in rows if _is_content_visible(row)]


def _content_article_dict(record, id_field, content_type, summary_field="summary", body_field="content"):
    content_id = getattr(record, id_field, None) or record.name
    summary = getattr(record, summary_field, None) or getattr(record, "message", None) or ""
    body = getattr(record, body_field, None) or summary
    published_on = (
        getattr(record, "published_on", None)
        or getattr(record, "effective_date", None)
        or getattr(record, "starts_on", None)
        or getattr(record, "modified", None)
    )

    return {
        "id": content_id,
        "name": record.name,
        id_field: content_id,
        "title": getattr(record, "title", None) or "",
        "summary": summary,
        "description": summary,
        "body": body,
        "content": body,
        "category": getattr(record, "category", None) or getattr(record, "priority", None) or "",
        "type": content_type,
        "is_featured": int(getattr(record, "is_featured", None) or 0),
        "published_on": str(published_on) if published_on else "",
        "published_at_label": str(published_on) if published_on else "",
        "author": getattr(record, "owner", None) or "",
        "external_url": getattr(record, "mobile_route", None) or "",
        "image": getattr(record, "cover_image", None) or "",
        "created_at": str(record.creation) if getattr(record, "creation", None) else "",
        "updated_at": str(record.modified) if getattr(record, "modified", None) else "",
        "source_doctype": record.doctype if getattr(record, "doctype", None) else "",
    }


def _knowledge_content_articles():
    articles = []

    articles.extend(
        _content_article_dict(row, "article_id", "Guide")
        for row in _safe_published_records(
            "OMC Knowledge Article",
            [
                "name",
                "article_id",
                "title",
                "category",
                "summary",
                "content",
                "cover_image",
                "is_featured",
                "sort_order",
                "published_on",
                "owner",
                "creation",
                "modified",
            ],
            "is_featured desc, sort_order asc, published_on desc, modified desc",
        )
    )

    articles.extend(
        _content_article_dict(row, "alert_id", "Tax Update")
        for row in _safe_published_records(
            "OMC Tax Alert",
            [
                "name",
                "alert_id",
                "title",
                "category",
                "summary",
                "content",
                "effective_date",
                "is_featured",
                "sort_order",
                "published_on",
                "owner",
                "creation",
                "modified",
            ],
            "is_featured desc, sort_order asc, effective_date desc, modified desc",
        )
    )

    articles.extend(
        _content_article_dict(row, "announcement_id", "News", summary_field="message", body_field="message")
        for row in _safe_published_records(
            "OMC Announcement",
            [
                "name",
                "announcement_id",
                "title",
                "message",
                "priority",
                "mobile_route",
                "starts_on",
                "ends_on",
                "is_featured",
                "sort_order",
                "owner",
                "creation",
                "modified",
            ],
            "is_featured desc, sort_order asc, modified desc",
        )
    )

    articles.sort(
        key=lambda item: (
            int(item.get("is_featured") or 0),
            item.get("published_on") or item.get("updated_at") or "",
        ),
        reverse=True,
    )
    return articles


def _fallback_service_articles():
    services = frappe.get_all(
        "OMC Service",
        filters={"is_active": 1},
        fields=[
            "name",
            "title",
            "description",
            "category",
            "is_featured",
            "creation",
            "modified",
        ],
        order_by="is_featured desc, modified desc",
        limit_page_length=100,
    )

    return [_knowledge_article_from_service(service) for service in services]


@frappe.whitelist(allow_guest=True)
def get_knowledge():
    articles = _knowledge_content_articles()
    if not articles:
        articles = _fallback_service_articles()

    return {"articles": articles}


def _find_content_article(article_id):
    content_sources = [
        ("OMC Knowledge Article", "article_id", "Guide"),
        ("OMC Tax Alert", "alert_id", "Tax Update"),
        ("OMC Announcement", "announcement_id", "News"),
    ]

    for doctype, id_field, content_type in content_sources:
        if not _has_doctype(doctype):
            continue

        name = article_id if frappe.db.exists(doctype, article_id) else None
        if not name:
            matches = frappe.get_all(
                doctype,
                filters={id_field: article_id, "status": "Published"},
                fields=["name"],
                limit_page_length=1,
            )
            name = matches[0].name if matches else None

        if not name:
            continue

        record = frappe.get_doc(doctype, name)
        if record.status != "Published" or not _is_content_visible(record):
            continue

        if doctype == "OMC Announcement":
            return _content_article_dict(record, id_field, content_type, summary_field="message", body_field="message")
        return _content_article_dict(record, id_field, content_type)

    return None


@frappe.whitelist(allow_guest=True)
def get_knowledge_article(article_id=None, name=None):
    article_id = article_id or name
    if not article_id:
        frappe.throw("article_id is required")

    content_article = _find_content_article(article_id)
    if content_article:
        return {"article": content_article}

    if not frappe.db.exists("OMC Service", article_id):
        frappe.throw("Knowledge article not found", frappe.DoesNotExistError)

    service = frappe.get_doc("OMC Service", article_id)

    if not service.is_active:
        frappe.throw("Knowledge article not found", frappe.DoesNotExistError)

    return {"article": _knowledge_article_from_service(service)}


@frappe.whitelist(allow_guest=True)
def get_app_banners():
    banners = []

    for row in _safe_published_records(
        "OMC App Banner",
        [
            "name",
            "banner_id",
            "title",
            "subtitle",
            "image",
            "action_label",
            "mobile_route",
            "starts_on",
            "ends_on",
            "sort_order",
            "creation",
            "modified",
        ],
        "sort_order asc, modified desc",
        limit=20,
    ):
        banners.append(
            {
                "id": row.banner_id or row.name,
                "name": row.name,
                "title": row.title or "",
                "subtitle": row.subtitle or "",
                "image": row.image or "",
                "image_url": _public_file_url(row.image),
                "action_label": row.action_label or "",
                "mobile_route": row.mobile_route or "",
                "action_url": row.mobile_route or "",
                "starts_on": str(row.starts_on) if row.starts_on else "",
                "ends_on": str(row.ends_on) if row.ends_on else "",
            }
        )

    return {"banners": banners}


@frappe.whitelist(allow_guest=True)
def get_faqs(category=None):
    if not _has_doctype("OMC FAQ"):
        return {"faqs": []}

    filters = {"status": "Published"}
    if category:
        filters["category"] = category

    rows = frappe.get_all(
        "OMC FAQ",
        filters=filters,
        fields=[
            "name",
            "faq_id",
            "question",
            "answer",
            "category",
            "sort_order",
            "creation",
            "modified",
        ],
        order_by="sort_order asc, modified desc",
        limit_page_length=100,
    )

    return {
        "faqs": [
            {
                "id": row.faq_id or row.name,
                "name": row.name,
                "question": row.question or "",
                "answer": row.answer or "",
                "category": row.category or "",
                "updated_at": str(row.modified) if row.modified else "",
            }
            for row in rows
        ]
    }


def _notification_mobile_route(notification):
    saved_route = getattr(notification, "mobile_route", None) or ""
    if saved_route:
        return saved_route

    reference_doctype = (notification.reference_doctype or "").strip()
    reference_name = (notification.reference_name or "").strip()
    if not reference_doctype or not reference_name:
        return ""

    if reference_doctype == "OMC Service Request":
        return f"/my-services/{reference_name}"
    if reference_doctype == "OMC Service Document":
        return f"/documents/{reference_name}"
    if reference_doctype == "OMC Service Payment":
        return f"/payments/{reference_name}"
    if reference_doctype == "OMC Support Ticket":
        return f"/support-tickets/{reference_name}"

    return ""


@frappe.whitelist()
def get_notifications():
    user = _current_user()
    if user == "Guest":
        return {"notifications": []}

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    filters = {
        "visible_to_customer": 1,
    }

    if profile:
        filters["customer_profile"] = profile.name
    elif user and user != "Guest":
        filters["recipient_user"] = user
    else:
        return {"notifications": []}

    notification_fields = [
        "name",
        "title",
        "message",
        "notification_type",
        "reference_doctype",
        "reference_name",
        "is_read",
        "creation",
        "read_on",
    ]
    if _doctype_has_field("OMC Notification", "mobile_route"):
        notification_fields.append("mobile_route")

    notifications = frappe.get_all(
        "OMC Notification",
        filters=filters,
        fields=notification_fields,
        order_by="creation desc",
    )

    return {
        "notifications": [
            {
                "name": notification.name,
                "title": notification.title or "",
                "message": notification.message or "",
                "type": notification.notification_type or "",
                "reference_doctype": notification.reference_doctype or "",
                "reference_name": notification.reference_name or "",
                "mobile_route": _notification_mobile_route(notification),
                "action_url": _notification_mobile_route(notification),
                "is_read": int(notification.is_read or 0),
                "created_at": str(notification.creation) if notification.creation else "",
                "read_on": str(notification.read_on) if notification.read_on else "",
            }
            for notification in notifications
        ]
    }


@frappe.whitelist()
def mark_notification_read(notification_id=None, name=None):
    notification_id = notification_id or name
    if not notification_id:
        frappe.throw("notification_id is required")

    if not frappe.db.exists("OMC Notification", notification_id):
        frappe.throw("Notification not found", frappe.DoesNotExistError)

    notification = frappe.get_doc("OMC Notification", notification_id)

    if not notification.visible_to_customer:
        frappe.throw("Notification not found", frappe.DoesNotExistError)

    user = _current_user()
    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    if profile and notification.customer_profile and notification.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    if not profile and notification.recipient_user and notification.recipient_user != user:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    notification.is_read = 1
    notification.read_on = frappe.utils.now_datetime()
    notification.save(ignore_permissions=True)

    frappe.db.commit()

    return {
        "name": notification.name,
        "is_read": int(notification.is_read or 0),
        "read_on": str(notification.read_on) if notification.read_on else "",
        "message": "Notification marked as read.",
    }






@frappe.whitelist()
def register_push_token(**kwargs):
    user = _current_user()

    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    token = (kwargs.get("token") or kwargs.get("push_token") or kwargs.get("fcm_token") or "").strip()
    if not token:
        frappe.throw("token is required")

    platform = (kwargs.get("platform") or "unknown").strip().lower()
    if platform not in {"android", "ios", "web", "unknown"}:
        platform = "unknown"

    device_id = (kwargs.get("device_id") or "").strip()
    device_name = (kwargs.get("device_name") or "").strip()
    app_version = (kwargs.get("app_version") or "").strip()

    profile = _get_customer_profile_for_user(user)
    now = frappe.utils.now_datetime()

    existing_name = frappe.db.get_value("OMC Push Token", {"token": token}, "name")
    if existing_name:
        doc = frappe.get_doc("OMC Push Token", existing_name)
    else:
        doc = frappe.new_doc("OMC Push Token")
        doc.token = token

    doc.user = user
    doc.customer_profile = profile.name if profile else None
    doc.platform = platform
    doc.device_id = device_id
    doc.device_name = device_name
    doc.app_version = app_version
    doc.is_active = 1
    doc.last_registered_on = now
    doc.last_unregistered_on = None

    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)

    frappe.db.commit()

    return {
        "registered": True,
        "name": doc.name,
        "platform": doc.platform or "unknown",
        "is_active": int(doc.is_active or 0),
        "message": "Push token registered.",
    }


@frappe.whitelist()
def unregister_push_token(**kwargs):
    user = _current_user()

    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    token = (kwargs.get("token") or kwargs.get("push_token") or kwargs.get("fcm_token") or "").strip()
    device_id = (kwargs.get("device_id") or "").strip()

    if not token and not device_id:
        frappe.throw("token or device_id is required")

    filters = {"user": user}
    if token:
        filters["token"] = token
    elif device_id:
        filters["device_id"] = device_id

    token_names = frappe.get_all("OMC Push Token", filters=filters, pluck="name")
    now = frappe.utils.now_datetime()

    for token_name in token_names:
        doc = frappe.get_doc("OMC Push Token", token_name)
        doc.is_active = 0
        doc.last_unregistered_on = now
        doc.save(ignore_permissions=True)

    if token_names:
        frappe.db.commit()

    return {
        "unregistered": bool(token_names),
        "count": len(token_names),
        "message": "Push token unregistered." if token_names else "No matching push token found.",
    }


@frappe.whitelist()
def mark_all_notifications_read():
    user = _current_user()

    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    filters = {
        "visible_to_customer": 1,
        "is_read": 0,
    }

    if profile:
        filters["customer_profile"] = profile.name
    else:
        filters["recipient_user"] = user

    notification_names = frappe.get_all(
        "OMC Notification",
        filters=filters,
        pluck="name",
    )

    now = frappe.utils.now_datetime()

    for notification_name in notification_names:
        notification = frappe.get_doc("OMC Notification", notification_name)
        notification.is_read = 1
        notification.read_on = now
        notification.save(ignore_permissions=True)

    if notification_names:
        frappe.db.commit()

    return {
        "updated": bool(notification_names),
        "count": len(notification_names),
        "message": "All notifications marked as read.",
    }


@frappe.whitelist()
def get_notification_detail(notification_id=None):
    if not notification_id:
        frappe.throw("notification_id is required")

    if not frappe.db.exists("OMC Notification", notification_id):
        frappe.throw("Notification not found", frappe.DoesNotExistError)

    notification = frappe.get_doc("OMC Notification", notification_id)

    if not notification.visible_to_customer:
        frappe.throw("Notification not found", frappe.DoesNotExistError)

    user = _current_user()
    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    if profile and notification.customer_profile and notification.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    if not profile and notification.recipient_user and notification.recipient_user != user:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    if not notification.is_read:
        notification.is_read = 1
        notification.read_on = frappe.utils.now_datetime()
        notification.save(ignore_permissions=True)
        frappe.db.commit()

    return {
        "name": notification.name,
        "title": notification.title or "",
        "message": notification.message or "",
        "type": notification.notification_type or "",
        "reference_doctype": notification.reference_doctype or "",
        "reference_name": notification.reference_name or "",
        "mobile_route": _notification_mobile_route(notification),
        "action_url": _notification_mobile_route(notification),
        "is_read": int(notification.is_read or 0),
        "created_at": str(notification.creation) if notification.creation else "",
        "read_on": str(notification.read_on) if notification.read_on else "",
    }



def _create_customer_notification(
    customer_profile=None,
    recipient_user=None,
    title="",
    message="",
    notification_type="General",
    reference_doctype=None,
    reference_name=None,
):
    if not title:
        return None

    notification = frappe.new_doc("OMC Notification")
    notification.customer_profile = customer_profile or None
    notification.recipient_user = recipient_user or None
    notification.title = title
    notification.message = message or ""
    notification.notification_type = notification_type or "General"
    notification.reference_doctype = reference_doctype or None
    notification.reference_name = reference_name or None
    if notification.meta.has_field("mobile_route"):
        notification.mobile_route = _notification_mobile_route(notification)
    notification.is_read = 0
    notification.visible_to_customer = 1
    notification.insert(ignore_permissions=True)
    return notification




def _default_support_channels():
    return [
        {
            "channel_type": "whatsapp",
            "label": "WhatsApp support",
            "value": "923001234567",
            "subtitle": "Fastest option for service and document queries",
            "is_active": 1,
            "sort_order": 1,
        },
        {
            "channel_type": "phone",
            "label": "Call OMC",
            "value": "+923001234567",
            "subtitle": "Talk to OMC support during business hours",
            "is_active": 1,
            "sort_order": 2,
        },
        {
            "channel_type": "email",
            "label": "Email support",
            "value": "support@omchouse.com",
            "subtitle": "Send service, tax, document and payment queries",
            "is_active": 1,
            "sort_order": 3,
        },
    ]


def _default_support_topics():
    return [
        {
            "title": "Income Tax",
            "subtitle": "Returns, NTN, IRIS and filing help",
            "default_message": "Hello OMC, I need help with an income tax or IRIS matter.",
            "icon_key": "tax",
            "is_active": 1,
            "sort_order": 1,
        },
        {
            "title": "POS & Digital Invoicing",
            "subtitle": "POS setup, FBR integration and invoices",
            "default_message": "Hello OMC, I need help with POS or digital invoicing.",
            "icon_key": "pos",
            "is_active": 1,
            "sort_order": 2,
        },
        {
            "title": "Sales Tax",
            "subtitle": "GST registration and sales tax queries",
            "default_message": "Hello OMC, I need help with sales tax or GST registration.",
            "icon_key": "sales_tax",
            "is_active": 1,
            "sort_order": 3,
        },
        {
            "title": "Technical Support",
            "subtitle": "App, login, upload or tracking issues",
            "default_message": "Hello OMC, I need technical support for the mobile app.",
            "icon_key": "technical",
            "is_active": 1,
            "sort_order": 4,
        },
        {
            "title": "Payment Support",
            "subtitle": "Invoices, receipts and payment follow-up",
            "default_message": "Hello OMC, I need help with payment or invoice status.",
            "icon_key": "payment",
            "is_active": 1,
            "sort_order": 5,
        },
    ]


def _support_channel_to_dict(row):
    return {
        "name": row.name,
        "channel_type": row.channel_type or "",
        "label": row.label or "",
        "value": row.value or "",
        "subtitle": getattr(row, "subtitle", None) or "",
        "is_active": int(row.is_active or 0),
        "sort_order": row.sort_order or 0,
    }


def _support_topic_to_dict(row):
    return {
        "name": row.name,
        "title": row.title or "",
        "subtitle": row.subtitle or "",
        "default_message": row.default_message or "",
        "icon_key": row.icon_key or "",
        "is_active": int(row.is_active or 0),
        "sort_order": row.sort_order or 0,
    }


def _get_single_settings(doctype):
    if not _has_doctype(doctype):
        return None

    try:
        return frappe.get_single(doctype)
    except Exception:
        return None


def _settings_bool(doc, fieldname, default=False):
    if not doc or not doc.meta.has_field(fieldname):
        return default

    # Frappe Single DocTypes can return Check fields as 0 before a row exists in
    # tabSingles. Use code defaults until an admin explicitly saves the field.
    try:
        has_saved_value = frappe.db.exists(
            "Singles",
            {"doctype": doc.doctype, "field": fieldname},
        )
    except Exception:
        has_saved_value = True

    if not has_saved_value:
        return default

    value = doc.get(fieldname)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on", "enabled"}

    if value is None:
        return default

    return bool(value)


def _settings_text(doc, fieldname, default=""):
    if not doc or not doc.meta.has_field(fieldname):
        return default

    value = doc.get(fieldname)
    text = str(value).strip() if value is not None else ""
    return text or default


def _public_file_url(value):
    text = (value or "").strip()
    if not text:
        return ""

    if text.startswith(("http://", "https://")):
        return text

    if text.startswith(("/files/", "/private/files/", "/assets/")):
        return frappe.utils.get_url(text)

    return text




@frappe.whitelist(allow_guest=True)
def get_mobile_app_config():
    """Return safe backend-driven mobile app configuration.

    Keep this API lightweight and public-safe. Do not expose internal secrets,
    backend URLs, credentials, or staff-only implementation details here.
    """

    support_config = get_support_config()
    mobile_settings = _get_single_settings("OMC Mobile Settings")
    branding_settings = _get_single_settings("OMC Branding Settings")
    branding_enabled = _settings_bool(branding_settings, "enabled", True)

    payments_enabled = _settings_bool(mobile_settings, "payments_enabled", True)
    support_enabled = _settings_bool(mobile_settings, "support_enabled", True)

    return {
        "support": {
            "channels": support_config.get("channels", []),
            "topics": support_config.get("topics", []),
            "business_hours": support_config.get("business_hours", ""),
            "office_address": support_config.get("office_address", ""),
            "whatsapp_message": support_config.get("whatsapp_message", ""),
            "fallback": bool(support_config.get("fallback")),
        },
        "features": {
            "expense_tracker_enabled": _settings_bool(mobile_settings, "expense_tracker_enabled", True),
            "knowledge_enabled": _settings_bool(mobile_settings, "knowledge_enabled", True),
            "payments_enabled": payments_enabled,
            "tax_calculator_enabled": _settings_bool(mobile_settings, "tax_calculator_enabled", True),
            "support_enabled": support_enabled,
            "guest_mode_enabled": _settings_bool(mobile_settings, "guest_mode_enabled", True),
            "subscriptions_enabled": _settings_bool(mobile_settings, "subscriptions_enabled", False),
            "internal_workspace_enabled": _settings_bool(mobile_settings, "internal_workspace_enabled", False),
            "payment_gateway_enabled": _settings_bool(mobile_settings, "payment_gateway_enabled", False),
        },
        "branding": {
            "company_name": _settings_text(branding_settings, "brand_name", "OMC House") if branding_enabled else "OMC House",
            "tagline": _settings_text(branding_settings, "tagline", "Business, tax and compliance support") if branding_enabled else "Business, tax and compliance support",
            "full_logo": _settings_text(branding_settings, "full_logo"),
            "logo_symbol": _settings_text(branding_settings, "logo_symbol"),
            "login_logo": _settings_text(branding_settings, "login_logo"),
        },
        "legal": {
            "privacy_policy_url": _settings_text(mobile_settings, "privacy_policy_url"),
            "privacy_policy_text": _settings_text(
                mobile_settings,
                "privacy_policy_text",
                "OMC uses customer information to manage service requests, documents, support, notifications and account access.",
            ),
            "terms_url": _settings_text(mobile_settings, "terms_url"),
            "terms_text": _settings_text(
                mobile_settings,
                "terms_text",
                "OMC services are subject to review, approval, document verification and applicable compliance requirements.",
            ),
        },
        "meta": {
            "source": "backend",
            "fallback": bool(support_config.get("fallback")),
            "minimum_app_version": _settings_text(mobile_settings, "minimum_app_version"),
            "force_update": _settings_bool(mobile_settings, "force_update", False),
            "maintenance_mode": _settings_bool(mobile_settings, "maintenance_mode", False),
        },
    }


@frappe.whitelist(allow_guest=True)
def get_support_config():
    channels = []
    topics = []

    if _has_doctype("OMC Support Channel"):
        channels = [
            _support_channel_to_dict(row)
            for row in frappe.get_all(
                "OMC Support Channel",
                filters={"is_active": 1},
                fields=[
                    "name",
                    "channel_type",
                    "label",
                    "value",
                    "is_active",
                    "sort_order",
                ],
                order_by="sort_order asc, creation asc",
            )
        ]

    if _has_doctype("OMC Support Topic"):
        topics = [
            _support_topic_to_dict(row)
            for row in frappe.get_all(
                "OMC Support Topic",
                filters={"is_active": 1},
                fields=[
                    "name",
                    "title",
                    "subtitle",
                    "default_message",
                    "icon_key",
                    "is_active",
                    "sort_order",
                ],
                order_by="sort_order asc, creation asc",
            )
        ]

    used_fallback = False
    if not channels:
        channels = _default_support_channels()
        used_fallback = True

    if not topics:
        topics = _default_support_topics()
        used_fallback = True

    return {
        "channels": channels,
        "topics": topics,
        "business_hours": "Monday to Saturday, 10:00 AM - 6:00 PM",
        "office_address": "OMC House, Pakistan",
        "whatsapp_message": "Hello OMC, I need help with my service request.",
        "fallback": used_fallback,
    }


@frappe.whitelist()
def create_support_ticket(**kwargs):
    subject = (kwargs.get("subject") or kwargs.get("title") or "").strip()
    message = (kwargs.get("message") or kwargs.get("description") or "").strip()

    if not subject:
        frappe.throw("subject is required")

    if not message:
        frappe.throw("message is required")

    user = _current_user()
    profile = _assert_approved_customer()

    reference_service_request = (
        kwargs.get("reference_service_request")
        or kwargs.get("service_request")
        or kwargs.get("case_id")
    )

    if reference_service_request:
        if not frappe.db.exists("OMC Service Request", reference_service_request):
            frappe.throw("Reference service request not found", frappe.DoesNotExistError)

        if profile:
            request_customer = frappe.db.get_value(
                "OMC Service Request",
                reference_service_request,
                "customer_profile",
            )
            if request_customer and request_customer != profile.name:
                frappe.throw(
                    "You do not have permission to reference this service request",
                    frappe.PermissionError,
                )

    ticket = frappe.new_doc("OMC Support Ticket")
    ticket.subject = subject
    ticket.message = message
    ticket.status = "Open"
    ticket.priority = kwargs.get("priority") or "Medium"
    ticket.customer_profile = profile.name if profile else None
    ticket.raised_by = user if user != "Guest" else None
    ticket.contact_email = kwargs.get("contact_email") or (profile.email if profile else "")
    ticket.contact_phone = kwargs.get("contact_phone") or (profile.phone if profile else "")
    ticket.reference_service_request = reference_service_request or None
    ticket.insert(ignore_permissions=True)
    frappe.db.commit()

    return {
        "message": "Support ticket created.",
        "created": True,
        "ticket": {
            "name": ticket.name,
            "subject": ticket.subject or "",
            "status": ticket.status or "",
            "priority": ticket.priority or "",
            "reference_service_request": ticket.reference_service_request or "",
            "raised_on": str(ticket.raised_on) if ticket.raised_on else "",
        },
    }



def _support_ticket_messages(ticket):
    raw_message = ticket.message or ""
    messages = []

    if not raw_message:
        return messages

    reply_marker = "\n\n--- Reply from "
    parts = raw_message.split(reply_marker)

    initial_message = parts[0].strip()
    if initial_message:
        messages.append(
            {
                "author": ticket.raised_by or "Customer",
                "message": initial_message,
                "created_at": str(ticket.creation) if ticket.creation else "",
                "type": "initial",
            }
        )

    for raw_reply in parts[1:]:
        header, separator, body = raw_reply.partition(" ---\n")
        if not separator:
            continue

        author = header
        created_at = ""

        if " at " in header:
            author, created_at = header.rsplit(" at ", 1)

        messages.append(
            {
                "author": author.strip() or "Customer",
                "message": body.strip(),
                "created_at": created_at.strip(),
                "type": "reply",
            }
        )

    return messages


def _support_ticket_to_dict(ticket):
    import re

    raw_message = ticket.message or ""
    raw_message = re.sub(r"--- Reply from\s*", "--- Reply from ", raw_message)
    raw_message = re.sub(r"\s+at\s*(\d{4}-\d{2}-\d{2})", r" at \1", raw_message)
    messages = _support_ticket_messages(ticket)
    capabilities = _get_mobile_capabilities()

    return {
        "name": ticket.name,
        "subject": ticket.subject or "",
        "message": raw_message,
        "messages": messages,
        "status": ticket.status or "",
        "priority": ticket.priority or "",
        "customer_profile": ticket.customer_profile or "",
        "raised_by": ticket.raised_by or "",
        "contact_email": ticket.contact_email or "",
        "contact_phone": ticket.contact_phone or "",
        "reference_service_request": ticket.reference_service_request or "",
        "raised_on": str(ticket.raised_on) if ticket.raised_on else "",
        "closed_on": str(ticket.closed_on) if ticket.closed_on else "",
        "created_at": str(ticket.creation) if ticket.creation else "",
        "updated_at": str(ticket.modified) if ticket.modified else "",
        "can_update_status": capabilities["can_update_support_ticket_status"],
        "can_reply": ticket.status not in ["Closed", "Cancelled"],
    }



def _assert_support_ticket_access(ticket):
    user = _current_user()

    if user == "Guest":
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if _can_access_internal_workspace(user):
        return user, None

    profile = _assert_approved_customer()

    if profile and ticket.customer_profile and ticket.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if not profile and user != "Guest" and ticket.raised_by and ticket.raised_by != user:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    return user, profile


@frappe.whitelist()
def get_support_tickets():
    user = _current_user()
    if user == "Guest":
        return {"tickets": []}

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    filters = {}

    if profile:
        filters["customer_profile"] = profile.name
    elif _can_access_internal_workspace(user):
        filters = {}
    elif user != "Guest":
        filters["raised_by"] = user
    else:
        return {"tickets": []}

    tickets = frappe.get_all(
        "OMC Support Ticket",
        filters=filters,
        fields=[
            "name",
            "subject",
            "message",
            "status",
            "priority",
            "customer_profile",
            "raised_by",
            "contact_email",
            "contact_phone",
            "reference_service_request",
            "raised_on",
            "closed_on",
            "creation",
            "modified",
        ],
        order_by="modified desc",
        limit_page_length=50,
    )

    return {
        "tickets": [
            {
                "name": row.name,
                "subject": row.subject or "",
                "message": row.message or "",
                "status": row.status or "",
                "priority": row.priority or "",
                "customer_profile": row.customer_profile or "",
                "raised_by": row.raised_by or "",
                "contact_email": row.contact_email or "",
                "contact_phone": row.contact_phone or "",
                "reference_service_request": row.reference_service_request or "",
                "raised_on": str(row.raised_on) if row.raised_on else "",
                "closed_on": str(row.closed_on) if row.closed_on else "",
                "created_at": str(row.creation) if row.creation else "",
                "updated_at": str(row.modified) if row.modified else "",
                "can_update_status": _get_mobile_capabilities()["can_update_support_ticket_status"],
                "can_reply": row.status not in ["Closed", "Cancelled"],
            }
            for row in tickets
        ]
    }



@frappe.whitelist()
def get_support_ticket(ticket_id=None):
    if not ticket_id:
        frappe.throw("ticket_id is required")

    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    _assert_support_ticket_access(ticket)

    return {"ticket": _support_ticket_to_dict(ticket)}


def _get_customer_preferences(profile=None):
    profile = profile or _get_customer_profile_for_user()

    preference_name = frappe.db.get_value(
        "OMC Customer Preference",
        {"customer_profile": profile.name},
        "name",
    )

    if preference_name:
        return frappe.get_doc("OMC Customer Preference", preference_name)

    preferences = frappe.new_doc("OMC Customer Preference")
    preferences.customer_profile = profile.name
    preferences.service_updates_enabled = 1
    preferences.document_reminders_enabled = 1
    preferences.payment_alerts_enabled = 1
    preferences.tax_alerts_enabled = 1
    preferences.email_notifications_enabled = 1
    preferences.whatsapp_notifications_enabled = 1
    preferences.theme = "system"
    preferences.language = "en"
    preferences.insert(ignore_permissions=True)
    frappe.db.commit()

    return preferences


def _preference_bool(preferences, fieldname, fallback_fieldname=None, default=True):
    if preferences.meta.has_field(fieldname):
        return bool(preferences.get(fieldname))

    if fallback_fieldname and preferences.meta.has_field(fallback_fieldname):
        return bool(preferences.get(fallback_fieldname))

    return default


def _settings_preferences_to_dict(preferences):
    return {
        "service_updates_enabled": _preference_bool(preferences, "service_updates_enabled"),
        "document_reminders_enabled": _preference_bool(preferences, "document_reminders_enabled"),
        "payment_alerts_enabled": _preference_bool(preferences, "payment_alerts_enabled", "payment_reminders_enabled"),
        "tax_alerts_enabled": _preference_bool(preferences, "tax_alerts_enabled"),
        "email_notifications_enabled": _preference_bool(preferences, "email_notifications_enabled", "email_updates_enabled"),
        "whatsapp_notifications_enabled": _preference_bool(preferences, "whatsapp_notifications_enabled"),
        "theme": preferences.theme or "system",
        "language": preferences.language or "en",
    }





@frappe.whitelist()
def add_support_ticket_reply(ticket_id=None, message=None, **kwargs):
    ticket_id = ticket_id or kwargs.get("name")
    message = (message or kwargs.get("reply") or kwargs.get("description") or "").strip()

    if not ticket_id:
        frappe.throw("ticket_id is required")

    if not message:
        frappe.throw("message is required")

    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, _profile = _assert_support_ticket_access(ticket)

    if ticket.status in ["Closed", "Cancelled"]:
        frappe.throw("This support ticket is closed. Please reopen it before replying.")

    timestamp = frappe.utils.now_datetime()
    reply_text = f"\n\n--- Reply from {user} at {timestamp} ---\n{message}"

    ticket.message = (ticket.message or "").rstrip() + reply_text
    if ticket.status == "Resolved":
        ticket.status = "Open"
        ticket.closed_on = None

    ticket.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "updated": True,
        "ticket": _support_ticket_to_dict(ticket),
        "message": "Support reply added.",
    }



@frappe.whitelist()
def update_support_ticket_status(ticket_id=None, status=None, remarks=None):
    require_omc_staff(SUPPORT_STAFF_ROLES, "You do not have permission to update support tickets.")

    if not ticket_id:
        frappe.throw("ticket_id is required")

    if not status:
        frappe.throw("status is required")

    allowed_statuses = ["Open", "Waiting for Customer", "Resolved", "Closed", "Cancelled"]
    if status not in allowed_statuses:
        frappe.throw("status must be one of: Open, Waiting for Customer, Resolved, Closed, Cancelled")

    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    old_status = ticket.status or ""

    ticket.status = status
    if status in ["Resolved", "Closed", "Cancelled"]:
        ticket.closed_on = frappe.utils.now_datetime()
    else:
        ticket.closed_on = None

    if remarks:
        timestamp = frappe.utils.now_datetime()
        ticket.message = (ticket.message or "").rstrip() + f"\n\n--- Reply from OMC Support at {timestamp} ---\n{remarks}"

    ticket.save(ignore_permissions=True)

    if ticket.customer_profile:
        _create_customer_notification(
            customer_profile=ticket.customer_profile,
            title=f"Support Ticket {status}",
            message=remarks or f"Your support ticket '{ticket.subject or ticket.name}' is now {status}.",
            notification_type="Support",
            reference_doctype="OMC Support Ticket",
            reference_name=ticket.name,
        )

    frappe.db.commit()

    return {
        "updated": True,
        "old_status": old_status,
        "ticket": _support_ticket_to_dict(ticket),
        "message": "Support ticket status updated.",
    }


@frappe.whitelist()
def get_settings_preferences():
    profile = _get_customer_profile_for_user()
    preferences = _get_customer_preferences(profile)
    preference_data = _settings_preferences_to_dict(preferences)

    return {
        **preference_data,
        "preferences": preference_data,
    }


@frappe.whitelist()
def update_settings_preferences(**kwargs):
    profile = _get_customer_profile_for_user()
    preferences = _get_customer_preferences(profile)

    field_aliases = {
        "notifications_enabled": "service_updates_enabled",
        "push_notifications_enabled": "service_updates_enabled",
        "email_updates_enabled": "email_notifications_enabled",
        "payment_reminders_enabled": "payment_alerts_enabled",
    }

    for incoming_field, target_field in field_aliases.items():
        if incoming_field in kwargs and target_field not in kwargs:
            kwargs[target_field] = kwargs.get(incoming_field)

    allowed_check_fields = [
        "service_updates_enabled",
        "document_reminders_enabled",
        "payment_alerts_enabled",
        "tax_alerts_enabled",
        "email_notifications_enabled",
        "whatsapp_notifications_enabled",
    ]
    allowed_text_fields = ["language"]
    updated_fields = []

    for fieldname in allowed_check_fields:
        if fieldname not in kwargs:
            continue

        value = kwargs.get(fieldname)
        if isinstance(value, str):
            value = value.strip().lower() in ["1", "true", "yes", "on", "enabled"]

        value = 1 if value else 0

        if int(preferences.get(fieldname) or 0) != value:
            preferences.set(fieldname, value)
            updated_fields.append(fieldname)

    if "theme" in kwargs:
        theme = (kwargs.get("theme") or "system").strip().lower()
        if theme not in ["system", "light", "dark"]:
            frappe.throw("theme must be one of: system, light, dark")

        if preferences.theme != theme:
            preferences.theme = theme
            updated_fields.append("theme")

    for fieldname in allowed_text_fields:
        if fieldname not in kwargs:
            continue

        value = (kwargs.get(fieldname) or "").strip()
        if value and preferences.get(fieldname) != value:
            preferences.set(fieldname, value)
            updated_fields.append(fieldname)

    if updated_fields:
        preferences.save(ignore_permissions=True)
        frappe.db.commit()

    return {
        "message": "Settings preferences updated." if updated_fields else "No settings preferences changed.",
        "updated": bool(updated_fields),
        "updated_fields": updated_fields,
        "preferences": _settings_preferences_to_dict(preferences),
    }


@frappe.whitelist()
def get_internal_workspace_summary():
    _assert_internal_workspace_access()
    return {
        "leads": frappe.db.count("OMC Lead"),
        "customers": frappe.db.count("OMC Customer Profile"),
        "tasks": frappe.db.count(
            "OMC Task",
            {"status": ["not in", ["Completed", "Cancelled"]]},
        ),
        "open_services": frappe.db.count(
            "OMC Service Request",
            {"status": ["not in", ["Completed", "Cancelled"]]},
        ),
        "support_tickets": frappe.db.count(
            "OMC Support Ticket",
            {"status": ["not in", ["Resolved", "Closed", "Cancelled"]]},
        ),
        "documents": frappe.db.count("OMC Service Document"),
        "payments_due": frappe.db.count("OMC Service Payment", {"status": "Pending"}),
        "unread_notifications": frappe.db.count("OMC Notification", {"is_read": 0}),
    }


@frappe.whitelist()
def create_lead(**kwargs):
    _assert_internal_workspace_access()
    title = (kwargs.get("title") or kwargs.get("subject") or "").strip()
    lead_name = (kwargs.get("lead_name") or kwargs.get("name") or kwargs.get("full_name") or "").strip()
    company_name = (kwargs.get("company_name") or kwargs.get("company") or "").strip()
    email = (kwargs.get("email") or kwargs.get("email_id") or "").strip()
    phone = (kwargs.get("phone") or kwargs.get("mobile_no") or kwargs.get("mobile") or "").strip()
    source = (kwargs.get("source") or "Mobile App").strip()
    service_interest = (kwargs.get("service_interest") or kwargs.get("service") or "").strip()
    notes = (kwargs.get("notes") or kwargs.get("message") or kwargs.get("description") or "").strip()

    if not lead_name and not company_name and not title:
        frappe.throw("lead_name, company_name, or title is required")

    lead = frappe.new_doc("OMC Lead")
    lead.title = title or company_name or lead_name
    lead.lead_name = lead_name or title or company_name
    lead.company_name = company_name
    lead.email = email
    lead.phone = phone
    lead.status = kwargs.get("status") or "New"
    lead.source = source
    lead.service_interest = service_interest
    lead.notes = notes
    lead.insert(ignore_permissions=True)

    frappe.db.commit()

    return {
        "message": "Lead created.",
        "created": True,
        "lead": _lead_to_dict(lead),
    }


def _lead_to_dict(lead):
    return {
        "name": lead.name,
        "title": lead.title or "",
        "lead_name": lead.lead_name or "",
        "company_name": lead.company_name or "",
        "email": lead.email or "",
        "phone": lead.phone or "",
        "status": lead.status or "",
        "source": lead.source or "",
        "service_interest": lead.service_interest or "",
        "notes": lead.notes or "",
        "assigned_to": lead.assigned_to or "",
        "customer_profile": lead.customer_profile or "",
        "converted_customer_profile": lead.converted_customer_profile or "",
        "created_at": str(lead.creation) if lead.creation else "",
        "updated_at": str(lead.modified) if lead.modified else "",
    }


@frappe.whitelist()
def get_leads():
    _assert_internal_workspace_access()
    leads = frappe.get_all(
        "OMC Lead",
        fields=[
            "name",
            "title",
            "lead_name",
            "company_name",
            "email",
            "phone",
            "status",
            "source",
            "service_interest",
            "notes",
            "assigned_to",
            "customer_profile",
            "converted_customer_profile",
            "creation",
            "modified",
        ],
        order_by="modified desc",
        limit_page_length=100,
    )

    return {
        "leads": [
            {
                "name": row.name,
                "title": row.title or "",
                "lead_name": row.lead_name or "",
                "company_name": row.company_name or "",
                "email": row.email or "",
                "phone": row.phone or "",
                "status": row.status or "",
                "source": row.source or "",
                "service_interest": row.service_interest or "",
                "notes": row.notes or "",
                "assigned_to": row.assigned_to or "",
                "customer_profile": row.customer_profile or "",
                "converted_customer_profile": row.converted_customer_profile or "",
                "created_at": str(row.creation) if row.creation else "",
                "updated_at": str(row.modified) if row.modified else "",
            }
            for row in leads
        ]
    }


@frappe.whitelist()
def get_lead(lead_id=None):
    _assert_internal_workspace_access()
    if not lead_id:
        frappe.throw("lead_id is required")

    if not frappe.db.exists("OMC Lead", lead_id):
        frappe.throw("Lead not found", frappe.DoesNotExistError)

    lead = frappe.get_doc("OMC Lead", lead_id)
    return {"lead": _lead_to_dict(lead)}


def _customer_profile_to_dict(profile):
    return {
        "name": profile.name,
        "customer_id": profile.name,
        "customer_name": profile.full_name or "",
        "full_name": profile.full_name or "",
        "email": profile.email or "",
        "phone": profile.phone or "",
        "company_name": profile.company_name or "",
        "cnic": profile.cnic or "",
        "ntn": profile.ntn or "",
        "customer_status": profile.customer_status or "",
        "approval_status": profile.approval_status or "",
        "is_active": int(profile.is_active or 0),
        "linked_erpnext_customer": profile.linked_erpnext_customer or "",
        "created_at": str(profile.creation) if profile.creation else "",
        "updated_at": str(profile.modified) if profile.modified else "",
    }


@frappe.whitelist()
def get_customers():
    _assert_internal_workspace_access()
    customers = frappe.get_all(
        "OMC Customer Profile",
        fields=[
            "name",
            "full_name",
            "email",
            "phone",
            "company_name",
            "cnic",
            "ntn",
            "customer_status",
            "approval_status",
            "is_active",
            "linked_erpnext_customer",
            "creation",
            "modified",
        ],
        order_by="modified desc",
        limit_page_length=100,
    )

    return {
        "customers": [
            {
                "name": row.name,
                "customer_id": row.name,
                "customer_name": row.full_name or "",
                "full_name": row.full_name or "",
                "email": row.email or "",
                "phone": row.phone or "",
                "company_name": row.company_name or "",
                "cnic": row.cnic or "",
                "ntn": row.ntn or "",
                "customer_status": row.customer_status or "",
                "approval_status": row.approval_status or "",
                "is_active": int(row.is_active or 0),
                "linked_erpnext_customer": row.linked_erpnext_customer or "",
                "created_at": str(row.creation) if row.creation else "",
                "updated_at": str(row.modified) if row.modified else "",
            }
            for row in customers
        ]
    }


@frappe.whitelist()
def get_customer(customer_id=None):
    _assert_internal_workspace_access()
    if not customer_id:
        frappe.throw("customer_id is required")

    if not frappe.db.exists("OMC Customer Profile", customer_id):
        frappe.throw("Customer not found", frappe.DoesNotExistError)

    profile = frappe.get_doc("OMC Customer Profile", customer_id)
    return {"customer": _customer_profile_to_dict(profile)}


def _task_to_dict(task):
    return {
        "name": task.name,
        "title": task.title or "",
        "description": task.description or "",
        "status": task.status or "",
        "priority": task.priority or "",
        "due_date": str(task.due_date) if task.due_date else "",
        "assigned_to": task.assigned_to or "",
        "customer_profile": task.customer_profile or "",
        "service_request": task.service_request or "",
        "support_ticket": task.support_ticket or "",
        "completed_on": str(task.completed_on) if task.completed_on else "",
        "created_at": str(task.creation) if task.creation else "",
        "updated_at": str(task.modified) if task.modified else "",
    }


@frappe.whitelist()
def get_tasks():
    _assert_internal_workspace_access()
    tasks = frappe.get_all(
        "OMC Task",
        fields=[
            "name",
            "title",
            "description",
            "status",
            "priority",
            "due_date",
            "assigned_to",
            "customer_profile",
            "service_request",
            "support_ticket",
            "completed_on",
            "creation",
            "modified",
        ],
        order_by="modified desc",
        limit_page_length=100,
    )

    return {
        "tasks": [
            {
                "name": row.name,
                "title": row.title or "",
                "description": row.description or "",
                "status": row.status or "",
                "priority": row.priority or "",
                "due_date": str(row.due_date) if row.due_date else "",
                "assigned_to": row.assigned_to or "",
                "customer_profile": row.customer_profile or "",
                "service_request": row.service_request or "",
                "support_ticket": row.support_ticket or "",
                "completed_on": str(row.completed_on) if row.completed_on else "",
                "created_at": str(row.creation) if row.creation else "",
                "updated_at": str(row.modified) if row.modified else "",
            }
            for row in tasks
        ]
    }


@frappe.whitelist()
def get_task(task_id=None):
    _assert_internal_workspace_access()
    if not task_id:
        frappe.throw("task_id is required")

    if not frappe.db.exists("OMC Task", task_id):
        frappe.throw("Task not found", frappe.DoesNotExistError)

    task = frappe.get_doc("OMC Task", task_id)
    return {"task": _task_to_dict(task)}


@frappe.whitelist(allow_guest=True)
def calculate_tax(**kwargs):
    """Calculate a safe income-tax estimate for the mobile app.

    This endpoint intentionally returns the response shape expected by the
    Flutter app. It can later be replaced with configurable slab DocTypes
    without changing the mobile contract.
    """

    income_type = (kwargs.get("income_type") or "salary").strip().lower()
    monthly_income = _flt(kwargs.get("monthly_income"))
    yearly_income = _flt(kwargs.get("yearly_income")) or monthly_income * 12

    if monthly_income <= 0 and yearly_income > 0:
        monthly_income = yearly_income / 12

    if monthly_income <= 0 or yearly_income <= 0:
        frappe.throw("monthly_income or yearly_income is required")

    yearly_tax = _estimate_income_tax(yearly_income)
    monthly_tax = yearly_tax / 12
    monthly_after_tax = monthly_income - monthly_tax
    yearly_after_tax = yearly_income - yearly_tax
    effective_rate = (yearly_tax / yearly_income * 100) if yearly_income else 0

    return {
        "income_type": income_type,
        "monthly_income": round(monthly_income, 2),
        "yearly_income": round(yearly_income, 2),
        "monthly_tax": round(monthly_tax, 2),
        "yearly_tax": round(yearly_tax, 2),
        "monthly_after_tax": round(monthly_after_tax, 2),
        "yearly_after_tax": round(yearly_after_tax, 2),
        "taxable_income": round(yearly_income, 2),
        "tax": round(yearly_tax, 2),
        "effective_rate": round(effective_rate, 2),
        "breakdown": _income_tax_breakdown(yearly_income),
        "tax_year": kwargs.get("tax_year") or "estimate",
        "source": "backend_estimate",
        "calculation_source": "backend_estimate",
        "is_verified": False,
        "verified": False,
        "note": (
            "Estimate only — not for filing. OMC Tax Year and Tax Slab "
            "configuration is not enabled yet, so this result must be verified "
            "before filing."
        ),
    }


def _estimate_income_tax(yearly_income):
    yearly_income = _flt(yearly_income)

    if yearly_income <= 600000:
        return 0
    if yearly_income <= 1200000:
        return (yearly_income - 600000) * 0.05
    if yearly_income <= 2200000:
        return 30000 + ((yearly_income - 1200000) * 0.15)
    if yearly_income <= 3200000:
        return 180000 + ((yearly_income - 2200000) * 0.25)
    if yearly_income <= 4100000:
        return 430000 + ((yearly_income - 3200000) * 0.30)

    return 700000 + ((yearly_income - 4100000) * 0.35)


def _income_tax_breakdown(yearly_income):
    yearly_income = _flt(yearly_income)

    slabs = [
        {
            "from": 0,
            "to": 600000,
            "rate": 0,
            "tax": 0,
            "label": "Up to PKR 600,000",
        },
        {
            "from": 600000,
            "to": 1200000,
            "rate": 5,
            "tax": max(min(yearly_income, 1200000) - 600000, 0) * 0.05,
            "label": "PKR 600,001 to PKR 1,200,000",
        },
        {
            "from": 1200000,
            "to": 2200000,
            "rate": 15,
            "tax": max(min(yearly_income, 2200000) - 1200000, 0) * 0.15,
            "label": "PKR 1,200,001 to PKR 2,200,000",
        },
        {
            "from": 2200000,
            "to": 3200000,
            "rate": 25,
            "tax": max(min(yearly_income, 3200000) - 2200000, 0) * 0.25,
            "label": "PKR 2,200,001 to PKR 3,200,000",
        },
        {
            "from": 3200000,
            "to": 4100000,
            "rate": 30,
            "tax": max(min(yearly_income, 4100000) - 3200000, 0) * 0.30,
            "label": "PKR 3,200,001 to PKR 4,100,000",
        },
        {
            "from": 4100000,
            "to": None,
            "rate": 35,
            "tax": max(yearly_income - 4100000, 0) * 0.35,
            "label": "Above PKR 4,100,000",
        },
    ]

    visible_breakdown = []

    for slab in slabs:
        slab_to = slab["to"]
        is_active_slab = slab_to is None or yearly_income <= slab_to

        if slab["tax"] > 0 or is_active_slab:
            visible_breakdown.append(
                {
                    **slab,
                    "tax": round(slab["tax"], 2),
                }
            )

        if is_active_slab:
            break

    return visible_breakdown


def _flt(value):
    try:
        return float(str(value or 0).replace(",", "").strip())
    except Exception:
        return 0
