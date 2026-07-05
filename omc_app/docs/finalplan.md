# OMC App Final Execution Plan

_Last updated: 2026-07-05_

## Goal

Build `omc_app` as a premium, fast, backend-connected Flutter mobile app for OMC House.

The final app must not depend on fake/local bypass flows as the main product path. Temporary mock/sample data is allowed only for isolated UI preview or testing mode while real Frappe endpoints are being confirmed.

## Current Repo Status

### Completed foundation

- Clean Flutter app created under `omc_app/`.
- Riverpod app bootstrap is active through `ProviderScope`.
- GoRouter-based routing exists with auth-aware redirects.
- Feature-first structure is in place.
- Shared core providers exist for secure storage, Dio, and Frappe client.
- Core Frappe networking supports:
  - `GET /api/method/...`
  - `POST /api/method/...`
  - `GET /api/resource/...`
  - `POST /api/resource/...`
  - password login
  - file upload
- Session/cookie/token headers are injected through Dio interceptors.
- Premium shell/navigation is present with Home, Services, Calculator, Support, and More tabs.
- Service catalogue and service request draft flow exist.
- Service request creation is connected to the configured OMC/Frappe method path.
- Attachment upload flow exists after service request creation.
- My Services route, list flow, case detail model, document status, and timeline UI foundation exist.

### Current technical risk

- `serviceCasesProvider` still returns `sampleCasesForUiPreview()` because the final backend endpoint mapping is not confirmed yet.
- `ServiceCaseRepository.fetchServiceCases()` and `fetchServiceCaseDetail()` are backend-ready but still point to placeholder method names:
  - `omc_app.api.mobile.get_service_cases`
  - `omc_app.api.mobile.get_service_case`
- `createServiceRequest()` still logs backend response with `debugPrint`; remove this after endpoint shape is confirmed.
- Some screens still need deeper backend readiness: notifications mark-as-read, profile, settings, internal workspace modules.
- Knowledge / News module foundation is now added with backend-first repository, list/detail screens, routes, and More menu entry.
- `pubspec.yaml` still has default Flutter description text; polish metadata later.
- Real backend response contracts must be confirmed before expanding more UI around assumptions.

## Non-Negotiable Rules

1. Backend-connected architecture stays mandatory.
2. No fake/local bypass flow should become the production path.
3. Any temporary/mock/sample data must be clearly isolated and removable.
4. Keep feature-first architecture:
   - `lib/app`
   - `lib/core`
   - `lib/features/<feature>`
5. Keep each feature split into sensible layers:
   - `data`
   - `application` when state/logic is non-trivial
   - `presentation`
6. Preserve current working functionality before refactoring.
7. Run `flutter analyze` before every commit.
8. Commit after each stable milestone.

## Phase 1 — Backend Contract Lock

### Objective

Confirm exact OMC/Frappe API methods and response shapes before building deeper product flows.

### Tasks

- Confirm final login endpoint behavior:
  - request body
  - returned session/cookie/token shape
  - error shape
- Confirm service catalogue source:
  - static JSON only, backend resource, or backend method
- Confirm service request creation endpoint:
  - method path
  - payload keys
  - required fields
  - returned request/case ID
  - doctype name for file upload
- Confirm My Services endpoint:
  - list method
  - detail method
  - status values
  - progress format
  - required/submitted/missing document shape
  - timeline shape
- Confirm dashboard endpoint:
  - customer dashboard data
  - internal dashboard data if required

### Exit Criteria

- Backend method names are final.
- Repository mapping works without sample data in normal mode.
- Error messages are clean and user-safe.
- `flutter analyze` returns zero issues.

## Phase 2 — Auth and Session Hardening

### Objective

Make login/session reliable before adding more features.

### Tasks

- Verify login against real OMC/Frappe server.
- Add session validation endpoint if available.
- Handle expired session globally.
- Redirect to login on 401/403 where appropriate.
- Add logout backend call if available.
- Keep credentials out of SharedPreferences.
- Keep secure storage as the only session/token store.

### Exit Criteria

- Cold app start correctly restores or rejects session.
- Expired sessions fail safely.
- Login/logout flow is stable.
- No sensitive logs remain.

## Phase 3 — Service Request Production Flow

### Objective

Make service request submission production-grade.

### Tasks

- Replace response debug logging with structured handling.
- Finalize request payload mapping.
- Finalize request ID extraction.
- Finalize attachment `doctype` and `docname` rules.
- Add upload failure handling:
  - request created but upload failed
  - partial file upload failure
  - retry path
- Add success screen with reference number and next step.
- Add validation per service type where required.

### Exit Criteria

- User can create a request on real backend.
- User can upload attachments to the correct backend document.
- App shows correct reference/status after submit.
- No fake request is created in normal mode.

## Phase 4 — My Services Real Data

### Objective

