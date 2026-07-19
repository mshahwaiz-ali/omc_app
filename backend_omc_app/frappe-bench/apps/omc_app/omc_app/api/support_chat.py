import re

import frappe

from omc_app.api import access
from omc_app.api.mobile import (
    _assert_approved_customer,
    _can_access_internal_workspace,
    _create_customer_notification,
    _current_user,
    _get_mobile_capabilities,
)


SUPPORT_MESSAGE_DOCTYPE = "OMC Support Ticket Message"
ALLOWED_SUPPORT_ATTACHMENT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png", "doc", "docx"}
MAX_SUPPORT_ATTACHMENT_SIZE_BYTES = 10 * 1024 * 1024


def _capabilities():
    return access.get_mobile_capabilities()


def _require_capability(capability, message):
    capabilities = _capabilities()
    if not capabilities.get(capability):
        frappe.throw(message, frappe.PermissionError)
    return capabilities



def _assert_support_assignee_allowed(assigned_to):
    user_values = frappe.db.get_value(
        "User",
        assigned_to,
        ["enabled", "user_type"],
        as_dict=True,
    )
    if not user_values:
        frappe.throw("Assigned user not found", frappe.DoesNotExistError)

    if not int(user_values.enabled or 0):
        frappe.throw(
            "Support tickets can only be assigned to an enabled user.",
            frappe.ValidationError,
        )

    if user_values.user_type != "System User":
        frappe.throw(
            "Support tickets can only be assigned to an internal system user.",
            frappe.PermissionError,
        )

    capabilities = access.get_mobile_capabilities(user=assigned_to)
    if not capabilities.get("can_view_support_tickets"):
        frappe.throw(
            "Assigned user does not have permission to access support tickets.",
            frappe.PermissionError,
        )


def _clean_file_reference(value):
    text_value = (value or "").strip()
    if not text_value:
        return ""
    return text_value.split("?")[0].strip()


def _file_extension(value):
    file_name = _clean_file_reference(value).rsplit("/", 1)[-1]
    if "." not in file_name:
        return ""
    return file_name.rsplit(".", 1)[-1].strip().lower()


def _find_uploaded_file(file_reference):
    clean_reference = _clean_file_reference(file_reference)
    if not clean_reference:
        return None

    file_name = clean_reference.rsplit("/", 1)[-1]
    for filters in ({"file_url": clean_reference}, {"file_name": file_name}):
        file_docname = frappe.db.exists("File", filters)
        if file_docname:
            return frappe.get_doc("File", file_docname)
    return None


def _public_file_url(value):
    text = (value or "").strip()
    if not text:
        return ""
    if text.startswith(("http://", "https://")):
        return text
    if text.startswith(("/files/", "/private/files/", "/assets/")):
        return frappe.utils.get_url(text)
    return text


def _attachment_meta(file_reference):
    clean_reference = _clean_file_reference(file_reference)
    if not clean_reference:
        return {
            "attachment": "",
            "attachment_url": "",
            "attachment_name": "",
            "attachment_type": "",
            "attachment_size": 0,
        }

    uploaded_file = _find_uploaded_file(clean_reference)
    file_name = ""
    file_size = 0
    if uploaded_file:
        file_name = uploaded_file.file_name or ""
        file_size = int(uploaded_file.file_size or 0)

    if not file_name:
        file_name = clean_reference.rsplit("/", 1)[-1]

    return {
        "attachment": clean_reference,
        "attachment_url": _public_file_url(clean_reference),
        "attachment_name": file_name,
        "attachment_type": _file_extension(file_name or clean_reference),
        "attachment_size": file_size,
    }


