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
    return _message(
        "Signup endpoint is ready. Full customer registration will be enabled after backend setup."
    )


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
    return _message("Contact update endpoint is ready.", updated=False)


@frappe.whitelist()
def get_dashboard_data():
    return {
        "open_services": 0,
        "documents": 0,
        "payments_due": 0,
        "notifications": 0,
        "recent_activity": [],
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
def mark_notification_read(notification_id=None):
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
        frappe.throw("You do not have permission to update this notification", frappe.PermissionError)

    if not profile and notification.recipient_user and notification.recipient_user != user:
        frappe.throw("You do not have permission to update this notification", frappe.PermissionError)

    notification.is_read = 1
    notification.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "name": notification.name,
        "marked": True,
        "is_read": int(notification.is_read or 0),
        "message": "Notification marked as read.",
    }


@frappe.whitelist(allow_guest=True)
def get_knowledge():
    return _items_response("articles")


@frappe.whitelist(allow_guest=True)
def get_knowledge_article(article_id=None):
    return {
        "name": article_id or "",
        "title": "",
        "content": "",
        "created_at": "",
    }


@frappe.whitelist(allow_guest=True)
def create_support_ticket(**kwargs):
    return _message("Support ticket endpoint is ready.", created=False)


@frappe.whitelist()
def get_settings_preferences():
    return {
        "notifications_enabled": True,
        "email_updates_enabled": True,
        "theme": "system",
    }


@frappe.whitelist()
def update_settings_preferences(**kwargs):
    return _message("Settings preferences endpoint is ready.", updated=False)


@frappe.whitelist()
def get_internal_workspace_summary():
    return {
        "leads": 0,
        "customers": 0,
        "tasks": 0,
        "open_services": 0,
    }


@frappe.whitelist()
def get_leads():
    return _items_response("leads")


@frappe.whitelist()
def get_lead(lead_id=None):
    return {"name": lead_id or "", "title": "", "status": ""}


@frappe.whitelist()
def get_customers():
    return _items_response("customers")


@frappe.whitelist()
def get_customer(customer_id=None):
    return {"name": customer_id or "", "customer_name": "", "email": "", "phone": ""}


@frappe.whitelist()
def get_tasks():
    return _items_response("tasks")


@frappe.whitelist()
def get_task(task_id=None):
    return {"name": task_id or "", "title": "", "status": "", "due_date": ""}


@frappe.whitelist(allow_guest=True)
def calculate_tax(**kwargs):
    return {
        "taxable_income": 0,
        "tax": 0,
        "effective_rate": 0,
        "breakdown": [],
    }
