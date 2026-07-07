# OMC App Modification Plan

This document records the active improvement phase for the OMC Flutter app and Frappe backend.

Primary focus: Flutter mobile app.
Secondary focus: backend/API changes needed to support a cleaner, backend-driven mobile experience.

Last reviewed: 2026-07-07.

---

## Working Rules

- Branch flow: commit directly to `main` unless a PR is explicitly requested.
- Keep `chatgpt-work` synced to `main` after direct-main work.
- Do not force-push unless explicitly approved.
- Backend-driven architecture is mandatory for production behaviour.
- Do not use `sync_apps.sh` for the current local bench sync situation.
- Current local backend sync direction is:

```text
backend_omc_app/apps/omc_app -> backend_omc_app/frappe-bench/apps/omc_app
```

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
- Service-case detail/status/document-review Flutter methods route through `omc_app.api.secured_mobile` wrappers.
- `omc_app.api.mobile.get_service_cases` routes through the secured service-case list API.
- Service-case list response is normalized for Flutter tracking cards.
- Service-case list capability flags are role-aware.
- Secured service-case detail accepts request aliases: `case_id`, `name`, `service_request`, `request_id`.
- Secured service-case status update accepts request aliases: `case_id`, `name`, `service_request`, `request_id`.
- Secured document review accepts document aliases: `document_id`, `document`, `name`.
- Service catalogue parser accepts additional backend response keys.
- Service tracking parser accepts additional backend response shapes.

### Remaining main gaps

- Copied backend files in the running Frappe bench still need local verification and Frappe reload.
- Service case detail still needs final customer/internal UI verification after secured API routing.
- Service catalogue should be backend-first by default for staging/production.
- Tax calculator should avoid presenting local fallback estimates as official.
- Expense tracker is still local-only through `SharedPreferences`.
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

Status: Backend patched - pending local bench reload and UI verification.

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

### Backend route state

Expected mobile routes:

```text
omc_app.api.mobile.get_service_cases -> omc_app.api.secured_mobile.get_service_cases
omc_app.api.mobile.get_service_case -> omc_app.api.secured_mobile.get_service_case
omc_app.api.mobile.update_service_case_status -> secured wrapper
omc_app.api.mobile.update_service_document_status -> secured wrapper
```

Expected accepted aliases:

```text
case detail: case_id, name, service_request, request_id
case status: case_id, name, service_request, request_id
document review: document_id, document, name
```

Expected list fields:

```text
id
reference
case_reference
progress
progress_percent
current_stage
next_step
required_documents_count
submitted_documents_count
missing_documents_count
customer_action_required
can_update_status
can_review_documents
can_view_internal_notes
```

Security expectation:

- Internal workspace users receive internal capability flags when allowed.
- Normal customers receive capability flags as false.
- Normal customers should not receive internal remarks in case detail response.
- Flutter should render controls from backend capability flags, not role-name checks.

### Required local verification

First verify copied backend files in the running bench target:

```bash
cd ~/data_drive/app_omc/backend_omc_app

grep -n "def get_service_cases\|omc_app.api.mobile.get_service_cases\|results\|records" \
  frappe-bench/apps/omc_app/omc_app/api/secured_mobile.py \
  frappe-bench/apps/omc_app/omc_app/hooks.py
```

If the expected secured routing/list normalization code is present, reload Frappe:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench

bench --site all clear-cache
bench restart
```

If behaviour is still old after restart:

```bash
bench --site all migrate
bench restart
```

### Flutter test

- Run `flutter analyze`.
- Login as customer and open My Services detail.
- Customer can upload/request support but cannot approve/reject/update status.
- Login as internal user and confirm internal controls appear only when backend allows them.

---

# P1 - Important Improvements

## 5. Make service catalogue backend-first

Status: Next after P0 service tracking verification.

### Current state

Flutter supports backend service catalogue, and backend returns service metadata including required documents.

Recent parser improvement:

- Flutter catalogue parser accepts additional backend list keys and response wrappers.

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

Status: Partially patched - list response normalized; detail/timeline verification remains.

### Current state

Flutter uses backend progress/timeline when available, but static fallback steps can still appear when timeline is empty.

Recent parser improvement:

- Flutter service tracking parser accepts additional response shapes such as `results`, `records`, wrapped lists, and normalized tracking fields.

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

Status: Done.

### Current state

Support screen now loads backend support channels/topics through `get_support_config` and keeps local values as safe fallback.

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

Flutter uses backend support config and keeps local config as safe fallback when backend config is unavailable or empty.

---

## 8. Improve More page structure

Status: Done.

Current More page groups:

```text
Account
Services
Help
Workspace - capability gated
Logout
```

Completed polish:

- Renamed `Expense Tracker` to `Personal Expense Tracker`.
- Moved `Support` into a separate Help group.
- Updated Dashboard wording to customer-focused service summary language.
- Kept Internal Workspace backend capability-gated.

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

Verify copied backend files in the Frappe bench, then reload Frappe.

Run locally:

```bash
cd ~/data_drive/app_omc/backend_omc_app

grep -n "def get_service_cases\|omc_app.api.mobile.get_service_cases\|results\|records" \
  frappe-bench/apps/omc_app/omc_app/api/secured_mobile.py \
  frappe-bench/apps/omc_app/omc_app/hooks.py
```

Expected result:

- `secured_mobile.py` contains `def get_service_cases` and list response normalization for `results` / `records`.
- `hooks.py` contains the route override for `omc_app.api.mobile.get_service_cases`.

Then run:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench

bench --site all clear-cache
bench restart
```

If behaviour is still old:

```bash
bench --site all migrate
bench restart
```

After backend reload passes, continue with:

1. `flutter analyze`.
2. Customer service-case detail verification.
3. Internal user service-case detail verification.
4. P1 item 5: backend-first service catalogue behaviour.
