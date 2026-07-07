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
- Service-case detail/status/document-review Flutter methods now route through `omc_app.api.secured_mobile` wrappers.

### Remaining main gaps

- Service case detail still needs final customer/internal UI verification after secured API routing.
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

Status: In progress - secured API routing patched.

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

Current patch:

- `serviceCaseDetailMethod` now points to `omc_app.api.secured_mobile.get_service_case`.
- `updateServiceCaseStatusMethod` now points to `omc_app.api.secured_mobile.update_service_case_status`.
- `updateServiceDocumentStatusMethod` now points to `omc_app.api.secured_mobile.update_service_document_status`.

### Test

- Run `flutter analyze`.
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
