# OMC House Mobile App + Frappe Backend — Safely Merged Roadmap

Last reviewed from source files: **2026-07-07**  
Merged from:

- `modification(4).md`
- `modi_for_codex.md`

## 0. Safe Merge Notes

This file merges both uploaded roadmap/planning documents into one cleaner source of truth.

Merge approach:

- Duplicate sections were consolidated instead of repeated.
- More specific implementation notes were preserved.
- Conflicts or potentially stale observations were kept as **verification-required** items.
- No original file is overwritten.
- Commands are kept as operational checklists, not proof that they have already run.
- Branch status and repo scan observations should be re-verified before coding.

---

## 1. Project Summary

This repository contains a full-stack **OMC House mobile app + Frappe backend system**.

Major parts:

```text
omc_app/
  Flutter mobile application

backend_omc_app/
  Custom Frappe backend app and bench workspace
```

The direction is clear:

- Customers use the Flutter mobile app for services, documents, payments, support, notifications, settings, profile, tax calculator, expense tracker, knowledge/news, and service tracking.
- Internal OMC users use the Frappe backend/workspace for service operations, customers, support, leads, tasks, documents, payments, and internal follow-up.
- The architecture should remain backend-driven for production behavior.

Current overall assessment from both files:

```text
Foundation: Strong
Backend API: Strong base completed
Flutter structure: Strong base completed
Customer UI polish: Partially complete / Medium
Local runtime verification: Pending
Production readiness: Not complete yet
Internal permissions: Good direction, needs dedicated roles
Documentation: Good start, can be expanded
```

The app is already beyond a static frontend prototype. It has real feature structure, Frappe API integration, custom OMC DocTypes, customer workflows, internal workspace foundations, and backend-controlled permissions.

---

## 2. Working Rules

Use these rules for all next work:

1. Use backend-driven architecture for production behavior.
2. Do not make the Flutter app depend on fake/local data in production.
3. Local/demo fallbacks are allowed only for development and must be clearly guarded.
4. Do not expose internal/admin controls to normal customer users.
5. Backend must return capability flags; Flutter should render controls from those flags.
6. Backend permissions must remain the real protection. UI hiding alone is not security.
7. Do not force-push unless explicitly approved.
8. Keep `chatgpt-work` synced with `main` before new feature work.
9. Confirm the active backend import path before editing backend APIs.
10. Do not start big new features before local verification is complete.

Current backend source-of-truth direction:

```text
backend_omc_app/apps/omc_app -> backend_omc_app/frappe-bench/apps/omc_app
```

---

## 3. Repository Status and Structure

### Repository

```text
Repo: mshahwaiz-ali/omc_app
Default branch: main
Working branch used earlier: chatgpt-work
```

Source scan observation:

```text
chatgpt-work was behind main by 44 commits.
chatgpt-work was ahead by 0 commits.
```

This may now be stale. Re-check before coding.

Recommended sync step before new coding:

```bash
git checkout chatgpt-work
git pull origin main
```

or update `chatgpt-work` from GitHub.

### High-Level Structure

```text
README.md
docs/
  modification.md

omc_app/
  Flutter mobile app
  lib/
    app/
    core/
    features/
  assets/
    data/
    images/
  docs/
    backend_api_contract.md
  pubspec.yaml

backend_omc_app/
  apps/
    sync_apps.sh
    omc_app/
      omc_app/
        api/
          mobile.py
          secured_mobile.py
        omc_app/
          doctype/
          workspace/
        fixtures/
        public/
        hooks.py
      pyproject.toml
```

### Important Backend Path Risk

Search showed similar backend files under duplicate-looking paths:

```text
backend_omc_app/apps/omc_app/omc_app/api/mobile.py
backend_omc_app/apps/omc_app/omc_app/omc_app/api/mobile.py
```

Active import path appears to be:

```text
omc_app.api.mobile
omc_app.api.secured_mobile
```

Before further backend changes, verify which path is actually installed in the running Frappe bench.

---

## 4. Tech Stack

### Mobile

```text
Flutter
Dart SDK ^3.12.2
Riverpod
GoRouter
Dio
Flutter Secure Storage
Shared Preferences
File Picker
Image Picker
URL Launcher
Flutter SVG
Cached Network Image
FL Chart
Package Info Plus
Flutter Launcher Icons
Flutter Native Splash
```

### Backend

```text
Frappe Framework
Python
Custom Frappe app: omc_app
Whitelisted Frappe API methods
OMC-owned DocTypes
Frappe file upload endpoint
Workspace fixtures
Backend-driven mobile configuration
```

---

## 5. Completed / Existing Mobile App Foundation

### 5.1 Flutter App Foundation

Status: **Done**

Existing feature areas:

