# OMC House Mobile App + Frappe Backend

A full-stack OMC House customer service platform with a Flutter mobile/web frontend and a custom Frappe backend.

The project provides one connected system for:

* Public guest browsing
* Customer signup and approval
* Service catalogue
* Service request creation
* Document upload and review
* Service tracking
* Payment receipt/status tracking
* Notifications
* Support tickets
* Customer profile/settings
* Tax calculator
* Expense tracker
* Internal OMC staff workspace

The backend is built as a standalone-first Frappe app with OMC-owned DocTypes. ERPNext or other external integrations can be added later without making the mobile app directly dependent on ERPNext objects.

---

## Project Overview

OMC App is designed to digitize OMC House customer service operations.

A customer can open the app, explore services, create an account, wait for OMC approval, submit a service request, upload required documents, track the request, view payment/receipt status, receive notifications, and contact support.

OMC staff can use backend/internal workflows to review customers, approve profiles, manage service cases, review documents, review payments, handle support tickets, manage leads, and follow tasks.

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
  pubspec.yaml

backend_omc_app/
  apps/
    omc_app/
      pyproject.toml
      README.md
      omc_app/
        hooks.py
        api/
          mobile.py
          secured_mobile.py
          guest_session.py
          expense.py
          service_templates.py
        omc_app/
          doctype/
          report/
          workspace/
        fixtures/
        public/
  frappe-bench/
    Local Frappe bench runtime folder

docs/
  Project notes, generated docs, testing plans, and supporting documentation
```

Root-level purpose:

| Path                            | Purpose                                                   |
| ------------------------------- | --------------------------------------------------------- |
| `omc_app/`                      | Flutter mobile/web frontend                               |
| `backend_omc_app/apps/omc_app/` | Repo-tracked custom Frappe backend app                    |
| `backend_omc_app/frappe-bench/` | Local Frappe bench runtime                                |
| `docs/`                         | Documentation, plans, testing notes, and generated guides |

---

## Tech Stack

### Frontend

* Flutter
* Dart
* Riverpod
* GoRouter
* Dio
* Flutter Secure Storage
* Shared Preferences
* File Picker
* Image Picker
* URL Launcher
* Flutter SVG
* Cached Network Image
* FL Chart
* Package Info Plus
* Flutter launcher icons
* Flutter native splash

### Backend

* Frappe Framework
* Python
* Custom Frappe app: `omc_app`
* Frappe whitelisted APIs
* Custom OMC DocTypes
* Frappe file upload endpoint
* MariaDB/MySQL through Frappe bench
* Redis/queue workers through Frappe bench

---

## High-Level Architecture

```text
Flutter App
  |
  | HTTPS / Frappe REST / Frappe method APIs
  v
Frappe Backend Site
  |
  | Custom whitelisted methods
  v
OMC Backend App: omc_app
  |
  | Controllers, permission checks, DocTypes
  v
OMC-owned business data
  |
  | Optional future mappings
  v
ERPNext / external systems / reports / integrations
```

Important architecture rule:

```text
The Flutter app can hide or lock UI, but protected business actions must also be blocked by backend permission checks.
```

---

## Product Flow

```text
Guest opens app
  -> Browses public services and content
  -> Uses tax calculator/support contact
  -> Tries protected customer action
  -> Login/signup prompt
  -> User signs up
  -> Backend creates pending OMC Customer Profile
  -> OMC team reviews user
  -> OMC team approves profile
  -> Customer gets full access
  -> Customer creates service request
  -> Customer uploads documents
  -> OMC staff processes case
  -> Customer tracks timeline/status
  -> Payment receipt tracking if enabled
  -> Customer receives notifications
  -> Support ticket if needed
  -> Service completed