def _assert_support_attachment_allowed(ticket, file_reference):
    clean_reference = _clean_file_reference(file_reference)
    if not clean_reference:
        return ""

    extension = _file_extension(clean_reference)
    if extension not in ALLOWED_SUPPORT_ATTACHMENT_EXTENSIONS:
        frappe.throw("Unsupported attachment type. Please upload PDF, JPG, PNG, DOC or DOCX files only.")

    uploaded_file = _find_uploaded_file(clean_reference)
    if not uploaded_file:
        return clean_reference

    uploaded_extension = _file_extension(uploaded_file.file_name or uploaded_file.file_url or clean_reference)
    if uploaded_extension not in ALLOWED_SUPPORT_ATTACHMENT_EXTENSIONS:
        frappe.throw("Unsupported attachment type. Please upload PDF, JPG, PNG, DOC or DOCX files only.")

    file_size = int(uploaded_file.file_size or 0)
    if file_size <= 0:
        frappe.throw("Uploaded attachment is empty.")
    if file_size > MAX_SUPPORT_ATTACHMENT_SIZE_BYTES:
        frappe.throw("Attachment is too large. Maximum allowed size is 10 MB.")

    current_user = _current_user()
    if uploaded_file.owner and uploaded_file.owner != current_user and not _can_access_internal_workspace(current_user):
        frappe.throw("You do not have permission to use this uploaded attachment.", frappe.PermissionError)

    if uploaded_file.attached_to_doctype and uploaded_file.attached_to_doctype not in {"", "OMC Support Ticket"}:
        frappe.throw("Uploaded attachment is attached to another document.", frappe.PermissionError)

    if uploaded_file.attached_to_name and uploaded_file.attached_to_name != ticket.name:
        frappe.throw("Uploaded attachment is attached to another support ticket.", frappe.PermissionError)

    if not uploaded_file.is_private:
        uploaded_file.is_private = 1

    if uploaded_file.attached_to_doctype != "OMC Support Ticket" or uploaded_file.attached_to_name != ticket.name:
        uploaded_file.attached_to_doctype = "OMC Support Ticket"
        uploaded_file.attached_to_name = ticket.name

    uploaded_file.save(ignore_permissions=True)
    return uploaded_file.file_url or clean_reference


def _has_message_doctype():
    try:
        return bool(frappe.db.exists("DocType", SUPPORT_MESSAGE_DOCTYPE))
    except Exception:
        return False


def _message_has_field(fieldname):
    if not _has_message_doctype():
        return False
    try:
        return bool(frappe.get_meta(SUPPORT_MESSAGE_DOCTYPE).has_field(fieldname))
    except Exception:
        return False


def _legacy_support_ticket_messages(ticket):
    raw_message = ticket.message or ""
    messages = []
    if not raw_message:
        return messages

    parts = raw_message.split("\n\n--- Reply from ")
    initial_message = parts[0].strip()
    if initial_message:
        messages.append(
            {
                "name": f"{ticket.name}-initial",
                "author": ticket.raised_by or "Customer",
                "sender_user": ticket.raised_by or "",
                "sender_type": "Customer",
                "message": initial_message,
                "created_at": str(ticket.creation) if ticket.creation else "",
                "type": "Customer",
                **_attachment_meta(""),
            }
        )

    for index, raw_reply in enumerate(parts[1:], start=1):
        header, separator, body = raw_reply.partition(" ---\n")
        if not separator:
            continue

        author = header
        created_at = ""
        if " at " in header:
            author, created_at = header.rsplit(" at ", 1)

        author = author.strip() or "Customer"
        sender_type = "Support" if author.lower() in {"omc support", "omc team"} or "admin" in author.lower() else "Customer"
        messages.append(
            {
                "name": f"{ticket.name}-legacy-{index}",
                "author": author,
                "sender_user": author,
                "sender_type": sender_type,
                "message": body.strip(),
                "created_at": created_at.strip(),
                "type": sender_type,
                **_attachment_meta(""),
            }
        )

    return messages


def _message_row_to_dict(row):
    attachment = _attachment_meta(getattr(row, "attachment", None))
    sender_user = getattr(row, "sender_user", None) or getattr(row, "owner", None) or ""
    sender_type = getattr(row, "sender_type", None) or "Customer"
    return {
        "name": row.name,
        "author": sender_user or sender_type,
        "sender_user": sender_user,
        "sender_type": sender_type,
        "message": getattr(row, "message", None) or "",
        "created_at": str(row.creation) if getattr(row, "creation", None) else "",
        "type": sender_type,
        "is_internal": int(getattr(row, "is_internal", None) or 0),
        **attachment,
    }


