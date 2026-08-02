# OMC Application Implementation and Inspection Report

## 1. Executive summary

The agreed OMC end-to-end workflow plan has been implemented and validated across the Flutter application and the OMC-owned Frappe backend. Routine customer, staff, reviewer, manager and administrator workflows are available through the app while backend capabilities and record scope remain authoritative.

All available in-scope executable validation gates passed:

- Backend application suite: **547/547 passed**.
- Flutter unit and widget suite: **296/296 passed**.
- Flutter Linux integration suite: **1/1 passed**.
- Flutter analyzer: **zero issues**.
- Android debug APK: **built successfully**.
- Real local HTTP workflow: **passed from signup through operational completion**.
- Migration and cache refresh: **passed**.
- Reserved QA cleanup: **passed with zero remaining users, customer profiles, service requests or temporary SMTP accounts**.

The only unverified release check is physical fingerprint/Face ID behavior because no physical biometric device was connected. This result was not fabricated.

## 2. Repository and scope inspected

Workspace root:

`/home/muhammad-shahwaiz-ali/data_drive/app_omc`

Primary components:

- Flutter app: `omc_app/`
- Runtime OMC backend: `backend_omc_app/frappe-bench/apps/omc_app/omc_app/`
- Human-readable test report: `docs/test_reports/omc_e2e_workflow_report_2026-08-02.md`
- Machine-readable test report: `docs/test_reports/omc_e2e_workflow_report_2026-08-02.json`

Current Git state at inspection time:

- Branch: `main`
- HEAD: `6179919f` — `codex all done`
- Previous main implementation commit: `772d3a9b` — `codex`
- `HEAD`, `origin/main` and `origin/HEAD` point to `6179919f`.
- The worktree was clean before this report was created.

The main implementation commit added or updated 59 files with 2,698 insertions and 139 deletions. The final hardening commit changed 19 files with 794 insertions and 146 deletions.

No ERPNext source file was changed as part of the workflow implementation. The HS Code repair is owned by the OMC app. No unrelated system file is part of the Git change set.

## 3. Architecture decisions implemented

### 3.1 Backend-owned authority

The backend is the source of truth for:

- Effective explicit roles.
- Capabilities and route eligibility.
- Record-level scope.
- Workflow transitions.
- Customer-facing workflow projection.
- Completion blockers.
- Duplicate-request decisions.
- Discounts, approval thresholds and final prices.
- Document and payment review authority.
- ERP synchronization and recovery.

Flutter displays and acts on the returned contract. It does not grant permissions independently.

### 3.2 Canonical workflow contract

`workflow_contract.py` now owns the customer-facing workflow projection:

- `status`
- `display_status`
- `current_stage`
- `progress`
- `progress_percent`
- `customer_action_required`
- `next_action`
- `next_step`
- `milestones`
- `completion_blockers`
- `completion_eligible`
- `documents_complete`
- `payment_complete`

Persistent production-compatible statuses were preserved:

- Service: `Open`, `In Progress`, `Waiting for Customer`, `Waiting for Payment`, `Completed`, `Cancelled`.
- Documents: `Pending`, `Uploaded`, `Approved`, `Rejected`.
- Payments: `Pending`, `Receipt Submitted`, `Under Review`, `Paid`, `Rejected`, `Cancelled`.

Legacy service status aliases are normalized at the backend boundary instead of introducing a destructive status migration.

### 3.3 Service Request and ERP Task authority

- `OMC Service Request` remains the customer-case record.
- ERPNext `Task` remains the operational work record.
- Request creation synchronizes an ERP Task idempotently.
- An open linked ERP Task now blocks case completion.
- The app's guarded `Submitted by QC` task operation completes the linked ERP Task and closes its assignments safely.
- The customer projection now reports operational completion from the actual linked Task rather than assuming that a completed case means operational work was completed.

This fixed a real inconsistency discovered during HTTP testing: the case previously allowed completion while its ERP Task was still open.

## 4. Roles, capabilities and onboarding

### 4.1 Explicit roles

Assignment and authorization use effective explicit Frappe roles rather than `role_profile_name`.

Covered roles include:

- OMC Customer
- OMC Consultant
- OMC Tax Associate
- OMC Business Partner
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Support Agent
- OMC Manager
- OMC Admin
- System Manager

Combined-role users receive the safe union of their explicit capabilities. Removing a role removes its routes and mutations after capability refresh.

Automatic assignment excludes:

- Disabled users.
- Website Users.
- Guest.
- Administrator.
- Users without an eligible operational capability.

### 4.2 Customer and staff registration separation

- Public customer signup creates a pending Website User workflow.
- Consultant, Tax Associate and Business Partner applications remain applications until reviewed.
- Applying for a staff role does not automatically grant internal access.
- Approval creates or updates the correct Website/System User and explicit roles.
- Rejection and pending states remain restricted.

### 4.3 Admin Control Center

The Flutter Admin Control Center and guarded backend APIs support:

- Registration approval and rejection.
- Staff invitations.
- Adding and removing canonical roles.
- Enabling and disabling accounts.
- Case reassignment.
- Exhausted ERP synchronization retry.
- Business configuration.
- Discount threshold and price-floor configuration.
- Discount approval and rejection.

Granular capabilities include:

- `can_manage_staff`
- `can_review_registrations`
- `can_manage_business_settings`
- `can_reassign_service_cases`
- `can_retry_sync`

Managers retain operational authority without receiving OMC Admin staff/configuration authority.

## 5. Operational workflow fixes

### 5.1 Duplicate service requests

- Active duplicate requests return a structured response instead of silently creating another case.
- The response includes the existing request, `duplicate: true`, `created: false` and allowed actions such as `resume_existing`.
- Parallel requests require both service configuration and explicit confirmation.
- Retry/idempotency tests ensure partial ERP bridge failures do not create duplicate records.

### 5.2 Documents

- Required documents are backend-owned.
- Uploads are private and linked to the correct service request.
- File extension, size, ownership and attachment scope are validated.
- Active duplicate submissions are rejected.
- Rejected documents can be replaced.
- The old rejected record remains available for audit/history while the approved replacement becomes active.
- Review assignments and customer timeline events are created and closed consistently.
- Terminal cases reject new document uploads.

### 5.3 Payments

- Payments are opened only after prerequisites are satisfied.
- Payment creation is blocked while a discount is pending approval.
- Receipt uploads are private, validated and customer-owned.
- Review supports `Under Review`, `Paid`, `Rejected` and `Cancelled`.
- Rejected receipts can be resubmitted.
- Payment list/detail scope is backend enforced.
- Pagination and backward-compatible response parsing are covered.

A real HTTP run exposed a scope defect: OMC Admin had `can_review_payments` but the payment module's older local scope still limited the admin to assigned cases. The fix now honors canonical `can_view_all_service_cases` and relevant finance queue capabilities. Regression coverage was added for both OMC Admin and Finance Reviewer.

### 5.4 Discounts and pricing

- Customer-created requests cannot inject staff discounts.
- Internal staff may request percentage or fixed-amount discounts with a reason.
- Percentage and fixed-amount bounds are validated.
- Backend settings control automatic approval thresholds and the minimum price floor.
- The backend calculates discount amount, approval state and final price.
- Pending discounts block payment creation.
- Approver/requester/applier attribution is preserved.

### 5.5 Assisted customers and referrals

- Internal staff can create assisted or walk-in customers through guarded app flows.
- Duplicate identity checks prevent accidental duplicate customer profiles.
- Existing accounts can be linked.
- Referral ownership does not automatically grant broad customer access.
- Assistance visibility requires explicit referral consent and an active customer relationship.
- Assisted uploads and actions preserve attribution.

### 5.6 Notifications and state refresh

- Mutations use focused Riverpod invalidation for affected cases, documents, payments, tasks, customers and notifications.
- Exact recent duplicate notifications are suppressed.
- Role removal and capability refresh revoke routes during an existing session.
- Cache refresh and restart checks preserved public access and protected denial behavior.

## 6. Authentication, email and device security

### 6.1 Email verification

Muted development/test email mode now returns safely without attempting to send through an incomplete dummy Email Account.

This is not used to claim real delivery. A separate real local delivery test was performed using a temporary SMTP capture server:

- Signup returned HTTP 200.
- The verification email was actually emitted and captured.
- The token was extracted and consumed.
- Login succeeded after verification.
- Pending access was enforced until admin approval.
- Temporary SMTP configuration was removed afterward.

### 6.2 Device lock

- Uses `local_auth` and operating-system biometric/device credentials.
- Does not store the user's password.
- Does not mint or bypass a server session.
- Android uses the required biometric activity/permission configuration.
- iOS usage text is present.
- Desktop integration compilation and Android APK build passed.

Physical fingerprint/Face ID validation remains unverified until suitable hardware is connected.