```text
Authentication
Home
Service Catalogue
Service Request / My Services
Service Tracking
Documents
Payments
Tax Calculator
Expense Tracker
Knowledge / News
Notifications
Profile
Settings
Support
Leads
Customers
Tasks
Internal Workspace
```

Completed foundation:

- Feature-first folder structure exists.
- Riverpod is used for state management.
- GoRouter is used for routing.
- Dio is used for API calls.
- Secure storage is used for session storage.
- Backend method names are centralized in `ApiConfig`.
- Main shell navigation is built.
- Floating premium bottom navigation is built.
- More page groups customer actions and internal workspace entry.

---

## 6. Mobile Feature Status

### 6.1 Authentication

Status: **Done / Strong base**

Completed:

- Email/password login.
- Signup flow.
- Session restore.
- Session validation through backend using `get_session_user`.
- Logout clears local session.
- Wrong email/password message improved.
- Flutter web browser-managed cookie support exists.
- Secure local session storage exists.
- Google login entry point exists but is intentionally disabled until secure backend token verification is implemented.

Pending:

- Google login is not production-ready.
- Password reset flow is not implemented.
- Email verification flow is not implemented.
- Account approval waiting screen.
- Improved signup validation for CNIC/NTN/phone.
- Customer onboarding steps after signup.

Important rule:

```text
Never enable Google login in production until backend verifies Google ID tokens securely.
```

---

### 6.2 Environment and API Configuration

Status: **Done**

Completed:

- `OMC_ENV` environment support.
- `OMC_API_BASE_URL` support.
- Production environment forces HTTPS.
- Development default points to local Frappe.
- Staging/production default points to OMC ERP domain.
- Mock auth is blocked in production.
- Service preview/local catalogue fallback is development-only.
- Google login flag is disabled in production unless intentionally changed.

---

### 6.3 Routing

Status: **Done / Strong**

Registered routes:

```text
/
login
signup
home
services
service detail
service request draft
my services
service case detail
dashboard
documents
document detail
payments
payment detail
leads
lead detail
customers
customer detail
tasks
task detail
knowledge
knowledge detail
notifications
notification detail
support
support ticket detail
tax calculator
profile
expense tracker
settings
internal workspace
```

Recently completed:

- `/support` route registered.
- `/tax-calculator` route registered.
- Support can be opened from Home/More.
- Tax Calculator can be opened from Home/More.

Pending verification:

- Run `flutter analyze`.
- Manually open all major routes after login.

Recommended improvements:

- Add guarded direct-route protection for internal workspace UI.
- Improve deep-link support.
- Add route-level loading/error fallbacks.
- Add unknown route / 404 screen.
- Add analytics-friendly route names later.

---

### 6.4 Main Shell / Navigation and More Page

Status: **Strong foundation / Mostly done**

Bottom navigation:

```text
Home
Services
Track
Docs
More
```

More page opens:

```text
Dashboard
Payments
Tax Calculator
Support
Profile
Settings
Notifications
Knowledge
Expense Tracker
Internal Workspace when allowed
Logout
```

More page already includes:

- Account group.
- Services group.
- Help group.
- Workspace group capability-gated.
- Logout.

Recommended polish:

- Add notification/payment/document badges.
- Add app version.
- Improve icons/spacing consistency.
- Make customer status more visible.
- Add quick action cards.
- Add animated skeleton loading states.

---

### 6.5 Home Dashboard

Status: **Backend-connected / Needs polish**

Designed to show:

```text
Open services
Documents
Payments due
Notifications
Recent activity
Quick access to services/support/calculator/notifications
```

Recommended improvements:

- Customer-specific greeting with profile status.
- Next pending customer action.
- Latest service timeline update.
- Payment due alert.
- Missing document alert.
- Unread notifications.
- OMC announcement banner from backend.

---

### 6.6 Settings / Preferences

Status: **Done / Customer-safe direction**

Completed:

- Settings page cleaned for customer-safe use.
- Technical backend/debug information removed from normal customer view.
- Customer-facing sections focus on:
  - Account
  - Preferences
  - About
  - Logout
- API server URL is not shown to normal customers.
- Backend technology labels are not shown.
- Environment/testing flags are not shown.
- Raw debug/connection sections are not shown.
- Preference toggles are backend-connected.

Pending verification:

- Open Settings as a normal customer.
- Confirm no backend/dev labels are visible.
- Confirm preference toggles load and save.
- Confirm logout clears session and returns to login.

Recommended improvements:

- Add app version display.
- Add privacy policy / terms links.
- Add delete account request.
- Add notification preference enforcement server-side.
- Add language switch support.
- Add theme switching polish.

---

### 6.7 Profile and Auth State

Status: **Done / Backend-connected**

Completed:

