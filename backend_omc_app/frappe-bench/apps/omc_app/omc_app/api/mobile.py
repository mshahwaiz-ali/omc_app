import re

import frappe
from frappe.utils.file_manager import save_file

from omc_app.api import access, idempotency, referrals
from omc_app.setup.roles import LEGACY_ROLES


def _items_response(key, items=None):
    return {key: items or []}


def _message(message="OK", **extra):
    data = {"message": message}
    data.update(extra)
    return data


_ACCENT_FAMILY_FALLBACKS = {
    "navy": "#111827",
    "blue": "#2563EB",
    "teal": "#0F766E",
    "indigo": "#4F46E5",
    "slate": "#475569",
    "burgundy": "#881337",
    "omc_red": "#C81D32",
}


def _valid_hex_color(value):
    text = (value or "").strip().upper()
    if re.fullmatch(r"#[0-9A-F]{6}", text):
        return text
    return ""


def _resolved_accent_color(settings):
    custom = _valid_hex_color(getattr(settings, "accent_color", None))
    if custom:
        return custom

    family = (getattr(settings, "primary_color_family", None) or "navy").strip().lower()
    return _ACCENT_FAMILY_FALLBACKS.get(family, "#111827")


def _format_datetime(value):
    if not value:
        return ""
    try:
        return str(value).split(".")[0]
    except Exception:
        return str(value)


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


def _service_category_identity(service):
    category_id = (getattr(service, "category", None) or "").strip()
    if not category_id:
        return "", ""

    category_title = ""
    if _has_doctype("OMC Service Category"):
        category_title = (
            frappe.db.get_value("OMC Service Category", category_id, "title")
            or ""
        ).strip()

    if not category_title:
        category_title = category_id.replace("_", " ").replace("-", " ").strip().title()

    return category_id, category_title


def _service_to_catalogue_dict(service, include_required_documents=False):
    category_id, category_title = _service_category_identity(service)
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
        "category": category_title,
        "category_id": category_id,
        "categoryId": category_id,
        "icon": service.icon or "general_service",
        "color_family": getattr(service, "color_family", None) or "slate",
        "colorFamily": getattr(service, "color_family", None) or "slate",
        "estimated_duration": service.estimated_duration or "",
        "completion_time": _service_completion_time(service),
        "completionTime": _service_completion_time(service),
        "base_price": service.base_price or 0,
        "currency": service.currency or "PKR",
        "fee_label": _service_fee_label(service),
        "feeLabel": _service_fee_label(service),
        "government_fee_label": getattr(service, "government_fee_label", None) or "",
        "support_message": getattr(service, "support_message", None) or "",
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


def _normalize_signup_user(user_doc):
    if not user_doc:
        return

    existing_roles = {row.role for row in (user_doc.roles or [])}
    is_internal_account = bool(existing_roles.intersection(access.INTERNAL_ROLES))

    if (
        not is_internal_account
        and frappe.db.exists("Role", access.CUSTOMER_ROLE)
        and access.CUSTOMER_ROLE not in existing_roles
    ):
        user_doc.append("roles", {"role": access.CUSTOMER_ROLE})

    user_doc.roles = [
        row for row in (user_doc.roles or []) if row.role not in LEGACY_ROLES
    ]
    final_roles = {row.role for row in (user_doc.roles or [])}
    user_doc.user_type = (
        "System User"
        if final_roles.intersection(access.INTERNAL_ROLES)
        else "Website User"
    )
    user_doc.save(ignore_permissions=True)
    frappe.clear_cache(user=user_doc.name)


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


def _activate_verified_registration(**kwargs):
    """Create the account only after pending-registration token validation."""
    email = (kwargs.get("email") or kwargs.get("user") or "").strip().lower()
    password = kwargs.get("password") or kwargs.get("new_password")
    full_name = (kwargs.get("full_name") or kwargs.get("name") or "").strip()
    submitted_username = kwargs.get("username")
    if submitted_username:
        username = access.validate_username(submitted_username)
    else:
        username = access.suggest_username(
            full_name=full_name,
            email=email,
        )["username"]
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
    acquisition_source = (kwargs.get("acquisition_source") or "").strip()
    acquisition_source_detail = (kwargs.get("acquisition_source_detail") or "").strip()
    submitted_referral_code = (
        kwargs.get("referral_code")
        or kwargs.get("submitted_referral_code")
        or ""
    )
    consent_value = kwargs.get("referral_assistance_consent")
    if consent_value is None:
        consent_value = kwargs.get("referral_consent")
    referral_assistance_consent = str(consent_value or "").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    allowed_sources = {
        "",
        "Referral",
        "Website",
        "Social Media",
        "Advertisement",
        "Existing Customer",
        "Event",
        "Other",
    }
    if acquisition_source not in allowed_sources:
        frappe.throw("Invalid acquisition source.", frappe.ValidationError)

    if acquisition_source == "Other" and not acquisition_source_detail:
        frappe.throw(
            "Please specify how you heard about OMC.",
            frappe.ValidationError,
        )

    normalized_referral_code = referrals.normalize_referral_code(
        submitted_referral_code
    )
    if acquisition_source == "Referral":
        if not normalized_referral_code:
            frappe.throw("Referral code is required.", frappe.ValidationError)
        if not referral_assistance_consent:
            frappe.throw(
                "Referral assistance consent is required.",
                frappe.ValidationError,
            )
        if not referrals.resolve_active_referral(normalized_referral_code):
            frappe.throw(
                "Referral code is invalid or inactive.",
                frappe.ValidationError,
            )
    elif normalized_referral_code:
        frappe.throw(
            "Select Referral as the acquisition source to use a referral code.",
            frappe.ValidationError,
        )

    if not email:
        frappe.throw("email is required")

    if "@" not in email:
        frappe.throw("A valid email address is required")

    if not password:
        frappe.throw("A password is required")

    if len(password) < 8:
        frappe.throw("Password must be at least 8 characters long")

    existing_profile = (
        frappe.db.exists("OMC Customer Profile", {"user": email})
        or frappe.db.exists("OMC Customer Profile", {"email": email})
    )
    if access.username_exists(username):
        frappe.throw("Username is already taken.", frappe.DuplicateEntryError)

    if frappe.db.exists("User", email) or existing_profile:
        frappe.throw(
            "An account with this email already exists. Please sign in.",
            frappe.DuplicateEntryError,
        )

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

    _normalize_signup_user(user)

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
        if register_as.strip().lower() == "customer":
            profile.customer_status = "Active"
            profile.approval_status = "Approved"
        else:
            profile.customer_status = "Pending"
            profile.approval_status = "Pending Review"
        profile.is_active = 1
        profile_created = True

    profile.full_name = full_name or profile.full_name
    profile.email = email
    profile.user = email
    _set_if_has_field(profile, "username", username)
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
    _set_if_has_field(profile, "acquisition_source", acquisition_source)
    _set_if_has_field(
        profile,
        "acquisition_source_detail",
        acquisition_source_detail,
    )
    _set_if_has_field(profile, "customer_origin", "App Signup")
    _set_if_has_field(profile, "linked_app_user", email)

    if acquisition_source == "Referral":
        referrals.apply_referral_to_customer(
            profile,
            normalized_referral_code,
            consent_granted=referral_assistance_consent,
        )

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
            "username": profile.get("username") or "",
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
            "acquisition_source": profile.get("acquisition_source") or "",
            "acquisition_source_detail": (
                profile.get("acquisition_source_detail") or ""
            ),
            "referral_code_used": profile.get("referral_code_used") or "",
            "referral_assistance_consent": int(
                profile.get("referral_assistance_consent") or 0
            ),
        },
        "access_state": _customer_access_state(user=email, profile=profile),
        "capabilities": _get_mobile_capabilities(user=email, profile=profile),
        "preferences": _settings_preferences_to_dict(preferences),
    }


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    """Compatibility route; all public signups require email verification."""
    from omc_app.api import signup_policy

    return signup_policy.sign_up(**kwargs)


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


def _get_profile_image_url(profile=None, user=None):
    user = user or _current_user()
    profile_image = ""

    if profile:
        try:
            profile_image = profile.get("profile_image") or ""
        except Exception:
            profile_image = ""

    if not profile_image and user and user != "Guest":
        profile_image = frappe.db.get_value("User", user, "user_image") or ""

    return profile_image or ""


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
            "profile_image": "",
            "user_image": "",
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
        "avatar_url": _get_profile_image_url(profile, user),
        "profile_image": _get_profile_image_url(profile, user),
        "user_image": frappe.db.get_value("User", user, "user_image") or "",
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
def upload_profile_image():
    """Backward-compatible route for canonical profile image upload."""
    from omc_app.api import profile

    return profile.upload_profile_image()