def _support_ticket_messages(ticket):
    if not _has_message_doctype():
        return _legacy_support_ticket_messages(ticket)

    rows = frappe.get_all(
        SUPPORT_MESSAGE_DOCTYPE,
        filters={"support_ticket": ticket.name, "is_internal": 0},
        fields=[
            "name",
            "sender_user",
            "sender_type",
            "message",
            "attachment",
            "is_internal",
            "creation",
            "owner",
        ],
        order_by="creation asc",
        limit_page_length=500,
    )

    if rows:
        return [_message_row_to_dict(row) for row in rows]

    return _legacy_support_ticket_messages(ticket)


def _ensure_initial_message_record(ticket):
    if not _has_message_doctype():
        return
    if frappe.db.exists(SUPPORT_MESSAGE_DOCTYPE, {"support_ticket": ticket.name}):
        return

    initial_message = (ticket.message or "").split("\n\n--- Reply from ")[0].strip()
    if not initial_message:
        return

    chat_message = frappe.new_doc(SUPPORT_MESSAGE_DOCTYPE)
    chat_message.support_ticket = ticket.name
    chat_message.sender_user = ticket.raised_by
    chat_message.sender_type = "Customer"
    chat_message.message = initial_message
    chat_message.is_internal = 0
    chat_message.read_by_customer = 1
    chat_message.read_by_staff = 0
    chat_message.insert(ignore_permissions=True)


def _create_support_message(ticket, message="", attachment="", sender_type=None, is_internal=0):
    message = (message or "").strip()
    attachment = _assert_support_attachment_allowed(ticket, attachment)

    if not message and not attachment:
        frappe.throw("message or attachment is required")

    user = _current_user()
    sender_type = sender_type or ("Support" if _can_access_internal_workspace(user) else "Customer")

    if not _has_message_doctype():
        timestamp = frappe.utils.now_datetime()
        ticket.message = (ticket.message or "").rstrip() + f"\n\n--- Reply from {user} at {timestamp} ---\n{message}"
        ticket.save(ignore_permissions=True)
        return None

    attachment_data = _attachment_meta(attachment)
    chat_message = frappe.new_doc(SUPPORT_MESSAGE_DOCTYPE)
    chat_message.support_ticket = ticket.name
    chat_message.sender_user = user if user != "Guest" else None
    chat_message.sender_type = sender_type
    chat_message.message = message
    chat_message.attachment = attachment_data["attachment"] or None
    chat_message.attachment_name = attachment_data["attachment_name"] or ""
    chat_message.attachment_type = attachment_data["attachment_type"] or ""
    chat_message.attachment_size = attachment_data["attachment_size"] or 0
    chat_message.is_internal = 1 if is_internal else 0
    chat_message.read_by_customer = 1 if sender_type == "Customer" else 0
    chat_message.read_by_staff = 1 if sender_type in {"Support", "Admin", "System"} else 0
    chat_message.insert(ignore_permissions=True)
    return chat_message


