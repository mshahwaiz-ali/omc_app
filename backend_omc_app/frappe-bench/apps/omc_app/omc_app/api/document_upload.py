import frappe

from omc_app.api.mobile import (
    _assert_approved_customer,
    _clean_file_reference,
    _create_service_timeline_entry,
    _current_user,
    _document_extension,
    _find_uploaded_file,
)


ALLOWED_DOCUMENT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png", "doc", "docx"}
MAX_DOCUMENT_SIZE_BYTES = 10 * 1024 * 1024
MAX_FILES_PER_CASE = 20


def _validate_uploaded_document(service_case, attachment):
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
        return clean_attachment, None

    file_extension = _document_extension(
        uploaded_file.file_name or uploaded_file.file_url or clean_attachment
    )
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

    allowed_doctypes = {"", "OMC Service Request", "OMC Service Document"}
    if uploaded_file.attached_to_doctype and uploaded_file.attached_to_doctype not in allowed_doctypes:
        frappe.throw("Uploaded file is attached to another document.", frappe.PermissionError)

    if uploaded_file.attached_to_name and uploaded_file.attached_to_name not in {
        service_case.name,
        uploaded_file.attached_to_name,
    }:
        frappe.throw("Uploaded file is attached to another service request.", frappe.PermissionError)

    return uploaded_file.file_url or clean_attachment, uploaded_file


@frappe.whitelist()
def upload_service_document(**kwargs):
    """Create a service-document record for an already uploaded File.

    This endpoint intentionally inserts OMC Service Document without setting its
    Attach field first. Frappe's Attach field hook can try to recreate the file
    from a URL path during insert/update. We link the existing File record and
    then write the attachment URL directly with frappe.db.set_value.
    """

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
        frappe.throw(
            "You do not have permission to upload documents for this service request",
            frappe.PermissionError,
        )

    attachment, uploaded_file = _validate_uploaded_document(service_case, attachment)

    doc = frappe.new_doc("OMC Service Document")
    doc.service_request = service_case.name
    doc.document_title = document_title
    doc.document_type = document_type
    doc.status = "Uploaded"
    doc.visible_to_customer = 1
    doc.uploaded_by = _current_user()
    doc.uploaded_on = frappe.utils.now_datetime()
    doc.remarks = remarks
    doc.insert(ignore_permissions=True)

    if uploaded_file:
        frappe.db.set_value(
            "File",
            uploaded_file.name,
            {
                "attached_to_doctype": "OMC Service Document",
                "attached_to_name": doc.name,
                "attached_to_field": "attachment",
                "is_private": 1,
            },
            update_modified=False,
        )

    frappe.db.set_value(
        "OMC Service Document",
        doc.name,
        "attachment",
        attachment,
        update_modified=False,
    )
    doc.attachment = attachment

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
            "file_url": attachment or "",
            "attachment": attachment or "",
            "uploaded_on": str(doc.uploaded_on) if doc.uploaded_on else "",
            "uploaded_by": doc.uploaded_by or "",
            "remarks": doc.remarks or "",
        },
    }