- `get_profile` is backend source for profile summary.
- Profile includes:
  - `full_name`
  - `email`
  - `phone`
  - `customer_id`
  - `customer_status`
  - `approval_status`
  - `company_name`
  - `cnic`
  - `ntn`
  - `can_access_internal_workspace`
- Profile provider syncs profile summary into auth state.
- Home and More screens consume profile/auth state.
- Internal workspace visibility uses backend capability.
- Update profile/contact info direction exists.
- Customer profile creation fallback exists.

Pending polish:

- Avatar upload.
- CNIC/NTN formatting.
- Approval/verification screen.
- Business profile fields.
- Multiple company profiles.
- Customer verification workflow.

---

### 6.8 Internal Workspace Visibility

Status: **Done / Needs production role hardening**

Completed:

- Backend returns `can_access_internal_workspace`.
- Auth/profile state stores internal access capability.
- More page hides Internal Workspace unless backend allows it.
- Normal customer users should not see Internal Workspace.
- Internal users should see it only when backend capability is true.
- Service case controls use backend capability flags.

Pending verification:

- Login as customer: Internal Workspace hidden.
- Login as internal user/System Manager: Internal Workspace visible.
- Direct route access should not expose internal data unless backend allows it.

Recommended production improvement:

```text
Create roles:
- OMC Staff
- OMC Manager
- OMC Support Agent
- OMC Finance Reviewer
```

Recommended matrix:

| User Type | Customer Screens | Internal Workspace | Admin Controls |
|---|---:|---:|---:|
| Customer | Yes | No | No |
| OMC Staff | Yes | Yes | Limited |
| OMC Manager | Yes | Yes | Yes |
| System Manager | Yes | Yes | Full |

---

### 6.9 Service Catalogue

Status: **Done / Backend-first**

Completed:

- Service catalogue is backend-first.
- Backend returns OMC service records.
- Flutter can parse backend response wrappers.
- Flutter can parse service metadata.
- Required document metadata is supported.
- Production/staging do not silently fall back to stale local JSON.
- Local JSON fallback is development-only and requires explicit flag.

Backend-supported service fields:

```text
service_id
title
description
short_description
category
icon
estimated_duration
completion_time
base_price
currency
fee_label
government_fee_label
support_message
wizard_type
wizard_config
is_featured
required_documents
required_document_details
```

Pending verification:

- Run `flutter analyze`.
- Confirm real backend services load.
- Confirm empty backend catalogue shows clean empty state.
- Confirm local fallback only works with:

```bash
--dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=true
```

Recommended improvements:

- Backend-managed service category icons.
- Search and filters.
- Featured services carousel.
- Service comparison/cards.
- Dynamic service request forms based on `wizard_type`.
- Backend-controlled form schema per service.
- Service availability/status flag.
- Admin sort order polish.

---

### 6.10 Service Request Creation

Status: **Done / Basic request creation**

Completed:

- Customer can create a service request.
- Backend creates `OMC Service Request`.
- Backend links customer profile.
- Backend sets service, title, contact email, contact phone, priority, and status.
- Backend creates initial service timeline entry.
- Response returns created request name and status.

Pending improvement:

- Dynamic service request forms are future work.
- Current form is not yet fully service-specific.

Future backend DocType:

```text
OMC Service Form Field
```

Purpose:

- Each service can define its own required fields.
- Flutter renders fields dynamically.
- Submitted form data is saved as structured service details.

---

### 6.11 Service Tracking / My Services

Status: **Mostly done / Pending local verification**

Completed:

- Customer can list service cases.
- Customer can open service case detail.
- Backend returns tracking metadata.
- Backend returns progress value and progress percent.
- Backend returns current stage and next step.
- Backend returns document counts.
- Backend returns customer action required flag.
- Backend returns timeline.
- Backend returns capability flags for internal controls.

Expected service case fields:

```text
id
name
reference
case_reference
title
status
priority
service
description
created_at
updated_at
expected_completion_date
progress
progress_percent
current_stage
next_step
required_documents_count
submitted_documents_count
missing_documents_count
customer_action_required
timeline
can_update_status
can_review_documents
can_view_internal_notes
```

Security direction completed:

- Customer users should not receive internal controls.
- Customer users should not receive internal remarks.
- Staff/internal users receive capability flags when backend allows.
- Flutter should render buttons based on backend capability flags.

Pending verification:

- Customer opens My Services.
- Customer opens service case detail.
- Customer can upload/request support but cannot approve/reject/update status.
- Internal user can see internal controls only when backend allows.

Recommended improvements:

- Prefer real backend timeline rows.
- Use fallback timeline only when backend timeline is empty.
- Make timeline visually cleaner in Flutter.
- Show progress, next step, expected completion, and customer action required clearly.
- Add service cancellation/request close flow.
- Add customer comment thread UI polish.