def _support_ticket_to_dict(ticket):
    raw_message = ticket.message or ""
    raw_message = re.sub(r"--- Reply from\s*", "--- Reply from ", raw_message)
    raw_message = re.sub(r"\s+at\s*(\d{4}-\d{2}-\d{2})", r" at \1", raw_message)
    messages = _support_ticket_messages(ticket)
    capabilities = _capabilities()
    is_internal = _can_access_internal_workspace()
    last_message = messages[-1]["message"] if messages else raw_message

    return {
        "name": ticket.name,
        "subject": ticket.subject or "",
        "message": raw_message,
        "last_message": last_message or "",
        "messages": messages,
        "status": ticket.status or "",
        "priority": ticket.priority or "",
        "customer_profile": ticket.customer_profile or "",
        "raised_by": ticket.raised_by or "",
        "contact_email": ticket.contact_email or "",
        "contact_phone": ticket.contact_phone or "",
        "reference_service_request": ticket.reference_service_request or "",
        "assigned_to": ticket.assigned_to or "",
        "raised_on": str(ticket.raised_on) if ticket.raised_on else "",
        "closed_on": str(ticket.closed_on) if ticket.closed_on else "",
        "created_at": str(ticket.creation) if ticket.creation else "",
        "updated_at": str(ticket.modified) if ticket.modified else "",
        "can_update_status": bool(
            capabilities.get("can_update_support_ticket_status")
        ),
        "can_assign": bool(capabilities.get("can_assign_support_tickets")),
        "can_reply": (
            ticket.status not in ["Closed", "Cancelled"]
            and (
                capabilities.get("can_reply_support_tickets")
                if is_internal
                else capabilities.get("can_view_support_tickets")
            )
        ),
    }


def _assert_support_ticket_access(ticket):
    user = _current_user()
    if user == "Guest":
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if _can_access_internal_workspace(user):
        _require_capability(
            "can_view_support_tickets",
            "You do not have permission to access support tickets.",
        )
        return user, None

    profile = _assert_approved_customer()
    if profile and ticket.customer_profile and ticket.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if not profile and ticket.raised_by and ticket.raised_by != user:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    return user, profile


def _support_ticket_filters_for_current_user():
    user = _current_user()
    if user == "Guest":
        return user, None, None

    if _can_access_internal_workspace(user):
        _require_capability(
            "can_view_support_tickets",
            "You do not have permission to view support tickets.",
        )
        return user, None, {}

    profile = _assert_approved_customer()
    if profile:
        return user, profile, {"customer_profile": profile.name}

    return user, None, {"raised_by": user}


def _support_message_read_filters(user, profile, mark_read=False):
    if user == "Guest" or not _has_message_doctype():
        return None

    if _can_access_internal_workspace(user):
        if not _message_has_field("read_by_staff"):
            return None
        return {
            "is_internal": 0,
            "sender_type": "Customer",
            "read_by_staff": 0 if not mark_read else ["in", [0, 1]],
        }

    if not _message_has_field("read_by_customer"):
        return None
    return {
        "is_internal": 0,
        "sender_type": ["in", ["Support", "Admin", "System"]],
        "read_by_customer": 0 if not mark_read else ["in", [0, 1]],
    }


@frappe.whitelist()
def create_support_ticket(**kwargs):
    subject = (kwargs.get("subject") or kwargs.get("title") or "").strip()
    message = (kwargs.get("message") or kwargs.get("description") or "").strip()
    attachment = kwargs.get("attachment") or kwargs.get("file_url") or kwargs.get("file") or ""

    if not subject:
        frappe.throw("subject is required")
    if not message and not attachment:
        frappe.throw("message or attachment is required")

    user = _current_user()
    capabilities = _capabilities()
    if not capabilities.get("can_create_support_ticket"):
        frappe.throw(
            "You do not have permission to create support tickets.",
            frappe.PermissionError,
        )
    profile = _assert_approved_customer()
    reference_service_request = kwargs.get("reference_service_request") or kwargs.get("service_request") or kwargs.get("case_id")

    if reference_service_request:
        if not frappe.db.exists("OMC Service Request", reference_service_request):
            frappe.throw("Reference service request not found", frappe.DoesNotExistError)
        request_customer = frappe.db.get_value("OMC Service Request", reference_service_request, "customer_profile")
        if profile and request_customer and request_customer != profile.name:
            frappe.throw("You do not have permission to reference this service request", frappe.PermissionError)

    ticket = frappe.new_doc("OMC Support Ticket")
    ticket.subject = subject
    ticket.message = message or "Attachment shared from the app."
    ticket.status = "Open"
    ticket.priority = kwargs.get("priority") or "Medium"
    ticket.customer_profile = profile.name if profile else None
    ticket.raised_by = user if user != "Guest" else None
    ticket.contact_email = kwargs.get("contact_email") or (profile.email if profile else "")
    ticket.contact_phone = kwargs.get("contact_phone") or (profile.phone if profile else "")
    ticket.reference_service_request = reference_service_request or None
    ticket.insert(ignore_permissions=True)

    _create_support_message(ticket, message=message, attachment=attachment, sender_type="Customer")
    frappe.db.commit()

    return {"message": "Support ticket created.", "created": True, "ticket": _support_ticket_to_dict(ticket)}