```

---

## User Types and Access

### Guest

A guest is a user who opens the app without logging in.

Guest users can access:

* Home
* Services
* Service detail
* Knowledge/news
* Tax calculator
* Support/contact information
* Login/signup

Guest users cannot access:

* Service request creation
* My Services / tracking
* Customer dashboard
* Documents
* Payments
* Customer-specific notifications
* Support ticket detail
* Expense tracker
* Internal workspace

Guest route access is handled in Flutter routing and protected actions are also checked by backend APIs.

---

### Pending User

A pending user is someone who has signed up but is not yet approved by OMC.

Signup creates or updates:

* Frappe `User`
* `OMC Customer Profile`
* Customer preferences

Initial profile status:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending users can log in, but protected customer features remain locked. If they try to open protected routes, the app can show an under-review screen.

---

### Approved Customer

An approved customer has:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can:

* View customer dashboard
* Create service requests
* Track My Services
* Upload service documents
* View documents
* View payment status
* Upload payment receipts if enabled
* Create support tickets
* View notifications
* Use profile/settings
* Use tax calculator
* Use expense tracker
* Read knowledge/news content

---

### Internal OMC Staff

Internal users are controlled by Frappe roles and backend capability checks.

Supported internal role groups include:

* System Manager
* OMC Admin
* OMC Manager
* OMC Support Agent
* OMC Document Reviewer
* OMC Finance Reviewer
* OMC Consultant
* OMC Business Partner
* OMC Tax Associate

Internal staff can access modules depending on their role:

| Role Type                                         | Typical Access                                |
| ------------------------------------------------- | --------------------------------------------- |
| OMC Admin / System Manager                        | Full internal access                          |
| OMC Manager                                       | Service case and operations management        |
| OMC Support Agent                                 | Support tickets, replies, leads where allowed |
| OMC Document Reviewer                             | Document review                               |
| OMC Finance Reviewer                              | Payment/receipt review                        |
| OMC Consultant / Business Partner / Tax Associate | Internal/field workspace where allowed        |

---

## Frontend Features

### Authentication

* Login with Frappe email/password
* Signup for new customers/applicants
* Under-review route for pending users
* Guest mode
* Secure local session storage
* Session restore and backend validation
* Logout
* Google login method exists but backend blocks it until verified server-side token validation is implemented

### Home

* Main app entry after splash
* Public/guest-friendly access
* Customer shortcuts after approval
* Service, track, documents, support, profile, settings, and utility navigation

### Services

* Public service catalogue
* Service detail page
* Backend service catalogue API
* Service metadata support:

  * Title
  * Category
  * Description
  * Fee label
  * Government fee label
  * Estimated duration/completion time
  * Wizard type
  * Required documents
  * Featured service flag

### Service Requests / My Services

* Approved customers can create service requests
* Request route: `/services/:serviceId/request`
* Track route: `/track` and `/my-services`
* Service case detail route: `/my-services/:caseId`
* Backend links requests to customer profile and selected service
* Backend returns service status, customer action, timeline, documents, and progress data

### Documents

* Document list
* Document detail
* Service document upload
* Backend file upload through Frappe `upload_file`
* Document status and review flow
* Reviewer roles can update document status through secured backend methods

### Payments

* Payment list
* Payment detail
* Payment receipt upload
* Receipt review flow
* Payment status tracking
* Payment feature can be enabled/disabled from backend configuration

The current payment flow is designed for payment due/status and receipt/proof tracking, not direct payment gateway collection by default.

### Knowledge / News / FAQs

* Knowledge list
* Knowledge detail
* Public content access
* App banners API
* FAQs API
* Useful for tax updates, service explainers, announcements, and help content

### Notifications

* Notification list
* Notification detail
* Mark single notification as read
* Mark all notifications as read
* Register/unregister push token
* Notifications can link to service, document, payment, or support references

### Support

* Public support/contact screen
* Support config API
* Support ticket creation for approved customers
* Support ticket list/detail
* Customer replies
* Staff status updates where permitted

### Profile

* Customer profile view
* Contact/profile update
* Fields include:

  * Name
  * Email
  * Phone
  * WhatsApp
  * Company name
  * CNIC
  * NTN
  * Register-as type
  * Customer type
  * Address
  * Education/experience/remarks where supported
  * Customer status
  * Approval status

### Settings

* Customer preferences
* Notification preference toggles
* Theme preference
* Language preference
* Persistent backend-backed preferences

### Tax Calculator

* Public/guest-friendly tax estimate feature
* Backend method returns estimate output
* Intended as a quick utility, not final verified filing advice

### Expense Tracker

* Customer utility module
* Expense categories
* Expense entries
* Create/update/delete entry
* Expense summary
* Available for approved customers or internal users according to route capability checks

### Internal Workspace

* Internal workspace route: `/internal-workspace`
* Visible only when backend capabilities allow it
* Internal modules include:

  * Workspace summary
  * Leads
  * Customers
  * Tasks
  * Open service cases
  * Documents
  * Payments
  * Support tickets
  * Notifications

---

## Flutter App Structure

```text
omc_app/lib/
  app/
    router.dart
    main_shell.dart
    providers.dart
    theme.dart

  core/
    config/
      api_config.dart
      env.dart
    network/
      dio_client.dart
      frappe_client.dart
      api_error.dart
    storage/
      secure_storage_service.dart
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

