# OMC App

OMC App is a full-stack customer service and internal operations platform for OMC House. It combines a Flutter mobile/web frontend with a Frappe backend app so customers can browse services, create service requests, upload documents, track progress, handle payment receipt tracking, receive notifications, and contact support. OMC staff use backend/internal workflows for customer profiles, service cases, documents, payments, leads, tasks, and support operations.

---

## Overview

The project is designed around a backend-driven business workflow:

```text
Guest explores app
  -> Signup
  -> OMC profile pending review
  -> OMC team approval
  -> Approved customer access
  -> Service request
  -> Documents
  -> Payment/receipt tracking
  -> Timeline/notifications
  -> Completion/support follow-up
```

The frontend does not depend directly on ERPNext objects. It talks to the custom Frappe app through mobile-friendly API methods. The backend owns the OMC data model through custom DocTypes and can later integrate with ERPNext or other systems if required.

---

## What This Project Includes

- Flutter mobile/web frontend
- Custom Frappe backend app
- Admin/internal workspace foundation
- Customer service portal
- Guest mode and public browsing
- Signup, login, approval, and role-based access
- Backend-driven service catalogue
- Service request tracking
- Document upload and review flow
- Payment due and receipt tracking flow
- Notifications and support tickets
- Knowledge/news/public content hooks
- Tax calculator
- Personal expense tracker
- Settings/profile management

---

## Backend

Backend source lives in:

```text
backend_omc_app/apps/omc_app
```

Local Frappe bench runtime is expected under:

```text
backend_omc_app/frappe-bench
```

The backend is a custom Frappe app named `omc_app`. Mobile methods are exposed through:

```text
/api/method/omc_app.api.mobile.<method_name>
```

Some secured/internal methods are exposed through dedicated modules such as:

```text
/api/method/omc_app.api.secured_mobile.<method_name>
/api/method/omc_app.api.guest_session.<method_name>
/api/method/omc_app.api.expense.<method_name>
/api/method/omc_app.api.service_templates.<method_name>
```

File uploads use standard Frappe upload:

```text
/api/method/upload_file
```

### Backend Responsibilities

- Frappe/ERP-style backend operations
- OMC-owned DocTypes
- Mobile API surface
- Customer profile creation and approval state
- Service catalogue and service request handling
- Required document rules
- Customer document upload and review
- Payment due/receipt tracking
- Notifications and push token registration
- Support tickets and replies
- Leads, customers, tasks, and internal workspace data
- Server-side permission checks for protected actions

### Key Backend DocTypes

| DocType | Purpose |
|---|---|
| OMC Customer Profile | Customer/applicant identity, approval state, linked user data |
| OMC Customer Preference | Customer notification, theme, and language preferences |
| OMC Service | Backend-managed service catalogue |
| OMC Service Category | Service grouping/category |
| OMC Service Required Document | Service-wise required/optional document rules |
| OMC Service Request | Customer service case/request |
| OMC Service Timeline | Status and activity tracking |
| OMC Service Document | Uploaded or requested service documents |
| OMC Service Payment | Payment due, receipt upload, and review status |
| OMC Notification | Customer/internal notifications |
| OMC Push Token | Push notification device token storage |
| OMC Support Ticket | Customer support ticket |
| OMC Support Reply | Support conversation replies |
| OMC Support Channel | Support contact channels |
| OMC Support Topic | Support categories |
| OMC Lead | Internal lead/CRM record |
| OMC Task | Internal task/follow-up record |
| OMC Expense Entry | Customer expense tracker records |

---

## Frontend

Frontend source lives in:

```text
omc_app
```

The Flutter app uses a feature-first structure:

```text
omc_app/lib/
  app/
    router.dart
    main_shell.dart
    providers.dart
    theme.dart
  core/
    config/
    network/
    storage/
    widgets/
  features/
    auth/
    home/
    service_catalogue/
    service_requests/
    documents/
    payments/
    dashboard/
    leads/
    customers/
    tasks/
    tax_calculator/
    expense_tracker/
    knowledge/
    notifications/
    profile/
    settings/
    support/
    internal_workspace/
    splash/
```

### Frontend Responsibilities