@frappe.whitelist()
def get_support_tickets():
    user, _profile, filters = _support_ticket_filters_for_current_user()
    if user == "Guest" or filters is None:
        return {"tickets": []}

    ticket_names = frappe.get_all(
        "OMC Support Ticket",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        limit_page_length=50,
    )
    return {"tickets": [_support_ticket_to_dict(frappe.get_doc("OMC Support Ticket", name)) for name in ticket_names]}


@frappe.whitelist()
def get_support_ticket(ticket_id=None, name=None):
    ticket_id = ticket_id or name
    if not ticket_id:
        frappe.throw("ticket_id is required")
    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    _assert_support_ticket_access(ticket)
    return {"ticket": _support_ticket_to_dict(ticket)}


@frappe.whitelist()
def get_active_support_ticket():
    user, _profile, filters = _support_ticket_filters_for_current_user()
    if user == "Guest" or filters is None:
        return {"ticket": None}

    active_filters = dict(filters)
    active_filters["status"] = ["not in", ["Closed", "Cancelled"]]
    ticket_names = frappe.get_all(
        "OMC Support Ticket",
        filters=active_filters,
        pluck="name",
        order_by="modified desc",
        limit_page_length=1,
    )
    if not ticket_names:
        return {"ticket": None}

    ticket = frappe.get_doc("OMC Support Ticket", ticket_names[0])
    _assert_support_ticket_access(ticket)
    return {"ticket": _support_ticket_to_dict(ticket)}


@frappe.whitelist()
def get_support_unread_count():
    user, profile, ticket_filters = _support_ticket_filters_for_current_user()
    if user == "Guest" or ticket_filters is None:
        return {"count": 0}

    message_filters = _support_message_read_filters(user, profile)
    if not message_filters:
        return {"count": 0}

    ticket_names = frappe.get_all("OMC Support Ticket", filters=ticket_filters, pluck="name")
    if not ticket_names:
        return {"count": 0}

    message_filters["support_ticket"] = ["in", ticket_names]
    return {"count": frappe.db.count(SUPPORT_MESSAGE_DOCTYPE, message_filters)}


@frappe.whitelist()
def mark_support_ticket_read(ticket_id=None, name=None):
    ticket_id = ticket_id or name
    if not ticket_id:
        frappe.throw("ticket_id is required")
    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, profile = _assert_support_ticket_access(ticket)
    _ensure_initial_message_record(ticket)

    message_filters = _support_message_read_filters(user, profile, mark_read=True)
    if not message_filters:
        return {"updated": 0}

    message_filters["support_ticket"] = ticket.name
    message_names = frappe.get_all(SUPPORT_MESSAGE_DOCTYPE, filters=message_filters, pluck="name")
    read_field = "read_by_staff" if _can_access_internal_workspace(user) else "read_by_customer"

    for message_name in message_names:
        frappe.db.set_value(SUPPORT_MESSAGE_DOCTYPE, message_name, read_field, 1, update_modified=False)

    frappe.db.commit()
    return {"updated": len(message_names)}


