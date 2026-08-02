# OMC App Final Architecture and Production-Readiness Audit

Date: 2026-08-03

Branch: `main`

Audited HEAD: `3d282689` (`origin/main`; the additional commit after the requested `6179919f` only adds this report)

Site: `omc.local`

## Executive verdict

| Area | Verdict | Evidence boundary |
|---|---|---|
| Backend readiness | READY for the OMC-owned application boundary | Migration passed; guarded HS retirement verified; focused tests passed; full isolated OMC suite passed 556/556 with `--skip-test-records`. |
| Flutter readiness | READY for software release gates | Analyzer clean; full test suite passed 303/303; Linux workflow contract passed 1/1; Android debug APK built. |
| Backend-to-Flutter parity | COMPLETE for routine app-user workflows listed below | Reassignment, exhausted sync recovery, discount review, payment review and OMC Task operations all have capability-gated Flutter paths. |
| Environment gates | PASS for the local site and build environment | Live HTTP public/protected and reserved-admin operations checks passed; cache refresh passed. Ordinary global ERP test fixtures remain outside the populated-site OMC gate. |
| Hardware gates | UNVERIFIED | No physical Android/iOS biometric device was connected. Device-lock software and Android compilation are covered; fingerprint/Face ID success is not claimed. |
| Client ERP prerequisite | OPEN, separate from OMC | Four client/ERP metadata fields still link to a missing `HS Code` target. All are empty. Their owner must restore the original external dependency or retire/change those fields through client ERP administration. |

No branch, commit, push, backup tree, ERPNext source edit, ERPNext DocType edit, or client configuration mutation was performed.

## HS Code resolution

### Confirmed evidence

- The removed global `HS Code` DocType was owned by module `OMC App`, but its only database row was the exact OMC test fixture `9999.99` / `Reserved QA HS code`, owned by `Administrator`.
- The checked-in ERPNext 14.87 source does not provide a canonical global `HS Code` DocType for these links.
- The broken references originate outside OMC's product model:
  - standard/client-modified ERP metadata: `Item.hs_code`, `Purchase Invoice Item.hs_code`, `Purchase Order Item.hs_code`;
  - client Custom Field: `Sales Invoice Item.custom_hs_code`.
- Installed data evidence after migration: all four fields have zero distinct non-empty values.
- No current OMC workflow reads or writes HS Code.

### Final correction

The OMC substitute source, test, and fixture were removed. Two ordered, idempotent pre-model patches now:

1. verify ownership, record values, and every referring field;
2. remove only the exact reserved OMC fixture;
3. refuse retirement if any other HS record or non-empty referring value exists;
4. permanently delete only the OMC-owned DocType;
5. drop the orphan `tabHS Code` table only when the DocType is absent, the table is empty, and all references are empty.

Post-migration evidence is:

```text
doctype_exists=false
table_exists=false
record_count=0
Item.hs_code distinct_nonempty_count=0
Purchase Invoice Item.hs_code distinct_nonempty_count=0
Purchase Order Item.hs_code distinct_nonempty_count=0
Sales Invoice Item.custom_hs_code distinct_nonempty_count=0
```

The external/client Link metadata was deliberately retained. OMC does not impersonate the missing master and does not silently delete client metadata.

## Complete backend-to-Flutter parity matrix

`Scope` is enforced by backend capability and object filters; Flutter visibility is not treated as authority.

