import re

import frappe
from frappe.utils.file_manager import save_file

from omc_app.api import access
from omc_app.api import staff_profile


ALLOWED_PROFILE_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
PROFILE_IMAGE_CONTENT_TYPES = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}
MAX_PROFILE_IMAGE_SIZE_BYTES = 5 * 1024 * 1024


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _get_customer_profile_for_user(user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return None

    if access.is_internal_user(user):
        return None

    profile_name = frappe.db.get_value("OMC Customer Profile", {"user": user}, "name")
    if not profile_name:
        profile_name = frappe.db.get_value("OMC Customer Profile", {"email": user}, "name")

    if profile_name:
        return frappe.get_doc("OMC Customer Profile", profile_name)

    return None


def _get_user_image_url(user=None):
    user = user or _current_user()
    if not user or user == "Guest" or not frappe.db.exists("User", user):
        return ""

    return frappe.db.get_value("User", user, "user_image") or ""


def _internal_role_label(user):
    profile_role = staff_profile.get_staff_role(user)
    if profile_role:
        return profile_role

    roles = set(frappe.get_roles(user) or [])

    if user == "Administrator":
        return "OMC Admin"

    priority = (
        "OMC Admin",
        "OMC Manager",
        "OMC Support Agent",
        "OMC Document Reviewer",
        "OMC Finance Reviewer",
        "OMC Consultant",
        "OMC Tax Associate",
        "OMC Business Partner",
    )

    for role in priority:
        if role in roles:
            return role

    return "Internal"


def _internal_profile_payload(user):
    profile = staff_profile.ensure_staff_profile(user)
    user_doc = frappe.get_doc("User", user)
    role_label = _internal_role_label(user)
    capabilities = access.get_mobile_capabilities(user=user)

    def profile_value(fieldname):
        if not profile or not profile.meta.has_field(fieldname):
            return ""
        return str(profile.get(fieldname) or "")

    full_name = (
        profile_value("full_name")
        or str(user_doc.get("full_name") or "")
        or str(user_doc.get("first_name") or "")
        or user
    )

    email = (
        profile_value("email")
        or str(user_doc.get("email") or "")
        or user
    )

    phone = (
        profile_value("phone")
        or str(user_doc.get("mobile_no") or "")
    )

    return {
        "full_name": full_name,
        "display_name": full_name,
        "email": email,
        "user": user,
        "username": str(user_doc.get("username") or ""),
        "phone": phone,
        "whatsapp_no": profile_value("whatsapp_no"),
        "avatar_url": _get_user_image_url(user),
        "profile_image": _get_user_image_url(user),
        "user_image": _get_user_image_url(user),

        # Preserve Flutter response compatibility while keeping domains clean.
        "customer_id": "",
        "staff_profile_id": str(profile.name if profile else ""),
        "linked_employee": profile_value("linked_employee"),
        "staff_role": profile_value("staff_role"),
        "referral_record": profile_value("referral_record"),
        "own_referral_code": profile_value("own_referral_code"),

        "staff_status": profile_value("staff_status") or "Pending",
        # Compatibility alias expected by the current Flutter profile model.
        "customer_status": profile_value("staff_status") or "Pending",
        "approval_status": profile_value("approval_status") or "Pending Review",
        "is_active": int(profile.get("is_active") or 0) if profile else 0,
        "customer_type": role_label,
        "company_name": profile_value("company_name"),
        "cnic": profile_value("cnic"),
        "ntn": profile_value("ntn"),
        "register_as": role_label,
        "address": profile_value("address"),
        "education": profile_value("education"),
        "experience": profile_value("experience"),
        "remarks": profile_value("remarks"),
        "access_state": capabilities.get("access_state", "pending"),
        "can_access_internal_workspace": bool(
            capabilities.get("can_access_internal_workspace")
        ),
        "capabilities": capabilities,
        **capabilities,
    }


def _profile_payload(profile, user):
    user_image = _get_user_image_url(user)
    if not profile:
        return {
            "full_name": "",
            "email": user if user and user != "Guest" else "",
            "phone": "",
            "avatar_url": user_image,
            "user_image": user_image,
            "customer_id": "",
            "customer_status": "Guest" if user == "Guest" else "",
            "approval_status": "",
            "access_state": "guest" if user == "Guest" else "pending",
        }

    return {
        "full_name": profile.full_name or "",
        "display_name": profile.full_name or "",
        "email": profile.email or user or "",
        "user": user or "",
        "phone": profile.phone or "",
        "whatsapp_no": profile.get("whatsapp_no") or "",
        "avatar_url": user_image,
        "user_image": user_image,
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
        "access_state": "approved"
        if (profile.customer_status or "").lower() == "active"
        and (profile.approval_status or "").lower() == "approved"
        else "pending",
    }


@frappe.whitelist()
def get_profile():
    user = _current_user()
    if user == "Guest":
        return _profile_payload(None, user)

    if access.is_internal_user(user):
        return _internal_profile_payload(user)

    profile = _get_customer_profile_for_user(user)
    return _profile_payload(profile, user)


def _clean_filename(filename, content_type=""):
    raw_filename = (filename or "profile-image").strip() or "profile-image"
    raw_filename = raw_filename.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    safe_filename = re.sub(r"[^A-Za-z0-9._-]+", "-", raw_filename).strip(".-_") or "profile-image"

    if "." in safe_filename:
        base, extension = safe_filename.rsplit(".", 1)
        extension = extension.lower().strip()
        base = base.strip(".-_") or "profile-image"
    else:
        base = safe_filename
        extension = ""

    if extension not in ALLOWED_PROFILE_IMAGE_EXTENSIONS:
        extension = PROFILE_IMAGE_CONTENT_TYPES.get((content_type or "").lower().split(";", 1)[0].strip(), "")

    if extension not in ALLOWED_PROFILE_IMAGE_EXTENSIONS:
        frappe.throw("Only JPG, PNG, or WEBP profile images are allowed.")

    return f"{base}.{extension}"


def _read_uploaded_file():
    request = getattr(frappe, "request", None)
    uploaded_file = request.files.get("file") if request and getattr(request, "files", None) else None
    if not uploaded_file:
        frappe.throw("Profile image file is required.")

    filename = _clean_filename(
        getattr(uploaded_file, "filename", "") or "profile-image",
        getattr(uploaded_file, "content_type", "") or "",
    )
    content = uploaded_file.stream.read()

    if not content:
        frappe.throw("Selected profile image is empty. Please choose another photo.")

    if len(content) > MAX_PROFILE_IMAGE_SIZE_BYTES:
        frappe.throw("Profile image must be 5 MB or smaller.")

    return filename, content


@frappe.whitelist()
def upload_profile_image():
    user = _current_user()
    if not user or user == "Guest":
        frappe.throw("Login is required to upload a profile image.", frappe.PermissionError)

    if not frappe.db.exists("User", user):
        frappe.throw("Logged-in user account was not found.", frappe.PermissionError)

    filename, content = _read_uploaded_file()
    file_doc = save_file(
        filename,
        content,
        "User",
        user,
        is_private=0,
    )

    file_url = file_doc.file_url or ""
    if not file_url:
        frappe.throw("Profile image was uploaded but no file URL was generated.")

    user_doc = frappe.get_doc("User", user)
    user_doc.user_image = file_url
    user_doc.save(ignore_permissions=True)

    profile = _get_customer_profile_for_user(user)

    frappe.db.commit()
    frappe.clear_cache(user=user)

    return {
        "updated": True,
        "avatar_url": file_url,
        "user_image": file_url,
        "customer_id": profile.name if profile else "",
        "file_name": file_doc.name,
        "profile": _internal_profile_payload(user) if access.is_internal_user(user) else _profile_payload(profile, user),
        "message": "Profile image updated.",
    }