Future backend DocType:

```text
OMC Service Stage Template
```

---

### 6.12 Secured Service Case Wrappers

Status: **Repo patched / Pending local bench reload, migrate, and test**

Expected secured route direction:

```text
omc_app.api.mobile.get_service_cases -> omc_app.api.secured_mobile.get_service_cases
omc_app.api.mobile.get_service_case -> omc_app.api.secured_mobile.get_service_case
omc_app.api.mobile.update_service_case_status -> secured wrapper
omc_app.api.mobile.update_service_document_status -> secured wrapper
```

Accepted aliases:

```text
case detail: case_id, name, service_request, request_id
case status: case_id, name, service_request, request_id
document review: document_id, document, name
```

Secured wrapper behavior:

- Normalizes service case list response.
- Adds progress and tracking fields.
- Adds capability flags.
- Protects status updates.
- Protects document review actions.
- Hides internal remarks from normal customers.

Required local verification:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

Then:

```bash
cd ~/data_drive/app_omc/omc_app
flutter analyze
```

---

### 6.13 Documents

Status: **Backend foundation done**

Completed:

- Customer document list.
- Customer document detail.
- Upload service document against service request.
- Backend checks service request exists.
- Backend checks customer owns service request.
- Backend validates document title.
- Backend validates attachment.
- Backend validates file extension.
- Backend validates file size.
- Backend validates file owner.
- Backend enforces private files.
- Backend limits files per case.
- Backend creates timeline entry after upload.
- Internal document status update API exists.
- Visible-to-customer filtering direction exists.

Allowed service document extensions:

```text
pdf
jpg
jpeg
png
doc
docx
```

Current max document size:

```text
10 MB
```

Pending polish:

- Better document checklist UI.
- Missing documents first.
- Rejected documents with reason.
- Upload action per required document.
- Preview/download support.
- Document expiry/review metadata.
- Required vs optional document sections.
- Re-upload rejected document flow.
- Image/PDF thumbnail.
- Admin document approval dashboard.
- Document templates by service.

---

### 6.14 Payments

Status: **Backend foundation done**

Completed:

- Customer payment list.
- Customer payment detail.
- Receipt upload.
- Receipt file validation.
- Payment reference support.
- Receipt remarks support.
- Receipt Submitted status.
- Internal payment receipt review.
- Paid/Rejected/Cancelled flow.
- Payment timeline entry.
- Customer notification after payment review.

Allowed receipt extensions:

```text
pdf
jpg
jpeg
png
```

Current max receipt size:

```text
10 MB
```

Pending polish:

- Better payment detail screen.
- Receipt preview.
- Rejected receipt reason.
- Bank/payment instructions from backend.
- Payment deadline display.
- Invoice PDF.
- Online payment gateway later.
- JazzCash/EasyPaisa/bank account config.
- Payment reminders.
- Payment due badges.
- Partial payment support.
- Admin payment review queue.

---

### 6.15 Notifications

Status: **Done / Strong backend base**

Completed APIs:

```text
get_notifications
get_notification_detail
mark_notification_read
mark_all_notifications_read
register_push_token
unregister_push_token
```

Completed behavior:

- Customer-specific notifications.
- Recipient-user fallback.
- Read/unread state.
- Read timestamp.
- Reference doctype/name support.
- Push token storage foundation.

Pending future work:

- Firebase Messaging integration.
- Real push notification delivery.
- Notification badges.
- Deep links from notifications to service/payment/document/support ticket.
- Notification preferences enforcement.
- Grouped notification types.
- Silent refresh after mark-read.
- Admin notification composer.

---

### 6.16 Support

Status: **Done / Good base**

Completed:

- Backend-driven support config.
- Default support channels.
- Default support topics.
- Create support ticket.
- List support tickets.
- View support ticket detail.
- Add support ticket reply.
- Internal update support ticket status.
- Customer notification on support ticket status update.

Support fallback channels:

```text
WhatsApp
Phone
Email
```

Support fallback topics include:

```text
Income Tax
POS & Digital Invoicing
Sales Tax
Technical Support
Payment Support
```

Pending polish:

- Attachments in support tickets.
- Staff assignment.
- Better chat-like reply UI.
- Ticket unread badge.
- SLA/priority handling.
- Reopen ticket flow.
- Backend-managed support topics/channels final verification.
- WhatsApp click-to-chat polish.
- Admin reply UI.

---

### 6.17 Mobile App Config

Status: **Done / Backend config exists**

Completed API:

```text
omc_app.api.mobile.get_mobile_app_config
```

Current backend config returns:

- Support channels.
- Support topics.
- Business hours.
- Office address.
- WhatsApp default message.
- Feature flags.
- Branding company name.
- Branding tagline.
- Meta source/fallback.

Feature flags currently include:

