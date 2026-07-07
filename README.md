# OMC House Mobile App + Frappe Backend

A full-stack OMC House customer service and internal workspace system.

This repository contains two connected applications:

1. `omc_app` - a premium Flutter mobile app for OMC House customers and internal users.
2. `backend_omc_app` - a custom Frappe backend app that exposes mobile APIs, stores OMC-owned business data, and supports service operations.

The project is designed for a production-style OMC House workflow where customers can browse services, submit service requests, upload documents, track progress, manage payments, receive notifications, and contact support. Internal users can use workspace modules for leads, customers, tasks, service cases, payments, and support operations.

---

## Repository Structure

```text
omc_app/
  Flutter mobile application
  lib/
    app/
    core/
    features/
  assets/
  android/
  ios/
  README.md

backend_omc_app/
  Frappe backend workspace
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
      README.md
  frappe-bench/
    Local bench runtime folder, not the source of truth for Git commits

docs/
  Project notes, roadmaps, and supporting documentation
```

Root-level purpose:

- `omc_app` is the mobile frontend.
- `backend_omc_app/apps/omc_app` is the repo-tracked custom Frappe backend app.
- `backend_omc_app/frappe-bench` is used locally to run Frappe/bench.
- `backend_omc_app/apps/sync_apps.sh` syncs custom apps from the local bench into the repo-tracked apps folder before backend commits.

---

## Product Overview

OMC House app is built to digitize customer-facing service delivery and internal follow-up operations.

Main product goals:

- Give customers a simple mobile entry point for OMC services.
- Let customers submit service requests with documents and contact details.
- Keep every service request trackable from mobile.
- Allow OMC staff to review service cases, documents, payments, support tickets, leads, customers, and tasks from backend/mobile workspace views.
- Keep the backend standalone-first using OMC-owned DocTypes, while staying compatible with future ERPNext/Frappe integrations.

---

## Tech Stack

### Mobile App

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio
- Flutter Secure Storage
- Shared Preferences
- File Picker
- Image Picker
- URL Launcher
- Flutter SVG
- Cached Network Image
- FL Chart
- Flutter launcher icons
- Flutter native splash

### Backend

- Frappe Framework
- Python
- Custom Frappe app: `omc_app`
- Frappe whitelisted API methods under `omc_app.api.mobile`
- Frappe DocTypes for service operations, customers, payments, documents, support, notifications, leads, and tasks
- Frappe file upload endpoint for attachments

---

## High-Level Architecture

```text
Flutter App
  |
  | HTTPS / Frappe REST
  |
Frappe Backend
  |
  | Custom whitelisted methods
  |
OMC App DocTypes
  |
  | Optional future mappings
  |
ERPNext / external systems
```

The Flutter app does not directly depend on ERPNext objects. It talks to the custom Frappe app through mobile-friendly API methods. The backend keeps OMC app-owned DocTypes as the primary data model.

---

## Mobile App Features

### Authentication

- Login with Frappe email/password credentials.
- Signup flow for new customer profile creation.
- Secure session storage using Flutter Secure Storage.
- Session cookie and API token support through Dio interceptors.
- Invalid login handling with clear `Wrong email or password` message.
- Optional Google login flag exists, but backend currently blocks it until verified server-side token validation is implemented.

### Home Dashboard

- Customer dashboard entry point.
- Quick service access.
- Recent activity/service status summary.
- Navigation to services, documents, payments, support, notifications, profile, and settings.

### Service Catalogue

- Browse OMC services.
- Service detail screen.
- Featured services and category-style presentation.
- Supports local JSON service catalogue.
- Optional backend service catalogue mode using `OMC_USE_BACKEND_SERVICE_CATALOGUE`.
- Service metadata supports title, category, description, pricing label, government fee label, estimated duration, completion time, wizard type, and required documents.

### Service Requests / My Services

- Create service request from a selected service.
- Submit request title, description, priority, customer/contact data, and selected service.
- Track submitted service cases.
- View service case detail.
- Add service-related documents.
- Backend can update service case status, notes, expected completion, and timeline.

### Documents

- Customer-visible document list.
- Document detail view.
- Upload service documents against a service request.
- Document review status support: pending, uploaded, approved, rejected.
- Document visibility control from backend through `visible_to_customer`.

### Payments

- Customer-visible payment list.
- Payment detail view.
- Payment due status, amount, currency, due date, receipt, and remarks.
- Receipt upload support.
- Internal receipt review endpoint support.
- Payment status flow supports pending, receipt submitted, under review, paid, rejected, and cancelled.

