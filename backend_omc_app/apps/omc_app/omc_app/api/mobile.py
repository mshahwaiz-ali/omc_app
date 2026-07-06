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


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    email = (kwargs.get("email") or kwargs.get("user") or "").strip().lower()
    password = kwargs.get("password") or kwargs.get("new_password")
    full_name = (kwargs.get("full_name") or kwargs.get("name") or "").strip()
    phone = (kwargs.get("phone") or kwargs.get("mobile") or "").strip()
    company_name = (kwargs.get("company_name") or kwargs.get("company") or "").strip()
    cnic = (kwargs.get("cnic") or "").strip()
    ntn = (kwargs.get("ntn") or "").strip()

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
            "company_name": profile.company_name or "",
            "cnic": profile.cnic or "",
            "ntn": profile.ntn or "",
            "customer_status": profile.customer_status or "",
            "approval_status": profile.approval_status or "",
        },
        "preferences": _settings_preferences_to_dict(preferences),
    }


@frappe.whitelist()
def get_session_user():
    user = _current_user()
    return {
        "user": user,
        "is_guest": user == "Guest",
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
        return {
            "full_name": "",
            "email": "",
            "phone": "",
            "avatar_url": "",
            "customer_id": "",
            "customer_status": "Guest",
            "approval_status": "",
        }

    profile = _get_customer_profile_for_user(user)

    return {
        "full_name": profile.full_name or "",
        "email": profile.email or user,
        "phone": profile.phone or "",
        "avatar_url": "",
        "customer_id": profile.name,
        "customer_status": profile.customer_status or "",
        "approval_status": profile.approval_status or "",
        "company_name": profile.company_name or "",
        "cnic": profile.cnic or "",
        "ntn": profile.ntn or "",
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

    if user != "Guest":
        profile = _get_customer_profile_for_user(user)

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
            "icon",
            "estimated_duration",
            "base_price",
            "currency",
            "is_featured",
        ],
        order_by="sort_order asc, modified desc",
    )

    return {
        "services": [
            {
                "id": service.service_id or service.name,
                "name": service.name,
                "title": service.title,
                "description": service.description or "",
                "category": service.category or "",
                "icon": service.icon or "",
                "estimated_duration": service.estimated_duration or "",
                "base_price": service.base_price or 0,
                "currency": service.currency or "PKR",
                "is_featured": int(service.is_featured or 0),
            }
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

    return {
        "name": service.name,
        "id": service.service_id or service.name,
        "title": service.title,
        "description": service.description or "",
        "category": service.category or "",
        "icon": service.icon or "",
        "estimated_duration": service.estimated_duration or "",
        "base_price": service.base_price or 0,
        "currency": service.currency or "PKR",
        "is_featured": int(service.is_featured or 0),
        "required_documents": [],
    }


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
    profile = _get_customer_profile_for_user()

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


@frappe.whitelist()
def get_service_cases():
    profile = _get_customer_profile_for_user()

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


@frappe.whitelist()
def get_service_case(case_id=None):
    if not case_id:
        frappe.throw("case_id is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    profile = _get_customer_profile_for_user()
    doc = frappe.get_doc("OMC Service Request", case_id)

    if profile and doc.customer_profile and doc.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this service case", frappe.PermissionError)

    return {
        "name": doc.name,
        "title": doc.title or doc.service_title or "Service Request",
        "status": doc.status or "",
        "priority": doc.priority or "",
        "service": doc.service_title or doc.service or "",
        "description": doc.description or "",
        "created_at": str(doc.creation.date()) if doc.creation else "",
        "updated_at": str(doc.modified.date()) if doc.modified else "",
        "expected_completion_date": str(doc.expected_completion_date) if doc.expected_completion_date else "",
        "timeline": _get_service_timeline(doc.name),
        "attachments": _get_service_documents(doc.name),
    }


@frappe.whitelist()
def add_service_case_comment(case_id=None, message=None):
    if not case_id:
        frappe.throw("case_id is required")

    if not message:
        frappe.throw("message is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    profile = _get_customer_profile_for_user()
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



@frappe.whitelist()
def upload_service_document(**kwargs):
    case_id = kwargs.get("case_id") or kwargs.get("service_request")
    document_title = kwargs.get("document_title") or kwargs.get("title") or "Uploaded Document"
    document_type = kwargs.get("document_type") or kwargs.get("type") or ""
    attachment = kwargs.get("attachment") or kwargs.get("file_url") or kwargs.get("file")

    if not case_id:
        frappe.throw("case_id is required")

    if not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service case not found", frappe.DoesNotExistError)

    profile = _get_customer_profile_for_user()
    service_case = frappe.get_doc("OMC Service Request", case_id)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this service case", frappe.PermissionError)

    doc = frappe.new_doc("OMC Service Document")
    doc.service_request = service_case.name
    doc.document_title = document_title
    doc.document_type = document_type
    doc.attachment = attachment or ""
    doc.status = kwargs.get("status") or "Uploaded"
    doc.visible_to_customer = 1
    doc.remarks = kwargs.get("remarks") or ""
    doc.insert(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Document Uploaded",
        title="Document Uploaded",
        description=f"{document_title} uploaded.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "name": doc.name,
        "case_id": service_case.name,
        "title": doc.document_title,
        "file_url": doc.attachment or "",
        "status": doc.status,
        "uploaded": True,
        "message": "Service document uploaded.",
    }



@frappe.whitelist()
def update_service_document_status(document_id=None, status=None, remarks=None):
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
    profile = _get_customer_profile_for_user()

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

    profile = _get_customer_profile_for_user()
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
    }


@frappe.whitelist()
def get_payments():
    profile = _get_customer_profile_for_user()

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

    profile = _get_customer_profile_for_user()
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

    profile = _get_customer_profile_for_user()
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this payment", frappe.PermissionError)

    payment.receipt_attachment = receipt_attachment
    payment.payment_reference = payment_reference or payment.payment_reference
    payment.remarks = remarks or payment.remarks
    payment.status = "Paid"
    payment.save(ignore_permissions=True)

    _create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title="Payment Receipt Uploaded",
        description=remarks or f"Receipt uploaded for {payment.payment_title or 'payment'}.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "name": payment.name,
        "case_id": payment.service_request,
        "status": payment.status,
        "receipt_url": payment.receipt_attachment or "",
        "uploaded": True,
        "message": "Payment receipt uploaded.",
    }


@frappe.whitelist()
def get_notifications():
    user = _current_user()
    profile = _get_customer_profile_for_user()

    filters = {
        "visible_to_customer": 1,
    }

    if profile:
        filters["customer_profile"] = profile.name
    elif user and user != "Guest":
        filters["recipient_user"] = user
    else:
        return {"notifications": []}

    notifications = frappe.get_all(
        "OMC Notification",
        filters=filters,
        fields=[
            "name",
            "title",
            "message",
            "notification_type",
            "reference_doctype",
            "reference_name",
            "is_read",
            "creation",
            "read_on",
        ],
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
                "is_read": int(notification.is_read or 0),
                "created_at": str(notification.creation) if notification.creation else "",
                "read_on": str(notification.read_on) if notification.read_on else "",
            }
            for notification in notifications
        ]
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
    profile = _get_customer_profile_for_user()

    if profile and notification.customer_profile and notification.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    if not profile and notification.recipient_user and notification.recipient_user != user:
        frappe.throw("You do not have permission to access this notification", frappe.PermissionError)

    return {
        "name": notification.name,
        "title": notification.title or "",
        "message": notification.message or "",
        "type": notification.notification_type or "",
        "reference_doctype": notification.reference_doctype or "",
        "reference_name": notification.reference_name or "",
        "is_read": int(notification.is_read or 0),
        "created_at": str(notification.creation) if notification.creation else "",
        "read_on": str(notification.read_on) if notification.read_on else "",
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
    profile = _get_customer_profile_for_user()

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



def _support_ticket_to_dict(ticket):
    return {
        "name": ticket.name,
        "subject": ticket.subject or "",
        "message": ticket.message or "",
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
    }


@frappe.whitelist()
def get_support_tickets():
    user = _current_user()
    profile = _get_customer_profile_for_user()

    filters = {}

    if profile:
        filters["customer_profile"] = profile.name
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

    user = _current_user()
    profile = _get_customer_profile_for_user()

    if profile and ticket.customer_profile and ticket.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if not profile and user != "Guest" and ticket.raised_by and ticket.raised_by != user:
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

    if user == "Guest":
        frappe.throw("You do not have permission to access this support ticket", frappe.PermissionError)

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
    preferences.notifications_enabled = 1
    preferences.email_updates_enabled = 1
    preferences.payment_reminders_enabled = 1
    preferences.service_updates_enabled = 1
    preferences.theme = "system"
    preferences.language = "en"
    preferences.insert(ignore_permissions=True)
    frappe.db.commit()

    return preferences


def _settings_preferences_to_dict(preferences):
    return {
        "notifications_enabled": bool(preferences.notifications_enabled),
        "email_updates_enabled": bool(preferences.email_updates_enabled),
        "payment_reminders_enabled": bool(preferences.payment_reminders_enabled),
        "service_updates_enabled": bool(preferences.service_updates_enabled),
        "theme": preferences.theme or "system",
        "language": preferences.language or "en",
    }


@frappe.whitelist()
def get_settings_preferences():
    profile = _get_customer_profile_for_user()
    preferences = _get_customer_preferences(profile)

    return _settings_preferences_to_dict(preferences)


@frappe.whitelist()
def update_settings_preferences(**kwargs):
    profile = _get_customer_profile_for_user()
    preferences = _get_customer_preferences(profile)

    allowed_check_fields = [
        "notifications_enabled",
        "email_updates_enabled",
        "payment_reminders_enabled",
        "service_updates_enabled",
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
    if not task_id:
        frappe.throw("task_id is required")

    if not frappe.db.exists("OMC Task", task_id):
        frappe.throw("Task not found", frappe.DoesNotExistError)

    task = frappe.get_doc("OMC Task", task_id)
    return {"task": _task_to_dict(task)}


@frappe.whitelist(allow_guest=True)
def calculate_tax(**kwargs):
    return {
        "taxable_income": 0,
        "tax": 0,
        "effective_rate": 0,
        "breakdown": [],
    }