The frontend follows a feature-first structure. Shared config, networking, secure storage, and reusable widgets live under `core`. Product modules live under `features`.

---

## Routing Summary

Main app routes include:

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

Routing behavior:

* Unauthenticated users are redirected to login except public/auth routes.
* Guest users can access public routes only.
* Pending users are sent to under-review for blocked protected routes.
* Approved customers can access customer modules.
* Internal users can access internal routes based on backend capabilities.

---

## Backend Overview

The backend app is a custom Frappe app named:

```text
omc_app
```

Backend package metadata:

```text
App name: omc_app
Description: OMC mobile backend app for ERPNext/Frappe
Python: >=3.10
Build backend: flit_core
```

Important backend files:

```text
backend_omc_app/apps/omc_app/pyproject.toml
backend_omc_app/apps/omc_app/README.md
backend_omc_app/apps/omc_app/omc_app/hooks.py
backend_omc_app/apps/omc_app/omc_app/api/mobile.py
backend_omc_app/apps/omc_app/omc_app/api/secured_mobile.py
backend_omc_app/apps/omc_app/omc_app/api/guest_session.py
backend_omc_app/apps/omc_app/omc_app/api/expense.py
backend_omc_app/apps/omc_app/omc_app/api/service_templates.py
backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/
```

The backend exposes mobile APIs through:

```text
/api/method/omc_app.api.<module>.<method>
```

File uploads use:

```text
/api/method/upload_file
```

---

## Backend API Surface

### Auth / Session

```text
login
logout
omc_app.api.mobile.sign_up
omc_app.api.mobile.google_mobile_login
omc_app.api.mobile.get_session_user
```

### Guest

```text
omc_app.api.guest_session.create_guest_session
omc_app.api.guest_session.update_guest_activity
```

### Profile / Settings

```text
omc_app.api.mobile.get_profile
omc_app.api.mobile.update_profile
omc_app.api.mobile.update_contact_info
omc_app.api.mobile.get_settings_preferences
omc_app.api.mobile.update_settings_preferences
```

### Dashboard / Services

```text
omc_app.api.mobile.get_dashboard_data
omc_app.api.mobile.get_service_catalogue
omc_app.api.mobile.get_service_detail
omc_app.api.service_templates.get_service_template
omc_app.api.mobile.create_service
```

### Service Cases

```text
omc_app.api.mobile.get_service_cases
omc_app.api.mobile.get_service_case
omc_app.api.secured_mobile.get_service_cases
omc_app.api.secured_mobile.get_service_case
omc_app.api.secured_mobile.update_service_case_status
```

### Documents

```text
omc_app.api.mobile.get_documents
omc_app.api.mobile.get_document
omc_app.api.mobile.upload_service_document
omc_app.api.secured_mobile.update_service_document_status
```

### Payments

```text
omc_app.api.mobile.get_payments
omc_app.api.mobile.get_payment
omc_app.api.mobile.upload_payment_receipt
omc_app.api.mobile.review_payment_receipt
```

### Knowledge / Banners / FAQs

```text
omc_app.api.mobile.get_knowledge
omc_app.api.mobile.get_knowledge_article
omc_app.api.mobile.get_app_banners
omc_app.api.mobile.get_faqs
```

### Notifications

```text
omc_app.api.mobile.get_notifications
omc_app.api.mobile.get_notification_detail
omc_app.api.mobile.mark_notification_read
omc_app.api.mobile.mark_all_notifications_read
omc_app.api.mobile.register_push_token
omc_app.api.mobile.unregister_push_token
```

### Support

```text
omc_app.api.mobile.get_support_config
omc_app.api.mobile.create_support_ticket
omc_app.api.mobile.get_support_tickets
omc_app.api.mobile.get_support_ticket
omc_app.api.mobile.add_support_ticket_reply
omc_app.api.mobile.update_support_ticket_status
```

### Expense Tracker

```text
omc_app.api.expense.get_expense_categories
omc_app.api.expense.get_expense_entries
omc_app.api.expense.create_expense_entry
omc_app.api.expense.update_expense_entry
omc_app.api.expense.delete_expense_entry
omc_app.api.expense.get_expense_summary
```

### Internal Workspace

```text
omc_app.api.mobile.get_internal_workspace_summary
omc_app.api.mobile.create_lead
omc_app.api.mobile.get_leads
omc_app.api.mobile.get_lead
omc_app.api.mobile.get_customers
omc_app.api.mobile.get_customer
omc_app.api.mobile.get_tasks
omc_app.api.mobile.get_task
```

### Tax

```text
omc_app.api.mobile.calculate_tax
```

---