## 7. HS Code compatibility repair

The populated site contained Link fields pointing to `HS Code`, but no target DocType existed. Read-only inspection found the fields and confirmed that they contained no non-empty production values.

The repair added an OMC-owned Desk-only `HS Code` master with:

- Stable field-based naming.
- Uppercase normalization.
- Validation for letters, numbers, spaces, dots and hyphens.
- Description and disabled fields.
- Full management for System Manager and OMC Admin.
- Read/select access for Accounts, Purchase and Stock users.
- Focused normalization and invalid-value tests.

ERPNext source was not edited. The solution deliberately avoids modifying upstream ERPNext files.

Potential future risk: if a later ERPNext version introduces its own DocType with the exact name `HS Code`, migration compatibility must be reviewed before upgrading.

## 8. Real end-to-end HTTP workflow executed

Reserved `.test` identities were used; no real person's identity or production data was used.

Customer:

`layla.hussain.http@qa.omc.test`

Administrator persona:

`zain.abbas.http@qa.omc.test`

Executed sequence:

1. Customer signup.
2. Real localhost SMTP verification email delivery.
3. Verification-token consumption.
4. Customer login.
5. Pending capability response.
6. Protected service denial while pending.
7. OMC Admin login.
8. Registration approval.
9. Capability refresh in the customer's existing session.
10. Service request creation.
11. Duplicate request rejection with resume contract.
12. Required CNIC private upload.
13. Document rejection with reviewer remarks.
14. Corrected replacement upload.
15. Replacement approval.
16. Payment opening.
17. Receipt upload.
18. Receipt rejection.
19. Corrected receipt resubmission.
20. Payment approval.
21. ERP Task operational completion.
22. Canonical completed projection.
23. Deterministic cleanup.

Created evidence records:

| Record | ID |
|---|---|
| Customer profile | `OMC-CUST-260803-00003` |
| Service request | `OMC-SR-260803-00001` |
| ERP Task | `TASK-2026-00003` |
| Rejected document | `OMC-DOC-260803-00001` |
| Approved replacement | `OMC-DOC-260803-00002` |
| Service payment | `OMC-PAY-260803-00001` |
| Corrected payment reference | `PK-OMC-20260803-4821-R` |

Cleanup removed 26 linked workflow records plus the HTTP customer, HTTP admin and temporary SMTP account. The final read-only audit returned:

- Reserved QA users: 0
- Reserved QA customer profiles: 0
- Reserved QA service requests: 0
- Temporary QA SMTP accounts: 0

## 9. Test evidence

### 9.1 Backend

| Gate | Result |
|---|---:|
| Full OMC suite with app-owned fixtures | 547/547 PASS |
| Realistic persona matrix | 6/6 PASS |
| Payment scope regression | 11/11 PASS |
| Workflow and task authority focused suite | 16/16 PASS |
| Pending registration suite | 12/12 PASS |
| HS Code tests | 2/2 PASS |

The suite covers guest denial, pending/rejected customers, every named role, combined roles, disabled users, Website User rejection, Administrator exclusion, direct/cross-customer access, old-assignee access, duplicate handling, documents, payments, task synchronization, retries, referrals, assisted customers, admin controls and completion blockers.

### 9.2 Flutter

| Gate | Result |
|---|---:|
| `flutter analyze` | PASS — no issues |
| `flutter test` | PASS — 296/296 |
| Linux integration workflow contract | PASS — 1/1 |
| Android debug APK | PASS |

APK artifact:

`omc_app/build/app/outputs/flutter-apk/app-debug.apk`

### 9.3 Runtime and migration

| Gate | Result |
|---|---:|
| `bench --site omc.local migrate` | PASS |
| `bench --site omc.local clear-cache` | PASS |
| Public catalogue after cache refresh | HTTP 200 |
| Protected dashboard as Guest | HTTP 403 |
| `git diff --check` during handoff | PASS |

### 9.4 Honest boundaries

- Physical biometric success is not verified without a real biometric device.
- The complete OMC suite deliberately uses `--skip-test-records` because the populated local business site is not an isolated blank ERP test site.
- Frappe's ordinary ERP test-record bootstrap proceeds past HS Code now, but then expects standard `_Test Company` and `_Test Account` fixtures. Persistent fake ERP companies were not injected into `omc.local`.
- Mirror synchronization is not applicable because the repository contains one tracked runtime OMC backend and no second mirror target.

