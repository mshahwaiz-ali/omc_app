# OMC End-to-End Workflow Validation Report

Date: 2026-08-02  
Site: `omc.local`  
Flutter package: `omc_app`  
Backend app: `omc_app`  
Result: **Implementation complete; 2 environment gates blocked, 1 hardware gate unverified**

## Implementation verified

- A canonical backend workflow projection now owns persistent-status normalization, stage, progress, next action, milestones, customer action, completion eligibility, and completion blockers.
- Backend capability and record scope remains authoritative. Effective explicit Frappe roles support safe combined-role unions; `role_profile_name` is not assignment authority and `Administrator` is never auto-assigned.
- Public customer registration remains separate from Consultant, Tax Associate, and Business Partner applications. Staff roles are granted only after review.
- The app Admin Control Center supports registration review, multi-role invitations and edits, account enable/disable, business toggles, discount threshold and floor, case reassignment, exhausted ERP synchronization retry, and discount review.
- Duplicate service requests return structured resume/start-another actions. Parallel requests require both service configuration and explicit confirmation.
- Discount price and approval state are calculated on the backend. Payment creation is blocked while approval is pending.
- Service Request remains customer-case authority and ERP Task remains operational authority, with tested idempotency and bounded recovery.
- Flutter consumes canonical backend progress and keeps only a legacy-response fallback. Mutations invalidate focused case/document/payment/task/notification state.
- Device lock uses the operating system biometric/device credential through `local_auth`; it stores no password and does not bypass the server session.

## QA persona matrix

All identities use the reserved `.test` domain. They were created as real Frappe User records during the isolated persona suite and removed deterministically after every scenario.

| Persona | Record ID | Role/type | Evidence |
|---|---|---|---|
| Ayesha Khan | `ayesha.khan@qa.omc.test` | OMC Customer / Website User | Internal workspace denied |
| Bilal Ahmed | `bilal.ahmed@qa.omc.test` | OMC Consultant | Assigned-case operations allowed; finance denied |
| Sana Iqbal | `sana.iqbal@qa.omc.test` | OMC Tax Associate | Assigned-case operations allowed; staff admin denied |
| Hamza Siddiqui | `hamza.siddiqui@qa.omc.test` | OMC Business Partner | Assisted request allowed; document review denied |
| Mariam Raza | `mariam.raza@qa.omc.test` | OMC Document Reviewer | Document review allowed; finance denied |
| Farhan Malik | `farhan.malik@qa.omc.test` | OMC Finance Reviewer | Payment review allowed; documents denied |
| Noor Fatima | `noor.fatima@qa.omc.test` | OMC Support Agent | Support operations allowed; finance denied |
| Usman Sheikh | `usman.sheikh@qa.omc.test` | OMC Manager | Reassignment/retry allowed; staff/config admin denied |
| Zain Abbas | `zain.abbas@qa.omc.test` | OMC Admin | Granular administration allowed |
| Hira Qureshi | `hira.qureshi@qa.omc.test` | Document + Finance Reviewer | Safe union; finance revoked after role removal |
| Danish Mirza | `danish.mirza@qa.omc.test` | Disabled Consultant | Assignment rejected |
| Administrator | `Administrator` | Built-in administrator | Automatic assignment rejected |

Cleanup evidence: 11 reserved-domain persona records removed; subsequent reserved-domain User query returned no records. The failed HTTP signup identity `layla.hussain.http@qa.omc.test` was not persisted.

## Scenario results

| Scenario | Result | Evidence |
|---|---:|---|
| Guest public catalogue/config/support | PASS | Three HTTP 200 responses |
| Guest protected dashboard/session/admin | PASS | Three HTTP 403 responses |
| Signup and email verification | BLOCKED | HTTP reached email dispatch; site has no default outgoing Email Account and returned 501 |
| Pending/approved/rejected/customer activation | PASS | Backend signup, canonical role, approval, and authority modules in 538-test suite |
| Role allow/deny matrix and direct assignment eligibility | PASS | 6 database-backed persona tests |
| Capability removal during session | PASS | Finance permission disappeared after explicit role deletion and cache refresh |
| Disabled user, Website User, Administrator exclusion | PASS | Database-backed assignment test |
| Canonical transition/progress/blockers projection | PASS | 4 workflow-contract tests plus Flutter integration projection check |
| Duplicate, resume/start-another, cancellation | PASS | Backend duplicate and cancellation modules |
| Document rejection, replacement, history and guarded access | PASS | Document resubmission/review/upload/scope modules |
| Payment review, rejection/resubmission and pagination | PASS | Payment/receipt/read/mutation/lifecycle modules |
| Completion blockers and completion | PASS | Required-document and workflow-completion modules |
| ERP Task sync, idempotency, failure and bounded retry | PASS | ERP flow/adapter/status/recovery modules |
| Assisted/walk-in customers, referral ownership and consent | PASS | Assisted-service, referral and lead-integrity modules |
| Reviewer queues, manager escalation and admin controls | PASS | Access, routing, workflow automation, admin-control modules |
| Flutter route revocation/canonical contract | PASS | 296 unit/widget tests and 1 Linux integration test |
| Secure device-lock implementation | PASS (software) | Analyzer, Linux integration compilation and Android APK build |
| Physical fingerprint/Face ID unlock | UNVERIFIED | No physical biometric device was connected |
| Restart/session recovery | PASS (local) | Server remained responsive after migration and cache clear; protected/public session behavior rechecked |
| Mirror synchronization dry run | NOT APPLICABLE | This checkout contains one tracked runtime backend app; no second mirror target exists |

## Commands and gates

| Command/gate | Result |
|---|---:|
| `bench --site omc.local run-tests --app omc_app --skip-test-records` | PASS — 538/538 |
| Persona module | PASS — 6/6 after committed cleanup fix |
| Focused workflow/admin/discount/assignment modules | PASS — 28/28 |
| Payment scope regression module | PASS — 9/9 |
| `flutter analyze` | PASS — no issues |
| `flutter test` | PASS — 296/296 |
| `flutter test -d linux integration_test/workflow_contract_test.dart` | PASS — 1/1 |
| `flutter build apk --debug` | PASS — `build/app/outputs/flutter-apk/app-debug.apk` |
| `bench --site omc.local migrate` | PASS |
| `bench --site omc.local clear-cache` | PASS |
| HTTP public/protected smoke | PASS — 6/6 |
| HTTP signup/email smoke | BLOCKED — missing outgoing Email Account |
| Normal backend test-record bootstrap | BLOCKED before tests — `DocType HS Code not found` |

## Failures and release gates

1. **Outgoing email is not configured on `omc.local`.** Signup correctly invokes verification delivery, but Frappe cannot send without a default Email Account. An authorized SMTP account must be configured in Desk, then signup and token consumption must be rerun over HTTP.
2. **The installed/custom ERPNext checkout references `HS Code` but contains no `HS Code` DocType source.** Normal Frappe test-record bootstrapping stops before OMC tests. The complete OMC suite itself passes 538/538 with `--skip-test-records`. This must be repaired in the client ERPNext installation/source as a separate low-level ERP administration action; no ERPNext source was modified here.
3. **Physical biometric verification remains a device release gate.** Android compiles with `FlutterFragmentActivity` and biometric permission, but real fingerprint/Face ID success cannot be established without hardware.

Because required environment gates remain blocked/unverified, this report deliberately does not declare every gate green.
