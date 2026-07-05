# OMC Flutter App Backend API Contract

This document lists the Frappe API methods expected by the Flutter mobile app.

The app is backend-ready but keeps safe empty fallbacks where data is not available yet. Backend methods should return stable JSON shapes so Flutter screens can render without feature-specific parsing changes.

## Base API

Flutter calls Frappe methods through:

```text
/api/method/<method_name>
Base URL is configured in:

lib/core/config/api_config.dart

Default environments currently point to:

https://erp.omchouse.com
General Response Rule

Preferred response shape:

{
  "message": {
    "items": []
  }
}

For list endpoints, Flutter currently accepts these shapes:

{
  "message": []
}
{
  "message": {
    "items": []
  }
}
{
  "message": {
    "data": []
  }
}
{
  "data": []
}

Module-specific aliases such as leads, customers, tasks, documents, and payments are also accepted in their related repositories.

Auth Methods
lead_app.lead_app.apis.login

Used by:

lib/features/auth/data/auth_repository.dart

Expected purpose:

login user with email/password
return authenticated user/session payload compatible with Frappe auth flow
lead_app.lead_app.apis.google_mobile_login

Expected purpose:

login/signup with Google mobile token
return authenticated user/session payload
lead_app.lead_app.apis.sign_up

Expected purpose:

create/register customer user
return success message and/or user data
Home Dashboard
lead_app.lead_app.apis.get_dashboard_data

Used by:

lib/features/home/data/home_dashboard_repository.dart

Preferred response:

{
  "message": {
    "open_services": 0,
    "documents": 0,
    "payments_due": 0,
    "notifications": 0,
    "recent_activity": []
  }
}

Notes:

Keep missing values safe as 0 or empty arrays.
recent_activity should include short user-facing activity rows.
Service Catalogue
omc_app.api.mobile.get_service_catalogue

Used by:

lib/features/service_catalogue/data/service_catalogue_repository.dart

Preferred response:

{
  "message": {
    "services": [
      {
        "id": "tax-filing",
        "title": "Tax Filing",
        "description": "Professional tax filing support",
        "category": "Tax",
        "icon": "receipt"
      }
    ]
  }
}

Notes:

If backend catalogue is unavailable, Flutter can use local asset catalogue.
IDs must be stable because routes use service ID.
Service Requests
lead_app.lead_app.apis.create_service

Used by:

lib/features/service_requests/data/service_request_repository.dart

Expected purpose:

create a new service request/case from mobile app
support attached files uploaded through Frappe upload_file

Preferred response:

{
  "message": {
    "name": "SR-0001",
    "status": "Open"
  }
}
omc_app.api.mobile.get_service_cases

Used by:

lib/features/service_requests/data/service_case_repository.dart

Preferred response:

{
  "message": {
    "cases": [
      {
        "name": "SR-0001",
        "title": "Tax Filing",
        "status": "Open",
        "service": "Tax Filing",
        "created_at": "2026-07-05",
        "updated_at": "2026-07-05"
      }
    ]
  }
}
omc_app.api.mobile.get_service_case

Expected purpose:

return one service case detail by ID

Preferred request argument:

{
  "case_id": "SR-0001"
}

Preferred response:

{
  "message": {
    "name": "SR-0001",
    "title": "Tax Filing",
    "status": "Open",
    "service": "Tax Filing",
    "description": "",
    "timeline": [],
    "attachments": []
  }
}
Documents
omc_app.api.mobile.get_documents

Used by:

lib/features/documents/data/documents_repository.dart

Preferred response:

{
  "message": {
    "documents": [
      {
        "name": "DOC-0001",
        "title": "Invoice.pdf",
        "type": "PDF",
        "status": "Available",
        "file_url": "/files/invoice.pdf",
        "created_at": "2026-07-05"
      }
    ]
  }
}
Payments
omc_app.api.mobile.get_payments

Used by:

lib/features/payments/data/payments_repository.dart

Preferred response:

{
  "message": {
    "payments": [
      {
        "name": "PAY-0001",
        "title": "Tax Filing Fee",
        "amount": 10000,
        "currency": "PKR",
        "status": "Pending",
        "due_date": "2026-07-10"
      }
    ]
  }
}
Profile
omc_app.api.mobile.get_profile

Used by:

lib/features/profile/data/profile_repository.dart

Preferred response:

{
  "message": {
    "full_name": "Customer Name",
    "email": "customer@example.com",
    "phone": "",
    "avatar_url": "",
    "customer_id": ""
  }
}
Notifications
omc_app.api.mobile.get_notifications

Used by:

lib/features/notifications/data/notifications_repository.dart

Preferred response:

{
  "message": {
    "notifications": [
      {
        "name": "NOTIF-0001",
        "title": "Request updated",
        "message": "Your service request has been updated.",
        "is_read": false,
        "created_at": "2026-07-05"
      }
    ]
  }
}
Internal Workspace
omc_app.api.mobile.get_internal_workspace_summary

Used by:

lib/features/internal_workspace/data/internal_workspace_repository.dart

Preferred response:

{
  "message": {
    "open_leads": 0,
    "active_customers": 0,
    "pending_tasks": 0,
    "payments_due": 0
  }
}
Leads
omc_app.api.mobile.get_leads

Used by:

lib/features/leads/data/leads_repository.dart

Preferred response:

{
  "message": {
    "leads": [
      {
        "name": "LEAD-0001",
        "title": "Website Inquiry",
        "customer_name": "Customer Name",
        "status": "New",
        "phone": "",
        "email": "",
        "source": "Website",
        "created_at": "2026-07-05"
      }
    ]
  }
}

Accepted status examples:

New
Contacted
Qualified
Converted
Lost
Customers
omc_app.api.mobile.get_customers

Used by:

lib/features/customers/data/customers_repository.dart

Preferred response:

{
  "message": {
    "customers": [
      {
        "name": "CUST-0001",
        "customer_name": "Customer Name",
        "company_name": "Company Pvt Ltd",
        "status": "Active",
        "phone": "",
        "email": "",
        "city": "Karachi",
        "last_activity": "2026-07-05"
      }
    ]
  }
}

Accepted status examples:

Active
Inactive
Prospect
Blocked
Tasks
omc_app.api.mobile.get_tasks

Used by:

lib/features/tasks/data/tasks_repository.dart

Preferred response:

{
  "message": {
    "tasks": [
      {
        "name": "TASK-0001",
        "subject": "Follow up with customer",
        "status": "Open",
        "priority": "Normal",
        "due_date": "2026-07-10",
        "assigned_to": "user@example.com"
      }
    ]
  }
}

Accepted field aliases:

title: subject, title, task_name
due date: exp_end_date, due_date, date, deadline
assigned user: assigned_to, owner
Uploads
upload_file

Used for service request attachments.

Expected behavior:

upload file to Frappe
return file URL or file document name
uploaded file references can be passed to service request create method
Future Detail Methods

Recommended backend methods for upcoming detail screens:

omc_app.api.mobile.get_lead
omc_app.api.mobile.get_customer
omc_app.api.mobile.get_task

Recommended request shape:

{
  "name": "DOCUMENT-ID"
}

Recommended response shape:

{
  "message": {
    "name": "DOCUMENT-ID",
    "title": "",
    "status": "",
    "details": {},
    "timeline": [],
    "attachments": []
  }
}
Backend Implementation Notes
Keep method names centralized and stable.
Return empty arrays instead of null for list data.
Return empty strings instead of null for display labels where practical.
Avoid exposing raw internal errors to mobile users.
Use permission checks on every method.
Filter records by authenticated user/customer unless the user has internal roles.
Keep date strings ISO-like where possible, for example 2026-07-05.