| Backend feature | Endpoint | Capability | Scope | Flutter method | Provider | Screen | Route | User action | Refresh | Result |
|---|---|---|---|---|---|---|---|---|---|---|
| Public catalogue | `mobile.get_service_catalogue` -> public guard | public catalogue | published services | catalogue fetch | catalogue provider | Services/detail | `/services`, `/services/:serviceId` | browse | provider retry | COMPLETE |
| Signup and verification | `access.sign_up`; pending-registration start/resend/verify | guest | submitted identity/token | `AuthRepository.signUp/verifyRegistration` | auth controller | Signup/verify | `/signup`, `/verify-email` | submit/verify/resend | session refresh | COMPLETE |
| Pending approval | `access_v2.get_session_user` | authenticated pending | own account | `getSessionUser` | auth controller | Under review | `/under-review` | refresh/logout | auth refresh | COMPLETE |
| Customer dashboard | `dashboard.get_dashboard_data` -> read guard | customer dashboard | own profile/cases | `HomeDashboardRepository.fetchSummary` | `homeDashboardSummaryProvider` | Home/dashboard | `/home`, `/dashboard` | open counters/actions | focused dashboard invalidation | COMPLETE |
| Service creation | `service_requests.create_service` | create request | own or explicitly assisted subject | `createServiceRequest` | service request repository | Request draft | `/services/:serviceId/request` | submit | case/dashboard invalidation | COMPLETE |
| Duplicate resume/start another | same create endpoint | create request | same customer/service policy | response parser | service request repository | Request draft/result | same | resume or explicitly start another | case list/detail | COMPLETE |
| Case tracking | secured case list/detail | track requests | own/relevant/assigned/all | `fetchServiceCases/fetchServiceCaseDetail` | case list/detail providers | My services/case detail | `/my-services`, `/my-services/:caseId` | inspect/cancel allowed case | focused case invalidation | COMPLETE |
| Required documents | document list/detail and upload | view/upload documents | own or relevant case | document fetch/upload | document providers | Documents/case detail | `/documents`, `/documents/:documentId` | upload required file | document/case/dashboard | COMPLETE |
| Rejected document replacement | `document_upload.upload_service_document` | upload documents | rejected document on permitted case | `uploadDocumentAttachments` | document providers | Document/case detail | document/detail routes | select replacement | document history/detail/case | COMPLETE |
| Payment details | payment read guard list/detail | view payments/summaries | own or permitted queue summary | `fetchPaymentPage/fetchPaymentDetail` | payment page/detail | Payments/detail | `/payments`, `/payments/:paymentId` | inspect context/status | page/detail retry | COMPLETE |
| Receipt upload/resubmission | payment mutation guard | upload receipt | own eligible payment | upload receipt methods | payment detail | Payment detail | `/payments/:paymentId` | select/upload/resubmit | payment/case/dashboard | COMPLETE |
| Notifications | mobile notification endpoints | customer notifications | own notifications | notification repository methods | notification list/detail | Notifications/detail | `/notifications`, `/notifications/:notificationId` | read/unread/dismiss/restore | list/detail/count | COMPLETE |
| Support | support read/write guards | create/view/reply/status as granted | own or assigned/relevant ticket | support repository methods | support providers | Support/ticket detail | `/support`, `/support-tickets/:ticketId` | create/reply/status/attach | ticket/list/unread | COMPLETE |
| Profile/settings | profile self-service and settings endpoints | authenticated self-service | own user/profile | profile/settings repositories | profile/settings providers | Profile/settings | `/profile`, `/profile/edit`, `/settings` | edit preferences/profile/password | profile/session/settings | COMPLETE |
| Device lock | local OS credential service | authenticated local opt-in | device-local secret only | device-lock service | device lock provider | Settings | `/settings` | enable/authenticate/disable | device-lock provider | COMPLETE |
| Assigned service cases | internal workspace case endpoints | assigned/relevant/all cases | backend filtered | internal workspace repository | internal case providers | Operations center/cases | `/internal-workspace/service-cases` | search/filter/open | list/detail/dashboard | COMPLETE |
| Internal assisted service | internal create-for-customer endpoint | create service for customer | selected eligible customer | `createServiceRequestForCustomer` | internal repository | Case workspace/request draft | internal routes | select customer/service/submit | case/customer/dashboard | COMPLETE |
| Walk-in/provisional customer | assisted selection/policy endpoint | create service for customer | allowed provisional subject | assisted selection + create | request repository | Assisted customer card | request draft | choose walk-in/provisional | request/case queues | COMPLETE |
| Referral-created service | referral + assisted policy endpoints | referral/create-for-customer | attributed referral subject | referral/request repositories | referral providers | Referral detail/request draft | `/my-referrals/:customerId` | open customer/start service | referral/case/dashboard | COMPLETE |
| Customer lookup | mobile customer list/detail | relevant/all customer capability | backend filtered | customer repository methods | customer providers | Customers/detail | `/customers`, `/customers/:customerId` | search/open | list/detail retry | COMPLETE |
| Task list/detail | task read guard | manage assigned/all tasks | exact assignment or all | `fetchTasks/fetchTaskDetail` | task list/detail | Tasks/detail | `/tasks`, `/tasks/:taskId` | filter/open | list/detail retry | COMPLETE |
| Task operational status | task write guard | assigned/all task management | exact ERP Task | `updateOperationStatus` | task providers | Task detail | `/tasks/:taskId` | allowed transition | task/case/dashboard | COMPLETE |
| Submitted by QC completion | task write guard | same | exact linked Task/ToDos | same | task providers | Task detail | `/tasks/:taskId` | confirm QC submission | transactional task/case/dashboard | COMPLETE |
| Document review queue/detail | document read/mutation guards | review documents | review queue/relevant summary | fetch/update document | document providers | Internal operations/detail | `/internal-workspace/documents`, `/documents/:documentId` | approve/reject with remarks | documents/case/dashboard | COMPLETE |
| Payment queue/detail | payment read guard | queue/summaries/receipts | payment-only related summary | `fetchPaymentPage/fetchPaymentDetail` | payment page/detail | Generalized operations/detail | `/internal-workspace/payments`, `/payments/:paymentId` | server search/filter/page/open | page/detail/case/dashboard | COMPLETE |
| Payment approval/rejection | payment mutation guard | review payments | eligible queue payment | `reviewPaymentReceipt` | payment providers | Generalized operations/detail | same | approve/reject with remarks | payment/case/dashboard | COMPLETE |
| Case reassignment | admin control | reassign service cases | selected case + backend eligible staff | `fetchCaseOptions/reassignCase` | admin operations/options | Admin operations | `/admin-control/operations` | search/select/reason/confirm | admin/case/task/doc/payment/dash | COMPLETE |
| Exhausted sync review/retry | admin control | retry sync | retryable exhausted case only | `fetchOperations/retrySync` | admin operations | Admin operations | `/admin-control/operations` | inspect error/attempts/retry | admin/case/task/dash | COMPLETE |
| Discount review | admin control | manage business settings | pending discount case | `fetchOperations/reviewDiscount` | admin operations/options | Admin operations | `/admin-control/operations` | inspect pricing/approve/reject remarks | admin/case/payment/dash | COMPLETE |
| Registration review | admin control | review registrations | pending applications | `reviewRegistration` | admin overview | Admin Control | `/admin-control` | approve/reject/roles/reason | overview/session downstream | COMPLETE |
| Staff invitation | admin control | manage staff | allowed OMC roles | `inviteStaff` | admin overview | Admin Control | `/admin-control` | invite | overview | COMPLETE |
| Staff role editing | admin control | manage staff | allowed OMC roles/user | `updateStaff` | admin overview | Admin Control | `/admin-control` | edit roles | overview; live session re-fetch | COMPLETE |
| Account enable/disable | admin control | manage staff | eligible staff account | `updateStaff` | admin overview | Admin Control | `/admin-control` | toggle/confirm | overview; revoked session denied | COMPLETE |
| Business settings | admin control | manage business settings | singleton safe fields | fetch/update settings | business settings provider | Admin Control | `/admin-control` | edit/save | settings/overview | COMPLETE |
| Dashboard actions/counters | dashboard + internal summary | matching granular capabilities | scoped aggregate | dashboard/quick-action repositories | dashboard providers | Home/internal workspace | `/home`, `/internal-workspace` | open capability-derived action | focused mutation invalidation | COMPLETE |
| Capability route access | session capability contract | per-route explicit capability | current session | auth state parser | auth controller | router/shell | all routes | navigate/deep-link | session refresh reroutes | COMPLETE |
| Direct API/object denial | all guarded endpoints | backend capability | own/assigned/relevant/all per object | n/a | n/a | safe error states | direct URL/API | denied without mutation | n/a | COMPLETE |
| Pagination/search/filter | admin, payment, notification and internal list APIs | list-specific | already scoped result set | query/page repository methods | family/page providers | queue/list screens | relevant list routes | search/filter/next/previous | query-keyed refresh | COMPLETE |
| Async states and busy guards | guarded APIs | inherited | current object | repository futures | Riverpod AsyncValue | all mutation/list screens | retry/submit once | focused only | COMPLETE |
| Logout/session revocation | logout + session-user | authenticated | current session | auth controller logout/check | auth/effective capability providers | shell/settings | logout or refresh | clears session-dependent providers | COMPLETE |
| Role removal in active session | session-user capability refresh | refreshed roles | current user | `checkSession` | effective capability provider | router/shell | refresh/navigation | forbidden route redirect | COMPLETE |

