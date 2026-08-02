# OMC End-to-End Workflow Validation Report

Date: 2026-08-03

Site: `omc.local`

Flutter package: `omc_app`

Backend app: `omc_app`

Result: **All available in-scope executable gates passed**

## Outcome

- Backend capabilities and record scope are authoritative; explicit Frappe roles support combined-role unions and immediate revocation.
- Customer signup, staff applications, approval, staff invitations, role/account management, business settings, reassignment, sync recovery, document review, payment review and task operations are available through guarded app APIs and UI.
- Service Request remains customer-case authority and ERP Task remains operational authority. A linked open ERP Task blocks completion; submitting QC completes the guarded ERP Task operation.
- The canonical projection owns status, display status, stage, progress, customer action, next action, milestones and completion blockers.
- HS Code references are satisfied by an OMC-owned Desk-only master DocType. No ERPNext source file was modified.
- Device lock uses the operating-system biometric/device credential and stores no password or substitute server session.

## Realistic QA personas

| Name | Reserved identity | Role and evidence |
|---|---|---|
| Ayesha Khan | `ayesha.khan@qa.omc.test` | Customer Website User; internal access denied |
| Bilal Ahmed | `bilal.ahmed@qa.omc.test` | Consultant; assigned operations only |
| Sana Iqbal | `sana.iqbal@qa.omc.test` | Tax Associate; assigned operations only |
| Hamza Siddiqui | `hamza.siddiqui@qa.omc.test` | Business Partner; assisted/referral flow |
| Mariam Raza | `mariam.raza@qa.omc.test` | Document Reviewer; document queue only |
| Farhan Malik | `farhan.malik@qa.omc.test` | Finance Reviewer; payment queue only |
| Noor Fatima | `noor.fatima@qa.omc.test` | Support Agent; support operations only |
| Usman Sheikh | `usman.sheikh@qa.omc.test` | Manager; operations/reassignment, no staff/config admin |
| Zain Abbas | `zain.abbas@qa.omc.test` | OMC Admin; granular administration |
| Hira Qureshi | `hira.qureshi@qa.omc.test` | Document + Finance safe capability union |
| Danish Mirza | `danish.mirza@qa.omc.test` | Disabled Consultant; assignment denied |
| Administrator | `Administrator` | Excluded from automatic assignment |

## Real HTTP workflow evidence

The reserved customer `layla.hussain.http@qa.omc.test` and admin `zain.abbas.http@qa.omc.test` exercised the live local API:

1. Signup returned HTTP 200 and a real verification email was captured by an isolated localhost SMTP server.
2. Token verification, login and pending capability denial passed.
3. Admin registration approval activated customer capabilities in the existing session after refresh.
4. Request `OMC-SR-260803-00001` created ERP Task `TASK-2026-00003`; duplicate submission returned `duplicate: true` with `resume_existing` and created no second request.
5. CNIC `OMC-DOC-260803-00001` was rejected, corrected by replacement `OMC-DOC-260803-00002`, then approved with private file linkage and history preserved.
6. Payment `OMC-PAY-260803-00001` was submitted, rejected, resubmitted with reference `PK-OMC-20260803-4821-R`, and marked Paid.
7. The run exposed and fixed two genuine gaps: admin/finance payment scope now follows canonical capabilities, and operational completion now requires/completes the linked ERP Task.
8. Cleanup removed 26 workflow records plus both HTTP users and the SMTP account. Final audit returned no reserved QA users, profiles or service requests.

## Scenario matrix

| Scenario | Result |
|---|---:|
| Guest public browsing and protected denials | PASS |
| Signup, actual email delivery, token verification and pending access | PASS |
| Admin approval and live capability refresh | PASS |
| Customer request and structured duplicate policy | PASS |
| Document rejection, private replacement, review and history | PASS |
| Payment rejection, resubmission, review and pagination contracts | PASS |
| ERP Task sync, operational completion, idempotency and bounded retry | PASS |
| Completion blockers and canonical customer projection | PASS |
| Cancellation and audited terminal behavior | PASS |
| Consultant, Tax Associate and Business Partner least privilege | PASS |
| Assisted customers, referrals and consent | PASS |
| Reviewer queues, manager escalation and combined roles | PASS |
| Disabled users, Website User rejection and Administrator exclusion | PASS |
| Role removal during session | PASS |
| Admin control and business/discount settings | PASS |
| Migration, cache refresh and restart/session recovery | PASS |
| Deterministic reserved-domain cleanup | PASS |

## Commands and gates

| Gate | Result |
|---|---:|
| `bench --site omc.local run-tests --app omc_app --skip-test-records` | PASS — 547/547 |
| Realistic persona module | PASS — 6/6 |
| Focused payment-scope regression | PASS — 11/11 |
| Focused workflow/task regression | PASS — 16/16 |
| Pending-registration suite | PASS — 12/12 |
| `flutter analyze` | PASS — no issues |
| `flutter test` | PASS — 296/296 |
| `flutter test integration_test -d linux` | PASS — 1/1 |
| `flutter build apk --debug` | PASS — `build/app/outputs/flutter-apk/app-debug.apk` |
| `bench --site omc.local migrate` | PASS |
| `bench --site omc.local clear-cache` | PASS |
| Post-cache HTTP public/protected check | PASS — 200/403 |
| Reserved QA cleanup audit | PASS — zero users, profiles, cases and SMTP accounts |
| `git diff --check` | PASS |

## Explicit environment boundaries

- Physical fingerprint/Face ID success is **unverified**, because only Linux and Chrome targets were connected. Software integration and Android compilation passed; physical biometric validation remains a device release check and was not fabricated.
- Frappe's ordinary ERP test-record bootstrap is not a valid gate on this populated local site: after the OMC-owned HS Code repair it reaches standard ERP fixtures, then expects `_Test Company` and `_Test Account` records. The complete isolated OMC app suite passes with its deliberate `--skip-test-records` runner; no persistent ERP test company was injected.
- Mirror sync is not applicable because this checkout has one tracked runtime backend app and no second mirror target.
- No commit or push was performed. No ERPNext source file or user system file was edited.