### Tax Calculator

- Mobile tax estimate screen.
- Backend method `calculate_tax` returns mobile-friendly tax calculation output.
- Current backend implementation is safe/basic and can later be replaced with configurable tax slab DocTypes.

### Expense Tracker

- Mobile expense tracking UI module.
- Built as a customer utility feature.
- Can be extended later to persist expense data in backend DocTypes.

### Knowledge / News

- Knowledge list screen.
- Knowledge article detail screen.
- Backend currently exposes knowledge-style content using service records.
- Useful for tax updates, service explainers, help content, and OMC announcements.

### Notifications

- Notification list and detail views.
- Mark single notification as read.
- Mark all notifications as read.
- Register/unregister push token endpoints exist on backend.
- Notification records can be linked to service requests, documents, payments, or support references.

### Support

- Create support ticket.
- Support ticket list/detail APIs.
- Add support ticket replies.
- Internal status update endpoint.
- Support tickets can reference service requests and customer profiles.

### Profile

- Customer profile view.
- Update profile fields.
- Update contact information.
- Profile fields include name, email, phone, company name, CNIC, NTN, customer status, and approval status.

### Settings

- Customer preferences API.
- Update notification preference toggles.
- Service update, document reminder, payment alert, tax alert, email notification, WhatsApp notification, theme, and language preferences.

### Internal Workspace

Internal workspace is intended for authorized internal OMC users.

Backend access is protected by role check. Current internal workspace role set is `System Manager`.

Internal modules include:

- Workspace summary
- Leads
- Customers
- Tasks
- Payments due
- Open service cases
- Pending documents
- Support tickets
- Unread notifications

---

## Flutter App Structure

```text
omc_app/lib/
  app/
    router.dart
    main_shell.dart
    theme.dart
    providers.dart

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
      shared premium widgets

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

The Flutter app follows a feature-first structure. Shared configuration, networking, storage, and reusable UI components live under `core`. Route-level screens and business modules live under `features`.

---

## Routing Summary

Main routes include:

```text
/
/login
/signup
/home
/services
/services/:serviceId
/services/:serviceId/request
/my-services
/my-services/:caseId
/dashboard
/documents
/documents/:documentId
/payments
/payments/:paymentId
/leads
/leads/:leadId
/customers
/customers/:customerId
/tasks
/tasks/:taskId
/knowledge
/knowledge/:articleId
/notifications
/notifications/:notificationId
/profile
/settings
/expense-tracker
/support-tickets/:ticketId
/internal-workspace
```

Unauthenticated users are redirected to login. Authenticated users are redirected away from login/signup to home.

---

## Backend Overview

The backend app is a custom Frappe app named `omc_app`.

Backend app metadata:

```text
App name: omc_app
App title: OMC App
Description: OMC mobile backend app for ERPNext/Frappe
Module: OMC App
```

Important backend files:

```text
backend_omc_app/apps/omc_app/pyproject.toml
backend_omc_app/apps/omc_app/omc_app/hooks.py
backend_omc_app/apps/omc_app/omc_app/api/mobile.py
backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/
backend_omc_app/apps/sync_apps.sh
```

The backend exposes mobile methods through:

```text
/api/method/omc_app.api.mobile.<method_name>
```

File uploads use standard Frappe upload:

```text
/api/method/upload_file
```

---

## Main Backend DocTypes

Current important OMC-owned DocTypes include:

| DocType | Purpose |
|---|---|
| OMC Service | Service catalogue master |
| OMC Service Category | Service grouping/category |
| OMC Service Required Document | Required/optional document rules per service |
| OMC Service Request | Customer service case/request |
| OMC Service Timeline | Service activity/timeline updates |
| OMC Service Document | Uploaded/requested documents |
| OMC Service Payment | Payment dues, status, and receipts |
| OMC Customer Profile | Customer profile linked to Frappe User |
| OMC Customer Preference | Customer app/notification preferences |
| OMC Notification | Customer/internal notifications |
| OMC Push Token | Mobile push token storage |
| OMC Support Ticket | Customer support ticket |
| OMC Support Reply | Support ticket conversation replies |
| OMC Lead | Internal CRM lead |
| OMC Task | Internal task/follow-up item |

---

## Backend API Surface

The Flutter app centralizes backend method names in:

```text
omc_app/lib/core/config/api_config.dart
```

Important backend methods include:

### Auth / User

```text
login
logout
omc_app.api.mobile.sign_up
omc_app.api.mobile.google_mobile_login
omc_app.api.mobile.get_session_user
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
omc_app.api.mobile.create_service
omc_app.api.mobile.get_service_cases
omc_app.api.mobile.get_service_case
omc_app.api.mobile.update_service_case_status
omc_app.api.mobile.add_service_case_comment
```

### Documents

```text
omc_app.api.mobile.get_documents
omc_app.api.mobile.get_document
omc_app.api.mobile.upload_service_document
omc_app.api.mobile.update_service_document_status
```

### Payments

```text
omc_app.api.mobile.get_payments
omc_app.api.mobile.get_payment
omc_app.api.mobile.upload_payment_receipt
omc_app.api.mobile.review_payment_receipt
```

### Knowledge / Notifications

```text
omc_app.api.mobile.get_knowledge
omc_app.api.mobile.get_knowledge_article
omc_app.api.mobile.get_notifications
omc_app.api.mobile.get_notification_detail
omc_app.api.mobile.mark_notification_read
omc_app.api.mobile.mark_all_notifications_read
omc_app.api.mobile.register_push_token
omc_app.api.mobile.unregister_push_token
```

### Support

```text
omc_app.api.mobile.create_support_ticket
omc_app.api.mobile.get_support_tickets
omc_app.api.mobile.get_support_ticket
omc_app.api.mobile.add_support_ticket_reply
omc_app.api.mobile.update_support_ticket_status
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

