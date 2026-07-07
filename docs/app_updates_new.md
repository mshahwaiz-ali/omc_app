# OMC App Production Readiness Roadmap

This document tracks the remaining work required before the OMC mobile app and Frappe backend can be treated as production-ready.

## Current Status

The repository contains:

* Flutter mobile app in `omc_app/`
* Frappe backend app in `backend_omc_app/apps/omc_app/`
* Backend integration contract in `flutter_backend_integration_contract.md`
* Product and implementation docs in `docs/`

The app UI is mostly built and many backend methods already exist, but production release should wait until all customer-facing actions are connected to real backend logic and all mock/fallback behaviour is isolated from production builds.

## Production Rule

Flutter must use Frappe backend APIs as the source of truth.

No production screen should show an action unless one of these is true:

1. The action is fully connected to a backend endpoint.
2. The action is intentionally read-only.
3. The action is hidden in production until the backend is ready.

Mock data and preview flows are allowed only behind local development flags and must never be active in production builds.

## P0 — Must Fix Before Production

### 1. Backend Contract Alignment

Audit every Flutter repository/model against the backend response.

Status: ApiConfig mobile method scan passed with zero missing backend methods. Backend now exposes service catalogue required-document metadata and push-token registration endpoints.

Required checks:

* `ApiConfig` method names match actual backend methods. ✅
* Backend returns the same field names Flutter parses. ✅
* Flutter does not depend on invented fields. ✅
* Backend does not silently ignore frontend fields. ✅
* Every list/detail endpoint has tested empty, success, permission, and error states. In progress.

Modules to verify:

* Auth/session
* Profile
* Settings/preferences
* Dashboard
* Service catalogue
* Service requests/cases
* Documents
* Payments
* Notifications
* Support tickets
* Internal workspace
* Leads
* Customers
* Tasks
* Tax calculator

### 2. Settings Preferences

Current settings UI includes service, document, payment, tax, email, and WhatsApp notification controls.

Before production:

* Add matching fields to backend `OMC Customer Preference`, or
* Rename Flutter preference fields to match backend fields exactly.

Required production fields:

* `service_updates_enabled`
* `document_reminders_enabled`
* `payment_alerts_enabled`
* `tax_alerts_enabled`
* `email_notifications_enabled`
* `whatsapp_notifications_enabled`
* `theme`
* `language`

The settings screen should not show toggles that are not saved by the backend.

### 3. Service Progress Tracker

Service tracking must be backend-driven.

Backend `get_service_case` should return:

```json
{
  "name": "OMC-SR-2026-00001",
  "title": "Service Request",
  "status": "In Progress",
  "progress": 0.6,
  "next_step": "OMC team is reviewing your documents.",
  "required_documents": [],
  "submitted_documents": [],
  "missing_documents": [],
  "timeline": [],
  "attachments": []
}
```

Recommended status-to-progress mapping:

| Status               | Progress |
| -------------------- | -------: |
| Open                 |     0.10 |
| Waiting for Customer |     0.35 |
| In Progress          |     0.60 |
| Under Review         |     0.80 |
| Completed            |     1.00 |
| Cancelled            |     0.00 |

The progress bar must not rely on hardcoded sample data in production.

### 4. Document Upload Security

Client-side upload limits already exist, but backend validation must also be added.

Required server-side rules:

* Max file size: 10 MB per file.
* Max files per upload action: 5.
* Max files per service case: configurable, recommended 20.
* Allowed extensions: `pdf`, `jpg`, `jpeg`, `png`, `doc`, `docx`.
* Allowed MIME types must match extension.
* Force private files for customer documents.
* Verify uploaded file belongs to the current user/session.
* Verify file is attached to the correct service request or document record.
* Reject executable/script/archive files.
* Reject empty files.
* Log upload events in service timeline.
* Add clear error messages for rejected files.

Recommended backend setting:

```python
ALLOWED_DOCUMENT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png", "doc", "docx"}
MAX_DOCUMENT_SIZE_BYTES = 10 * 1024 * 1024
MAX_FILES_PER_UPLOAD = 5
MAX_FILES_PER_CASE = 20
```

### 5. Authentication and Session Handling

Before production:

* Confirm email/password login works with wrong-password errors.
* Confirm secure session persistence.
* Confirm logout clears local secure storage.
* Add session-expired handling.
* Hide Google login unless real Google token validation is implemented.
* Confirm production builds reject non-HTTPS backend URLs.
* Confirm mock auth cannot run in production.

### 6. Notifications

Required production behaviour:

* Notification list loads from backend.
* Detail screen loads from backend.
* Opening a notification marks it as read.
* Unread count refreshes after read.
* Add “Mark all as read”. ✅
* Add backend endpoint for `mark_all_notifications_read`. ✅
* Add mobile push token registration endpoints. ✅

Recommended new backend methods:

```text
omc_app.api.mobile.mark_all_notifications_read
omc_app.api.mobile.register_push_token
omc_app.api.mobile.unregister_push_token
```

### 7. Payments and Receipts