## Secured API Overrides

The backend uses `override_whitelisted_methods` in hooks to route selected customer-facing methods through secured implementations.

Current secured overrides include:

```text
omc_app.api.mobile.get_service_cases
  -> omc_app.api.secured_mobile.get_service_cases

omc_app.api.mobile.get_service_case
  -> omc_app.api.secured_mobile.get_service_case

omc_app.api.mobile.update_service_case_status
  -> omc_app.api.secured_mobile.update_service_case_status

omc_app.api.mobile.update_service_document_status
  -> omc_app.api.secured_mobile.update_service_document_status
```

This keeps frontend method names stable while enforcing backend-owned security and tracking logic.

---

## Main Backend DocTypes

Important OMC-owned DocTypes include:

| DocType                       | Purpose                                               |
| ----------------------------- | ----------------------------------------------------- |
| OMC Customer Profile          | Customer/applicant profile, user link, approval state |
| OMC Customer Preference       | Notification/theme/language preferences               |
| OMC Service                   | Service catalogue master                              |
| OMC Service Category          | Service grouping/category                             |
| OMC Service Required Document | Required/optional document rules per service          |
| OMC Service Request           | Customer service case/request                         |
| OMC Service Timeline          | Service progress and activity timeline                |
| OMC Service Document          | Uploaded/requested customer documents                 |
| OMC Service Payment           | Payment due, receipt, and review status               |
| OMC Notification              | Customer/internal notifications                       |
| OMC Push Token                | Mobile push notification token storage                |
| OMC Support Ticket            | Customer support ticket                               |
| OMC Support Reply             | Support ticket conversation replies                   |
| OMC Support Channel           | Support contact channels                              |
| OMC Support Topic             | Support categories                                    |
| OMC Lead                      | Internal CRM/lead record                              |
| OMC Task                      | Internal task/follow-up record                        |
| OMC Expense Entry             | Customer expense tracker entry                        |

---

## Backend Data Flows

### Signup Flow

1. Mobile app sends signup data.
2. Backend validates email.
3. Backend creates or reuses Frappe `User`.
4. Backend assigns applicant role if the role exists.
5. Backend creates or updates `OMC Customer Profile`.
6. Backend saves supported fields such as phone, WhatsApp, CNIC, NTN, company, register-as type, address, education, experience, and remarks.
7. Backend sets profile as pending review.
8. Backend creates/loads customer preferences.
9. Backend returns user, profile, access state, capabilities, and preferences.

### Login Flow

1. App calls standard Frappe `login`.
2. Frappe returns session/cookie.
3. App stores session securely.
4. App calls `get_session_user`.
5. Backend returns roles, access state, and capability flags.
6. Router opens or blocks routes based on capabilities.

### Approved Customer Flow

1. OMC staff approves profile in backend.
2. Profile becomes active/approved.
3. Backend capability response allows customer actions.
4. Customer can create requests, upload documents, track cases, view payments, create support tickets, and use customer modules.

### Service Request Flow

1. Customer opens Services.
2. Customer selects a service.
3. Customer creates a service request.
4. Backend validates approved customer access.
5. Backend creates `OMC Service Request`.
6. Backend links request to customer profile and service.
7. Backend creates timeline/tracking data.
8. Customer tracks request from Track/My Services.

### Document Flow

1. Backend defines required documents per service.
2. Customer uploads file.
3. Frappe stores file through `upload_file`.
4. Backend creates/updates `OMC Service Document`.
5. Staff reviews document.
6. Customer sees approved/rejected/submitted status.

### Payment Flow

1. Backend creates payment/due record.
2. Customer views payment details.
3. Customer uploads receipt/proof if enabled.
4. Backend links receipt to payment record.
5. Staff reviews receipt.
6. Customer sees updated payment status.

### Support Flow

1. Customer opens Support.
2. Customer creates support ticket.
3. Backend links ticket to customer and optional service request.
4. Customer/staff add replies.
5. Staff updates status.
6. Customer sees latest ticket state.

### Internal Workspace Flow

1. Internal user logs in.
2. Backend checks internal roles.
3. Backend returns internal capability flags.
4. User opens internal workspace.
5. Staff can view/manage leads, customers, tasks, service cases, documents, payments, and support modules according to role.

---

## Environment Configuration

### Backend URL

The Flutter app reads backend URL from:

```bash
--dart-define=OMC_API_BASE_URL=<url>
```

Defaults:

```text
development: http://127.0.0.1:8000
production:  https://erp.omchouse.com
```

### Environment

Set environment with:

```bash
--dart-define=OMC_ENV=development
```