## Backend Data Flow

### Signup Flow

1. Mobile app sends signup data.
2. Backend creates or reuses a Frappe `User`.
3. Backend creates or updates `OMC Customer Profile`.
4. Backend creates/loads customer preferences.
5. Backend returns profile and preference data to the app.

### Login Flow

1. Mobile app calls Frappe `login` with email/password.
2. Frappe returns session data/cookie.
3. App stores session cookie securely.
4. Dio attaches the session cookie/API token to future requests.
5. Router allows authenticated navigation.

### Service Request Flow

1. Customer selects a service.
2. App submits request details to `create_service`.
3. Backend creates `OMC Service Request`.
4. Backend creates a timeline entry.
5. Backend can create document/payment/notification records as needed.
6. App uploads attachments against the created request.
7. Customer tracks the request from My Services.

### Document Flow

1. Backend defines required documents for a service.
2. Customer uploads files from mobile.
3. Files are linked to `OMC Service Document` or `OMC Service Request` depending on flow.
4. Internal team reviews and updates document status.
5. Customer sees the updated status.

### Payment Flow

1. Backend creates `OMC Service Payment` records against a service request.
2. Customer views payment due details.
3. Customer uploads receipt/reference.
4. Internal team reviews receipt and updates status.
5. Customer sees payment status in mobile app.

### Internal Workspace Flow

1. Internal user opens workspace.
2. Backend verifies role access.
3. User can view operational summaries, leads, customers, and tasks.
4. Internal APIs can create leads and update operational records.

---

## Environment Configuration

### Supported environments

```text
development
staging
production
```

Set environment with:

```bash
--dart-define=OMC_ENV=production
```

Default environment is `development`.

### Backend URL

Set backend URL with:

```bash
--dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Default URLs:

```text
development: http://127.0.0.1:8000
staging:     https://erp.omchouse.com
production:  https://erp.omchouse.com
```

Production requires HTTPS. The app throws an error if a production backend URL is not HTTPS.

### Local-only flags

Mock auth:

```bash
--dart-define=OMC_USE_MOCK_AUTH=true
```

Service preview data:

```bash
--dart-define=OMC_USE_SERVICE_PREVIEW=true
```

Backend service catalogue:

```bash
--dart-define=OMC_USE_BACKEND_SERVICE_CATALOGUE=true
```

Google login flag:

```bash
--dart-define=OMC_ENABLE_GOOGLE_LOGIN=true
```

Production builds force mock/preview behavior off where guarded by environment logic.

---

## Mobile Setup

From repo root:

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Run against local Frappe backend:

```bash
cd omc_app
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

Run against production backend:

```bash
cd omc_app
flutter run --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

---

## Android Build

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

APK output:

```text
omc_app/build/app/outputs/flutter-apk/
```

AAB output:

```text
omc_app/build/app/outputs/bundle/release/
```

For production signing, configure:

```text
omc_app/android/key.properties
```

Use `android/key.properties.example` as the template if available.

---

## Backend Setup / Local Bench Notes

The backend is a Frappe app. Local execution happens through `backend_omc_app/frappe-bench`.

Typical local commands:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local clear-cache
bench start
```