@frappe.whitelist()
def update_profile(**kwargs):
    """Backward-compatible wrapper around the canonical secure profile API."""
    from omc_app.api import profile_self_service

    return profile_self_service.update_profile(**kwargs)


@frappe.whitelist()
def update_contact_info(**kwargs):
    """Preserve legacy aliases without bypassing protected profile fields."""
    from omc_app.api import profile_self_service

    alias_map = {
        "name": "full_name",
        "mobile": "phone",
        "company": "company_name",
    }
    payload = dict(kwargs or {})

    for alias, canonical in alias_map.items():
        if alias in payload and canonical not in payload:
            payload[canonical] = payload.pop(alias)

    return profile_self_service.update_profile(**payload)


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
            "color_family",
            "estimated_duration",
            "completion_time",
            "base_price",
            "currency",
            "fee_label",
            "government_fee_label",
            "support_message",
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
            "category_id": "",
            "categoryId": "",
            "icon": "general_service",
            "color_family": "slate",
            "colorFamily": "slate",
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
    event_type_aliases = {
        "": "Update",
        "update": "Update",
        "request created": "Request Created",
        "created": "Request Created",
        "status updated": "Status Updated",
        "status update": "Status Updated",
        "document uploaded": "Document Uploaded",
        "document upload": "Document Uploaded",
        "payment updated": "Payment Updated",
        "payment update": "Payment Updated",
        "payment": "Payment Updated",
        "internal note": "Internal Note",
        "assignment": "Internal Note",
        "assigned": "Internal Note",
        "customer message": "Customer Message",
        "message": "Customer Message",
    }
    normalized_event_type = event_type_aliases.get(
        str(event_type or "").strip().lower(),
        "Update",
    )

    entry = frappe.new_doc("OMC Service Timeline")
    entry.service_request = service_request
    entry.event_type = normalized_event_type
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
            "created_at": _format_datetime(entry.event_time),
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

    if doc.service and frappe.db.exists("OMC Service", doc.service):
        service_doc = frappe.get_doc("OMC Service", doc.service)
        original_price = frappe.utils.flt(service_doc.base_price or 0)
        pricing_values = {
            "original_price": original_price,
            "pricing_currency": service_doc.currency or "PKR",
            "discount_type": "",
            "discount_value": 0,
            "discount_amount": 0,
            "final_price": original_price,
            "discount_reason": "",
            "discount_applied_by": "",
        }
        for fieldname, value in pricing_values.items():
            if doc.meta.get_field(fieldname):
                doc.set(fieldname, value)

    doc.insert(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=doc.name,
        event_type="Request Created",
        title="Request Created",
        description="Your service request has been created successfully.",
        visible_to_customer=1,
    )

    _create_service_notification(
        doc,
        title="Request received",
        message=(
            f"Your {doc.title or doc.service_title or 'service'} request "
            f"{doc.name} has been received. OMC will review it shortly."
        ),
        notification_type="Service Update",
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
            "uploaded_at": _format_datetime(doc.uploaded_on),
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


def _document_match_identity(document):
    def clean(value):
        return " ".join(str(value or "").strip().lower().split())

    title = clean(
        document.get("title")
        or document.get("document_title")
    )
    document_type = clean(
        document.get("type")
        or document.get("document_type")
    )
    return title, document_type


def _required_documents_uploaded(
    required_document_templates,
    documents,
):
    """Return True when every required document has a real uploaded file.

    Document approval is intentionally NOT required here. This helper is used
    for payment readiness; document review remains a separate workflow.
    """
    required_templates = [
        template
        for template in required_document_templates or []
        if template.get("is_required")
    ]
    if not required_templates:
        return True

    uploaded_documents = [
        document
        for document in documents or []
        if bool(
            document.get("file_url")
            or document.get("attachment")
        )
        and str(document.get("status") or "").strip().lower()
        not in {"rejected", "cancelled", "archived"}
    ]

    unused_indexes = set(range(len(uploaded_documents)))

    for template in required_templates:
        template_identity = _document_match_identity(template)
        if not all(template_identity):
            return False

        matched_index = None
        for index in sorted(unused_indexes):
            if (
                _document_match_identity(uploaded_documents[index])
                == template_identity
            ):
                matched_index = index
                break

        if matched_index is None:
            return False

        unused_indexes.remove(matched_index)

    return True


def _required_documents_complete(
    required_document_templates,
    documents,
):
    required_templates = [
        template
        for template in required_document_templates or []
        if template.get("is_required")
    ]
    if not required_templates:
        return True

    approved_documents = [
        document
        for document in documents or []
        if (
            str(document.get("status") or "").strip().lower()
            == "approved"
        )
        and bool(
            document.get("file_url")
            or document.get("attachment")
        )
    ]

    unused_indexes = set(range(len(approved_documents)))

    for template in required_templates:
        template_identity = _document_match_identity(template)
        if not all(template_identity):
            return False

        matched_index = None
        for index in sorted(unused_indexes):
            if (
                _document_match_identity(
                    approved_documents[index]
                )
                == template_identity
            ):
                matched_index = index
                break

        if matched_index is None:
            return False

        unused_indexes.remove(matched_index)

    return True


def _service_case_payment_contract(
    service_case,
    *,
    documents,
    required_document_templates,
):
    # Payment becomes available once all required files are uploaded.
    # Approval/review is a separate operational workflow.
    documents_complete = _required_documents_uploaded(
        required_document_templates,
        documents,
    )

    payment_rows = frappe.get_all(
        "OMC Service Payment",
        filters={
            "service_request": service_case.name,
            "visible_to_customer": 1,
            "status": ["not in", ["Cancelled"]],
        },
        fields=[
            "name",
            "status",
            "amount",
            "currency",
            "receipt_attachment",
        ],
        order_by="creation desc",
        limit=1,
    )
    payment = payment_rows[0] if payment_rows else None
    payment_id = payment.name if payment else ""
    payment_status = (payment.status or "").strip() if payment else ""
    normalized_payment_status = payment_status.lower()

    normalized_case_status = (service_case.status or "").strip().lower()
    case_closed = normalized_case_status in {"completed", "cancelled"}

    locked_final_price = getattr(service_case, "final_price", None)
    service_amount = frappe.utils.flt(
        locked_final_price
        if locked_final_price is not None
        else 0
    )

    payment_eligible = (
        documents_complete
        and not case_closed
        and service_amount > 0
        and normalized_payment_status != "paid"
    )

    if case_closed:
        payment_block_reason = "case_closed"
        next_action = "view_case"
    elif not documents_complete:
        payment_block_reason = "required_documents_missing"
        next_action = "upload_documents"
    elif service_amount <= 0:
        payment_block_reason = "service_fee_not_configured"
        next_action = "contact_support"
    elif normalized_payment_status == "paid":
        payment_block_reason = "payment_completed"
        next_action = "service_processing"
    elif normalized_payment_status in {"receipt submitted", "under review"}:
        payment_block_reason = "receipt_under_review"
        next_action = "await_payment_review"
    elif normalized_payment_status == "rejected":
        payment_block_reason = "receipt_rejected"
        next_action = "resubmit_payment_receipt"
    elif payment_id:
        payment_block_reason = ""
        next_action = "complete_payment"
    else:
        payment_block_reason = "payment_not_opened"
        next_action = "await_payment_opening"

    return {
        "documents_complete": bool(documents_complete),
        "payment_eligible": bool(payment_eligible),
        "payment_id": payment_id,
        "payment_status": payment_status,
        "payment_block_reason": payment_block_reason,
        "next_action": next_action,
    }



def _service_case_scope_names(capabilities, user=None):
    user = user or _current_user()

    if capabilities.get("can_view_all_service_cases"):
        return None

    names = set()

    if capabilities.get("can_view_assigned_service_cases"):
        names.update(_assigned_record_names("OMC Service Request", user))

    if capabilities.get("can_view_relevant_service_cases"):
        if capabilities.get("can_view_support_tickets") and _has_doctype("OMC Support Ticket"):
            names.update(
                frappe.get_all(
                    "OMC Support Ticket",
                    filters={"reference_service_request": ["is", "set"]},
                    pluck="reference_service_request",
                )
            )

        if (
            capabilities.get("can_view_document_queue")
            or capabilities.get("can_view_document_summaries")
            or capabilities.get("can_review_documents")
        ) and _has_doctype("OMC Service Document"):
            names.update(
                frappe.get_all(
                    "OMC Service Document",
                    filters={"service_request": ["is", "set"]},
                    pluck="service_request",
                )
            )

        if (
            capabilities.get("can_view_payment_queue")
            or capabilities.get("can_view_payment_summaries")
            or capabilities.get("can_review_payments")
        ) and _has_doctype("OMC Service Payment"):
            names.update(
                frappe.get_all(
                    "OMC Service Payment",
                    filters={"service_request": ["is", "set"]},
                    pluck="service_request",
                )
            )

    return sorted(name for name in names if name)


def _require_service_case_read_scope(case_id=None):
    user = _assert_internal_workspace_access()
    capabilities = _canonical_capabilities()

    if not any(
        capabilities.get(name)
        for name in (
            "can_view_all_service_cases",
            "can_view_relevant_service_cases",
            "can_view_assigned_service_cases",
        )
    ):
        frappe.throw(
            "You do not have permission to view service cases.",
            frappe.PermissionError,
        )

    allowed_names = _service_case_scope_names(capabilities, user)
    if case_id and allowed_names is not None and case_id not in allowed_names:
        frappe.throw(
            "You do not have permission to access this service request.",
            frappe.PermissionError,
        )

    return user, capabilities, allowed_names


def _require_service_case_update_scope(case_id):
    user = _assert_internal_workspace_access()
    capabilities = _canonical_capabilities()

    if capabilities.get("can_update_service_status"):
        return user, capabilities

    if not capabilities.get("can_update_assigned_service_status"):
        frappe.throw(
            "You do not have permission to update service case status.",
            frappe.PermissionError,
        )

    assigned_names = set(_assigned_record_names("OMC Service Request", user))
    if case_id not in assigned_names:
        frappe.throw(
            "You may only update service requests assigned to you.",
            frappe.PermissionError,
        )

    return user, capabilities


@frappe.whitelist()
def get_service_cases(start=0, limit=50, limit_start=None, limit_page_length=None):
    start = _notification_page_value(
        limit_start if limit_start is not None else start,
        default=0,
        minimum=0,
        maximum=100000,
    )
    limit = _notification_page_value(
        limit_page_length if limit_page_length is not None else limit,
        default=50,
        minimum=1,
        maximum=100,
    )
    if _can_access_internal_workspace():
        profile = None
        capabilities = _canonical_capabilities()

        if capabilities.get("can_manage_customer_service_flow"):
            from omc_app.api import customer_service_access

            allowed_names = sorted(
                customer_service_access.accessible_assisted_service_request_names(
                    internal_capability="can_manage_customer_service_flow",
                )
            )
        else:
            _user, _capabilities, allowed_names = _require_service_case_read_scope()
    else:
        profile = _assert_approved_customer()
        allowed_names = None

    filters = {}
    if profile:
        filters["customer_profile"] = profile.name
    elif allowed_names is not None:
        filters["name"] = ["in", allowed_names or ["__no_service_requests__"]]

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
            "customer_mode",
            "submission_mode",
            "created_on_behalf",
            "creation",
            "modified",
            "expected_completion_date",
        ],
        order_by="modified desc",
        limit_start=start,
        limit_page_length=limit + 1,
    )

    has_more = len(cases) > limit
    cases = cases[:limit]

    items = [
            {
                "name": case.name,
                "title": case.title or case.service_title or "Service Request",
                "status": case.status or "",
                "priority": case.priority or "",
                "service": case.service_title or case.service or "",
                "description": case.description or "",
                "customer_mode": case.customer_mode or "",
                "submission_mode": case.submission_mode or "",
                "created_on_behalf": int(case.created_on_behalf or 0),
                "created_at": str(case.creation.date()) if case.creation else "",
                "updated_at": str(case.modified.date()) if case.modified else "",
                "expected_completion_date": str(case.expected_completion_date) if case.expected_completion_date else "",
            }
            for case in cases
        ]
    return {
        "items": items,
        "cases": items,
        "start": start,
        "limit": limit,
        "has_more": has_more,
        "next_start": start + limit if has_more else None,
    }




