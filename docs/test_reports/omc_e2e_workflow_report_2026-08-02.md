# OMC End-to-End Workflow Validation Report

Report updated: 2026-08-03

Site: `omc.local`

Flutter package/backend app: `omc_app`

Result: **All current in-scope executable software gates passed**

## Final outcome

- The unsafe OMC-owned global `HS Code` substitute and its orphan table are retired through guarded, idempotent patches. Four retained external/client ERP Link fields are empty and remain a separate client prerequisite.
- Backend capabilities and object filters remain authoritative. Flutter now exposes all routine app-user operations in the audited matrix, including case reassignment, exhausted sync retry, discount review, generalized payment review, and OMC Task transitions.
- Service Request remains customer-case authority; ERP Task remains operational authority. QC submission uses transaction-safe linked-ToDo handling.
- ERPNext source, DocTypes, workflows, permissions, and client configuration were not edited.
- Physical biometric success is not claimed without a connected device.

The complete endpoint-to-provider-to-screen matrix is in root `inspection.md`.

## HS Code data-safety evidence

Before retirement, the only OMC master row was the exact reserved fixture `9999.99` (`Reserved QA HS code`). The migration refused to proceed until that row was explicitly identified. It would also refuse any non-fixture row or non-empty referring value.

Final inspection:

```json
{
  "doctype_exists": false,
  "table_exists": false,
  "record_count": 0,
  "nonempty_link_value_counts": {
    "Item.hs_code": 0,
    "Purchase Invoice Item.hs_code": 0,
    "Purchase Order Item.hs_code": 0,
    "Sales Invoice Item.custom_hs_code": 0
  }
}
```

## Historical full HTTP workflow evidence

The prior 2026-08-03 reserved-domain HTTP run remains retained as historical evidence, not mislabeled as a rerun. It used customer `layla.hussain.http@qa.omc.test` and admin `zain.abbas.http@qa.omc.test` and verified:

1. real localhost SMTP capture, token verification, login, pending denial, and approval refresh;
2. service request `OMC-SR-260803-00001`, ERP Task `TASK-2026-00003`, and duplicate resume policy;
3. rejected document `OMC-DOC-260803-00001`, replacement `OMC-DOC-260803-00002`, and preserved private history;
4. payment `OMC-PAY-260803-00001`, rejection, corrected resubmission, and Paid state;
5. completion blockers and linked ERP Task authority;
6. cleanup of 26 workflow records plus both HTTP users and the isolated SMTP account.

## Current correction-pass HTTP evidence

This pass reran the changed/live boundaries against the running local server:

| HTTP check | Result |
|---|---:|
| Guest public catalogue | PASS — 200 |
| Guest protected dashboard | PASS — 403 |
| Reserved OMC Admin login | PASS — 200 |
| Reassignment queue, server page metadata and case context | PASS — 200 |
| Exhausted sync queue and server page metadata | PASS — 200 |
| Discount queue and server page metadata | PASS — 200 |
| Admin overview for registration/staff controls | PASS — 200 |
| Deterministic cleanup | PASS — reserved users/profiles/cases/SMTP all zero |

The database-backed persona suite independently verifies Customer, Consultant, Tax Associate, Business Partner, Document Reviewer, Finance Reviewer, Support Agent, Manager, OMC Admin, combined Document+Finance roles, disabled-user rejection, Administrator exclusion, and live capability revocation after role removal.

## Commands and actual gates

| Gate | Actual result |
|---|---:|
| `bench --site omc.local migrate` | PASS |
| Focused backend regression modules | PASS — 86/86 |
| `bench --site omc.local run-tests --app omc_app --skip-test-records` | PASS — 556/556; 83.134s |
| `flutter analyze` | PASS — no issues; 2.2s |
| Focused Flutter route/admin/payment contracts | PASS — 198/198 |
| `flutter test` | PASS — 303/303 |
| `flutter test -d linux integration_test/workflow_contract_test.dart` | PASS — 1/1 |
| `flutter build apk --debug` | PASS — `build/app/outputs/flutter-apk/app-debug.apk` |
| Live HTTP checks | PASS — 7/7 |
| Reserved QA zero-state | PASS |

An overlapping test-process run produced database deadlocks and was discarded. The reported 556/556 result is from the subsequent clean serial run with no competing test process.

## Scenario matrix

| Scenario | Result |
|---|---:|
| Public browsing, authentication, pending approval and deep-link denial | PASS |
| Customer request, duplicate resolution, tracking and cancellation contracts | PASS |
| Document upload, rejection replacement, private access and review | PASS |
| Payment upload/resubmission, scoped queue, authenticated receipt and review | PASS |
| Assigned cases, assisted/walk-in/referral service and customer lookup | PASS |
| ERP Task list/detail/transitions, QC completion and rollback safety | PASS |
| Reassignment, exhausted sync retry and discount review Flutter paths | PASS |
| Registration, staff, account and business settings controls | PASS |
| Capability union, direct denial and role-removal revocation | PASS |
| Pagination, search/filter, async/busy states and focused invalidation | PASS |
| Guarded HS retirement and retained client metadata | PASS |
| Deterministic reserved QA cleanup | PASS |
| Physical biometric authentication | UNVERIFIED — no connected biometric device |
| Client `HS Code` dependency resolution | OPEN — external/client ERP prerequisite |

## Source and release boundaries

- No commit or push was performed.
- No ERPNext source or client-owned ERP metadata was changed.
- No production customer data was fabricated or deleted.
- Ordinary global ERP test-record bootstrap is not an OMC gate on this populated site; the complete OMC suite passes with `--skip-test-records`.
- Android build passes with a non-failing future Kotlin plugin migration warning.