Receipt upload must not directly mark a payment as paid unless OMC’s business rule allows it.

Recommended flow:

1. Customer uploads receipt.
2. Payment status becomes `Receipt Submitted`.
3. OMC staff reviews receipt.
4. Staff marks payment as `Paid` or `Rejected`.
5. Timeline and notification are created.

Required statuses:

* Pending
* Receipt Submitted
* Under Review
* Paid
* Rejected
* Cancelled

### 8. Support Tickets

Support should be more than ticket creation.

Required backend features:

* Create ticket
* List tickets
* Ticket detail
* Add customer reply
* Add staff reply
* Ticket timeline/messages
* Close/reopen rules
* Notification on staff response

Recommended new backend method:

```text
omc_app.api.mobile.add_support_ticket_reply
```

## P1 — Strongly Recommended Before First Public Release

### 1. Service Catalogue

Production catalogue should come from backend by default.

Status: backend contract implemented for service pricing/duration aliases, active services, required-document metadata, and wizard config fields. Flutter production fallback removal still needs final app-side verification.

Required:

* Backend returns required documents per service. ✅
* Backend returns service pricing/estimated duration fields and Flutter aliases. ✅
* Backend has active/inactive service controls. ✅
* Backend has wizard config fields. ✅
* Remove production dependency on bundled/local catalogue fallback. Pending Flutter verification.

### 2. Required Documents

Backend should define required documents per service.

Recommended DocType:

```text
OMC Service Required Document
```

Fields:

* service
* document_title
* document_type
* is_required
* instructions
* allowed_extensions
* max_size_mb
* sort_order

Service request detail should calculate:

* required_documents
* submitted_documents
* missing_documents

### 3. Timeline Events

Every meaningful action should create a timeline row:

* Request created
* Document requested
* Document uploaded
* Document approved
* Document rejected
* Payment requested
* Receipt uploaded
* Payment verified
* Customer message
* Staff update
* Case completed
* Case cancelled

### 4. Error and Empty States

Every module must have:

* Loading state
* Empty state
* API error state
* Pull-to-refresh
* Retry button
* Session-expired state
* Permission error state

### 5. Internal Workspace Permissions

Internal workspace must be role-gated.

Required:

* Customers should not see internal CRM modules.
* Internal users should see leads/customers/tasks only if role allows.
* Backend must enforce permissions; Flutter hiding alone is not enough.

## P2 — Release Quality

### 1. CI Checks

Add GitHub Actions workflow:

* Flutter pub get
* Flutter analyze
* Flutter test
* Build Android debug/release artifact
* Python syntax check for backend
* Optional Frappe import check

### 2. Release Build Checklist

Before release:

```bash
cd omc_app
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

### 3. Security Checklist

* HTTPS only in production.
* No hardcoded credentials.
* No debug/mock mode in production.
* Private uploads by default.
* Backend validates file size/type.
* Backend validates user ownership.
* Backend validates role permissions.
* Sensitive errors are not exposed to users.
* API errors are normalized.
* Rate limiting enabled for signup/login/support/upload.
* Audit logs for document/payment/status changes.

### 4. Production UX Checklist

* Hide non-functional buttons.
* Hide “coming later” actions.
* All visible actions must either work or show a clear backend-backed state.
* No fake counters.
* No hardcoded customer data.
* No static payment/document/service status in production.
* Pull-to-refresh on all dynamic modules.
* Clear success/failure snackbars.
* Disable submit buttons during API calls.
* Prevent duplicate submissions.

## Suggested Implementation Order

### Phase 1 — Contract Cleanup

1. Compare Flutter models with backend responses.
2. Fix settings preference mismatch.
3. Fix service case detail response.
4. Fix document upload contract.
5. Fix payment receipt flow.
6. Fix notification read/update flow.

### Phase 2 — Backend Logic Completion

1. Add service required document model.
2. Add service progress calculation.
3. Add missing document calculation.
4. Add support ticket replies.
5. Add notification mark-all-read.
6. Add push token registration if needed.

### Phase 3 — Flutter Production Wiring

1. Remove/disable fallback catalogue in production.
2. Connect all visible buttons to real repository methods.
3. Add controllers for mutations.
4. Add loading/disabled states.
5. Add optimistic refresh where safe.
6. Add retry and error states.

### Phase 4 — Security and Release

1. Add server-side upload validation.
2. Add role checks.
3. Add rate limits.
4. Add CI workflow.
5. Run release build.
6. Test on real Android device.
7. Test with production-like Frappe site.

## Definition of Done

The app is production-ready only when:

* Every visible button has real behaviour.
* Every production module gets data from backend.
* Backend validates permissions and ownership.
* Uploads are protected server-side.
* Service progress is calculated from real backend status/timeline/documents.
* Settings toggles persist correctly.
* Notifications update read/unread state correctly.
* Payment receipt upload uses a review-safe workflow.
* Google login is either fully implemented or hidden.
* `flutter analyze`, `flutter test`, and release build pass.
* Backend API methods are tested with real Frappe site data.
