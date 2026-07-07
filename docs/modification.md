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

## Current Repo Status

### Completed foundations

- Flutter app is feature-first and includes auth, home, service catalogue, tracking, documents, payments, tax calculator, expense tracker, knowledge, notifications, profile, settings, support, leads, customers, tasks, and internal workspace.
- Backend method names are centralized in `ApiConfig`.
- Frappe backend app exposes mobile APIs and OMC-owned DocTypes for core flows.
- Backend service catalogue returns service pricing labels, wizard metadata, completion time, and required-document metadata.
- Backend document/payment upload validation exists for type, size, ownership, privacy, and linked records.
- Settings preferences are backend-connected through `get_settings_preferences` and `update_settings_preferences`.
- Notification APIs include list, detail, mark single read, mark all read, and push-token register/unregister.
- Support APIs include ticket create/list/detail/reply/status update.
- Support configuration is backend-driven through `get_support_config`.
- Mobile app configuration is backend-driven through `get_mobile_app_config`.
- Profile summary is backend-driven through `get_profile` and synced into auth state.

### Recently completed

- `/support` and `/tax-calculator` routes are registered.
- Settings page has been cleaned into customer-safe account/preference/about sections.
- More page receives `canAccessInternalWorkspace` from auth/profile state and hides Internal Workspace unless allowed.
- Backend `get_session_user` returns roles and `can_access_internal_workspace`.
- Service-case detail/status/document-review Flutter methods route through secured wrappers.
- `omc_app.api.mobile.get_service_cases` routes through the secured service-case list API.
- Service-case list/detail response parsing accepts aliases and backend capability flags.
- Service catalogue loading is backend-first by default.
- Service catalogue local JSON fallback is development-only and requires explicit `OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=true`.
- Tax calculator clearly labels backend-verified results versus unofficial fallback estimates.
- Expense tracker backend sync foundation has been added while local-only mode remains the safe default.

### Remaining main gaps

- Copied backend files in the running Frappe bench still need local verification, migrate, and Frappe reload.
- Flutter analyze and role-based manual verification still need to be run locally.
- Expense tracker UI still needs the visible local/sync toggle wired into the large tracker screen.
- Service tracking timeline should continue to prefer real backend timeline/stages and only use static fallback for dev/demo empty states.
- Payment UX, dynamic service request forms, document checklist polish, offline caching, app version display, and push notifications remain future polish items.

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

Expected routes:

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
- Auth/profile state stores capability flag.
- More page renders Workspace group only when capability is true.

Required test:

- Customer user: Internal Workspace is hidden.
- System Manager/staff user: Internal Workspace is visible.
- Direct route access should still be protected by backend permissions.

---

## 4. Separate customer tracking from admin controls

Status: Repo patched - pending local bench reload and UI verification.

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

Expected list/detail fields include:

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

Required local verification:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

Then run:

```bash
cd ~/data_drive/app_omc/omc_app
flutter analyze
```

Manual test:

- Login as customer and open My Services detail.
- Customer can upload/request support but cannot approve/reject/update status.
- Login as internal user and confirm internal controls appear only when backend allows.

---

# P1 - Important Improvements

## 5. Make service catalogue backend-first

Status: Done - pending local Flutter analyze/test.

Current state:

- Flutter supports backend service catalogue.
- Backend returns service metadata including required documents.
- Flutter catalogue parser accepts additional backend list keys and response wrappers.
- Production/staging do not silently fall back to local JSON.

Required test:

- Run `flutter analyze`.
- Service catalogue loads real backend services in development with `OMC_API_BASE_URL`.
- Production build does not silently fall back to stale local JSON.
- Empty backend catalogue shows a clean empty state, not fake data.
- Development fallback works only with `--dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=true`.

---

## 6. Improve service progress model

Status: Partially patched - list/detail response normalized; final timeline verification remains.

Backend response should include:

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

Optional future DocType:

```text
OMC Service Stage Template
```

Flutter should prefer backend timeline/stages and only use fallback for empty demo/dev states.

---

## 7. Backend-driven support configuration

Status: Done.

API:

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

Status: Done.

API:

```text
omc_app.api.mobile.get_mobile_app_config
```

Flutter consumes support details, feature flags, branding, and meta source/fallback values.

---

## 10. Improve profile/auth state

Status: Done.

Current state:

- `get_profile` is the source for display name, phone, company, customer status, approval status, and internal access capability.
- Shared profile provider syncs summary fields into auth state.
- Home and More consume profile/auth state.

Future polish:

- Continue checking Profile and Settings screens for duplicate fallback wording.

---

# P2 - Backend-Connected Enhancements

## 11. Optional backend sync for Expense Tracker

Status: Backend and repository foundation added - visible UI toggle pending.

Current safe default:

- Local mode remains default.
- Existing entries remain stored in `SharedPreferences` unless the user explicitly chooses account sync later.

Backend DocTypes added:

```text
OMC Expense Category
OMC Expense Entry
```

Backend APIs added:

```text
omc_app.api.expense.get_expense_categories
omc_app.api.expense.get_expense_entries
omc_app.api.expense.create_expense_entry
omc_app.api.expense.update_expense_entry
omc_app.api.expense.delete_expense_entry
omc_app.api.expense.get_expense_summary
```

Flutter foundation added:

- `ApiConfig` constants for expense sync APIs.
- Sync-ready repository methods.
- Persisted storage-mode controller.

Next UI step:

- Wire `ExpenseTrackerScreen` banner/toggle to `expenseTrackerStorageModeProvider`.
- When mode is `localOnly`, keep current local read/save/delete behaviour.
- When mode is `syncWithAccount`, load from backend and call create/update/delete APIs.
- Provide explicit wording before upload/sync to avoid unexpected data movement.

---

## 12. Backend configurable tax slabs

Status: Flutter result labeling done; backend tax-year/slab DocTypes still future.

Current state:

- Tax calculator calls backend first.
- Fallback estimates are clearly labeled unofficial and not for filing.

Future backend additions:

```text
OMC Tax Year
OMC Tax Slab
omc_app.api.mobile.get_tax_years
omc_app.api.mobile.calculate_tax
```

Flutter future improvement:

- Tax year selector.

---

## 13. Dynamic service request forms

Status: Future.

Future DocType:

```text
OMC Service Form Field
```

Flutter should render service-specific form fields from backend config and submit structured `service_details`.

---

## 14. Better document checklist

Status: Future polish.

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

Flutter should show missing documents first, rejected documents with reason, uploaded documents with preview/download, and upload action per missing document.

---

## 15. Better payment UX

Status: Future polish.

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

Flutter should show pay-now when gateway URL exists, receipt upload, receipt review timeline, and rejected receipt reason.

---

# P3 - Future Polish

## 16. App version/build info

Add `package_info_plus` and show app version/build number in Settings or More.

## 17. Safe offline caching

Cache low-risk data only:

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

Wire the visible Expense Tracker storage-mode toggle in `ExpenseTrackerScreen`, then run local backend migration/restart and `flutter analyze`.