or:

```bash
--dart-define=OMC_ENV=production
```

Production builds should use HTTPS.

---

## Local Development

### Frontend

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
```

Run Flutter app against local backend:

```bash
cd omc_app
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

### Backend

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

---

## Running in Development Mode

Start backend:

```bash
cd backend_omc_app/frappe-bench
bench start
```

Start Flutter frontend:

```bash
cd omc_app
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

---

## Running in Production Mode

Build Android APK:

```bash
cd omc_app
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Build Android App Bundle:

```bash
cd omc_app
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Production requirements:

* Backend URL must use HTTPS.
* Mock/preview-only behavior must not be used as production flow.
* Android signing must be configured before release.
* Backend smoke tests should pass.
* Customer approval and role-gated workflows should be tested end-to-end.

---

## Android Build Outputs

Debug APK:

```bash
cd omc_app
flutter build apk --debug
```

Release APK:

```bash
cd omc_app
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Release app bundle:

```bash
cd omc_app
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Output folders:

```text
omc_app/build/app/outputs/flutter-apk/
omc_app/build/app/outputs/bundle/release/
```

---

## Testing Checklist

### Authentication and Access

* Wrong login shows clean error.
* Guest mode opens allowed public routes.
* Guest cannot create service request.
* Signup creates pending user/profile.
* Pending user is redirected to under-review for protected routes.
* Approved customer can access customer modules.
* Internal workspace is blocked for normal customers.
* Internal workspace works for allowed staff roles.

### Customer Flow

* Service catalogue loads.
* Service detail opens.
* Approved customer creates service request.
* Created service appears in Track/My Services.
* Service case detail opens.
* Timeline/progress displays correctly.

### Documents

* Required documents show correctly.
* Approved customer can upload document.
* Guest/pending user cannot upload document.
* Staff can review document where role allows.
* Customer sees approved/rejected/submitted state.

### Payments

* Payment list/detail loads if enabled.
* Receipt upload works if enabled.
* Staff can review receipt where role allows.
* Customer sees latest payment status.
* Payment module remains clean if disabled.

### Support

* Support config loads for guest/customer.
* Approved customer can create support ticket.
* Ticket detail/replies work.
* Staff update flow works where role allows.

### Notifications

* Notification list loads.
* Detail opens.
* Mark one read works.
* Mark all read works.
* Invalid/missing action route does not crash app.

### Settings/Profile

* Profile loads.
* Profile/contact update works.
* Preferences load.
* Preferences update works.
* Logout works.

---

## Recommended Validation Commands

Frontend:

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
```

Backend:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local execute omc_app.api.mobile.get_session_user
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
bench --site omc.local execute omc_app.api.mobile.get_support_config
```

Production build:

```bash
cd omc_app
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

---

## Current Project Status

Implemented/currently present in repo:

* Flutter app structure
* Feature-first frontend modules
* Guest mode routing
* Under-review route
* Capability-based route guards
* Frappe backend app package
* Mobile API configuration
* Signup with pending review profile creation
* Backend access state and capability checks
* OMC internal role groups
* Secured mobile method overrides for selected service/document operations
* Service catalogue API integration
* Customer service request flow foundation
* Document upload/review flow foundation
* Payment receipt/status tracking foundation
* Support ticket foundation
* Notifications foundation
* Tax calculator
* Expense tracker API integration
* Internal workspace foundation
* Android release build path

Still required before production release:

* Full local and production smoke testing
* Real backend data verification
* HTTPS production backend verification
* Android release signing validation
* Final APK/AAB validation
* Role-specific internal workspace testing
* Customer approval flow testing with real users
* Document/payment/support end-to-end testing

---

## Known Notes

* Google login is intentionally blocked by backend until verified Google token validation is implemented server-side.
* Pending users can exist and log in, but protected customer actions are blocked until approval.
* Internal access is controlled by backend role/capability checks.
* Payment module is receipt/status tracking by default, not direct payment gateway collection.
* Frappe backend is standalone-first and does not require ERPNext DocTypes for core mobile app operation.
* Future ERPNext integration can be added through optional mappings/settings.

---

## Roadmap / Future Scope

* Production deployment documentation
* CI for Flutter analyze/test/build
* Backend tests for service request, document upload, payment receipt, and support flows
* More API response examples
* Demo/seed data for service catalogue
* Screenshots/GIFs for client demo
* Role matrix documentation
* Email notifications for signup and approval
* Subscription/package flow if required
* ERPNext/external integration if required
* Advanced reporting for staff/internal workspace

---

## License

MIT
