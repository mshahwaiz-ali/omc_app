# OMC App Modification Plan

This document records the next improvement phase after inspecting the current Flutter app and Frappe backend.

Primary focus: Flutter mobile app.
Secondary focus: backend/API changes needed to support a cleaner mobile experience.

---

## Main Goals

- Make customer-facing screens cleaner and more professional.
- Remove technical/debug information from normal app UI.
- Make important app data backend-driven where practical.
- Keep preview/mock data only behind development flags.
- Improve More and Settings screens.
- Improve service tracking, documents, payments, support, notifications, and internal workspace behavior.
- Add backend DocTypes/APIs only where they create clear product value.

---

## Current Findings

### Good existing foundation

- Flutter app is feature-first and already includes auth, home, service catalogue, tracking, documents, payments, tax calculator, expense tracker, knowledge, notifications, profile, settings, support, leads, customers, tasks, and internal workspace.
- Backend method names are centralized in `ApiConfig`.
- `FrappeClient` supports method calls, resource calls, login, session cookie extraction, API token headers, file upload, and API error normalization.
- Home dashboard is backend-connected through `get_dashboard_data`.
- My Services / tracking is backend-connected by default through `get_service_cases` and `get_service_case`.
- Documents, payments, notifications, settings, support, leads, customers, and tasks have backend repositories.
- Frappe backend app has mobile APIs and OMC-owned DocTypes for core flows.
- Backend validates document/payment uploads for type, size, ownership, privacy, and linked records.

### Main gaps

- Settings page shows technical details such as environment, API server URL, backend label, catalogue source, and testing flags in non-production.
- More page shows Internal Workspace to every user, even though it should be internal-role only.
- Service catalogue defaults to local JSON unless backend catalogue mode is explicitly enabled.
- Service case detail includes admin controls in the same screen as customer tracking.
- Tax calculator has backend-first logic but falls back to local hardcoded slabs.
- Expense tracker is local-only through `SharedPreferences`.
- Support contact values and support categories are hardcoded in Flutter.
- `MainShell` opens `/tax-calculator` and `/support`; router should confirm both routes are registered.
- Tracking timeline has fallback static steps if backend timeline is empty.

---

## Priority Legend

- P0: Must fix before next stable test build.
- P1: Important for production-quality UX.
- P2: Useful backend-connected enhancement.
- P3: Future polish.

---

# P0 - Must Fix

## 1. Register Support and Tax Calculator routes

### Problem

`MainShell` opens:

```text
/tax-calculator
/support
```

The router must include these routes.

### Flutter changes

In `omc_app/lib/app/router.dart`, add imports:

```dart
import '../features/tax_calculator/presentation/tax_calculator_screen.dart';
import '../features/support/presentation/support_screen.dart';
```

Add routes:

```dart
GoRoute(
  path: '/tax-calculator',
  name: 'tax-calculator',
  builder: (context, state) => const TaxCalculatorScreen(),
),
GoRoute(
  path: '/support',
  name: 'support',
  builder: (context, state) => const SupportScreen(),
),
```

### Test

- Home > Calculator opens.
- More > Tax Calculator opens.
- Home/More > Support opens.
- `flutter analyze` is clean.

---

## 2. Clean Settings page

### Problem

Settings should not show technical implementation details in normal UI.

Current items to remove/hide from customer-facing Settings:

- API server URL/host
- Backend technology label
- Environment label
- Testing flags
- Catalogue source label
- Raw backend connection section

### Flutter changes

In `settings_screen.dart`:

- Remove API URL chip from `_SettingsHero`.
- Replace technical chips with customer-safe labels:
  - `Account active`
  - `Protected account`
  - `OMC services`
- Remove visible `Connection` section from normal UI.
- Optional: keep diagnostics behind a hidden non-production developer screen.

### Better copy

Use:

```text
Manage your account, preferences and OMC service updates.
```

Avoid:

```text
Backend-connected development setup.
API server
Frappe
Testing flags
```

---

## 3. Hide Internal Workspace for normal customers

### Problem

More page always shows Internal Workspace. Backend blocks unauthorized users, but customer UI should not show internal modules.

### Flutter changes

- Add user capability state to auth/profile.
- Show Workspace group only when `canAccessInternalWorkspace == true`.

### Backend change

Update `get_session_user` or `get_profile` to return:

```json
{
  "can_access_internal_workspace": true,
  "roles": ["System Manager"]
}
```

Flutter should use the boolean, not hardcoded role names.

---

## 4. Separate customer tracking from admin controls

### Problem

`ServiceCaseDetailScreen` includes admin-style controls:

- Admin case controls
- Status update actions
- Document approve/reject actions

These should not appear for normal customers.

### Flutter changes

Customer view:

- Case status
- Progress timeline
- Required/missing documents
- Upload document
- Support/contact action

Internal view:

- Status update controls
- Document review controls
- Internal notes
- Expected completion update

### Backend improvement

Return capability flags with case detail:

```json
{
  "can_update_status": false,
  "can_review_documents": false,
  "can_view_internal_notes": false
}
```

Flutter should render controls based on backend capability flags.

---

# P1 - Important Improvements

## 5. Make service catalogue backend-first

### Current state

Flutter loads local `assets/data/service_catalogue.json` unless backend catalogue flag is enabled.

### Desired state

- Production/staging: backend catalogue first.
- Development: backend first with optional local fallback.
- Explicit preview flag: local catalogue only.

### Backend requirements

Populate and maintain:

- `OMC Service`
- `OMC Service Category`
- `OMC Service Required Document`

API response should include:

```text
id
name
title
category
short_description
description
fee_label
government_fee_label
completion_time
wizard_type
required_documents
required_document_details
```

---

## 6. Improve service progress model

### Current state

Flutter uses backend `progress` if present. If timeline is empty, Flutter creates fallback steps.

### Backend improvement

Enhance `get_service_case` with:

```text
progress_percent
current_stage
next_step
expected_completion_date
customer_action_required
required_documents_count
submitted_documents_count
missing_documents_count
timeline
```

### Optional DocType

Add `OMC Service Stage Template`:

```text
service
stage_title
stage_order
progress_percent
visible_to_customer
expected_duration_label
```

Flutter should prefer backend timeline/stages and only use fallback for empty demo/dev states.

---

## 7. Backend-driven support configuration

### Current state

Support phone, WhatsApp, email, address, business hours, and topics are hardcoded in Flutter.

### Backend additions

Add `OMC Support Channel`:

```text
channel_type
label
value
is_active
sort_order
```

Add `OMC Support Topic`:

```text
title
subtitle
default_message
icon_key
is_active
sort_order
```

Add API:

```text
omc_app.api.mobile.get_support_config
```

Flutter should use backend support config and keep local config only as fallback.

---

## 8. Improve More page structure

### Recommended customer More page

```text
Account
- Profile
- Notifications
- Preferences

Services
- My Services
- Documents
- Payments
- Tax Calculator
- Knowledge Center
- Personal Expense Tracker

Help
- Support Tickets
- Contact OMC

Account Action
- Logout
```

### Rules

- Hide Internal Workspace unless backend says user can access it.
- Hide internal dashboard for customers if it is not customer-focused.
- Rename Expense Tracker to `Personal Expense Tracker`.

---

## 9. Add backend mobile app config

### Backend API

Add:

```text
omc_app.api.mobile.get_mobile_app_config
```

Response shape:

```json
{
  "support": {
    "phone": "+92...",
    "email": "support@...",
    "whatsapp": "92...",
    "business_hours": "...",
    "office_address": "..."
  },
  "features": {
    "expense_tracker_enabled": true,
    "knowledge_enabled": true,
    "payments_enabled": true,
    "internal_workspace_enabled": false
  },
  "branding": {
    "company_name": "OMC House",
    "tagline": "..."
  }
}
```

Flutter should use these flags/details after login or app bootstrap.

---

## 10. Improve profile/auth state

### Current state

Home greeting can derive name from email/local part.

### Improvement

Use `get_profile` as source for:

- display name
- phone
- company
- customer status
- approval status
- internal access capability

Flutter should create a shared profile provider and use it in Home, More, Profile, and Settings.

---

# P2 - Backend-Connected Enhancements

## 11. Optional backend sync for Expense Tracker

### Current state

Expense tracker stores data locally in `SharedPreferences`.

### Keep local mode

Local mode is useful and can remain.

### Add optional sync mode

Backend DocTypes:

```text
OMC Expense Category
OMC Expense Entry
```

APIs:

```text
omc_app.api.mobile.get_expense_entries
omc_app.api.mobile.create_expense_entry
omc_app.api.mobile.update_expense_entry
omc_app.api.mobile.delete_expense_entry
omc_app.api.mobile.get_expense_summary
```

Flutter UX:

- `Store only on this device`
- `Sync with my OMC account`

---

## 12. Backend configurable tax slabs

### Current state

Tax calculator calls backend first and then falls back to local slabs.

### Backend additions

DocTypes:

```text
OMC Tax Year
OMC Tax Slab
```

APIs:

```text
omc_app.api.mobile.get_tax_years
omc_app.api.mobile.calculate_tax
```

Flutter improvements:

- Tax year selector.
- Label result source clearly.
- Avoid presenting fallback estimate as official.

---

## 13. Dynamic service request forms

### Current state

Service catalogue supports `wizard_type` and `wizard_config`.

### Backend addition

Add `OMC Service Form Field`:

```text
service
field_key
label
field_type
required
options
sort_order
help_text
```

Flutter should render service-specific form fields from backend config and submit structured `service_details`.

---

## 14. Better document checklist

Backend should return detailed checklist items:

```text
id
title
type
required
status
uploaded_on
reviewed_on
reviewer_remarks
file_url
```

Flutter should show:

- Missing documents first
- Rejected documents with reason
- Uploaded documents with preview/download
- Upload action per missing document

---

## 15. Better payment UX

Backend should add/return:

```text
invoice_number
invoice_pdf
service_request
payment_method_instructions
payment_gateway_url
bank_account_details
payment_deadline
receipt_review_remarks
```

Flutter should show:

- Pay now when gateway URL exists
- Upload receipt for manual payment
- Receipt review timeline
- Rejected receipt reason

---

# P3 - Future Polish

## 16. App version/build info

Add `package_info_plus` and show app version/build number in Settings or More.

Technical details should remain hidden from normal users.

## 17. Safe offline caching

Cache low-risk data:

- service catalogue
- profile summary
- dashboard summary
- settings preferences

Do not cache sensitive documents/payment data unless necessary and protected.

## 18. Push notifications

Backend already has token register/unregister methods.

Next Flutter work:

- Add Firebase Messaging.
- Register token after login.
- Unregister token on logout.
- Add deep links to service case, payment, document, notification, and support ticket.

## 19. Role/capability matrix

Recommended behavior:

| User type | Customer screens | Internal workspace | Admin controls |
|---|---:|---:|---:|
| Customer | Yes | No | No |
| OMC Staff | Yes | Yes | Limited |
| System Manager | Yes | Yes | Yes |

Backend should return capability flags. Flutter should render UI using flags.

---

# Recommended Execution Order

## Batch 1

1. Add missing `/support` and `/tax-calculator` routes.
2. Remove Settings connection/debug UI.
3. Hide Internal Workspace for normal users.
4. Hide admin case/document controls for customers.
5. Run `flutter analyze`.

## Batch 2

1. Make service catalogue backend-first.
2. Add/load backend mobile app config.
3. Move support contact/topics to backend.
4. Rework More page structure.

## Batch 3

1. Improve `get_service_case` response.
2. Add richer progress/stage fields.
3. Improve document checklist and missing document CTA.
4. Improve timeline UI.

## Batch 4

1. Improve payment metadata and receipt review UX.
2. Add tax year/slab DocTypes.
3. Add optional expense tracker sync.
4. Add push notification integration later.

---

# Acceptance Checklist

- `flutter analyze` returns 0 issues.
- `/support` opens from Home and More.
- `/tax-calculator` opens from Home and More.
- Settings does not show backend URL/host, backend technology label, environment, or testing flags to normal users.
- More page hides internal workspace for customers.
- Customer case detail does not show admin controls.
- Service catalogue works from backend in production.
- Support contact values are real and backend-configurable.
- Dashboard/home summary still loads from backend.
- Document upload still works.
- Payment receipt upload still works.
- Settings preferences still load/update from backend.
- Internal workspace still works for authorized users.

---

# Notes

- Keep local preview/testing flags for development only.
- Do not expose backend implementation details in normal customer UI.
- Backend should remain standalone-first with OMC-owned DocTypes.
- ERPNext integration should remain optional and should not be required for core mobile app flows.
