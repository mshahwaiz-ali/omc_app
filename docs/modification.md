# OMC App Modification Plan

This document records the next improvement phase after inspecting the current Flutter app and Frappe backend.

Primary focus: Flutter mobile app.
Secondary focus: backend/API changes needed to support a cleaner mobile experience.

Last reviewed: 2026-07-07.

---

## Main Goals

- Make customer-facing screens cleaner, premium, and non-technical.
- Keep customer UI backend-driven wherever production behaviour depends on real business data.
- Keep preview/mock data only behind explicit development flags.
- Keep internal/admin tools hidden unless the backend says the logged-in user can access them.
- Continue improving service tracking, documents, payments, support, notifications, and internal workspace behaviour.
- Add backend DocTypes/APIs only where they create clear product value.

---

## Current Repo Findings

### Completed foundation

- Flutter app is feature-first and includes auth, home, service catalogue, tracking, documents, payments, tax calculator, expense tracker, knowledge, notifications, profile, settings, support, leads, customers, tasks, and internal workspace.
- Backend method names are centralized in `ApiConfig`.
- Frappe backend app exposes mobile APIs and OMC-owned DocTypes for core flows.
- Backend service catalogue returns service pricing labels, wizard metadata, completion time, and required-document metadata.
- Backend document/payment upload validation exists for type, size, ownership, privacy, and linked records.
- Settings preferences are backend-connected through `get_settings_preferences` and `update_settings_preferences`.
- Notification APIs include list, detail, mark single read, mark all read, and push-token register/unregister.
- Support APIs include ticket create/list/detail/reply/status update.

### Recently completed from this modification plan

- `/support` and `/tax-calculator` routes are registered.
- Settings page has been cleaned into customer-safe account/preference/about sections.
- More page now receives `canAccessInternalWorkspace` from auth state and hides Internal Workspace unless allowed.
- Auth state now carries `canAccessInternalWorkspace`.
- Backend `get_session_user` returns roles and `can_access_internal_workspace`.

### Remaining main gaps

- Service case detail still needs stronger separation between customer tracking and admin controls.
- Service catalogue should be backend-first by default for staging/production.
- Tax calculator should avoid presenting local fallback estimates as official.
- Expense tracker is still local-only through `SharedPreferences`.
- Support contact values and support categories should become backend-configurable.
- Tracking timeline should prefer real backend timeline/stages and only use static fallback for dev/demo empty states.
- Profile/auth state should become a shared provider used consistently by Home, More, Profile, and Settings.

---

## Priority Legend

- P0: Must fix before next stable test build.
- P1: Important for production-quality UX.
- P2: Backend-connected enhancement.
- P3: Future polish.

---

# P0 - Must Fix / Verify

## 1. Register Support and Tax Calculator routes

Status: Done.

Verified expected routes:

```text
/support
/tax-calculator
```

Required test:

- Home > Calculator opens.
- More > Tax Calculator opens.
- Home/More > Support opens.
- `flutter analyze` stays clean.

---

## 2. Clean Settings page

Status: Done.

Current direction:

- Keep customer-facing settings focused on Account, Preferences, and About.
- Do not show API server URL, backend technology label, environment label, testing flags, catalogue source, or raw connection/debug sections.
- Keep diagnostics only behind a future hidden developer-only screen if needed.

Required test:

- Open Settings as a normal customer.
- Confirm no technical backend/dev labels are visible.
- Confirm preference toggles load/save through backend.
- Confirm logout clears secure session and returns to login.

---

## 3. Hide Internal Workspace for normal customers

Status: Done.

Current direction:

- Backend returns capability flag.
- Auth state stores capability flag.
- More page renders Workspace group only when capability is true.

Required test:

- Customer user: Internal Workspace is hidden.
- System Manager/staff user: Internal Workspace is visible.
- Direct route access should still be protected by backend permissions.

---

## 4. Separate customer tracking from admin controls

Status: Next active P0.

### Problem

`ServiceCaseDetailScreen` should not expose admin-style controls to normal customers.

Controls to verify/hide for normal customers:

- Status update actions.
- Document approve/reject actions.
- Internal notes/actions.
- Staff-only case controls.

### Desired customer view

- Case status.
- Progress timeline.
- Required/missing documents.
- Upload document action.
- Support/contact action.
- Expected completion / next step.

### Desired internal view

- Status update controls.
- Document review controls.
- Internal notes.
- Expected completion update.

### Backend improvement

Return capability flags with case detail:

```json
{
  "can_update_status": false,
  "can_review_documents": false,
  "can_view_internal_notes": false
}
```

Flutter should render controls from backend capability flags, not role-name checks.

### Test

- Login as customer and open My Services detail.
- Customer can upload/request support but cannot approve/reject/update status.
- Login as internal user and confirm internal controls appear only when backend allows them.

---

# P1 - Important Improvements

## 5. Make service catalogue backend-first

### Current state

Flutter supports backend service catalogue, and backend returns service metadata including required documents.

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
wizard_config
required_documents
required_document_details
```

### Test

- Service catalogue loads real backend services in development with `OMC_API_BASE_URL`.
- Production build does not silently fall back to stale local JSON.
- Empty backend catalogue shows a clean empty state, not fake data.

---

## 6. Improve service progress model

### Current state

Flutter uses backend progress/timeline when available, but static fallback steps can still appear when timeline is empty.

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

Support screen still has static contact/channel/topic style content in Flutter.

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

Flutter should use backend support config and keep local config only as dev fallback.

---

## 8. Improve More page structure

Status: Partly done.

Current More page groups:

```text
Account
Services
Workspace - capability gated
Logout
```

Next polish:

- Rename `Expense Tracker` to `Personal Expense Tracker` if this is meant as a customer personal finance tool.
- Consider moving `Support` under a separate Help group if More becomes crowded.
- Keep Dashboard only if the dashboard is customer-focused; otherwise hide/gate internal analytics.

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

Auth state contains user id and internal workspace capability.

### Improvement

Use `get_profile` as source for:

- Display name.
- Phone.
- Company.
- Customer status.
- Approval status.
- Internal access capability if added to profile response.

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

- `Store only on this device`.
- `Sync with my OMC account`.

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

- Missing documents first.
- Rejected documents with reason.
- Uploaded documents with preview/download.
- Upload action per missing document.

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

- Pay now when gateway URL exists.
- Upload receipt for manual payment.
- Receipt review timeline.
- Rejected receipt reason.

---

# P3 - Future Polish

## 16. App version/build info

Add `package_info_plus` and show app version/build number in Settings or More.

Technical details should remain hidden from normal users.

## 17. Safe offline caching

Cache low-risk data:

- service catalogue.
- profile summary.
- dashboard summary.
- settings preferences.

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

# Immediate Next Step

Start from P0 item 4:

```text
ServiceCaseDetailScreen capability gating
```

Work order:

1. Inspect `service_case_detail_screen.dart`.
2. Find all status/document/admin controls.
3. Add model fields for backend capability flags with safe defaults `false`.
4. Hide admin controls unless backend allows them.
5. Add/adjust backend response flags in `get_service_case` if missing.
6. Run `flutter analyze` after the patch.