@frappe.whitelist()
def update_service_case_status(case_id=None, status=None, note=None, expected_completion_date=None):
    if not case_id:
        frappe.throw("case_id is required")

    _require_service_case_update_scope(case_id)

    if not status:
        frappe.throw("status is required")

    allowed_statuses = [
        "Open",
        "In Progress",
        "Waiting for Customer",
        "Waiting for Payment",
        "Completed",
        "Cancelled",
    ]

    if status not in allowed_statuses:
        frappe.throw("Invalid status")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Request", case_id)
    old_status = doc.status or ""

    from omc_app.api import workflow_contract

    try:
        workflow_contract.validate_service_transition(old_status, status)
    except ValueError as exc:
        frappe.throw(str(exc), frappe.ValidationError)

    if status == "Completed":
        from omc_app.api import workflow_automation

        blockers = workflow_automation.completion_blockers(doc)
        if blockers:
            frappe.throw(
                "Cannot complete this service request: " + " ".join(blockers),
                frappe.ValidationError,
            )

    doc.status = status

    if status == "Completed" and old_status != "Completed":
        from omc_app.api import workflow_automation

        workflow_automation.record_completion_attribution(
            doc,
            source="Mobile / Desk",
            actor=frappe.session.user,
        )

    if expected_completion_date is not None:
        doc.expected_completion_date = expected_completion_date or None

    if status in ["Completed", "Cancelled"] and not doc.closed_on:
        doc.closed_on = frappe.utils.now_datetime()

    if status not in ["Completed", "Cancelled"]:
        doc.closed_on = None

    doc.save(ignore_permissions=True)

    if old_status != status:
        description = note or f"Status changed from {old_status or 'Unknown'} to {status}."

        if status == "Completed":
            from omc_app.api import workflow_automation

            workflow_automation.finalize_completed_case(doc)

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

    if old_status != status:
        status_messages = {
            "Open": "Your service request is open and awaiting review.",
            "In Progress": "OMC has started working on your service request.",
            "Waiting for Customer": (
                "OMC needs information or action from you. "
                "Open the request to review the next step."
            ),
            "Waiting for Payment": (
                "A payment step is pending for your service request."
            ),
            "Completed": "Your service request has been completed.",
            "Cancelled": "Your service request has been cancelled.",
        }
        _create_service_notification(
            doc,
            title=f"Service status: {status}",
            message=note or status_messages.get(
                status,
                f"Your service request status changed to {status}.",
            ),
            notification_type="Service Update",
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
    if can_access_internal_workspace:
        capabilities = _canonical_capabilities()

        if capabilities.get("can_manage_customer_service_flow"):
            from omc_app.api import customer_service_access

            customer_service_access.assert_service_request_action(
                case_id,
                internal_capability="can_manage_customer_service_flow",
            )
        else:
            _require_service_case_read_scope(case_id)

        profile = None
    else:
        profile = _assert_approved_customer()

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
    payment_contract = _service_case_payment_contract(
        service_case,
        documents=documents,
        required_document_templates=required_document_templates,
    )

    return {
        "case": {
            "name": service_case.name,
            "service_id": service_case.service,
            "service_title": service_case.service_title or "",
            "status": service_case.status or "",
            "priority": service_case.priority or "",
            "customer_mode": service_case.customer_mode or "",
            "submission_mode": service_case.submission_mode or "",
            "created_on_behalf": int(service_case.created_on_behalf or 0),
            "progress": progress,
            "progress_percent": int(progress * 100),
            "current_stage": service_case.status or "",
            "next_step": _service_case_next_step(service_case.status, missing_documents),
            "customer_action_required": customer_action_required,
            **payment_contract,
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


def _save_base64_file(
    *,
    file_name,
    content_base64,
    is_private=1,
    attached_to_doctype=None,
    attached_to_name=None,
):
    import base64

    try:
        content = base64.b64decode(
            content_base64,
            validate=True,
        )
    except Exception:
        frappe.throw(
            "Invalid base64 file content.",
            frappe.ValidationError,
        )

    if not content:
        frappe.throw(
            "Uploaded file is empty.",
            frappe.ValidationError,
        )

    return save_file(
        file_name,
        content,
        attached_to_doctype,
        attached_to_name,
        is_private=is_private,
    )


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

    exact_name = frappe.db.exists(
        "File",
        {"file_url": clean_attachment},
    )
    if exact_name:
        return frappe.get_doc("File", exact_name)

    file_name = clean_attachment.rsplit("/", 1)[-1]
    matches = frappe.get_all(
        "File",
        filters={
            "file_name": file_name,
            "owner": _current_user(),
        },
        fields=["name"],
        order_by="creation desc",
        limit_page_length=2,
    )

    if len(matches) > 1:
        frappe.throw(
            "Uploaded file reference is ambiguous. Please upload the file again.",
            frappe.ValidationError,
        )

    if matches:
        return frappe.get_doc("File", matches[0].name)

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
    """Backward-compatible route for the canonical document upload API."""
    from omc_app.api import document_upload

    return document_upload.upload_service_document(**kwargs)


@frappe.whitelist()
def update_service_document_status(document_id=None, status=None, remarks=None):
    # Compatibility wrapper for the canonical document review endpoint.
    from omc_app.api import customer_documents

    old_status = ""
    document = None
    if document_id and frappe.db.exists("OMC Service Document", document_id):
        document = frappe.get_doc("OMC Service Document", document_id)
        old_status = (document.status or "").strip()

    result = customer_documents.update_service_document_status(
        document_id=document_id,
        status=status,
        remarks=remarks,
    )

    if document_id and frappe.db.exists("OMC Service Document", document_id):
        document = frappe.get_doc("OMC Service Document", document_id)
        new_status = (document.status or "").strip()
        if new_status and new_status != old_status:
            service_request = frappe.get_doc(
                "OMC Service Request",
                document.service_request,
            )
            document_title = (
                document.document_title
                or document.document_type
                or "Document"
            )
            normalized_status = new_status.lower()

            if normalized_status == "approved":
                title = "Document approved"
                message = f"{document_title} has been approved by OMC."
            elif normalized_status == "rejected":
                title = "Document needs correction"
                message = (
                    remarks
                    or document.remarks
                    or (
                        f"{document_title} was not approved. "
                        "Please upload a corrected document."
                    )
                )
            else:
                title = f"Document status: {new_status}"
                message = (
                    remarks
                    or document.remarks
                    or f"{document_title} status changed to {new_status}."
                )

            _create_service_notification(
                service_request,
                title=title,
                message=message,
                notification_type="Document Request",
                reference_doctype="OMC Service Document",
                reference_name=document.name,
            )
            frappe.db.commit()

    return result

@frappe.whitelist()
def get_documents():
    # Compatibility wrapper for canonical document reads.
    from omc_app.api import customer_documents

    return customer_documents.get_documents()

@frappe.whitelist()
def get_document(document_id=None):
    # Compatibility wrapper for canonical document detail reads.
    from omc_app.api import customer_documents

    return customer_documents.get_document(document_id=document_id)

@frappe.whitelist()
def get_payments():
    # Compatibility wrapper for canonical payment reads.
    from omc_app.api import payments

    return payments.get_payments()

@frappe.whitelist()
def get_payment(payment_id=None):
    # Compatibility wrapper for canonical payment detail reads.
    from omc_app.api import payments

    return payments.get_payment(payment_id=payment_id)

@frappe.whitelist()
def upload_payment_receipt(**kwargs):
    payment_id = kwargs.get("payment_id")
    receipt_attachment = (
        kwargs.get("receipt_attachment")
        or kwargs.get("receipt_url")
        or kwargs.get("file_url")
        or kwargs.get("file")
    )
    payment_reference = (
        kwargs.get("payment_reference")
        or kwargs.get("reference")
        or ""
    )
    remarks = kwargs.get("remarks") or ""

    if not payment_id:
        frappe.throw("payment_id is required")

    if not receipt_attachment:
        frappe.throw("receipt_attachment is required")

    if not frappe.db.exists("OMC Service Payment", payment_id):
        frappe.throw(
            "Payment not found",
            frappe.DoesNotExistError,
        )

    payment = frappe.get_doc(
        "OMC Service Payment",
        payment_id,
    )

    profile = _assert_approved_customer()
    service_case = frappe.get_doc(
        "OMC Service Request",
        payment.service_request,
    )

    if (
        profile
        and service_case.customer_profile
        and service_case.customer_profile != profile.name
    ):
        frappe.throw(
            "You do not have permission to update this payment",
            frappe.PermissionError,
        )

    from omc_app.api import payments

    payments._assert_payment_accepts_receipt(payment)

    receipt_attachment = _assert_payment_receipt_upload_allowed(
        payment,
        receipt_attachment,
    )

    capabilities = _get_mobile_capabilities()
    if not (
        capabilities.get("can_upload_payment_receipt")
        or capabilities.get("can_upload_payment_receipts")
    ):
        frappe.throw(
            "You do not have permission to upload payment receipts.",
            frappe.PermissionError,
        )

    clean_reference = payment_reference.strip()
    clean_remarks = remarks.strip()

    if payments._payment_receipt_submission_is_unchanged(
        payment,
        receipt_attachment=receipt_attachment,
        payment_reference=clean_reference,
        remarks=clean_remarks,
    ):
        return {
            "updated": False,
            "name": payment.name,
            "case_id": payment.service_request,
            "status": payment.status,
            "receipt_url": payment.receipt_attachment or "",
            "payment_reference": payment.payment_reference or "",
            "remarks": payment.remarks or "",
            "message": "No payment receipt change.",
        }

    payment.receipt_attachment = receipt_attachment
    payment.payment_reference = clean_reference
    payment.remarks = clean_remarks
    payment.status = "Receipt Submitted"
    payment.paid_on = None
    payment.save(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title="Payment Receipt Submitted",
        description=(
            clean_remarks
            or (
                f"Receipt submitted for "
                f"{payment.payment_title or 'payment'} "
                "and is waiting for OMC review."
            )
        ),
        visible_to_customer=1,
    )

    payments._set_case_status(service_case, "Waiting for Payment")
    payments._notify_payment_reviewers(
        service_case,
        title="Payment receipt submitted",
        message=(
            "A receipt has been submitted for "
            f"{payment.payment_title or payment.name}. "
            "Review it in the payment queue."
        ),
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
def review_payment_receipt(
    payment_id=None,
    status=None,
    remarks=None,
    payment_reference=None,
):
    # Compatibility wrapper for the canonical finance review endpoint.
    from omc_app.api import payments

    return payments.review_payment_receipt(
        payment_id=payment_id,
        status=status,
        remarks=remarks,
        payment_reference=payment_reference,
    )


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
        "published_on": _format_datetime(service.modified),
        "created_at": _format_datetime(service.creation),
        "updated_at": _format_datetime(service.modified),
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
        "published_on": _format_datetime(published_on),
        "published_at_label": _format_datetime(published_on),
        "author": getattr(record, "owner", None) or "",
        "external_url": getattr(record, "mobile_route", None) or "",
        "image": getattr(record, "cover_image", None) or "",
        "created_at": _format_datetime(getattr(record, "creation", None)),
        "updated_at": _format_datetime(getattr(record, "modified", None)),
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


@frappe.whitelist(allow_guest=True)
def get_knowledge():
    return {"articles": _knowledge_content_articles()}


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

    frappe.throw("Knowledge article not found", frappe.DoesNotExistError)


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
def get_onboarding_slides():
    slides = []

    if not _has_doctype("OMC Onboarding Slide"):
        return {"slides": slides}

    for row in frappe.get_all(
        "OMC Onboarding Slide",
        filters={"enabled": 1, "audience": ["in", ["Public", "All"]]},
        fields=[
            "name",
            "slide_id",
            "title",
            "subtitle",
            "description",
            "image",
            "icon_key",
            "accent_color",
            "benefits",
            "primary_cta_label",
            "primary_cta_route",
            "secondary_cta_label",
            "secondary_cta_route",
            "sort_order",
        ],
        order_by="sort_order asc, modified desc",
        limit_page_length=10,
    ):
        slides.append(
            {
                "id": row.slide_id or row.name,
                "name": row.name,
                "title": row.title or "",
                "subtitle": row.subtitle or "",
                "description": row.description or "",
                "image": row.image or "",
                "image_url": _public_file_url(row.image),
                "icon_key": row.icon_key or "",
                "accent_color": row.accent_color or "#C81D32",
                "benefits": row.benefits or "",
                "primary_cta_label": row.primary_cta_label or "",
                "primary_cta_route": row.primary_cta_route or "",
                "secondary_cta_label": row.secondary_cta_label or "",
                "secondary_cta_route": row.secondary_cta_route or "",
            }
        )

    return {"slides": slides}


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
    from omc_app.api.notification_events import validated_mobile_route

    saved_route = validated_mobile_route(
        getattr(notification, "mobile_route", None) or ""
    )
    reference_doctype = (notification.reference_doctype or "").strip()
    reference_name = (notification.reference_name or "").strip()

    supported_routes = {
        "OMC Service Request": "/my-services/{name}",
        "OMC Service Document": "/documents/{name}",
        "OMC Service Payment": "/payments/{name}",
        "OMC Support Ticket": "/support-tickets/{name}",
        "OMC Referral Commission": "/my-commissions/{name}",
        "Task": "/tasks/{name}",
    }

    if reference_doctype in supported_routes and reference_name:
        if not frappe.db.exists(reference_doctype, reference_name):
            return ""
        return saved_route or supported_routes[reference_doctype].format(
            name=reference_name
        )

    return saved_route


def _notification_page_value(value, *, default, minimum, maximum):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(parsed, maximum))


@frappe.whitelist()
def get_notifications(start=0, limit=50):
    start = _notification_page_value(
        start,
        default=0,
        minimum=0,
        maximum=100000,
    )
    limit = _notification_page_value(
        limit,
        default=50,
        minimum=1,
        maximum=100,
    )

    user = _current_user()
    if user == "Guest":
        return {
            "notifications": [],
            "start": start,
            "limit": limit,
            "has_more": False,
            "next_start": None,
        }

    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()

    filters = {
        "visible_to_customer": 1,
    }
    if _doctype_has_field("OMC Notification", "is_dismissed"):
        filters["is_dismissed"] = 0

    if profile:
        filters["customer_profile"] = profile.name
    elif user and user != "Guest":
        filters["recipient_user"] = user
    else:
        return {
            "notifications": [],
            "start": start,
            "limit": limit,
            "has_more": False,
            "next_start": None,
        }

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

    rows = frappe.get_all(
        "OMC Notification",
        filters=filters,
        fields=notification_fields,
        order_by="creation desc",
        limit_start=start,
        limit_page_length=limit + 1,
    )
    has_more = len(rows) > limit
    notifications = rows[:limit]

    items = []
    for notification in notifications:
        mobile_route = _notification_mobile_route(notification)
        items.append(
            {
                "name": notification.name,
                "title": notification.title or "",
                "message": notification.message or "",
                "type": notification.notification_type or "",
                "reference_doctype": notification.reference_doctype or "",
                "reference_name": notification.reference_name or "",
                "mobile_route": mobile_route,
                "action_url": mobile_route,
                "is_read": int(notification.is_read or 0),
                "created_at": _format_datetime(notification.creation),
                "read_on": str(notification.read_on) if notification.read_on else "",
            }
        )

    return {
        "notifications": items,
        "start": start,
        "limit": limit,
        "has_more": has_more,
        "next_start": start + limit if has_more else None,
    }



def _assert_notification_access(notification, user=None, profile=None):
    user = user or _current_user()
    if not user or user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    customer_profile = (getattr(notification, "customer_profile", None) or "").strip()
    recipient_user = (getattr(notification, "recipient_user", None) or "").strip()

    if profile:
        if customer_profile != profile.name:
            frappe.throw(
                "You do not have permission to access this notification",
                frappe.PermissionError,
            )
        return

    if recipient_user != user:
        frappe.throw(
            "You do not have permission to access this notification",
            frappe.PermissionError,
        )


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

    _assert_notification_access(
        notification,
        user=user,
        profile=profile,
    )

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







def _notification_for_current_user(notification_id=None, name=None):
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
    _assert_notification_access(notification, user=user, profile=profile)
    return notification


@frappe.whitelist()
def mark_notification_unread(notification_id=None, name=None):
    notification = _notification_for_current_user(notification_id, name)
    notification.is_read = 0
    notification.read_on = None
    notification.save(ignore_permissions=True)
    frappe.db.commit()
    return {"name": notification.name, "is_read": 0, "message": "Notification marked as unread."}


@frappe.whitelist()
def dismiss_notification(notification_id=None, name=None):
    notification = _notification_for_current_user(notification_id, name)
    if notification.meta.has_field("is_dismissed"):
        notification.is_dismissed = 1
    if notification.meta.has_field("dismissed_on"):
        notification.dismissed_on = frappe.utils.now_datetime()
    if not notification.is_read:
        notification.is_read = 1
        notification.read_on = frappe.utils.now_datetime()
    notification.save(ignore_permissions=True)
    frappe.db.commit()
    return {"name": notification.name, "dismissed": True, "message": "Notification cleared."}


@frappe.whitelist()
def restore_notification(notification_id=None, name=None):
    notification = _notification_for_current_user(notification_id, name)
    if notification.meta.has_field("is_dismissed"):
        notification.is_dismissed = 0
    if notification.meta.has_field("dismissed_on"):
        notification.dismissed_on = None
    notification.save(ignore_permissions=True)
    frappe.db.commit()
    return {"name": notification.name, "dismissed": False, "message": "Notification restored."}


@frappe.whitelist()
def get_unread_notification_count():
    user = _current_user()
    if user == "Guest":
        return {"count": 0}
    profile = None if _can_access_internal_workspace(user) else _assert_approved_customer()
    filters = {"visible_to_customer": 1, "is_read": 0}
    if _doctype_has_field("OMC Notification", "is_dismissed"):
        filters["is_dismissed"] = 0
    if profile:
        filters["customer_profile"] = profile.name
    else:
        filters["recipient_user"] = user
    return {"count": frappe.db.count("OMC Notification", filters)}


@frappe.whitelist()
def register_push_token(**kwargs):
    user = _current_user()

    if user == "Guest":
        frappe.throw("Login is required", frappe.PermissionError)

    token = (
        kwargs.get("token")
        or kwargs.get("push_token")
        or kwargs.get("fcm_token")
        or ""
    ).strip()
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

    # Prefer the canonical token record. FCM/APNs tokens can move between
    # authenticated users after logout/login on the same installation.
    existing_name = frappe.db.get_value(
        "OMC Push Token",
        {"token": token},
        "name",
    )

    # Token refresh commonly issues a new token for the same app installation.
    # Reuse that user's device record instead of creating duplicate active rows.
    if not existing_name and device_id:
        existing_name = frappe.db.get_value(
            "OMC Push Token",
            {
                "user": user,
                "device_id": device_id,
            },
            "name",
        )

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
    if _doctype_has_field("OMC Notification", "is_dismissed"):
        filters["is_dismissed"] = 0

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
        frappe.db.set_value(
            "OMC Notification",
            notification_name,
            {
                "is_read": 1,
                "read_on": now,
            },
            update_modified=False,
        )

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

    _assert_notification_access(
        notification,
        user=user,
        profile=profile,
    )

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
        "created_at": _format_datetime(notification.creation),
        "read_on": str(notification.read_on) if notification.read_on else "",
    }




# OMC automatic service notification engine
def _service_notification_recipient(service_request):
    if isinstance(service_request, str):
        if not frappe.db.exists("OMC Service Request", service_request):
            return None, None, None
        service_request = frappe.get_doc("OMC Service Request", service_request)

    customer_profile = (
        getattr(service_request, "customer_profile", None) or ""
    ).strip()
    recipient_user = (
        getattr(service_request, "requested_by", None) or ""
    ).strip()

    if customer_profile:
        recipient_user = ""

    return service_request, customer_profile or None, recipient_user or None


def cleanup_notifications():
    """Delete expired and old terminal notification rows in bounded batches."""
    now = frappe.utils.now_datetime()
    deleted = {"expired": 0, "dismissed": 0, "read": 0}

    policies = (
        ("expired", {"expires_on": ["<=", now]}),
        (
            "dismissed",
            {
                "is_dismissed": 1,
                "dismissed_on": [
                    "<=",
                    frappe.utils.add_to_date(now, days=-30),
                ],
            },
        ),
        (
            "read",
            {
                "is_read": 1,
                "read_on": [
                    "<=",
                    frappe.utils.add_to_date(now, days=-180),
                ],
            },
        ),
    )

    deleted_names = set()
    for key, filters in policies:
        names = frappe.get_all(
            "OMC Notification",
            filters=filters,
            pluck="name",
            limit_page_length=500,
        )
        for name in names:
            if name in deleted_names:
                continue
            frappe.delete_doc(
                "OMC Notification",
                name,
                ignore_permissions=True,
                force=True,
            )
            deleted_names.add(name)
            deleted[key] += 1

    if deleted_names:
        frappe.db.commit()

    deleted["total"] = len(deleted_names)
    return deleted

def _create_service_notification(
    service_request,
    *,
    title,
    message,
    notification_type="Service Update",
    reference_doctype="OMC Service Request",
    reference_name=None,
):
    service_request, customer_profile, recipient_user = (
        _service_notification_recipient(service_request)
    )
    if not service_request or not (customer_profile or recipient_user):
        return None

    clean_title = (title or "Service update").strip()
    clean_message = (
        message or "There is a new update on your service request."
    ).strip()
    resolved_reference = (
        reference_name
        or getattr(service_request, "name", None)
        or ""
    )

    filters = {
        "visible_to_customer": 1,
        "title": clean_title,
        "message": clean_message,
        "reference_doctype": reference_doctype,
        "reference_name": resolved_reference,
        "creation": [">=", frappe.utils.add_to_date(None, minutes=-10)],
    }
    if customer_profile:
        filters["customer_profile"] = customer_profile
    else:
        filters["recipient_user"] = recipient_user

    existing = frappe.db.exists("OMC Notification", filters)
    if existing:
        return frappe.get_doc("OMC Notification", existing)

    return _create_customer_notification(
        customer_profile=customer_profile,
        recipient_user=recipient_user,
        title=clean_title,
        message=clean_message,
        notification_type=notification_type,
        reference_doctype=reference_doctype,
        reference_name=resolved_reference,
    )


def _create_customer_notification(
    customer_profile=None,
    recipient_user=None,
    title="",
    message="",
    notification_type="General",
    reference_doctype=None,
    reference_name=None,
    mobile_route=None,
    event_key=None,
):
    if not title:
        return None

    notification_type_aliases = {
        "": "General",
        "general": "General",
        "service": "Service Request",
        "service request": "Service Request",
        "service update": "Service Request",
        "document": "Document",
        "document request": "Document",
        "payment": "Payment",
        "payment alert": "Payment",
        "support": "Support",
        "commission": "Commission",
    }
    normalized_notification_type = notification_type_aliases.get(
        str(notification_type or "").strip().lower(),
        "General",
    )

    dedupe_key = ""
    if event_key:
        recipient_key = customer_profile or recipient_user or "unknown"
        dedupe_key = f"{recipient_key}:{str(event_key).strip()}"[:140]
        existing = frappe.db.get_value(
            "OMC Notification", {"dedupe_key": dedupe_key}, "name"
        )
        if existing:
            return frappe.get_doc("OMC Notification", existing)

    if customer_profile and not _notification_preference_enabled(
        customer_profile=customer_profile,
        notification_type=normalized_notification_type,
    ):
        return None

    dedupe_filters = {
        "visible_to_customer": 1,
        "title": title,
        "message": message or "",
        "notification_type": normalized_notification_type,
        "reference_doctype": reference_doctype or "",
        "reference_name": reference_name or "",
        "creation": [">=", frappe.utils.add_to_date(None, minutes=-10)],
    }
    if customer_profile:
        dedupe_filters["customer_profile"] = customer_profile
    elif recipient_user:
        dedupe_filters["recipient_user"] = recipient_user

    existing = frappe.db.exists("OMC Notification", dedupe_filters)
    if existing:
        return frappe.get_doc("OMC Notification", existing)

    notification = frappe.new_doc("OMC Notification")
    notification.customer_profile = customer_profile or None
    notification.recipient_user = recipient_user or None
    notification.title = title
    notification.message = message or ""
    notification.notification_type = normalized_notification_type
    notification.reference_doctype = reference_doctype or None
    notification.reference_name = reference_name or None
    if notification.meta.has_field("mobile_route"):
        from omc_app.api.notification_events import validated_mobile_route

        notification.mobile_route = validated_mobile_route(
            str(mobile_route or "").strip()
            or _notification_mobile_route(notification)
        )
    if dedupe_key and notification.meta.has_field("dedupe_key"):
        notification.dedupe_key = dedupe_key
    notification.is_read = 0
    if notification.meta.has_field("is_dismissed"):
        notification.is_dismissed = 0
    notification.visible_to_customer = 1
    notification.insert(ignore_permissions=True)
    from omc_app.api import notification_delivery

    notification_delivery.enqueue_notification(notification.name)
    return notification




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
    """Return only file references that are safe for unauthenticated APIs."""
    text = (value or "").strip()
    if not text:
        return ""

    if text.startswith(("http://", "https://")):
        return text

    if text.startswith(("/files/", "/assets/")):
        return frappe.utils.get_url(text)

    # Never expose private or unclassified local paths through public content APIs.
    return ""




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
        "uploads": {
            "service_document": {
                "max_size_bytes": 10 * 1024 * 1024,
                "extensions": ["pdf", "jpg", "jpeg", "png", "doc", "docx"],
                "max_files": 20,
            },
            "support_attachment": {
                "max_size_bytes": 10 * 1024 * 1024,
                "extensions": ["pdf", "jpg", "jpeg", "png", "doc", "docx"],
                "max_files": 1,
            },
            "payment_receipt": {
                "max_size_bytes": 10 * 1024 * 1024,
                "extensions": ["pdf", "jpg", "jpeg", "png"],
                "max_files": 1,
            },
        },
        "branding": {
            "company_name": _settings_text(branding_settings, "brand_name", "OMC House") if branding_enabled else "OMC House",
            "tagline": _settings_text(branding_settings, "tagline", "Business, tax and compliance support") if branding_enabled else "Business, tax and compliance support",
            "full_logo": _settings_text(branding_settings, "full_logo"),
            "logo_symbol": _settings_text(branding_settings, "logo_symbol"),
            "login_logo": _settings_text(branding_settings, "login_logo"),
            "primary_color_family": (_get_single_settings("OMC Mobile Settings").get("primary_color_family") or "navy"),
            "primaryColorFamily": (_get_single_settings("OMC Mobile Settings").get("primary_color_family") or "navy"),
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

    return {
        "channels": channels,
        "topics": topics,
        "business_hours": "",
        "office_address": "",
        "whatsapp_message": "",
        "fallback": False,
    }


@frappe.whitelist()
def create_support_ticket(**kwargs):
    """Backward-compatible route for canonical support ticket creation."""
    from omc_app.api import support_chat

    return support_chat.create_support_ticket(**kwargs)



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
def get_support_tickets(**kwargs):
    """Backward-compatible route for the canonical support ticket list."""
    from omc_app.api import support_chat

    return support_chat.get_support_tickets(**kwargs)



@frappe.whitelist()
def get_support_ticket(ticket_id=None):
    """Backward-compatible route for canonical support ticket detail."""
    from omc_app.api import support_chat

    return support_chat.get_support_ticket(ticket_id=ticket_id)


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
    preferences.in_app_notifications_enabled = 1
    preferences.push_notifications_enabled = 1
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
    from omc_app.api.notification_delivery import provider_status

    push_status = provider_status()
    return {
        "in_app_notifications_enabled": _preference_bool(preferences, "in_app_notifications_enabled"),
        "push_notifications_enabled": _preference_bool(preferences, "push_notifications_enabled"),
        "push_provider_configured": push_status.configured,
        "push_provider_operational": push_status.operational,
        "service_updates_enabled": _preference_bool(preferences, "service_updates_enabled"),
        "document_reminders_enabled": _preference_bool(preferences, "document_reminders_enabled"),
        "payment_alerts_enabled": _preference_bool(preferences, "payment_alerts_enabled", "payment_reminders_enabled"),
        "tax_alerts_enabled": _preference_bool(preferences, "tax_alerts_enabled"),
        "email_notifications_enabled": _preference_bool(preferences, "email_notifications_enabled", "email_updates_enabled"),
        "whatsapp_notifications_enabled": _preference_bool(preferences, "whatsapp_notifications_enabled"),
        "theme": preferences.theme or "system",
        "language": preferences.language or "en",
    }


_NOTIFICATION_PREFERENCE_FIELDS = {
    "general": "service_updates_enabled",
    "service": "service_updates_enabled",
    "service request": "service_updates_enabled",
    "support": "service_updates_enabled",
    "document": "document_reminders_enabled",
    "payment": "payment_alerts_enabled",
    "commission": "payment_alerts_enabled",
    "tax": "tax_alerts_enabled",
}


def _normalized_notification_type(notification_type=None):
    clean = " ".join(str(notification_type or "General").strip().lower().replace("_", " ").split())
    return clean or "general"


def _notification_preference_field(notification_type=None, channel="push"):
    normalized_channel = str(channel or "push").strip().lower()
    if normalized_channel == "email":
        return "email_notifications_enabled"
    if normalized_channel in {"whatsapp", "whats_app", "whats app"}:
        return "whatsapp_notifications_enabled"

    return _NOTIFICATION_PREFERENCE_FIELDS.get(
        _normalized_notification_type(notification_type),
        "service_updates_enabled",
    )


def _notification_preference_enabled(
    customer_profile=None,
    notification_type=None,
):
    """Return whether a customer in-app notification may be created.

    Internal recipient-user notifications bypass customer preferences. Existing
    customers without a preference document retain historical enabled behavior.
    """
    if not customer_profile:
        return True

    preference_name = frappe.db.get_value(
        "OMC Customer Preference",
        {"customer_profile": customer_profile},
        "name",
    )
    if not preference_name:
        return True

    in_app_enabled = frappe.db.get_value(
        "OMC Customer Preference", preference_name, "in_app_notifications_enabled"
    )
    if in_app_enabled is not None and not frappe.utils.cint(in_app_enabled):
        return False

    preference_field = _notification_preference_field(
        notification_type,
        channel="push",
    )

    value = frappe.db.get_value(
        "OMC Customer Preference",
        preference_name,
        preference_field,
    )
    if value is None:
        return True

    return bool(frappe.utils.cint(value))


def _notification_delivery_enabled(
    notification_type=None,
    *,
    customer_profile=None,
    user=None,
    channel="push",
):
    profile = customer_profile
    if isinstance(profile, str):
        if not frappe.db.exists("OMC Customer Profile", profile):
            return True
        profile = frappe.get_doc("OMC Customer Profile", profile)

    if profile is None and user:
        profile = _get_customer_profile_for_user(user)

    if profile is None:
        return True

    preferences = _get_customer_preferences(profile)
    if str(channel or "push").strip().lower() == "push" and not _preference_bool(
        preferences, "push_notifications_enabled"
    ):
        return False
    fieldname = _notification_preference_field(notification_type, channel)
    return _preference_bool(preferences, fieldname)


def _active_push_tokens_for_notification(
    notification_type=None,
    *,
    customer_profile=None,
    user=None,
):
    if not _notification_delivery_enabled(
        notification_type,
        customer_profile=customer_profile,
        user=user,
        channel="push",
    ):
        return []

    filters = {"is_active": 1}
    if customer_profile:
        filters["customer_profile"] = (
            customer_profile.name if hasattr(customer_profile, "name") else customer_profile
        )
    elif user:
        filters["user"] = user
    else:
        return []

    return frappe.get_all(
        "OMC Push Token",
        filters=filters,
        fields=["name", "token", "platform", "device_id", "user", "customer_profile"],
        order_by="modified desc",
    )





@frappe.whitelist()
def add_support_ticket_reply(ticket_id=None, message=None, **kwargs):
    """Backward-compatible route for canonical support replies."""
    from omc_app.api import support_chat

    return support_chat.add_support_ticket_reply(
        ticket_id=ticket_id,
        message=message,
        **kwargs,
    )



@frappe.whitelist()
def update_support_ticket_status(ticket_id=None, status=None, remarks=None):
    """Backward-compatible route for canonical support status updates."""
    from omc_app.api import support_chat

    return support_chat.update_support_ticket_status(
        ticket_id=ticket_id,
        status=status,
        remarks=remarks,
    )


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
        "notifications_enabled": "in_app_notifications_enabled",
        "email_updates_enabled": "email_notifications_enabled",
        "payment_reminders_enabled": "payment_alerts_enabled",
    }

    for incoming_field, target_field in field_aliases.items():
        if incoming_field in kwargs and target_field not in kwargs:
            kwargs[target_field] = kwargs.get(incoming_field)

    allowed_check_fields = [
        "in_app_notifications_enabled",
        "push_notifications_enabled",
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


def _pending_linked_erp_task_count():
    if not _has_doctype("Task"):
        return 0

    task_names = list(
        {
            name
            for name in frappe.get_all(
                "OMC Service Request",
                filters={"erp_task": ["is", "set"]},
                pluck="erp_task",
            )
            if name
        }
    )
    if not task_names:
        return 0

    return frappe.db.count(
        "Task",
        {
            "name": ["in", task_names],
            "status": ["not in", ["Completed", "Cancelled"]],
        },
    )

@frappe.whitelist()
def get_internal_workspace_summary():
    _assert_internal_workspace_access()
    user = frappe.session.user
    today = frappe.utils.getdate()
    month_start = today.replace(day=1)

    my_filters = {"assigned_staff": user}
    my_active_filters = {
        "assigned_staff": user,
        "status": ["not in", ["Completed", "Cancelled"]],
    }
    my_completed_filters = {
        "completed_by": user,
        "status": "Completed",
    }
    my_month_completed_filters = {
        "completed_by": user,
        "status": "Completed",
        "closed_on": [">=", month_start],
    }

    return {
        "leads": frappe.db.count("OMC Lead"),
        "customers": frappe.db.count("OMC Customer Profile"),
        "tasks": _pending_linked_erp_task_count(),
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
        "unread_notifications": frappe.db.count(
            "OMC Notification",
            {
                "visible_to_customer": 1,
                "is_read": 0,
                "recipient_user": user,
                **(
                    {"is_dismissed": 0}
                    if _doctype_has_field("OMC Notification", "is_dismissed")
                    else {}
                ),
            },
        ),
        "my_assigned_services": frappe.db.count(
            "OMC Service Request",
            my_filters,
        ),
        "my_active_services": frappe.db.count(
            "OMC Service Request",
            my_active_filters,
        ),
        "my_completed_services": frappe.db.count(
            "OMC Service Request",
            my_completed_filters,
        ),
        "my_completed_this_month": frappe.db.count(
            "OMC Service Request",
            my_month_completed_filters,
        ),
    }


@frappe.whitelist()
def create_lead(**kwargs):
    claim = idempotency.begin(
        operation="lead.create",
        actor=_current_user(),
        payload=kwargs,
    )
    if claim and claim.replay is not None:
        return claim.replay
    try:
        response = _create_lead(**kwargs)
        lead = response.get("lead") or {}
        return idempotency.complete(
            claim,
            response,
            reference_doctype="OMC Lead",
            reference_name=lead.get("name") or "",
            stored_response={
                "created": True,
                "lead": {"name": lead.get("name") or ""},
                "message": "Lead created.",
            },
        )
    except Exception:
        idempotency.fail(claim)
        raise


def _create_lead(**kwargs):
    _assert_internal_workspace_access()
    _require_canonical_capability(
        "can_manage_leads",
        message="You do not have permission to create leads.",
    )

    title = (kwargs.get("title") or kwargs.get("subject") or "").strip()
    first_name = (kwargs.get("first_name") or "").strip()
    middle_name = (kwargs.get("middle_name") or "").strip()
    last_name = (kwargs.get("last_name") or "").strip()
    supplied_name = (kwargs.get("lead_name") or kwargs.get("name") or kwargs.get("full_name") or "").strip()
    derived_name = " ".join(part for part in (first_name, middle_name, last_name) if part)
    lead_name = supplied_name or derived_name
    company_name = (kwargs.get("company_name") or kwargs.get("company") or "").strip()
    email_id = (kwargs.get("email_id") or kwargs.get("email") or "").strip()
    mobile_no = (kwargs.get("mobile_no") or kwargs.get("mobile") or kwargs.get("phone") or "").strip()
    phone = (kwargs.get("phone") or mobile_no).strip()
    source = (kwargs.get("source") or "Mobile App").strip()
    service_interest = (kwargs.get("service_interest") or kwargs.get("service") or "").strip()
    notes = (kwargs.get("notes") or kwargs.get("message") or kwargs.get("description") or "").strip()

    if not lead_name and not company_name and not title:
        frappe.throw("lead_name, company_name, title, or personal name is required")

    lead = frappe.new_doc("OMC Lead")
    values = {
        "title": title or company_name or lead_name,
        "first_name": first_name,
        "middle_name": middle_name,
        "last_name": last_name,
        "lead_name": lead_name or title or company_name,
        "company_name": company_name,
        "email_id": email_id,
        "email": email_id,
        "mobile_no": mobile_no,
        "phone": phone,
        "whatsapp_no": kwargs.get("whatsapp_no"),
        "phone_ext": kwargs.get("phone_ext"),
        "website": kwargs.get("website"),
        "status": kwargs.get("status") or "New",
        "source": source,
        "lead_type": kwargs.get("lead_type") or kwargs.get("type"),
        "request_type": kwargs.get("request_type"),
        "service_interest": service_interest,
        "lead_owner": kwargs.get("lead_owner"),
        "assigned_to": kwargs.get("assigned_to"),
        "sales_person": kwargs.get("sales_person"),
        "industry": kwargs.get("industry"),
        "market_segment": kwargs.get("market_segment"),
        "territory": kwargs.get("territory"),
        "no_of_employees": kwargs.get("no_of_employees"),
        "annual_revenue": kwargs.get("annual_revenue"),
        "city": kwargs.get("city"),
        "state": kwargs.get("state"),
        "country": kwargs.get("country"),
        "qualification_status": kwargs.get("qualification_status"),
        "qualified_by": kwargs.get("qualified_by"),
        "qualified_on": kwargs.get("qualified_on"),
        "campaign_name": kwargs.get("campaign_name"),
        "reference_business_partner": kwargs.get("reference_business_partner"),
        "notes": notes,
        "customer_profile": kwargs.get("customer_profile"),
        "converted_customer_profile": kwargs.get("converted_customer_profile"),
    }
    for fieldname, value in values.items():
        _set_if_has_field(lead, fieldname, value)

    lead.insert(ignore_permissions=True)
    frappe.db.commit()

    return {
        "message": "Lead created.",
        "created": True,
        "lead": _lead_to_dict(lead),
    }


def _lead_to_dict(lead):
    def value(fieldname):
        return getattr(lead, fieldname, None) or ""

    email_id = value("email_id") or value("email")
    mobile_no = value("mobile_no") or value("phone")
    return {
        "name": lead.name,
        "title": value("title"),
        "first_name": value("first_name"),
        "middle_name": value("middle_name"),
        "last_name": value("last_name"),
        "lead_name": value("lead_name"),
        "company_name": value("company_name"),
        "email_id": email_id,
        "email": email_id,
        "mobile_no": mobile_no,
        "mobile": mobile_no,
        "phone": value("phone") or mobile_no,
        "whatsapp_no": value("whatsapp_no"),
        "phone_ext": value("phone_ext"),
        "website": value("website"),
        "status": value("status"),
        "source": value("source"),
        "lead_type": value("lead_type"),
        "request_type": value("request_type"),
        "service_interest": value("service_interest"),
        "lead_owner": value("lead_owner"),
        "assigned_to": value("assigned_to"),
        "sales_person": value("sales_person"),
        "industry": value("industry"),
        "market_segment": value("market_segment"),
        "territory": value("territory"),
        "no_of_employees": value("no_of_employees"),
        "annual_revenue": getattr(lead, "annual_revenue", None) or 0,
        "city": value("city"),
        "state": value("state"),
        "country": value("country"),
        "qualification_status": value("qualification_status"),
        "qualified_by": value("qualified_by"),
        "qualified_on": str(getattr(lead, "qualified_on", None) or ""),
        "campaign_name": value("campaign_name"),
        "reference_business_partner": value("reference_business_partner"),
        "notes": value("notes"),
        "customer_profile": value("customer_profile"),
        "converted_customer_profile": value("converted_customer_profile"),
        "created_at": str(lead.creation) if lead.creation else "",
        "updated_at": str(lead.modified) if lead.modified else "",
    }




def _canonical_capabilities():
    return access.get_mobile_capabilities()


def _require_canonical_capability(*capability_names, message):
    capabilities = _canonical_capabilities()
    if not any(capabilities.get(name) for name in capability_names):
        frappe.throw(message, frappe.PermissionError)
    return capabilities


def _assigned_record_names(reference_type, user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return []
    return frappe.get_all(
        "ToDo",
        filters={
            "reference_type": reference_type,
            "allocated_to": user,
            "status": ["not in", ["Cancelled", "Closed"]],
        },
        pluck="reference_name",
    )


def _relevant_customer_names(user=None):
    user = user or _current_user()
    names = set()

    service_request_names = _assigned_record_names("OMC Service Request", user)
    if service_request_names:
        names.update(
            frappe.get_all(
                "OMC Service Request",
                filters={"name": ["in", service_request_names]},
                pluck="customer_profile",
            )
        )


    if _has_doctype("OMC Support Ticket"):
        names.update(
            frappe.get_all(
                "OMC Support Ticket",
                filters={"assigned_to": user},
                pluck="customer_profile",
            )
        )

    return sorted(name for name in names if name)

@frappe.whitelist()
def get_leads():
    from omc_app.api import lead_read_guard

    return lead_read_guard.get_leads()



@frappe.whitelist()
def get_lead(lead_id=None):
    from omc_app.api import lead_read_guard

    return lead_read_guard.get_lead(lead_id=lead_id)




def _customer_profile_image(profile):
    """Resolve the Frappe User image linked to a customer profile."""
    if not profile:
        return ""

    candidates = []

    # Prefer explicit Customer Profile -> User link fields when present.
    for fieldname in (
        "user",
        "user_id",
        "linked_user",
        "customer_user",
        "portal_user",
    ):
        try:
            if hasattr(profile, "meta") and profile.meta.has_field(fieldname):
                value = (profile.get(fieldname) or "").strip()
                if value:
                    candidates.append(value)
            else:
                value = (getattr(profile, fieldname, None) or "").strip()
                if value:
                    candidates.append(value)
        except Exception:
            pass

    email = (getattr(profile, "email", None) or "").strip()
    if email:
        candidates.append(email)

    # Remove duplicates while preserving priority.
    candidates = list(dict.fromkeys(candidates))

    for candidate in candidates:
        try:
            image = frappe.db.get_value("User", candidate, "user_image")
            if image:
                return image
        except Exception:
            pass

        try:
            user_name = frappe.db.get_value(
                "User",
                {"email": candidate},
                "name",
            )
            if user_name:
                image = frappe.db.get_value(
                    "User",
                    user_name,
                    "user_image",
                )
                if image:
                    return image
        except Exception:
            pass

        try:
            user_name = frappe.db.get_value(
                "User",
                {"username": candidate},
                "name",
            )
            if user_name:
                image = frappe.db.get_value(
                    "User",
                    user_name,
                    "user_image",
                )
                if image:
                    return image
        except Exception:
            pass

    return ""


def _customer_profile_to_dict(profile):
    user_image = _customer_profile_image(profile)

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
        "user_image": user_image,
        "avatar_url": user_image,
        "created_at": str(profile.creation) if profile.creation else "",
        "updated_at": str(profile.modified) if profile.modified else "",
    }


@frappe.whitelist()
def get_customers(start=0, limit=50, limit_start=None, limit_page_length=None):
    start = _notification_page_value(limit_start if limit_start is not None else start, default=0, minimum=0, maximum=100000)
    limit = _notification_page_value(limit_page_length if limit_page_length is not None else limit, default=50, minimum=1, maximum=100)
    user = _assert_internal_workspace_access()
    capabilities = _require_canonical_capability(
        "can_manage_customers",
        "can_view_all_customers",
        "can_view_relevant_customers",
        message="You do not have permission to view customers.",
    )

    filters = {}
    if not (
        capabilities.get("can_manage_customers")
        or capabilities.get("can_view_all_customers")
    ):
        relevant_names = _relevant_customer_names(user)
        if not relevant_names:
            return {"items": [], "customers": [], "start": start, "limit": limit, "has_more": False, "next_start": None}
        filters["name"] = ["in", relevant_names]

    customer_names = frappe.get_all(
        "OMC Customer Profile",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        limit_start=start,
        limit_page_length=limit + 1,
    )

    has_more = len(customer_names) > limit
    customer_names = customer_names[:limit]

    customers = [
        _customer_profile_to_dict(
            frappe.get_doc("OMC Customer Profile", customer_name)
        )
        for customer_name in customer_names
    ]

    return {"items": customers, "customers": customers, "start": start, "limit": limit, "has_more": has_more, "next_start": start + limit if has_more else None}


@frappe.whitelist()
def get_customer(customer_id=None):
    user = _assert_internal_workspace_access()
    capabilities = _require_canonical_capability(
        "can_manage_customers",
        "can_view_all_customers",
        "can_view_relevant_customers",
        message="You do not have permission to view customers.",
    )
    if not customer_id:
        frappe.throw("customer_id is required")

    if not frappe.db.exists("OMC Customer Profile", customer_id):
        frappe.throw("Customer not found", frappe.DoesNotExistError)

    if not (
        capabilities.get("can_manage_customers")
        or capabilities.get("can_view_all_customers")
    ) and customer_id not in _relevant_customer_names(user):
        frappe.throw(
            "You do not have permission to view this customer.",
            frappe.PermissionError,
        )

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
def get_tasks(start=0, limit=100, limit_start=None, limit_page_length=None):
    """Stable mobile route delegated to canonical ERP Task authority."""
    from omc_app.api.task_read_guard import get_tasks as guarded_get_tasks

    return guarded_get_tasks(
        limit_start=limit_start if limit_start is not None else start,
        page_length=limit_page_length if limit_page_length is not None else limit,
    )



@frappe.whitelist()
def get_task(task_id=None):
    """Stable mobile route delegated to canonical ERP Task authority."""
    from omc_app.api.task_read_guard import get_task as guarded_get_task

    return guarded_get_task(task_id=task_id)



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