Move My Services from UI preview to real backend data.

### Tasks

- Convert `serviceCasesProvider` from simple `Provider<List<ServiceCase>>` to async state.
- Use `fetchServiceCases()` for normal mode.
- Keep sample data only behind explicit development/testing mode if still needed.
- Add loading, empty, error, and retry states.
- Connect case detail screen to backend detail method.
- Add missing-document upload action from case detail.
- Add status normalization and visual mapping.

### Exit Criteria

- My Services list comes from backend.
- Detail screen comes from backend.
- Missing document upload works against selected case.
- No production sample data remains.

## Phase 5 — Core Customer Modules

### Objective

Complete main customer-facing app areas.

### Modules

1. Documents
   - Uploaded documents list
   - Required documents
   - Missing documents
   - Upload/replace document
2. Dashboard
   - Active cases
   - Pending actions
   - Tax reminders
   - Recent activity
3. Notifications
   - Service updates
   - Document requests
   - Tax alerts
   - Mark-as-read backend readiness
4. Profile
   - Personal info
   - CNIC/NTN/status fields where relevant
   - Contact information
5. Settings
   - Notification preferences
   - Theme/settings if needed
   - Account/session actions
6. Tax Calculator
   - Keep current calculator screen polished
   - Validate formulas before calling production-ready
7. Knowledge / News
   - Backend-first article/news list
   - Backend-first article detail
   - Empty state when endpoint is unavailable
   - More menu access

### Exit Criteria

- Main customer journey works end-to-end:
  - login
  - browse service
  - submit request
  - upload documents
  - track service
  - receive/see updates

## Phase 6 — Internal Workspace Modules

### Objective

Build internal workspace only after customer flow is stable.

### Modules

- Leads
- Customers
- Tasks
- Payments
- Service operations dashboard
- Assigned cases
- Follow-ups

### Rule

Internal workspace must use authenticated backend data and role-aware access. Do not expose internal-only features to normal customers unless backend roles allow it.

## Phase 7 — Premium UI/UX Pass

### Objective

Make the app feel modern, luxury, clean, and consistent.

### Tasks

- Unify spacing, card radius, typography, and shadows.
- Audit dark/light compatibility if enabled.
- Polish empty states and errors.
- Replace generic placeholders with designed screens.
- Add skeleton/loading states.
- Add haptic/interaction polish where useful.
- Optimize list performance.
- Ensure forms are easy, minimal, and guided.

### Exit Criteria

- UI feels consistent across all modules.
- No unfinished placeholder appears in main customer path.
- Forms are easy to complete.

## Phase 8 — Production Readiness

### Objective

Prepare app for stable release builds.

### Tasks

- Add app icons/splash configuration.
- Finalize app name and package IDs.
- Confirm Android signing setup.
- Confirm iOS bundle setup if needed.
- Add build flavors or dart-define setup for dev/staging/prod URLs.
- Add release build checks.
- Add privacy/security review.
- Remove debug logs.
- Verify no secrets are committed.

### Exit Criteria

- `flutter analyze` passes.
- Android release build succeeds.
- Backend base URL is configurable through build-time env.
- No sensitive values are hardcoded except safe public host defaults.

## Recent Progress

- Phase 4 service request polish completed:
  - missing-document upload from case detail
  - CNIC/NTN validation
  - internal customer picker readiness
- Phase 5 wizard polish completed:
  - IRIS/business dropdown validation
  - improved wizard wording
- Phase 7 tax calculator foundation completed:
  - backend-first repository/data layer
  - safe local fallback
- Phase 8 support/notifications polish completed:
  - support category WhatsApp quick actions
  - notification deep links to service/payment records
- Knowledge / News foundation added:
  - backend-first repository/data layer
  - safe empty fallback when endpoint is unavailable
  - premium list/detail screens
  - More menu and router integration

## Immediate Next Steps


### Step 1

Commit this plan and keep it updated after each milestone.

### Step 2

Continue customer-facing backend readiness:

- add Notifications mark-as-read method readiness
- keep Knowledge / News endpoint names centralized in ApiConfig
- keep safe empty states when backend endpoints are unavailable
- avoid fake production data

### Step 3

Patch service request debug logging:

- remove raw `debugPrint` from production path
- replace with safe structured handling or temporary debug guarded by debug mode

### Step 4

Start backend contract verification with the actual OMC/Frappe endpoints.

## Recommended Commit Style

Use small stable commits:

- `Add final execution plan`
- `Prepare My Services async backend state`
- `Harden service request response handling`
- `Connect My Services to backend endpoint`
- `Polish service tracking states`

## Working Command Checklist

Run from `~/data_drive/app_omc/omc_app`:

```bash
flutter analyze
git status
git add -A
git commit -m "Add final execution plan"
git push
```

After code patches:

```bash
flutter analyze
git diff --stat
git status
```