- Flutter app UI and navigation
- Guest/customer/admin flows
- Login/signup/under-review screens
- Service catalogue and service detail
- Service request draft and tracking screens
- Dashboard
- Documents and payment receipt screens
- Support tickets
- Knowledge/news pages
- Tax calculator
- Expense tracker
- Profile/settings
- Internal workspace screens for allowed roles

### Main Routes

```text
/
/login
/signup
/under-review
/home
/services
/services/:serviceId
/services/:serviceId/request
/track
/my-services
/my-services/:caseId
/dashboard
/documents
/documents/:documentId
/payments
/payments/:paymentId
/knowledge
/knowledge/:articleId
/notifications
/notifications/:notificationId
/support
/support-tickets/:ticketId
/tax-calculator
/expense-tracker
/profile
/settings
/internal-workspace
/leads
/leads/:leadId
/customers
/customers/:customerId
/tasks
/tasks/:taskId
```

---

## Access Model

### Guest

Allowed public routes:

- Home
- Services catalogue
- Service detail
- Knowledge/news
- Tax calculator
- Support contact screen

Blocked actions:

- Create service request
- Track personal service cases
- Upload/view customer documents
- View customer dashboard
- View payments
- Create customer-specific support tickets
- Access internal workspace

### Pending Signup User

Signup creates or updates a Frappe `User` and `OMC Customer Profile`. The profile starts as:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending users can log in and see limited access, but protected customer actions are blocked until approval.

### Approved Customer

Approved customer state:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can create service requests, upload documents, track service cases, view payments, upload receipts when enabled, create support tickets, view notifications, use profile/settings, and use customer utilities.

### Internal / Staff Roles

The backend defines capability groups for internal roles such as:

- System Manager
- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Consultant
- OMC Business Partner
- OMC Tax Associate

Internal access is protected server-side. UI hiding alone is not treated as security.

---

## Key Features

### Authentication and Approval

- Standard Frappe login via `/api/method/login`
- Signup creates user/profile records
- Signup role fields such as customer, consultant, business partner, and tax associate
- Pending review access state
- Under-review screen for blocked protected actions
- Approved customer access unlocks service workflows
- Google login is intentionally blocked until verified token validation is implemented server-side

### Guest Mode

- Guest users can explore public content
- Guest sessions/activity can be tracked without allowing sensitive actions
- Guest route access is restricted by router and backend capability checks

### Service Catalogue

- Backend-driven `OMC Service` records
- Service title, description, category, pricing label, completion time, wizard type, and required documents
- Public catalogue access
- Service detail pages

### Service Requests

- Approved customers can create service requests
- Requests link to customer profile and selected service
- Backend creates timeline entries
- Customers can track cases from My Services/Track
- Staff can update service status where role allows

### Documents

- Required document rules per service
- File upload through Frappe `upload_file`
- Service document records linked to service/customer data
- Document status support: pending, uploaded, approved, rejected
- Reviewer roles can approve/reject where allowed

### Payments

- Payment module is receipt/status tracking by default, not direct payment gateway collection
- Backend creates payment dues against service requests
- Customer can upload receipt/proof when enabled
- Staff can review and mark receipt status
- Supported flow includes pending, receipt submitted, under review, paid, rejected, and cancelled

### Support

- Public support contact screen
- Customer support ticket creation for approved customers
- Ticket detail/reply flow
- Staff status updates
- Configurable support topics/channels

### Notifications

- Notification list/detail
- Mark one/all as read
- Link notifications to service, document, payment, or support references
- Push token registration/unregistration endpoints

### Knowledge, News, Banners, FAQs

- Public content routes
- Backend methods for knowledge articles, banners, FAQs, and public content
- Designed for service education, tax updates, announcements, and help content

### Tax Calculator

- Public/guest-friendly tax estimate feature
- Backend method returns estimate output
- Intended as a utility, not final filing advice

### Expense Tracker

- Customer utility for income/expense entries and summary
- Backend API methods exist for categories, entries, create/update/delete, and summary

### Profile and Settings

- Profile view/update
- Contact info update
- Customer preferences for notifications, theme, and language

### Internal Workspace