## 10. Issues discovered and fixed during final testing

### 10.1 Muted-email crash

Problem: Frappe's dummy account could fail when emails were muted and the account lacked a usable email id.

Fix: pending registration detects `frappe.are_emails_muted()` and exits safely. A regression test temporarily controls and restores the mute setting.

### 10.2 Missing HS Code Link target

Problem: linked ERP metadata referenced a missing `HS Code` DocType.

Fix: added the OMC-owned master DocType without editing ERPNext source.

### 10.3 Admin payment review denied

Problem: capability allowed payment review, but legacy payment scope denied an unassigned case.

Fix: payment scope now honors canonical all-case and relevant finance capabilities.

### 10.4 Case completed while ERP Task remained open

Problem: completion blockers checked documents and payment but not the linked operational Task.

Fix: linked Task status is now a completion blocker and the customer projection receives actual operational status.

### 10.5 ERP Task completion failed through Desk assignment permission

Problem: ERPNext Task validation attempted to close assignments through a Desk permission check even after the guarded app API had authorized the mutation.

Fix: the guarded task API temporarily moves only the linked Task assignments through a safe terminal transition, saves the Task, then records them Closed. Authorization remains checked before mutation.

### 10.6 Incomplete QA cleanup

Problem: one profile from an earlier failed signup variant remained after the first cleanup pass.

Fix: cleanup now searches the entire reserved `@qa.omc.test` domain for pending registrations and profiles, removes their linked workflow records, and provides a read-only zero-state audit.

## 11. Recommended improvements

### Priority 0 — release gates

#### 11.1 Run physical-device security validation

Test on at least one Android fingerprint device and one iOS Face ID/Touch ID device:

- Enable device lock.
- Cold start and warm resume.
- Successful biometric unlock.
- Cancellation and retry.
- Device credential fallback.
- Biometric enrollment change.
- App reinstall and secure-storage reset.
- Expired/revoked server session while the local lock is enabled.

Acceptance: local unlock never restores an invalid server session and no password appears in storage or logs.

#### 11.2 Add an isolated CI Frappe test site

Do not use populated `omc.local` for ordinary ERP test fixtures. CI should create a disposable site/database, install ERPNext and OMC, run migration, execute tests, then destroy the site.

Suggested gates:

1. Fresh-site install.
2. `bench migrate` twice to prove idempotency.
3. Full OMC suite.
4. API smoke personas.
5. Deterministic teardown.

Acceptance: CI never creates `_Test Company` or QA identities on a business site.

#### 11.3 Validate production SMTP configuration

The local capture proves application delivery behavior, not production provider reputation or deliverability. A staging environment should test:

- SPF, DKIM and DMARC.
- From/reply-to identity.
- Verification link host and TLS.
- Queue retry and dead-letter visibility.
- Expired and reused tokens.
- Delivery bounce handling.

Acceptance: a reserved staging-domain signup is delivered externally and all records are cleaned.

### Priority 1 — correctness and maintainability

#### 11.4 Fix the catalogue service slug typo safely

Runtime evidence currently exposes `ndividual-tax-return-filing`, missing the initial `i`.

Do not directly rename it in production because existing Service Requests may reference it. Add a data migration and compatibility alias from the old id to `individual-tax-return-filing`, update catalogue links, and verify old deep links still resolve.

#### 11.5 Consolidate remaining legacy workflow helpers

The canonical projection exists, but older helper names such as progress/next-step functions remain in large API modules for compatibility. Inventory which paths still execute them, add telemetry or tests around fallback usage, then remove them after the supported client migration window.

Acceptance: one backend implementation computes workflow semantics and fallback invocation reaches zero in staging.

#### 11.6 Split oversized backend API modules

`mobile.py` and some workspace modules carry many unrelated responsibilities. Move code behind stable public wrappers into focused services:

- customer access
- service cases
- documents
- payments
- tasks
- notifications
- support

Keep endpoint names backward-compatible. This reduces authorization drift like the payment-scope defect found by HTTP testing.

#### 11.7 Create one reusable scope service

Payment, document, support and task modules should consume the same canonical record-scope primitives. Add contract tests showing that:

- OMC Admin sees all.
- Specialist reviewers see only their relevant queues.
- Field staff see assigned/consented records.
- Customers see only their own records.
- Old assignees lose access immediately.

#### 11.8 Add database-level idempotency keys

Application duplicate checks are good but concurrent retries can still race. Add a client request id/idempotency key with a unique database constraint for high-risk mutations:

- Service request creation.
- Document submission.
- Payment receipt submission.
- Assisted customer creation.
- ERP bridge creation.

Return the original successful response for repeated keys.

#### 11.9 Formalize transition auditing

Store a normalized transition audit record containing actor, source, previous state, next state, reason, request id and timestamp. Avoid relying only on free-text timelines/comments for compliance evidence.

#### 11.10 Prepare for HS Code ownership conflicts

Before an ERPNext upgrade:

- Check whether upstream introduces `HS Code`.
- Compare schemas and permissions.
- Provide a migration path for existing Link values.
- Avoid two apps attempting to own the same DocType definition.

### Priority 1 — delivery and observability

#### 11.11 Add CI for Flutter and Android

Every pull request should run:

- `flutter analyze`
- `flutter test`
- Linux or web integration contract test
- Android debug build
- Generated-file consistency checks
- Route/capability parity tests

Publish the APK only from tagged/release builds.

#### 11.12 Add structured operational telemetry

Track without exposing sensitive documents:

- Signup verification queued/sent/failed.
- Registration review time.
- Cases by current stage.
- Document and payment rejection rate.
- ERP sync attempts, failure category and exhausted retries.
- Assignment age and reassignment count.
- Completion blocker frequency.
- API latency and error rates by endpoint.

Never log CNIC content, receipt bytes, auth cookies, verification tokens or private file URLs.

#### 11.13 Add alerting and queue dashboards

Alert on:

- Exhausted ERP synchronization.
- Email queue failures.
- Review queue aging.
- Payment receipt pending beyond SLA.
- Cases marked Completed with an incomplete Task.
- Repeated authorization denials that may indicate probing.

### Priority 2 — user experience and operations

#### 11.14 Add guided onboarding checklists

For each role, show an in-app setup checklist:

- Consultant/Tax Associate: profile, assignment readiness, task queue.
- Business Partner: referral consent, assisted customer creation.
- Reviewers: queue filters and review standards.
- Admin: SMTP, payment account, pricing, discount limits, staff coverage and escalation SLA.

#### 11.15 Add admin audit views

The app should expose searchable read-only audit views for:

- Registration decisions.
- Role changes.
- Account enable/disable actions.
- Reassignments.
- Sync retries.
- Discount decisions.
- Assisted uploads.

#### 11.16 Add accessibility and localization verification

Run screen-reader, text scaling, contrast, focus traversal and Urdu/English layout tests. Pay special attention to long service names, validation messages and status timelines.

#### 11.17 Resolve the future Kotlin build warning

The Android build passes, but Flutter warns that explicit Kotlin Gradle Plugin application will become unsupported. The repository already documents why it is currently retained: plugins such as `file_picker` still apply KGP.

Track compatible plugin releases and migrate to Flutter's Built-in Kotlin flow only when all required plugins support it. Do not remove KGP prematurely because that currently breaks the build.

#### 11.18 Add performance and pagination budgets

Define and test budgets for:

- Admin overview.
- Customer/service lists.
- Document and payment queues.
- Notifications.
- Timeline detail.

Use indexed filters, bounded page sizes and cursor/page metadata. Test with production-scale synthetic data, not only small fixtures.

## 12. Suggested next implementation sequence

1. Physical biometric/device release testing.
2. Disposable Frappe CI site and full pipeline.
3. Staging SMTP and external verification-link test.
4. Safe service-slug migration with backward-compatible alias.
5. Shared canonical scope service across payments/documents/support/tasks.
6. Database idempotency keys for high-risk mutations.
7. Structured audit events and operational dashboards.
8. Module decomposition behind unchanged public endpoints.
9. Accessibility/localization and production-scale performance testing.
10. Kotlin/plugin migration when ecosystem support is ready.

## 13. Final assessment

The project is materially stronger than the starting baseline. The main workflow is no longer only a collection of screens and endpoints: authority, scope, state transitions, review queues, pricing, ERP synchronization and recovery now form a tested end-to-end contract.

The most important next step is not adding more features. It is converting the successful local evidence into repeatable release infrastructure: disposable backend CI, physical-device security validation, staging email delivery and production observability. Those controls will keep the current behavior reliable as the team, data volume and ERP integration grow.

Detailed evidence remains available in:

- `docs/test_reports/omc_e2e_workflow_report_2026-08-02.md`
- `docs/test_reports/omc_e2e_workflow_report_2026-08-02.json`