```text
expense_tracker_enabled
knowledge_enabled
payments_enabled
tax_calculator_enabled
support_enabled
internal_workspace_enabled
```

Important note:

- `internal_workspace_enabled` currently appears disabled in backend mobile config.
- Internal workspace visibility also depends on profile/auth capability.
- Final behavior should be verified locally.

Future:

- OMC Branding Settings.
- OMC Mobile Settings.
- Minimum app version.
- Force update flag.
- Maintenance mode.
- Support contact config.
- Feature flags.
- Backend-managed branding and app config.

---

### 6.18 Tax Calculator

Status: **Basic backend-connected flow exists**

Completed:

- Tax calculator route exists.
- Flutter has backend method configured.
- Results distinguish backend-verified vs unofficial fallback estimates.

Pending backend work:

```text
OMC Tax Year
OMC Tax Slab
get_tax_years
configurable calculate_tax
```

Pending Flutter work:

- Tax year selector.
- Better calculation summary.
- Save/share calculation.
- Disclaimer section.
- Printable calculation summary.
- Calculation history.
- Admin-managed calculator rules.

---

### 6.19 Expense Tracker

Status: **Foundation added / Sync toggle pending**

Completed:

- Expense tracker screen exists.
- Backend API constants added.
- Backend sync API foundation added.
- Local-only mode remains safe default.
- Storage-mode controller foundation exists.

Backend DocTypes added/planned:

```text
OMC Expense Category
OMC Expense Entry
```

Backend APIs added/planned:

```text
omc_app.api.expense.get_expense_categories
omc_app.api.expense.get_expense_entries
omc_app.api.expense.create_expense_entry
omc_app.api.expense.update_expense_entry
omc_app.api.expense.delete_expense_entry
omc_app.api.expense.get_expense_summary
```

Still pending:

- Visible UI toggle in `ExpenseTrackerScreen`.
- Clear wording before account sync.
- Backend mode should load/create/update/delete via APIs.
- Local mode should keep current SharedPreferences behavior.
- No automatic data upload without explicit user action.

Product decision:

```text
For now, keep Expense Tracker as a customer utility.
Make sync optional.
Do not mix it with official accounting unless explicitly required.
```

Important rule:

```text
Do not silently upload customer expense data.
```

Future polish:

- Expense category management.
- Monthly summary charts.
- Receipt attachment.
- Export CSV/PDF.
- Cloud sync conflict handling.
- Budget limits.
- Recurring expenses.

---

### 6.20 Knowledge / News

Status: **Basic backend-connected flow exists**

Completed:

- Knowledge list.
- Knowledge detail.
- Backend exposes knowledge-style content using service records.
- Featured sorting exists.
- Service-based article mapping exists.

Pending improvement:

```text
Dedicated OMC Knowledge Article DocType
```

Fields:

```text
title
slug
category
summary
content
is_featured
is_published
published_on
related_service
```

Future polish:

- Categories/tags.
- Publish/unpublish controls.
- Featured announcement/news banner.
- Search.
- Rich content/HTML support.
- Related services.
- Read time.

---

## 7. Backend Status

### 7.1 Main Backend API

Main file:

```text
backend_omc_app/apps/omc_app/omc_app/api/mobile.py
```

Important implemented functions include:

```text
sign_up
google_mobile_login
get_session_user
get_profile
update_profile
update_contact_info
get_dashboard_data
get_service_catalogue
get_service_detail
create_service
get_service_cases
get_service_case
update_service_case_status
add_service_case_comment
upload_service_document
update_service_document_status
get_documents
get_document
get_payments
get_payment
upload_payment_receipt
review_payment_receipt
get_knowledge
get_knowledge_article
get_notifications
mark_notification_read
mark_all_notifications_read
get_notification_detail
register_push_token
unregister_push_token
get_mobile_app_config
get_support_config
create_support_ticket
get_support_tickets
get_support_ticket
add_support_ticket_reply
update_support_ticket_status
```

Backend is not empty. It already contains real app logic.

---

### 7.2 Secured Mobile API

Main file:

```text
backend_omc_app/apps/omc_app/omc_app/api/secured_mobile.py
```

Purpose:

- Keep customer-facing routes stable.
- Add server-side capability checks.
- Normalize service case responses.
- Protect internal-only actions.

Important secured functions:

```text
get_service_cases
get_service_case
update_service_case_status
update_service_document_status
```

Core direction:

```text
Flutter should never decide admin permissions by itself.
Backend should send capability flags.
Frontend should render controls based on backend flags.
```

---

### 7.3 Backend Workspace

Status: **Base workspace exists**

Workspace groups:

```text
Operations
Customers & Support
CRM & Internal
Users & Permissions
```

Workspace links include:

```text
OMC Service Request
OMC Service
OMC Service Category
OMC Service Required Document
OMC Service Document
OMC Service Payment
OMC Service Timeline
OMC Customer Profile
OMC Customer Preference
OMC Support Ticket
OMC Notification
OMC Push Token
OMC Lead
OMC Task
OMC Mobile Settings
OMC Branding Settings
Users
Roles
Role Profile
Module Profile
User Permissions
Role Permissions Manager
```

Pending polish:

- Workspace charts.
- Open service requests dashboard.
- Payment review queue.
- Document review queue.
- Support ticket queue.
- Staff-specific workspace.
- Better reports.
- Filtered shortcuts for open cases/payments/tickets.
- Workspace onboarding cards.
- Role-specific workspace views.

---

## 8. Current Strong Points

The project already has these strong foundations:

```text
Backend-driven architecture
Feature-first Flutter structure
Central API config
Environment guards
Production HTTPS enforcement
Session restore flow
Customer profile auto-creation
Service catalogue from backend
Service request lifecycle
Document upload validation
Payment receipt workflow
Notification system
Push token registration foundation
Support ticket system
Settings preference model
Workspace fixture
Role/capability-based internal controls
```

---

## 9. Main Risks / Issues

### 9.1 `chatgpt-work` branch may be stale

Risk:

```text
New changes on chatgpt-work may miss latest fixes from main.
```

Fix:

```bash
git checkout chatgpt-work
git pull origin main
```

Re-check current remote state before acting.

---

### 9.2 Duplicate backend path risk

Risk:

```text
Wrong file may be edited.
Frappe may import one path while repo contains another duplicate.
```

Recommended action:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site <site-name> console
```

Inside console:

```python
import omc_app.api.mobile
import omc_app.api.secured_mobile
print(omc_app.api.mobile.__file__)
print(omc_app.api.secured_mobile.__file__)
```

Then clean or document duplicate structure.

---

### 9.3 Local verification still needed

Repo scan does not confirm local runtime.

Need to run locally:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

Then:

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
```

Manual tests are still required.

---

### 9.4 Google login intentionally incomplete

Current backend blocks Google login until verified token validation exists.

Recommended:

```text
Keep disabled in production.
Implement proper Google ID token verification later.
Never accept only client-side Google flag.
```

---

### 9.5 Expense tracker needs explicit sync decision

Risk:

```text
Customer expense data may be sensitive.
Silent sync would damage trust.
```

Recommended:

```text
Default local-only.
Make sync optional.
Ask/confirm before syncing existing local expenses.
```

---

### 9.6 Internal workspace should move away from System Manager-only gate

Current internal gate uses System Manager-style capability.

Better production approach:

```text
Create role: OMC Staff
Create role: OMC Manager
Use those roles for internal workspace access.
Keep System Manager as super-admin only.
```

---

## 10. Required Local Verification

These are not new features. These are required verification steps before calling the current state stable.

### 10.1 Backend Verification

Run:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

Verify imports:

```bash
bench --site <site-name> console
```

Inside console:

```python
import omc_app.api.mobile
import omc_app.api.secured_mobile
print(omc_app.api.mobile.__file__)
print(omc_app.api.secured_mobile.__file__)
```

Reason:

- Confirm the running bench is using the expected repo-tracked backend files.
- Search showed possible duplicate nested backend paths.

### 10.2 Flutter Verification

Run:

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
```

Run app with local backend:

```bash
flutter run --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

Production-style test:

```bash
flutter run \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

### 10.3 Manual Customer Flow Testing

Test as customer:

```text
Signup
Login
Home dashboard
Service catalogue
Service detail
Create service request
My Services list
Service case detail
Document upload
Documents list/detail
Payment list/detail
Receipt upload
Notifications list/detail
Mark notification read
Mark all notifications read
Support ticket create/list/detail/reply
Profile
Settings preferences save
Logout
```

### 10.4 Manual Internal Flow Testing

Test as internal user:

```text
Internal Workspace visibility
Service case admin controls
Status update
Document approve/reject
Payment receipt review
Support ticket status update
Lead/customer/task screens
```

### 10.5 Normal Customer Security Testing

Confirm normal customer cannot see:

```text
Internal Workspace
Status update button
Document approve/reject controls
Internal remarks
Admin-only data
```

---

## 11. Priority Roadmap

### P0 — Must Fix / Verify Before Stable Build

#### P0.1 Sync branch state

Status: **Pending**

Need:

```bash
git checkout chatgpt-work
git pull origin main
```

Reason:

- `chatgpt-work` was behind main during source scan.
- Verify current branch status before new work.

#### P0.2 Verify active backend import path

Status: **Pending**

Need to confirm:

```text
Which mobile.py is actually imported by Frappe bench?
Which secured_mobile.py is actually imported?
```

Reason:

- Duplicate-looking backend paths appeared in repository search results.
- Editing the wrong copy would cause confusing bugs.

#### P0.3 Run backend migrate/cache/restart

Status: **Pending**

Need:

```bash
bench --site all migrate
bench --site all clear-cache
bench restart
```

Reason:

- Backend repo patches must be loaded into running Frappe.

#### P0.4 Run Flutter analyze

Status: **Pending**

Need:

```bash
flutter analyze
```

Reason:

- Current repo scan does not prove local Dart analysis is clean.

#### P0.5 Verify customer vs internal permissions

Status: **Pending**

Need test accounts:

```text
Customer account
Internal/staff account
System Manager account
```

Check:

```text
Workspace visibility
Service case controls
Document review controls
Payment review controls
Support status controls
Internal remarks exposure
```

---

### P1 — Important UX / Product Improvements

#### P1.1 Service tracking timeline polish

Status: **Partially done**

Need:

- Prefer real backend timeline rows.
- Use fallback timeline only when backend timeline is empty.
- Make timeline visually cleaner in Flutter.
- Show progress, next step, expected completion, and customer action required clearly.

Future backend DocType:

```text
OMC Service Stage Template
```

#### P1.2 Document checklist polish

Status: **Pending**

Need:

- Show required documents per service.
- Show missing documents first.
- Show rejected documents with reason.
- Upload per required document.
- Preview/download uploaded files.
- Separate:
  - Required
  - Submitted
  - Approved
  - Rejected
  - Missing

#### P1.3 Payment UX polish

Status: **Pending**

Need:

- Better payment detail screen.
- Receipt upload preview.
- Payment instructions from backend.
- Rejected receipt reason.
- Payment due badge.
- Payment timeline.
- Invoice PDF support later.

#### P1.4 More page polish

Status: **Mostly done, can improve**

Already done:

- Account group.
- Services group.
- Help group.
- Workspace group capability-gated.
- Logout.

Still improve:

- Notification/payment/document badges.
- App version.
- Icons/spacing consistency.
- Customer status visibility.

#### P1.5 Home dashboard polish

Status: **Pending**

Need:

- Next pending customer action.
- Latest service update.
- Missing document alert.
- Payment due alert.
- Unread notifications.
- OMC announcement banner.

#### P1.6 Support ticket UI polish

Status: **Pending**

Need:

- Better chat-style replies.
- Attach file to ticket.
- Show ticket status clearly.
- Show support topic.
- Show last reply preview.
- Add unread staff reply badge.

---

### P2 — Backend-Connected Enhancements

#### P2.1 Expense tracker sync toggle

Status: **Pending**

Need:

- Wire visible local/sync toggle in `ExpenseTrackerScreen`.
- Default to local-only mode.
- Ask/confirm before syncing existing local expenses.
- Sync mode should use backend APIs.

Important rule:

```text
Do not silently upload customer expense data.
```

#### P2.2 Configurable tax slabs

Status: **Future**

Need backend DocTypes:

```text
OMC Tax Year
OMC Tax Slab
```

Need APIs:

```text
get_tax_years
calculate_tax
```

Need Flutter:

- Tax year selector.
- Official backend calculation display.
- Clear disclaimer.

#### P2.3 Dynamic service request forms

Status: **Future**

Need backend DocType:

```text
OMC Service Form Field
```

Purpose:

- Each service can define its own required fields.
- Flutter renders fields dynamically.
- Submitted form data is saved as structured `service_details`.

#### P2.4 Dedicated knowledge article system

Status: **Future**

Need backend DocType:

```text
OMC Knowledge Article
```

Fields:

```text
title
slug
category
summary
content
is_featured
is_published
published_on
related_service
```

#### P2.5 Backend-managed branding and app config

Status: **Partially done**

Already:

```text
get_mobile_app_config exists
```

Future:

- OMC Branding Settings.
- OMC Mobile Settings.
- Minimum app version.
- Force update flag.
- Maintenance mode.
- Support contact config.
- Feature flags.

#### P2.6 Production roles

Status: **Future improvement**

Recommended roles:

```text
OMC Staff
OMC Manager
OMC Support Agent
OMC Finance Reviewer
```

---

### P3 — Future Polish

#### P3.1 Push notifications

Backend token register/unregister exists.

Need Flutter:

- Firebase Messaging.
- Register token after login.
- Unregister token on logout.
- Handle notification tap.
- Deep link to service/payment/document/support ticket.

#### P3.2 Offline caching

Cache only low-risk data:

```text
Service catalogue
Profile summary
Dashboard summary
Settings preferences
Support config
```

Avoid caching sensitive documents/payments unless encrypted and necessary.

#### P3.3 App version display

Need:

- `package_info_plus` integration.
- Version/build in Settings or More.
- Backend minimum version check later.

#### P3.4 Reports and dashboards

Backend future:

```text
Open service cases
Pending documents
Pending payments
Open support tickets
Lead pipeline
Staff task list
Daily activity summary
```

---

## 12. Recommended Next Work Plan

### Phase 1 — Stability Verification

Priority: **P0**

Tasks:

```text
Sync chatgpt-work with main
Verify active backend path
Run bench migrate
Run clear-cache/restart
Run flutter analyze
Run customer/staff manual tests
Fix only real errors found
```

Goal:

```text
Confirm current repo actually runs cleanly.
```

### Phase 2 — UI Polish

Priority: **P1**

Recommended UI changes:

```text
Add loading skeletons across list/detail pages
Add empty states with clear actions
Add error retry states
Add notification/payment/document badges
Polish More screen into grouped premium cards
Improve service detail page layout
Improve tracking timeline UI
Improve payment detail and receipt upload UX
Improve document checklist UX
Add app version in Settings/About
```

Best screens to polish first:

```text
Home
Service Detail
My Services Detail
Documents
Payments
Support
Settings
More
```

### Phase 3 — Backend Config Polish

Priority: **P1/P2**

Backend improvements:

```text
Create backend-managed app config DocType
Create backend-managed support channels/topics
Create service stage template DocType
Create knowledge article DocType
Create proper OMC Staff/OMC Manager roles
Add better workspace charts/reports
Add backend feature flags
Add branding settings API
Add app version/minimum version API
```

### Phase 4 — Production Readiness

Priority: **P2**

Tasks:

```text
Add API tests for key mobile methods
Add permission tests
Add fixture cleanup
Add seed/demo data script
Add release build docs
Add environment setup docs
Add backup/restore docs
Add deployment checklist
Add privacy policy/terms links
Add crash/error logging plan
```

---

## 13. Best Next Development Batch

After verification, the best next coding batch should be:

1. Fix any `flutter analyze` or backend runtime errors.
2. Wire Expense Tracker local/sync visible toggle.
3. Polish service tracking timeline UI.
4. Polish document checklist UI.
5. Polish payment receipt UX.
6. Add app version/about section.
7. Add notification/payment/document badges.

Do not start big new features before local verification is complete.

---

## 14. Recommended Immediate Commits

### Commit 1 — Repo hygiene

```text
Sync chatgpt-work with main
Confirm active backend path
Document local backend sync direction
Remove or document duplicate backend path risk
```

### Commit 2 — Verification fixes

```text
Run flutter analyze
Fix Dart analysis errors
Run bench migrate
Fix backend import/runtime errors
```

### Commit 3 — UI polish batch

```text
More screen badges
Settings about/app version
Document checklist polish
Payment receipt UX polish
Service timeline polish
```

### Commit 4 — Backend production roles

```text
Add OMC Staff role
Add OMC Manager role
Replace System Manager-only workspace gate
Keep System Manager as admin override
```

---

## 15. High-Impact Feature Ideas

### Customer App

```text
Service request wizard per service
Document checklist with missing/rejected/approved sections
Payment due alerts
Receipt upload with preview
Timeline with real backend stages
Support chat-like ticket replies
Push notifications
Knowledge/news center
Profile verification
App version/update alert
```

### Internal App / Workspace

```text
Open service case dashboard
Payment review queue
Document review queue
Support ticket queue
Lead pipeline
Task board
Customer profile overview
SLA overdue alerts
Daily activity report
```

### Backend / Admin

```text
Service template builder
Required document template builder
Stage template builder
Notification template builder
Support topic/channel builder
Tax calculator slab builder
Role-based workspace
Audit logs
```

---

## 16. Suggested README Commands

### Flutter

```bash
cd omc_app
flutter pub get
flutter analyze
flutter run --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

For staging/production:

```bash
flutter run \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

### Backend

```bash
cd backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

### Verify API Import Path

```bash
bench --site <site-name> console
```

Inside console:

```python
import omc_app.api.mobile
import omc_app.api.secured_mobile
print(omc_app.api.mobile.__file__)
print(omc_app.api.secured_mobile.__file__)
```

---

## 17. Final Assessment

Current app state is solid. Most core foundations are already done:

```text
Mobile structure
Backend APIs
Service catalogue
Service cases
Documents
Payments
Notifications
Support
Profile
Settings
Internal capability gating
```

Best next focus:

1. Verify everything locally.
2. Fix only real analyze/runtime issues.
3. Polish customer-facing flows.
4. Harden backend permissions.
5. Add backend-managed configuration and templates.
6. Prepare for production.

The next stage should stay focused:

```text
Verify
Stabilize
Polish
Harden permissions
Add backend-configurable templates
Prepare for production
```