- Internal summary and operational queues
- Leads, customers, tasks, payments, documents, service cases, support tickets, and unread notifications
- Role-gated access from backend capabilities

---

## Benefits / USPs

### For Customers

- One mobile portal for OMC services
- Clear required document visibility
- Service status tracking
- Receipt upload and payment status tracking
- Notifications and support history
- Tax/expense utility tools
- Better self-service experience than WhatsApp/manual follow-up

### For OMC Team

- Centralized customer profile records
- Structured service request lifecycle
- Documents tied to cases
- Payment receipt review trail
- Support tickets instead of scattered messages
- Internal role-based workspace foundation
- Backend-driven services/content without app redeploy for routine updates

---

## Architecture

```text
Flutter App
  |
  | HTTPS / Frappe REST / Frappe method APIs
  v
Frappe Backend App: omc_app
  |
  | Whitelisted mobile APIs + secured APIs
  v
OMC-owned DocTypes
  |
  | Optional future mappings
  v
ERPNext / external systems / integrations
```

Important principles:

- Backend-driven business rules
- Server-side permission enforcement
- Feature-first frontend structure
- OMC-owned DocTypes as source of truth
- Local/mock flags only for development
- HTTPS required for production backend

---

## Local Development

### Frontend Setup

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
```

Run app against local backend:

```bash
cd omc_app
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

### Backend Setup

Typical local bench commands:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local clear-cache
bench start
```

Install backend app on site if needed:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local install-app omc_app
bench --site omc.local migrate
```

Backend smoke checks:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local execute omc_app.api.mobile.get_session_user
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
```

---

## Running App in Dev Mode

```bash
cd omc_app
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

Default development backend URL:

```text
http://127.0.0.1:8000
```

---

## Running App in Production Mode

```bash
cd omc_app
flutter run --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Build release APK:

```bash
cd omc_app
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Build release app bundle:

```bash
cd omc_app
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Production rules:

- Use HTTPS backend URL
- Disable mock/preview data paths
- Configure Android signing before release
- Validate backend smoke tests before publishing

---

## Testing

Recommended test order:

1. Local readiness
2. Wrong login
3. Guest mode
4. Signup as customer
5. Pending user restrictions
6. Backend approval
7. Approved customer login
8. Service catalogue
9. Service detail
10. Service request creation
11. My Services / Track
12. Documents upload/review
13. Support ticket flow
14. Notifications
15. Payments if enabled
16. Settings/profile
17. Internal staff role checks
18. Final analyze/test/backend smoke

Frontend checks:

```bash
cd omc_app
flutter analyze
flutter test
```

Backend checks:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local execute omc_app.api.mobile.get_session_user
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
```

---

## Repository Structure

```text
omc_app/
  Flutter mobile/web application
  lib/
    app/
    core/
    features/
  assets/
  android/
  ios/

backend_omc_app/
  apps/
    sync_apps.sh
    omc_app/
      omc_app/
        api/
        omc_app/doctype/
        public/
        fixtures/
        hooks.py
      pyproject.toml
  frappe-bench/
    Local bench runtime folder

docs/
  Project notes, roadmaps, testing plan, and generated README documents
```

---

## Backend Sync Workflow

Repo-tracked backend app:

```text
backend_omc_app/apps/omc_app
```

Local bench app:

```text
backend_omc_app/frappe-bench/apps/omc_app
```

After backend changes in the local bench, sync into repo-tracked app before commit:

```bash
cd backend_omc_app/apps
./sync_apps.sh
```

Then verify:

```bash
git status --short
git diff --stat
```

---

## Roadmap / Future Scope

- Production smoke test completion
- Android release signing and AAB validation
- More backend tests for service/document/payment/support flows
- CI for Flutter analyze/test/build
- CI for Python/Frappe import checks
- Seed/demo service catalogue data
- Expanded API examples
- Production deployment guide
- Role matrix documentation
- Screenshots/GIFs for client demos
- Optional ERPNext/external system integrations
- Subscription/package flow if required by business
- Email notifications for signup, approval, and review outcomes

---

## Current Status

Development implementation is substantially complete. Production release still requires final smoke testing, backend validation, HTTPS verification, release signing, and final app build validation.