Install app on site if needed:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local install-app omc_app
bench --site omc.local migrate
```

Run API smoke checks:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local execute omc_app.api.mobile.get_settings_preferences
bench --site omc.local execute omc_app.api.mobile.get_service_cases
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
```

---

## Backend Sync Workflow

The repo-tracked backend app lives under:

```text
backend_omc_app/apps/omc_app
```

The local bench runtime app may be edited under:

```text
backend_omc_app/frappe-bench/apps/omc_app
```

Before committing backend changes, sync bench apps into the repo-tracked apps folder:

```bash
cd backend_omc_app/apps
./sync_apps.sh
```

The sync script:

- Reads custom apps from `backend_omc_app/frappe-bench/apps`.
- Skips standard apps such as `frappe`, `erpnext`, `payments`, and `hrms`.
- Syncs only custom Frappe apps with `pyproject.toml` or `setup.py` and matching package folder.
- Uses `rsync --delete` to keep the repo copy aligned with bench app source.
- Excludes virtualenvs, node modules, caches, build folders, and Python bytecode.

---

## Developer Workflow

### Flutter work

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
```

Use feature-first organization:

```text
features/<module>/data
features/<module>/domain
features/<module>/presentation
```

Keep reusable widgets in:

```text
core/widgets
features/crm/presentation/widgets
```

### Backend work

Edit in local bench when using Frappe tools:

```bash
cd backend_omc_app/frappe-bench/apps/omc_app
```

After backend changes:

```bash
cd backend_omc_app/apps
./sync_apps.sh
```

Then verify from repo root:

```bash
cd ../..
git status --short
git diff --stat
```

---

## Current Project Status

Current state:

- Flutter app structure is implemented.
- Major mobile modules are present and routed.
- Frappe backend app is present and repo-tracked.
- Mobile API method names are centralized in `ApiConfig`.
- Backend mobile API implementation is centralized in `omc_app.api.mobile`.
- OMC-owned DocTypes exist for customer profiles, services, service requests, documents, payments, notifications, support, leads, and tasks.
- Secure networking/session flow is implemented on the Flutter side.
- File upload flow is implemented through Frappe upload APIs.
- Android release build path is planned.
- Final production release still requires live backend smoke testing, HTTPS verification, release signing, and production app bundle validation.

Status label:

```text
Development update: Complete
Production release: Pending final smoke test + release build validation
```

---

## Production Smoke Checklist

Before release, verify:

- Valid login succeeds against production backend.
- Invalid login shows clear wrong email/password error.
- Signup creates Frappe User and OMC Customer Profile correctly.
- Profile loads after login.
- Settings preferences load and update.
- Service catalogue loads.
- Service detail opens.
- Service request creation works.
- Created service appears in My Services.
- Service case detail opens.
- Document upload works and links to the correct record.
- Documents list/detail load correctly.
- Payments list/detail load correctly.
- Receipt upload works.
- Notifications list handles empty and non-empty states.
- Mark notification read works.
- Support ticket creation works.
- Internal workspace is blocked for normal customers.
- Internal workspace works for authorized internal role.
- Android release APK/AAB builds with production flags.
- Production backend URL uses HTTPS.

Recommended commands:

```bash
cd omc_app
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

Backend smoke:

```bash
cd backend_omc_app/frappe-bench
bench --site omc.local execute omc_app.api.mobile.get_settings_preferences
bench --site omc.local execute omc_app.api.mobile.get_service_cases
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
```

---

## Known Implementation Notes

- Google login is intentionally guarded until backend verifies Google ID tokens server-side.
- Mock auth and preview data are local-only helpers and should not be used as production flows.
- Production backend URL must use HTTPS.
- Frappe backend should remain standalone-first and should not require ERPNext DocTypes for core mobile app operation.
- ERPNext integration can be added later through optional mappings/settings.
- Internal workspace access currently uses `System Manager` role enforcement in backend.
- Android is the primary release target. iOS requires macOS/Xcode signing and archive workflow.

---

## Suggested Future Improvements

- Add screenshots or GIFs for app screens.
- Add API response examples for every mobile endpoint.
- Add seed/demo data for OMC Service catalogue.
- Add backend tests for service request, document upload, payment receipt, and notification flows.
- Add CI for Flutter analyze/test/build.
- Add CI for Python linting and Frappe app import checks.
- Add environment-specific deployment documentation.
- Add role matrix for customer/internal users.
- Add production deployment guide for Frappe backend.

---

## License

MIT