@frappe.whitelist()
def add_support_ticket_reply(ticket_id=None, message=None, **kwargs):
    ticket_id = ticket_id or kwargs.get("name")
    message = (message or kwargs.get("reply") or kwargs.get("description") or "").strip()
    attachment = kwargs.get("attachment") or kwargs.get("file_url") or kwargs.get("file") or ""

    if not ticket_id:
        frappe.throw("ticket_id is required")
    if not message and not attachment:
        frappe.throw("message or attachment is required")
    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, _profile = _assert_support_ticket_access(ticket)

    if ticket.status in ["Closed", "Cancelled"]:
        frappe.throw("This support ticket is closed. Please reopen it before replying.")

    _ensure_initial_message_record(ticket)
    is_internal_user = _can_access_internal_workspace(user)
    if is_internal_user:
        _require_capability(
            "can_reply_support_tickets",
            "You do not have permission to reply to support tickets.",
        )
    sender_type = "Support" if is_internal_user else "Customer"
    _create_support_message(ticket, message=message, attachment=attachment, sender_type=sender_type)

    if not is_internal_user and ticket.status in ["Resolved", "Waiting for Customer"]:
        ticket.status = "Open"
        ticket.closed_on = None
    elif is_internal_user and ticket.status == "Open":
        ticket.status = "In Progress"
    ticket.save(ignore_permissions=True)

    if is_internal_user and ticket.customer_profile:
        _create_customer_notification(
            customer_profile=ticket.customer_profile,
            title="Support reply received",
            message=message or "OMC support added an attachment to your ticket.",
            notification_type="Support",
            reference_doctype="OMC Support Ticket",
            reference_name=ticket.name,
        )

    frappe.db.commit()
    return {"updated": True, "ticket": _support_ticket_to_dict(ticket), "message": "Support reply added."}


@frappe.whitelist()
def update_support_ticket_status(ticket_id=None, status=None, remarks=None, **kwargs):
    ticket_id = ticket_id or kwargs.get("name")
    allowed_statuses = {"Open", "In Progress", "Waiting for Customer", "Resolved", "Closed", "Cancelled"}

    if not ticket_id:
        frappe.throw("ticket_id is required")
    if not status:
        frappe.throw("status is required")
    if status not in allowed_statuses:
        frappe.throw("status must be one of: Open, In Progress, Waiting for Customer, Resolved, Closed, Cancelled")
    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, _profile = _assert_support_ticket_access(ticket)
    if not _can_access_internal_workspace(user):
        frappe.throw(
            "You do not have permission to update support ticket status.",
            frappe.PermissionError,
        )
    _require_capability(
        "can_update_support_ticket_status",
        "You do not have permission to update support ticket status.",
    )

    old_status = ticket.status or ""
    ticket.status = status
    ticket.closed_on = frappe.utils.now_datetime() if status in ["Resolved", "Closed", "Cancelled"] else None

    if remarks:
        _ensure_initial_message_record(ticket)
        _create_support_message(ticket, message=remarks, sender_type="Support")

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
    return {"updated": True, "old_status": old_status, "ticket": _support_ticket_to_dict(ticket), "message": "Support ticket status updated."}


@frappe.whitelist()
def assign_support_ticket(ticket_id=None, assigned_to=None, **kwargs):
    ticket_id = ticket_id or kwargs.get("name")
    assigned_to = (assigned_to or kwargs.get("user") or "").strip()

    if not ticket_id:
        frappe.throw("ticket_id is required")
    if not assigned_to:
        frappe.throw("assigned_to is required")
    if not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)
    _assert_support_assignee_allowed(assigned_to)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, _profile = _assert_support_ticket_access(ticket)
    if not _can_access_internal_workspace(user):
        frappe.throw(
            "You do not have permission to assign support tickets.",
            frappe.PermissionError,
        )
    _require_capability(
        "can_assign_support_tickets",
        "You do not have permission to assign support tickets.",
    )

    previous_user = ticket.assigned_to or ""
    ticket.assigned_to = assigned_to
    if ticket.status == "Open":
        ticket.status = "In Progress"
    ticket.save(ignore_permissions=True)

    _ensure_initial_message_record(ticket)
    assignment_note = f"Ticket assigned to {assigned_to}."
    if previous_user and previous_user != assigned_to:
        assignment_note = f"Ticket transferred from {previous_user} to {assigned_to}."
    _create_support_message(ticket, message=assignment_note, sender_type="System")

    frappe.db.commit()
    return {"updated": True, "ticket": _support_ticket_to_dict(ticket), "message": assignment_note}
