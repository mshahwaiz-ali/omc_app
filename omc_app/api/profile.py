import re

import frappe


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

    user_image = ""
    if user and user != "Guest" and frappe.db.exists("User", user):
        user_image = frappe.db.get_value("User", user, "user_image") or ""

    return profile_image or user_image or ""


def _profile_payload(profile, user):
    avatar_url = _get_profile_image_url(profile, user)
    if not profile:
        return {
            "full_name": "",
            "email": user if user and user != "Guest" else "",
            "phone": "",
            "avatar_url": avatar_url,
            "profile_image": avatar_url,
            "user_image": avatar_url,
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
        "avatar_url": avatar_url,
        "profile_image": avatar_url,
        "user_image": avatar_url,
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


def _save_profile_file(filename, content, profile):
    file_doc = frappe.get_doc(
        {
            "doctype": "File",
            "file_name": filename,
            "attached_to_doctype": "OMC Customer Profile",
            "attached_to_name": profile.name,
            "attached_to_field": "profile_image" if profile.meta.has_field("profile_image") else None,
            "is_private": 0,
            "content": content,
        }
    )
    file_doc.insert(ignore_permissions=True)
    return file_doc


@frappe.whitelist()
def upload_profile_image():
    user = _current_user()
    if not user or user == "Guest":
        frappe.throw("Login is required to upload a profile image.", frappe.PermissionError)

    if not frappe.db.exists("User", user):
        frappe.throw("Logged-in user account was not found.", frappe.PermissionError)

    filename, content = _read_uploaded_file()
    profile = _get_customer_profile_for_user(user)
    if not profile:
        frappe.throw("Customer profile was not found for this account.")

    file_doc = _save_profile_file(filename, content, profile)
    file_url = file_doc.file_url or ""
    if not file_url:
        frappe.throw("Profile image was uploaded but no file URL was generated.")

    if profile.meta.has_field("profile_image"):
        profile.profile_image = file_url
        profile.save(ignore_permissions=True)

    user_doc = frappe.get_doc("User", user)
    user_doc.user_image = file_url
    user_doc.save(ignore_permissions=True)

    frappe.db.commit()
    frappe.clear_cache(user=user)

    return {
        "updated": True,
        "avatar_url": file_url,
        "profile_image": file_url,
        "user_image": file_url,
        "customer_id": profile.name,
        "file_name": file_doc.name,
        "profile": _profile_payload(profile, user),
        "message": "Profile image updated.",
    }