## High-risk backend review

### Payment scope

Finance queue authority is separated from customer and service mutation authority. The authoritative hook routes payment list/detail to `payment_read_guard`; safe payloads expose only the related payment/case summary needed by the queue. Receipt visibility and review remain separate capabilities. Focused negative scope tests passed 11/11.

### Task and ToDo transaction safety

QC completion changes only ToDos linked to the exact ERP Task. A database savepoint wraps the temporary `Cancelled` state, Task save, and final `Closed` state. Any Task-save error rolls back the savepoint and restores in-memory state. Unauthorized, unrelated, already completed/cancelled, repeated-call, completion-blocker, projection, and rollback contracts are covered; the focused module passed 17/17. ERPNext was not modified.

### Email and QA helpers

Muted delivery is accepted only under explicit development/test configuration; production does not silently convert a delivery failure into approval. Verification token and expiry contracts remain backend-owned. The localhost SMTP helper refuses to replace a real default outgoing account. QA setup/cleanup functions are not whitelisted. Cleanup rejects non-`@qa.omc.test` identities and uses exact linked records. Focused registration and production-hardening modules passed 12/12 and 4/4; final reserved state is zero.

## Changed files

### Backend implementation and migrations

- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/admin_control.py` — adds capability-specific, searchable, paginated operation queues and complete case/reassignment/sync/discount detail contracts.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/payment_read_guard.py` — makes authoritative payment reads safely searchable/pageable after record-scope filtering.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/payments.py` — keeps the public payment API signature and response metadata aligned with the authoritative override.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/task_write_guard.py` — wraps QC Task/ToDo transition in a rollback-safe database savepoint.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/patches.txt` — registers the two ordered pre-model retirement patches.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/patches/remove_omc_hs_code_substitute.py` — guarded OMC DocType/fixture retirement.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/patches/drop_retired_omc_hs_code_table.py` — guarded empty orphan-table retirement.
- Deleted `backend_omc_app/frappe-bench/apps/omc_app/omc_app/omc_app/doctype/hs_code/__init__.py`, `hs_code.py`, `hs_code.json`, `test_hs_code.py`, and `test_records.json` — removes the unrelated OMC global master substitute and its test fixture.

### Backend coverage and inspection helpers

- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_admin_control.py` — queue capability, exhausted-sync, and required reject-remarks contracts.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_payment_read_guard.py` — scoped paging/search and safe-result contracts.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_erp_task_write_guard.py` — savepoint rollback and linked-ToDo safety.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_hs_code_retirement.py` — ownership/data/reference refusal and exact-fixture behavior.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_hs_code_table_retirement.py` — DocType/row/reference refusal and exact empty-table behavior.
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_e2e_role_personas.py` — robust post-retirement schema/value inspection.

### Flutter implementation

- `omc_app/lib/app/mutation_invalidation.dart` — focused cross-feature invalidation for admin and Task mutations.
- `omc_app/lib/app/route_access_policy.dart` and `omc_app/lib/app/router.dart` — capability-gated canonical admin-operations route.
- `omc_app/lib/core/config/api_config.dart` — admin-operations endpoint constant.
- `omc_app/lib/core/network/frappe_client.dart` — same-origin authenticated private-file retrieval.
- `omc_app/lib/features/admin_control/data/admin_control_repository.dart` — typed operation queries/pages/options and action payloads.
- `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart` — canonical operations entry from Admin Control.
- `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart` — complete reassignment, sync recovery, and discount review UI.
- `omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart` — server-side payment search/status/pagination and complete generalized review context.
- `omc_app/lib/features/internal_workspace/presentation/internal_workspace_screen.dart` — manager/admin operations quick action.
- `omc_app/lib/features/payments/data/payments_repository.dart` — typed server page queries and authenticated receipt download.
- `omc_app/lib/features/payments/presentation/payment_detail_screen.dart` — authenticated receipt opening/sharing and review remarks.
- `omc_app/lib/features/service_requests/presentation/service_case_detail_screen.dart` — typed options, required reject remarks, and comprehensive focused refresh for the detail shortcut.
- `omc_app/lib/features/tasks/presentation/task_detail_screen.dart` — task/case/dashboard focused refresh after operational mutation.

### Flutter coverage and reports

- `omc_app/test/app/route_access_policy_test.dart`, `route_capability_matrix_test.dart`, and `router_policy_parity_test.dart` — route visibility, deep-link denial, granular boundary and registry parity.
- `omc_app/test/features/admin_control/admin_operations_contract_test.dart` — reachable operations, mutation invalidation, payment paging and authenticated receipt contracts.
- `inspection.md` — replaces unsupported/outdated claims with the final evidence and full parity matrix.
- `docs/test_reports/omc_e2e_workflow_report_2026-08-02.md` and `.json` — update counts, HS ownership, current-versus-historical HTTP evidence, source boundaries and limitations.

## Validation evidence

| Command/gate | Actual result |
|---|---|
| `bench --site omc.local migrate` | PASS; both guarded HS retirement patches applied. |
| `inspect_hs_code_state` | PASS; DocType false, table false, record count 0, four link-value counts 0. |
| Focused backend modules | PASS; 86/86 across access, authorization, payment scope, admin, sync, task write, registration, hardening and HS retirement. |
| `bench --site omc.local run-tests --app omc_app --skip-test-records` | PASS; 556/556 in 83.134s. |
| `flutter analyze` | PASS; no issues in 2.2s. |
| Focused Flutter route/admin/payment contracts | PASS; 198/198. |
| `flutter test` | PASS; 303/303. |
| `flutter test -d linux integration_test/workflow_contract_test.dart` | PASS; 1/1; Linux bundle built. |
| `flutter build apk --debug` | PASS; `build/app/outputs/flutter-apk/app-debug.apk`. Kotlin migration warnings are non-failing future-toolchain warnings. |
| Live HTTP Guest catalogue/dashboard | PASS; HTTP 200 / 403. |
| Live reserved-admin login and three operation queues plus overview | PASS; five HTTP 200 responses with queue pagination metadata. |
| Reserved QA cleanup audit | PASS; users 0, profiles 0, service requests 0, SMTP account absent. |

One attempted full backend run was intentionally discarded: two concurrently launched suites produced database deadlocks. After confirming no test process remained, the suite was rerun alone and passed 556/556. This report uses only the clean serial result.

## Remaining limitations and prerequisites

- A client ERP administrator must resolve the retained empty `HS Code` Link metadata if those ERP fields are intended for use. OMC does not own that decision.
- Physical fingerprint/Face ID verification remains a real-device release check.
- The APK build reports Flutter's forward-looking Kotlin Gradle Plugin migration warning; the current debug build passes.
- Normal global ERP fixture bootstrap is not an OMC release gate on this populated business site. The isolated OMC suite deliberately uses `--skip-test-records` and passes.
- The exhaustive earlier customer/admin HTTP workflow remains valid historical evidence in the E2E report, while this correction pass reran the changed live surfaces (public/protected access and all three admin operation queues). It did not fabricate a second full business workflow solely for this audit.

## Git and source boundary

- Work remains uncommitted at handoff.
- No commit or push was requested or performed.
- No ERPNext file appears in the OMC diff.
- The unrelated `3d282689` commit was present before this correction pass and was not created here.
