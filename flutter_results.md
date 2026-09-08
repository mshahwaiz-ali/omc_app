# OMC Flutter production-readiness audit

## 1. Audit Metadata

- Repository: `mshahwaiz-ali/omc_app`; branch: `main`.
- Audited commit: **`b1f2b6f60572920d2341ab206f1aa910223ab4b2`**. `git fetch origin main` succeeded; HEAD and fetched `origin/main` matched. Initial working tree was clean. No alternate checkout was necessary.
- Date: 2026-09-08, Asia/Karachi.
- Root: `/home/muhammad-shahwaiz-ali/data_drive/prod_ex`; Flutter: `omc_app`; custom backend: `backend_omc_app/frappe-bench/apps/omc_app/omc_app`.
- Flutter 3.44.4, Dart 3.12.2, OpenJDK 17.0.20. Android SDK/build tools 36.1.0 installed; licenses accepted. No Android device attached. Linux and Chrome targets available.
- Local `omc-prod.local` site/database available for tests. Local HTTP port 8000 did not answer the read-only ping. Required release-journey actor environment variables were absent.
- Scope: audit only. No fixes, refactoring, branch, commit, push, or PR. This is the sole audit report.
- All **216 production Dart files / 87,667 lines** were inventoried and included in structural/risk scanning and Flutter analysis. An internal index covered 1,668 action/state/network markers. Route declarations, action entry points, repository calls, runtime guards, backend overrides, notification producers, and relevant native configuration were examined. This is **not** a claim that every line or every combination of UI state was manually simulated. Per-endpoint existence/signature checks are not full behavioral contract proof; the matrices preserve that distinction.

Evidence is from this checkout and this run. Earlier session results were not reused as current test evidence. Commands and actual outcomes are in section 12.

## 2. Executive Verdict

**NO-GO** for the requested production Android release with real notification-panel delivery.

| Severity | Confirmed findings |
|---|---:|
| P0 | 0 |
| P1 | 2 |
| P2 | 6 |
| P3 | 0 |

The primary blocker is absent end-to-end OS push implementation. A separate active Flutter/backend mismatch breaks expense receipt attachment. Settings, release-control behavior, and large-list completeness also need correction. Passing regression tests do not cover these discovered paths.

Residual release gates include signed Android execution, physical-device journeys, actual network failure/permission behavior, production push setup, Sentry setup, Play signing/version continuity, and verified domain association. Environment limitations are not counted as defects. The requested exhaustive human-action/runtime assurance remains open; this report must not be used as a complete release certificate.

## 3. Coverage Matrix

`U` = executed unit/model/provider tests; `W` = executed widget tests; `S` = executed source-contract assertions. Backend suite evidence includes mocked tests as well as database-backed tests; it is not equivalent to Flutter calling the live HTTP server. `Blocked` under Android applies throughout.

| Area | Static inspected | Automated test | Real local backend | Android device | External production config | Verdict |
|---|---|---|---|---|---|---|
| Startup, environment, splash, onboarding | Yes | U/S | Public/config regressions in suite | Blocked | Sentry required | Build-profile guard PASS; release launch unverified |
| Login/logout/session/account switch | Yes | U/W/S | Auth/security suite | Blocked | Production session not exercised | Focused tests PASS |
| Signup, activation, verification/reset | Yes | U/W/S | Registration/security suite | Blocked | Email delivery/link association | Local test evidence; email journey unverified |
| Pending/rejected/approved account authority | Yes | U/S | Persona/access suite | Blocked | Deployed staff/account reconciliation | Code/test verified |
| Biometrics/device lock | Yes | Indirect/source | Password validation tests | Blocked | Enrolled physical device | Device behavior unverified |
| Shell, More, Quick Actions, routes/back | Yes | U/W/S; Linux integration | Permission suite, separate from UI | Blocked | Android links | Policy PASS within tested cases |
| Catalogue/details/dynamic request form | Yes | U/S | Catalogue/request/pricing suite | Blocked | Live catalogue contents | F007; full submission journey blocked |
| Service documents/replacement/review | Yes | U/S | Upload/ownership/review suite | Blocked | Picker/scanner runtime | Code/test verified; physical paths unverified |
| Payment-first/receipt/reconciliation | Yes | U/S | Payment/lifecycle/accounting suite | Blocked | Actual payment/accounts | No new lifecycle defect established; E2E blocked |
| Track/history/cancellation | Yes | U/W/S | Terminal/lifecycle suite | Blocked | None inspected remotely | Historical-action tests PASS |
| In-app notifications/badges/actions | Yes | S, mapping tests | Notification/isolation suite | Blocked | Scheduler execution | F003; source event matrix below |
| OS push | Yes, both ends | S only | Token/preference tests only | Blocked | Provider credentials absent | F001: Missing/broken |
| Support/chat/attachments/status | Yes | U/S | Support/access suite | Blocked | External WhatsApp/email | Cache/session tests PASS; full chat E2E blocked |
| Profile/avatar/contact/address | Yes | U/S | Profile/self-service suite | Blocked | Maps configuration | Code/test evidence; permission UX unverified |
| Settings/business availability/update | Yes | U/S + audit probes | Settings/admin suite | Blocked | Deployed configuration | F003–F005 |
| Knowledge/FAQ/public content | Yes | U/S | Public-content tests | Blocked | Published content | Error mapping tested; visual inspection blocked |
| Tax/config/history/PDF/share/service | Yes | U/S | Tax/ownership/mutation suite | Blocked | PDF/provider runtime | Contract tests PASS; no active tax-alert producer found |
| Expenses/budgets/import/export/sync | Yes | S + audit probes | Expense/ownership suite | Blocked | None required for local mode | F002, F006 |
| Referrals/own commissions | Yes | U/W/S | Referral/commission/isolation suite | Blocked | Settlement evidence | Code/test evidence; live journey blocked |
| Internal workspace/cases/tasks | Yes | U/S + Linux contract integration | Staff/task/scope suite | Blocked | Deployed Staff Access | Policy/terminal tests PASS within scope |
| Customers/leads | Yes | U/S | Scope/read tests | Blocked | Actual directory size | F008 |
| Finance commissions/settlement | Yes | U/S | Finance/commission suite | Blocked | Accounting evidence | No new defect established; E2E blocked |
| Admin/staff/review/reassign/retry/discount | Yes | S | Admin/capability/mutation suite | Blocked | Deployed permissions | F005; operation E2E blocked |
| Android/release/security/files | Yes | Build-profile/security U/S | File permission tests | Blocked | Play, Sentry, links, Maps | Local keystore verified; release execution open |
| Visual/accessibility/performance | Structural scan | Limited shared-widget W | Not applicable | Blocked | Device sizes/text scale | Shared widgets tested; full screen matrix open |

Coverage gaps: most feature tests are model/provider tests or source-string assertions. A source assertion mentioning an upload, retry, or capability is not a renderer test or an HTTP integration test. The existing Linux integration case verifies a constructed workflow projection and route policy, not a real payment journey. Only selected shared widgets, signup, commissions, and historical states have renderer evidence in the executed test suite. Small/normal/large phones, keyboard/notch combinations, all modals, permission denial, app resume, and rapid interactions across every screen were not exhaustively rendered.

## 4. Findings

Paths below are repository-relative. `B/` means `backend_omc_app/frappe-bench/apps/omc_app/omc_app/`.

### F001 — Required Android OS push has no concrete end-to-end implementation

- **Severity:** P1. **Confidence:** Confirmed. **Category:** Notifications/release. **Persona/platform:** All intended Android recipients, including staff.
- **Source:** `omc_app/lib/core/push/push_registration.dart:30`, `pushTokenSourceProvider`; `omc_app/lib/main.dart:29`, root `ProviderScope`; `B/api/mobile.py:3527`, `_create_customer_notification`; `B/omc_app/doctype/omc_notification/omc_notification.py:5`.
- **Path/reproduction:** Start the current app. Its only production source returns `UnavailablePushTokenSource`; `requestToken()` returns null and both streams are empty. There is no production override. No messaging transport dependency/native service/permission/channel implementation was found. Backend events insert an `OMC Notification`; the controller updates read timestamps, but neither calls a push sender.
- **Expected:** A qualifying event reaches the authorized device notification panel in background/terminated states and opens its referenced screen.
- **Actual/impact:** In-app records and token registration abstractions exist, but no OS delivery chain exists. Supplying credentials alone cannot complete missing implementation.
- **Root cause:** Provider-neutral scaffolding and token storage have not been connected to concrete device and server transports. No dispatcher, provider response processing, retry queue, or invalid-token handling exists in the inspected custom notification chain.
- **Evidence:** Full production push-reference search, dependency/native inspection, custom-backend notification-producer search and AST call index; existing push tests are source-contract tests, not delivery tests. Details in sections 8–9.
- **Minimal fix direction:** Complete one concrete transport on both ends and prove permission, lifecycle, ownership, delivery, and tap behavior on Android. No implementation performed.

### F002 — Expense receipt upload loses the expense entry identifier

- **Severity:** P1. **Confidence:** Confirmed. **Category:** Flutter/backend upload contract. **Persona:** Approved customer using account sync and receipt attachments.
- **Source:** `omc_app/lib/features/expense_tracker/data/expense_tracker_repository.dart:538`, `uploadReceiptFile`; `B/api/expense_guard.py:7`, `upload_expense_receipt`; `B/api/expense.py:259`, `_assert_entry_access`; override in `B/hooks.py:12`.
- **Path/reproduction:** Save a synced expense with a selected receipt. Flutter uploads bytes with `doctype` and `docname: entryId`, without `entry_id`. The active override accepts only `entry_id` and `file_url`. Frappe's argument filter removes `docname`, and the guard delegates `entry_id=None` to the underlying expense method.
- **Expected:** Attach validated bytes to the authorized saved entry.
- **Actual/impact:** Entry lookup fails with “Expense entry not found”; the expense can be saved while its receipt attachment fails. The base implementation's `docname` alias does not help because the override discarded it first.
- **Root cause:** Multipart identifier and override signature disagree.
- **Evidence:** Temporary Dart probe executed actual repository method and captured `docname` without `entry_id`. Temporary Python probe executed the actual extracted Frappe `get_newargs` and active guard: it forwarded `entry_id=None`. No real customer record or production endpoint was used.
- **Minimal fix direction:** Align the client field and active override, preserving canonical ownership/file validation; verify a complete successful attachment and rejected foreign ID.

### F003 — “In-app notifications” master switch reports success without saving

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Settings/delivery contract. **Persona:** Customer changing notification preferences.
- **Source:** `omc_app/lib/features/settings/presentation/settings_screen.dart:690`, `_PreferencesSection`; `omc_app/lib/features/settings/data/settings_repository.dart:45`, `savePreferences`; `B/api/mobile.py:4071`, `_settings_preferences_to_dict`; `B/api/mobile.py:4245`, `update_settings_preferences`.
- **Path/reproduction:** Toggle In-app notifications off. Flutter sends `in_app_notifications_enabled:false`. Backend's permitted fields omit it; serialization omits it too. Flutter ignores the update result, announces settings updated, invalidates preferences, and reloads the missing field as true.
- **Expected:** The switch saves and consistently controls the advertised channel, or is not presented as an active control.
- **Actual/impact:** The switch resets; category notifications remain enabled. Users receive a misleading success message.
- **Root cause:** A client-only master field with no saved/backend delivery contract.
- **Evidence:** Dart probe verified outgoing false and reload-to-true; Python probe executed actual settings update/serializer and returned `updated=False` with no master field. Category notification creator uses category fields, not this master.
- **Minimal fix direction:** Define the supported master behavior end-to-end or remove the unsupported active control. Staff also see customer preference controls even though their provider returns defaults; staff applicability requires explicit treatment. Tax alerts save, but no current tax notification-producing event was found—do not imply demonstrated delivery from that switch.

### F004 — Mobile-config failure re-enables unavailable feature entry points

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Configuration/fallback reliability. **Persona:** Users affected by disabled business features during a config outage.
- **Source:** `omc_app/lib/features/app_config/data/mobile_app_config_repository.dart:26`, `fetchMobileAppConfig`; `omc_app/lib/features/app_config/data/mobile_app_config.dart:18`, `fallback`, and `:64`, `MobileFeatureConfig`; `omc_app/lib/app/navigation/omc_more_sheet.dart:41`, feature mapping.
- **Path/reproduction:** Backend has payments/support/expense/knowledge disabled; config read fails after its normal retries. Repository catches every error and returns a successful fallback with those flags true. More/navigation consumes those values; the provider retains the successful fallback rather than exposing a retryable config error.
- **Expected:** Disabled availability is retained or unknown configuration is shown honestly with recovery.
- **Actual/impact:** Previously unavailable entry points appear and can lead to rejected/unavailable workflows. This is a UI/business-availability defect, **not a demonstrated backend authorization bypass**.
- **Root cause:** An unknown config is modeled as an enabled default and a successful cached load.
- **Evidence:** Executed outage probe confirms `isFallback=true` with payments/support/expense enabled; traced More feature mapping. There is no preserved last-known authoritative config in this repository.
- **Minimal fix direction:** Distinguish unknown/unavailable config from enabled business features and provide bounded recovery without fabricating service data.

### F005 — Advertised maintenance and forced-update controls are not applied by Flutter

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Release/business-control contract. **Persona:** Business-settings administrator and clients requiring maintenance/update handling.
- **Source:** `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart:529`, `_toggleLabels`; `B/api/admin_control.py:40`, allowed settings; `B/api/mobile.py:3841`, mobile config `meta`; `omc_app/lib/features/app_config/data/mobile_app_config.dart:31`, `fromApiResponse`.
- **Path/reproduction:** Administrator enables Maintenance mode or Force app update; backend exposes the saved fields and minimum version in config metadata. Flutter parses only the metadata fallback indicator and never models/checks the version, force-update, or maintenance values.
- **Expected:** Controls advertised as applying to the live mobile app produce their stated behavior.
- **Actual/impact:** The app continues normal navigation; there is no version comparison, update prompt, forced gate, or Play Store update action. Administrators cannot rely on these controls when contracts change.
- **Root cause:** Saved server metadata has no client consumer. This is not inferred merely from absence of an update library: actual administrative controls establish the contract.
- **Evidence:** Production-wide symbol search found the labels but no client consumers; backend config and parser traced. Temporary parser probe confirmed normal enabled configuration despite these metadata flags being set.
- **Minimal fix direction:** Implement the intended control contract, including recovery, or stop advertising unsupported controls. Version display alone remains valid.

### F006 — Expense cloud refresh silently truncates history to 200 entries

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Pagination/state completeness. **Persona:** Synced customer with more than 200 non-archived expenses.
- **Source:** `omc_app/lib/features/expense_tracker/data/expense_tracker_repository.dart:454`, `fetchSyncedTransactions`; `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart:52`, `loadSynced`; `B/api/expense.py:324`, `get_expense_entries`.
- **Path/reproduction:** Have 201+ cloud entries; select Refresh while in account-sync mode. Flutter makes one read with no pagination arguments. Server defaults to `start=0, limit=200`. Controller persists that returned page as the local transaction collection.
- **Expected:** Complete history, or explicit pagination and totals that do not present a page as the entire account.
- **Actual/impact:** Older entries disappear from the refreshed mobile collection, local summaries, and export of that collection. This does not delete older server records. It can overwrite a previously more complete local snapshot.
- **Root cause:** One limited page is treated as complete synchronized state.
- **Evidence:** Executed repository probe confirmed no paging request; actual server limit and controller replacement traced. A 201-row live actor dataset was not created.
- **Minimal fix direction:** Use a complete/paged synchronization contract and preserve coherent local state until a complete refresh succeeds.

### F007 — Catalogue pagination is ignored, including service-detail lookup

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Catalogue/routing completeness. **Persona:** Guest/customer/staff accessing an active service beyond the first 50.
- **Source:** `omc_app/lib/features/service_catalogue/data/service_catalogue_repository.dart:79`, `_fetchBackendServices`; `B/api/public_catalogue.py:28`, `get_service_catalogue`; `omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart:45`, catalogue-backed detail lookup.
- **Path/reproduction:** Publish more than 50 services; place the target after the first page. The backend returns `has_more`/`next_start`, but Flutter only reads the first page. Detail screen searches that same catalogue collection.
- **Expected:** Discover/search/open any active service, including a directly referenced later service.
- **Actual/impact:** Later services are absent from search/list and their detail lookup can report unavailable despite an active backend record.
- **Root cause:** Page metadata is discarded; no dedicated active detail request compensates.
- **Evidence:** Source request/response and detail lookup traced. Backend exposes a detail method, but it has no active Flutter call. Threshold is code-proven; current production catalogue size was not queried.
- **Minimal fix direction:** Consume catalogue pagination and load detail by its authoritative ID independently of the first list page.

### F008 — Customer and lead directories cannot retrieve beyond their first 100

- **Severity:** P2. **Confidence:** Confirmed. **Category:** Internal workflow/scale. **Persona:** Authorized directory/lead staff with more than 100 visible records.
- **Source:** `B/api/mobile.py:4969`, `get_customers`; `B/api/lead_read_guard.py:37`, `get_leads`; `omc_app/lib/features/customers/data/customers_repository.dart:35`; `omc_app/lib/features/leads/data/leads_repository.dart:38`.
- **Path/reproduction:** More than 100 records satisfy the authorized list scope; search for an older record from the corresponding screen. Backend endpoints cap results at 100 and accept no paging/search parameters. Flutter searches its returned collection.
- **Expected:** Staff can find older authorized customers/leads through the directory.
- **Actual/impact:** Older records are undiscoverable from these screens. Customer detail by a known ID is a separate route and does not repair directory search. This materially affects the stated thousands-of-users target.
- **Root cause:** Fixed-cap list contracts with no continuation/server search.
- **Evidence:** Active override, endpoint signatures, limits, repository requests, and screen local filtering traced. No production directory was fetched.
- **Minimal fix direction:** Add scoped server search/pagination and corresponding client continuation; retain backend relevance/ownership checks.

## 5. Route / Screen / UI Action Matrix

The router declares **59 GoRoutes**, including the nested document route and three auth aliases. Route/capability/link/More tests passed. This table covers the declared entry points and important actions; device back, every error/timing permutation, and all visual combinations remain unverified.

| Entry points/screens | Meaningful actions traced | Static/automated result and limits |
|---|---|---|
| `/`, `/onboarding` | Session check, retry, next/skip/finish | Startup/onboarding state/recovery guards; no Android cold-start proof |
| `/login`, `/signup` | Password/biometric login, guest, activation/reset/support, registration steps, username/referral check | Canonical session enforced; signup W; duplicate/loading guards inspected |
| `/forgot-password`, `/reset-password` | Request email, submit/confirm password, expired-token recovery | Matching active methods; validation/error tests; email transport unverified |
| `/activate-existing-account`, `/activate-account` | Activation request, token/password completion | Backend methods matched; production email/app-link test blocked |
| `/verify-email` | Inspect token, complete registration, retry/login | Direct methods outside ApiConfig recorded below; token routes stay public during checking |
| `/app/activate-account`, `/app/reset-password`, `/app/verify-email` | Alias normalization retaining query | Link/auth redirect tests PASS |
| `/under-review` | Refresh approval, support, logout | Pending route; rejected/approved capability handling inspected |
| `/home`, `/more`, shell tabs/Quick Actions | Persona dashboard, shortcuts, badges, More, repeated tab/back policy | Capability/IA tests PASS; config F004 |
| `/services`, `/services/:serviceId` | Search/filter/detail/resume/start/support | F007; dynamic schema and server pricing inspected |
| `/services/:serviceId/request` | Customer/assisted selection, fields/dependencies, validation, attachments, submit/retry | Request ID, mutation intent and backend authority traced; real E2E blocked |
| `/track`, `/my-services`, `/my-services/:caseId` | List/filter/sort/detail/timeline/document/payment/cancel/support | Historical widget tests PASS; internal redirect to internal cases |
| `/documents`, `/documents/:documentId` | List/filter/load-more, detail, choose/upload/replace, authenticated preview/share | Upload policies + link authorization guards; picker/renderer on device blocked |
| `/payments`, `/payments/:paymentId` | List/detail, receipt upload/progress/cancel, invoice/receipt preview, review | Multipart payment contract matched; receipt is not treated as verified payment automatically |
| `/dashboard` | Next action, case/document/payment/workspace | Role-aware entry policy; projection tests |
| `/notifications`, `/notifications/:notificationId` | Pagination, read/unread/all-read, dismiss/undo, open reference | Ownership and route mapping tested; F001/F003; missing refs recover visibly |
| `/support`, `/support-tickets/:ticketId` | Channels, create/list/load-more, assignment, reply/file, read/status | Current wrappers use legacy presentation/repository code; generation guard and retries inspected |
| `/profile`, `/profile/edit` | Refresh/avatar, edit allowed identity/contact/address, maps, save/discard | Server edit policy; public avatar vs authenticated private documents distinguished |
| `/settings`, `/change-password` | Preferences, biometric enrollment, account request, logout, legal/version/password | F003/F005; password change clears biometric credentials |
| `/knowledge`, `/knowledge/:articleId` | List/search/article/FAQ, reload | Public content and safe error states; large-content visuals open |
| `/tax-calculator`, `/tax-calculator/history` | Year/income fields, calculate, history, PDF/share, start service | Backend calculation ownership and malformed-response tests; no OS/tax-alert evidence |
| `/expense-tracker`, `/expense-budget` | Local/sync mode, entries, edit/delete, import/export/clear, receipt, budget/month | F002/F006; local data namespaced; destructive-action guards inspected |
| `/my-referrals`, `/my-referrals/:customerId` | Search/page/detail/code copy/share/consented linked cases | Explicit own-referral capability and backend scope; tests PASS |
| `/my-commissions`, `/my-commissions/:earningId` | Filter/page/detail | Separate own-commission capability; ownership tests |
| `/internal-workspace`, `/internal-workspace/service-cases`, `/internal-workspace/service-cases/:caseId` | Queue/search/filter/page/case, status, review, reassignment, retry, discount | Backend capability/terminal guards; constructed Linux contract test PASS |
| `/customers`, `/customers/:customerId`, `/internal-workspace/customers` | Directory/search/detail/assisted entry | F008; relevant-customer scope retained |
| `/leads`, `/leads/:leadId` | Search/filter/create/detail | Real create endpoint/mutation intent; F008 |
| `/tasks`, `/tasks/:taskId` | Server search/filter/page/detail/linked case | Task scope + direct-route tests; no fabricated edit action assumed |
| `/internal-workspace/documents`, `/internal-workspace/payments` | Scoped review queues, filters/pages, preview/detail/review | Dedicated document screen; payments uses current payment branch |
| `/internal-workspace/commissions` | List/detail/approve/reject/payable/paid/reference | Finance methods outside ApiConfig; backend lifecycle guards |
| `/admin-control`, `/admin-control/operations` | Registration/staff/settings, reassign/retry/discount, paged operation queues | Backend enforcement; F005 |
| Settlement exceptions (Navigator route from workspace) | Search/page, case, resolve/ignore | Not a GoRoute; capability-gated entry and backend method; no missing-route finding |
| File previews, sheets, dialogs | Cancel/back, preview, confirmation, unsaved-form prompts | Navigator-based routes; relevant loading/mounted guards scanned; complete visual matrix open |

No confirmed missing literal navigation route or redirect loop was established. Dynamic backend route strings and every forged parameter were not exercised over HTTP. Task routes exist for in-app notification actions, but `LinkCoordinator` excludes `/tasks/` and internal workspace paths; a future OS-push adapter cannot assume arbitrary backend mobile routes already normalize on cold start. This is recorded as a constraint of F001, not as a currently demonstrated independent delivery defect.

The empty tune-button callback at `internal_operations_center_screen.dart:1070` belongs to the non-payment `_OperationsSearchAndFilters` branch. Current router construction uses this screen only for the separate payment branch. It is **not counted as a reachable production no-op**.

## 6. API / Backend Contract Matrix

Central configuration contains **119 `*Method` constants**, with 114 referenced somewhere under production `lib`; reference does not automatically mean a current reachable UI call. Five have no production references: `loginMethod`, `verifyRegistrationMethod`, `uploadPaymentReceiptMethod`, `uploadPaymentReceiptFileMethod`, `updateContactMethod`. The Google endpoint is development-guarded; push register/unregister references are scaffold-only while the token source is unavailable.

All central custom method targets resolved to Python definitions after applying hook overrides; native `logout`/`upload_file` are Frappe methods. A scan of 113 direct ApiConfig HTTP call sites found no GET-to-explicit-POST-only mismatch. Signature/name existence is a narrower result than correct payload, ownership, or deployment behavior.

| Group | Contract assessment |
|---|---|
| Auth/registration/activation/reset/guest | Methods and request fields matched; canonical session tests PASS. Two registration methods bypass central config. Guest analytics failure is intentionally non-blocking. |
| Services/templates/assisted creation | Active create routes delegate shared assisted authority; version/pricing/idempotency fields inspected. Catalogue pagination mismatch F007. |
| Cases/documents | Active read/mutation overrides and customer/internal dispatch traced; status/document/terminal tests. Multipart File upload followed by custom link creation is not one atomic client operation. |
| Payments/invoices | Read guard, multipart receipt route and review guard matched; old URL/base64 constants unused. Invoice bytes and receipt authorization tested in existing suite. |
| Profile/contact/address/avatar | Self-service policy methods and multipart avatar route matched; avatar is public by design. |
| Notifications/settings/push | In-app IDs, paging and ownership matched; master setting F003; sender/device implementation absent F001. |
| Support | Read/status/assignment overrides matched; generic File attachment then reply contract; stale cache guarded by session generation. |
| Public/home/knowledge/FAQ/config | Definitions/wrapping matched; config semantics F004/F005. |
| Tax | Config/calculation required fields and mutation/read ownership covered by existing tests; PDF/share runtime not exercised on Android. |
| Expenses | Receipt override mismatch F002; first-page-only refresh F006. Local-mode fallback intentionally disables sync/receipt/report claims. |
| Referrals/commissions/finance | Own and operations methods separately scoped; direct constants listed below. |
| Customers/leads/tasks/internal/admin | Canonical capability/ownership guards and relevant tests; directory completeness F008. Tasks and operation queues have paging contracts. |

Detailed endpoint index follows later in this section. “Definition/signature matched; HTTP runtime unverified” is deliberately not a blanket PASS for all fields/negative scenarios.

### Central endpoint index

All custom rows below have a source definition; all remain unverified as deployed HTTP endpoints in this run. Targets show hook overrides. Callers are production file names, including helpers.

| Constant | Effective target | Callers / reachability |
|---|---|---|
| `loginMethod` | `login` | Unused |
| `multiIdentifierLoginMethod` | `api.auth_login.login` | frappe_client.dart |
| `requestPasswordResetMethod` | `api.password_reset.request_reset` | auth_repository.dart |
| `resetPasswordMethod` | `api.password_reset.reset_password` | auth_repository.dart |
| `requestCustomerActivationMethod` | `api.customer_activation.request_activation` | auth_repository.dart |
| `completeCustomerActivationMethod` | `api.customer_activation.complete_activation` | auth_repository.dart |
| `changePasswordMethod` | `api.account_security.change_password` | auth_repository.dart |
| `verifyCurrentPasswordMethod` | `api.account_security.verify_current_password` | auth_repository.dart |
| `logoutMethod` | `logout` | auth_repository.dart |
| `googleLoginMethod` | `api.mobile_entry_mutations.google_mobile_login` | auth_repository.dart |
| `startRegistrationMethod` | `api.pending_registration.start_registration` | auth_repository.dart |
| `resendVerificationMethod` | `api.pending_registration.resend_verification` | auth_repository.dart |
| `verifyRegistrationMethod` | `api.pending_registration.verify_registration` | Unused |
| `suggestUsernameMethod` | `api.access.suggest_username` | auth_repository.dart |
| `checkUsernameAvailabilityMethod` | `api.access.check_username_availability` | auth_repository.dart |
| `validateReferralCodeMethod` | `referral_automation.validate_referral_code` | auth_repository.dart |
| `getSessionUserMethod` | `api.access_v2.get_session_user` | auth_repository.dart |
| `createGuestSessionMethod` | `api.guest_session.create_guest_session` | auth_repository.dart |
| `updateGuestActivityMethod` | `api.guest_session.update_guest_activity` | auth_repository.dart |
| `createServiceMethod` | `api.service_requests.create_service` | service_request_repository.dart |
| `assistedCustomerSelectionMethod` | `api.assisted_service_policy.get_customer_selection_options` | service_request_repository.dart |
| `createLeadMethod` | `api.mobile_entry_mutations.create_lead` | leads_repository.dart |
| `dashboardDataMethod` | `api.dashboard_read_guard.get_dashboard_data` | home_dashboard_repository.dart |
| `mobileQuickActionsMethod` | `api.quick_actions.get_mobile_quick_actions` | mobile_quick_actions_repository.dart |
| `taxCalculatorConfigMethod` | `api.tax_calculator.get_tax_calculator_config` | tax_calculation_repository.dart |
| `taxCalculatorMethod` | `api.tax_calculator_guard.calculate_tax` | tax_calculation_repository.dart |
| `taxCalculationHistoryMethod` | `api.tax_calculator.get_tax_calculation_history` | tax_calculation_repository.dart |
| `downloadTaxEstimatePdfMethod` | `api.tax_calculator_mutations.download_tax_estimate_pdf` | tax_calculation_repository.dart |
| `shareTaxEstimateWithConsultantMethod` | `api.tax_calculator_mutations.share_tax_estimate_with_consultant` | tax_calculation_repository.dart |
| `startTaxServiceFromCalculationMethod` | `api.tax_calculator_mutations.start_service_from_calculation` | tax_calculation_repository.dart |
| `serviceCatalogueMethod` | `api.public_catalogue.get_service_catalogue` | service_catalogue_repository.dart |
| `serviceTemplateMethod` | `api.service_templates.get_service_template` | service_catalogue_repository.dart, service_template_repository.dart |
| `serviceCasesMethod` | `api.service_case_contract.get_service_cases` | service_case_repository.dart |
| `serviceCaseDetailMethod` | `api.service_case_contract.get_service_case` | service_case_repository.dart |
| `updateServiceCaseStatusMethod` | `api.service_request_mutations.update_service_case_status` | service_case_repository.dart |
| `cancelServiceRequestMethod` | `api.service_request_mutations.cancel_service_request` | customer_service_case_repository.dart, service_case_repository.dart |
| `documentsMethod` | `api.service_document_read.get_documents` | documents_repository.dart |
| `documentDetailMethod` | `api.service_document_guard.get_document` | documents_repository.dart |
| `uploadServiceDocumentMethod` | `api.document_upload.upload_service_document` | documents_repository.dart, service_request_repository.dart |
| `updateServiceDocumentStatusMethod` | `api.service_document_guard.update_service_document_status` | documents_repository.dart, service_case_repository.dart |
| `paymentsMethod` | `api.payment_read_guard.get_payments` | payments_repository.dart |
| `paymentDetailMethod` | `api.payment_read_guard.get_payment` | payments_repository.dart |
| `downloadPaymentInvoiceMethod` | `api.payment_read_guard.download_invoice_pdf` | payments_repository.dart |
| `uploadPaymentReceiptMethod` | `api.mobile_state_mutations.upload_payment_receipt` | Unused |
| `uploadPaymentReceiptFileMethod` | `api.payment_mutation_guard.upload_payment_receipt_file` | Unused |
| `uploadPaymentReceiptMultipartMethod` | `api.payments.upload_payment_receipt_multipart` | payments_repository.dart |
| `reviewPaymentReceiptMethod` | `api.payment_mutation_guard.review_payment_receipt` | payments_repository.dart |
| `profileMethod` | `api.access_v2.get_profile` | profile_repository.dart |
| `updateProfileMethod` | `api.profile_self_service.update_profile` | profile_repository.dart |
| `updateWorkAddressMethod` | `api.profile_self_service.update_work_address` | profile_repository.dart |
| `dismissWorkAddressPromptMethod` | `api.profile_self_service.dismiss_work_address_prompt` | profile_repository.dart |
| `updateContactMethod` | `api.profile_guard.update_contact_info` | Unused |
| `uploadProfileImageMethod` | `api.profile.upload_profile_image` | profile_repository.dart |
| `knowledgeMethod` | `api.mobile.get_knowledge` | knowledge_repository.dart |
| `knowledgeDetailMethod` | `api.mobile.get_knowledge_article` | knowledge_repository.dart |
| `appBannersMethod` | `api.mobile.get_app_banners` | app_content_repository.dart |
| `onboardingSlidesMethod` | `api.mobile.get_onboarding_slides` | onboarding_repository.dart |
| `faqsMethod` | `api.mobile.get_faqs` | app_content_repository.dart |
| `notificationsMethod` | `api.mobile.get_notifications` | notifications_repository.dart |
| `notificationDetailMethod` | `api.mobile.get_notification_detail` | notifications_repository.dart |
| `markNotificationReadMethod` | `api.mobile_state_mutations.mark_notification_read` | notifications_repository.dart |
| `markAllNotificationsReadMethod` | `api.mobile_state_mutations.mark_all_notifications_read` | notifications_repository.dart |
| `dismissNotificationMethod` | `api.mobile_state_mutations.dismiss_notification` | notifications_repository.dart |
| `restoreNotificationMethod` | `api.mobile_state_mutations.restore_notification` | notifications_repository.dart |
| `markNotificationUnreadMethod` | `api.mobile_state_mutations.mark_notification_unread` | notifications_repository.dart |
| `unreadNotificationCountMethod` | `api.mobile.get_unread_notification_count` | notifications_repository.dart |
| `registerPushTokenMethod` | `api.mobile_state_mutations.register_push_token` | push_registration.dart |
| `unregisterPushTokenMethod` | `api.mobile_state_mutations.unregister_push_token` | push_registration.dart |
| `settingsPreferencesMethod` | `api.mobile.get_settings_preferences` | settings_repository.dart |
| `updateSettingsPreferencesMethod` | `api.mobile_state_mutations.update_settings_preferences` | settings_repository.dart |
| `createSupportTicketMethod` | `api.support_chat.create_support_ticket` | support_repository_legacy.dart |
| `supportTicketsMethod` | `api.support_ticket_read_guard.get_support_tickets` | support_repository_legacy.dart |
| `supportTicketDetailMethod` | `api.support_ticket_read_guard.get_support_ticket` | support_repository_legacy.dart |
| `activeSupportTicketMethod` | `api.support_ticket_read_guard.get_active_support_ticket` | support_repository_legacy.dart |
| `supportUnreadCountMethod` | `api.support_ticket_read_state_guard.get_support_unread_count` | support_repository_legacy.dart |
| `markSupportTicketReadMethod` | `api.support_ticket_read_state_guard.mark_support_ticket_read` | support_repository_legacy.dart |
| `addSupportTicketReplyMethod` | `api.support_chat.add_support_ticket_reply` | support_repository_legacy.dart |
| `updateSupportTicketStatusMethod` | `api.support_ticket_guard.update_support_ticket_status` | support_repository_legacy.dart |
| `uploadSupportTicketAttachmentMethod` | `upload_file` | support_repository_legacy.dart |
| `supportConfigMethod` | `api.mobile.get_support_config` | support_repository.dart, support_repository_legacy.dart |
| `uploadFileMethod` | `upload_file` | frappe_client.dart |
| `mobileAppConfigMethod` | `api.branding_config.get_mobile_app_config` | mobile_app_config_repository.dart |
| `customersMethod` | `api.mobile.get_customers` | customers_repository.dart |
| `customerDetailMethod` | `api.mobile.get_customer` | customers_repository.dart |
| `getMyReferralSummaryMethod` | `api.referral_analytics.get_my_referral_summary` | referral_repository.dart |
| `getMyReferralsMethod` | `api.referral_analytics.get_my_referrals` | referral_repository.dart |
| `getMyReferralDetailMethod` | `api.referral_analytics.get_my_referral_detail` | referral_repository.dart |
| `getMyCommissionSummaryMethod` | `api.referral_commissions.get_my_commission_summary` | commission_repository.dart |
| `getMyCommissionsMethod` | `api.referral_commissions.get_my_commissions` | commission_repository.dart |
| `getMyCommissionMethod` | `api.referral_commissions.get_my_commission` | commission_repository.dart |
| `leadsMethod` | `api.lead_read_guard.get_leads` | leads_repository.dart |
| `leadDetailMethod` | `api.lead_read_guard.get_lead` | leads_repository.dart |
| `tasksMethod` | `api.task_read_guard.get_tasks` | tasks_repository.dart |
| `taskDetailMethod` | `api.task_read_guard.get_task` | tasks_repository.dart |
| `internalWorkspaceSummaryMethod` | `api.internal_workspace_summary.get_internal_workspace_summary` | internal_workspace_repository.dart |
| `internalServiceCasesMethod` | `api.internal_workspace.get_service_cases` | internal_workspace_repository.dart |
| `createServiceRequestForCustomerMethod` | `api.assisted_service_policy.create_service_request_for_customer` | internal_workspace_repository.dart |
| `adminOverviewMethod` | `api.admin_control.get_admin_overview` | admin_control_repository.dart |
| `adminOperationsMethod` | `api.admin_control.get_admin_operations` | admin_control_repository.dart |
| `reviewRegistrationMethod` | `api.admin_control.review_registration` | admin_control_repository.dart |
| `inviteStaffMethod` | `api.admin_control.invite_staff` | admin_control_repository.dart |
| `updateStaffAccountMethod` | `api.admin_control.update_staff_account` | admin_control_repository.dart |
| `reassignServiceRequestMethod` | `api.admin_control.reassign_service_request` | admin_control_repository.dart |
| `caseAdminOptionsMethod` | `api.admin_control.get_case_admin_options` | admin_control_repository.dart |
| `retryServiceSyncMethod` | `api.admin_control.retry_service_sync` | admin_control_repository.dart |
| `businessSettingsMethod` | `api.admin_control.get_business_settings` | admin_control_repository.dart |
| `updateBusinessSettingsMethod` | `api.admin_control.update_business_settings` | admin_control_repository.dart |
| `reviewDiscountMethod` | `api.pricing_guard.review_discount` | admin_control_repository.dart |
| `expenseConfigMethod` | `api.expense.get_expense_config` | expense_tracker_repository.dart |
| `expenseCategoriesMethod` | `api.expense.get_expense_categories` | expense_tracker_repository.dart |
| `expenseEntriesMethod` | `api.expense_read_guard.get_expense_entries` | expense_tracker_repository.dart |
| `createExpenseEntryMethod` | `api.expense_write_guard.create_expense_entry` | expense_tracker_repository.dart |
| `bulkSyncExpenseEntriesMethod` | `api.expense_write_guard.bulk_sync_expense_entries` | expense_tracker_repository.dart |
| `updateExpenseEntryMethod` | `api.expense_write_guard.update_expense_entry` | expense_tracker_repository.dart |
| `deleteExpenseEntryMethod` | `api.expense_write_guard.delete_expense_entry` | expense_tracker_repository.dart |
| `expenseSummaryMethod` | `api.expense_read_guard.get_expense_summary` | expense_tracker_repository.dart |
| `expenseBudgetsMethod` | `api.expense_read_guard.get_expense_budgets` | expense_tracker_repository.dart |
| `saveExpenseBudgetMethod` | `api.expense_write_guard.save_expense_budget` | expense_tracker_repository.dart |
| `uploadExpenseReceiptMethod` | `api.expense_guard.upload_expense_receipt` | expense_tracker_repository.dart |

### Endpoints outside central configuration

| File | Method | Static definition |
|---|---|---|
| `features/admin_control/data/admin_overview_repository.dart` | `omc_app.api.admin_read.get_admin_overview` | admin_read.py:11; HTTP runtime unverified |
| `features/auth/data/auth_repository.dart` | `omc_app.api.pending_registration.get_registration_verification_status` | pending_registration.py:296; HTTP runtime unverified |
| `features/auth/data/auth_repository.dart` | `omc_app.api.pending_registration.complete_registration` | pending_registration.py:510; HTTP runtime unverified |
| `features/commissions/data/finance_commission_repository.dart` | `omc_app.api.commission_operations.get_commission_allocations` | commission_operations.py:169; HTTP runtime unverified |
| `features/commissions/data/finance_commission_repository.dart` | `omc_app.api.commission_operations.get_commission_allocation` | commission_operations.py:213; HTTP runtime unverified |
| `features/commissions/data/finance_commission_repository.dart` | `omc_app.api.commission_lifecycle.review_allocation` | commission_lifecycle.py:256; HTTP runtime unverified |
| `features/commissions/data/finance_commission_repository.dart` | `omc_app.api.commission_lifecycle.mark_payable` | commission_lifecycle.py:298; HTTP runtime unverified |
| `features/commissions/data/finance_commission_repository.dart` | `omc_app.api.commission_lifecycle.mark_paid` | commission_lifecycle.py:316; HTTP runtime unverified |
| `features/home/data/home_content_repository.dart` | `omc_app.api.home_content.get_home_content` | home_content.py:170; HTTP runtime unverified |
| `features/internal_workspace/data/internal_service_case_page_repository.dart` | `omc_app.api.internal_workspace_read_guard.get_service_cases` | internal_workspace_read_guard.py:164; HTTP runtime unverified |
| `features/payments/data/finance_reconciliation_repository.dart` | `omc_app.api.finance_reconciliation.get_settlement_reviews` | finance_reconciliation.py:90; HTTP runtime unverified |
| `features/payments/data/finance_reconciliation_repository.dart` | `omc_app.api.finance_reconciliation.decide_settlement_review` | finance_reconciliation.py:158; HTTP runtime unverified |
| `features/service_requests/data/customer_service_case_repository.dart` | `omc_app.api.service_case_contract.get_service_case` | service_case_contract.py:376; HTTP runtime unverified |
| `features/support/data/support_repository_legacy.dart` | `omc_app.api.support_chat.assign_support_ticket` | support_chat.py:805; HTTP runtime unverified |

## 7. Role / Capability Matrix

Authority comes from `B/api/capabilities.py:101` (`effective`), reconciled Customer Account/Staff Access, identity, and per-operation scopes—not merely role labels. Approved/current Staff Access is required for staff capability grants; customer service access is separately derived. Flutter `AuthCapabilities`, `effectiveCapabilitiesProvider`, route policy, shell, More and Quick Actions consume that authority. Backend guards remain the enforcement boundary.

| Persona/capability | Positive access traced | Negative/direct-route result | Evidence limit |
|---|---|---|---|
| Unauthenticated | Login/signup/reset/activation/token routes | Protected routes redirect to login | Auth redirect U; no forged HTTP session journey |
| Guest | Public services/content, tax, local expense, support entry | Protected payments/documents/internal/account routes denied | Route-policy U; public support entry does not grant private ticket access |
| Pending/rejected customer | Public utilities, account/review/recovery as allowed | No approved-customer service/document/payment authority | Auth state + backend persona regressions; live approval refresh unverified |
| Approved customer | Own request, documents, payment receipts, track, support, profile | Foreign case/file/payment/notification access checked server-side | Existing ownership/security suite; physical/customer E2E blocked |
| Internal approved/current | Internal workspace and explicitly granted features | Unknown internal subroutes fail closed | Route/capability tests; live revocation journey blocked |
| Assigned/relevant case staff | Scoped cases/customer relationships and granted updates | Backend case scope required despite direct route | Task/service/document read guards and scope tests |
| Document queue/summary/attachment/review grants | Distinct queue/detail/file/review capabilities | Visibility of a queue does not imply file/review permission | Document authority tests; actual actor not supplied |
| Payment queue/summary/receipt/review/reconciliation grants | Scoped payment actions and finance workspaces | Mutation/read/file gates on server | Finance/payment regressions; real accounting journey blocked |
| Customer/lead/task grants | Directory, lead creation, task pages and linked cases | Route gates plus canonical backend requirements | F008 limits directory completeness, not authorization |
| Own referrals / own commissions | Separate personal summary/list/detail | No automatic full referral/private-customer access | Referral consent/ownership tests |
| Commission approval/mark-paid | Finance allocation lifecycle | Server review and settlement checks | Commission regressions; settlement evidence external |
| Staff/admin/registration/business settings | Explicit administrative features | Direct APIs require relevant capabilities | Admin tests; F005 is control semantics, not bypass |
| Reassign/retry/discount capabilities | Case/admin operations | Scope + terminal/idempotency guards | Existing mutation/terminal regressions |

No confirmed cross-customer exposure was found in the traced active contracts. This is not an assertion that every forged ID or every deployed capability combination was runtime tested. Direct-route policy tests and server tests were executed separately, not as a full app-to-HTTP security journey.

## 8. Notification Event Matrix

Discovery included all production custom Python references to `OMC Notification`, direct construction/insertion, `_create_customer_notification`, `_create_service_notification`, `_notify_once`, reviewer helpers, payment notification helpers, scheduler hooks, and task hooks. Test/patch fixtures are not treated as runtime producers. The canonical creator sets `visible_to_customer=1` for **both** customer and recipient-user notifications; list/detail ownership decides visibility, so that flag alone does not broadcast staff messages to customers.

Common conventions:

- **D10:** same owner + title + message + normalized type + reference within ten minutes. Service helper adds a similar precheck. This is an existence-check dedupe, not demonstrated concurrent exactly-once insertion.
- Customer gates: **S**=`service_updates_enabled`; **D**=`document_reminders_enabled`; **P**=`payment_alerts_enabled`. Missing preference rows/values default enabled. Recipient-user internal events bypass customer preferences by design.
- Unsupported type aliases (`Reminder`, `Escalation`, `Workflow`) normalize to **General**. Thus the daily customer action reminder uses S, not D.
- **C**=`/my-services/{request}`; internal case viewers are redirected to `/internal-workspace/service-cases/{request}`. **D-route**=`/documents/{document}`; **P-route**=`/payments/{payment}`; **T**=`/tasks/{task}`; **H**=`/support-tickets/{ticket}`.
- Route resolver checks supported reference existence. It does not grant record access. For every current event below, **OS push is Missing/broken (F001)**. “Code” means in-app creation is source-verified, not that the event was generated/delivered on a device during this audit.

| Trigger / title / normalized type | Source | Recipient | Persona/capability | Preference | In-app | OS push | Route | Dedupe | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| Payment opened: “Payment is ready” / Payment | `api/payment_opening.py:91`, `_notify_payment_opened` | Request customer profile | Customer owning request | P | Code | Missing | P-route | D10; payment-opening idempotency | Current canonical producer |
| Legacy payment opening: “Payment is ready” / Payment | `api/payments.py:580`, `_ensure_payment_for_case` | Service-case customer | Customer | P | Code/legacy branch | Missing | P-route | D10/payment existence | Retained path; not assumed emitted by every new request |
| Document rejected: “Document needs attention” / Document | `api/payments.py:608`, `handle_document_review`, called by customer document review | Parent-case customer | Customer whose item was rejected | D | Code | Missing | C | D10 | Current review path; opens case, not document |
| Document approved when no payment returned: “Document approved” / Document | `api/payments.py:626`, `handle_document_review` | Parent-case customer | Customer | D | Code | Missing | C | D10 | Conditional branch |
| Receipt decision: “Payment Receipt Accepted” or “Payment {status}” / Payment | `api/payments.py:1403`, `review_payment_receipt` | Parent-case customer | Customer receiving finance decision | P | Code | Missing | P-route | D10; no-op review guard | Current producer |
| Document review assigned / Document | `api/review_routing.py:204`, `ensure_review_assignment` | Selected reviewer | Assigned staff if capable, else eligible specialist/fallback; least load | Internal bypass | Code | Missing | D-route | Existing review ToDo + D10 | Capability-aware selection |
| Payment review assigned / Payment | Same function; payment domain | Selected finance reviewer | `can_review_payments`; eligible active user | Internal bypass | Code | Missing | P-route | Existing review ToDo + D10 | Capability-aware selection |
| Document stale >4h: “Stale review task needs attention” / Document | `api/review_routing.py:222`, `_escalate_stale_review` | Least-loaded active manager/admin with document capability | Document reviewer/escalation | Internal bypass | Code | Missing | D-route | 24h owner/reference + D10 | Hourly review job |
| Payment stale >2h: same title / Payment | Same function; payment domain | Least-loaded eligible manager/admin | Payment reviewer/escalation | Internal bypass | Code | Missing | P-route | 24h + D10 | Hourly review job |
| New service assignment: “New service request assigned” / Service Request | `api/service_assignment.py:241`, `apply_assignment` | Chosen assignee | Assigned staff from assignment authority | Internal bypass | Code | Missing | C | Assignment path + D10 | Current producer |
| Assignment recovery requires attention / Service Request | `api/service_assignment.py:327`, `_escalate_assignment_issue` | First sorted active/current approved staff with reassignment capability | `can_reassign_service_cases` | Internal bypass | Code | Missing | C | 24h + D10 | No eligible recipient means no notification |
| New ERP task assignment: “New task assigned” / Task | `api/erp_service_task_adapter.py:215`, `ensure_task_assignment` | Task assignee | Operational staff | Internal bypass | Code | Missing | T | Assignment/ToDo + D10 | In-app route exists; future cold push normalization needs work |
| Linked ERP Task update: “Task updated” / Task | `api/erp_task_status_sync.py:166`, `_notify_task_recipients` | Case assigned staff union open Task ToDo assignees, enabled users only | Operational task participants | Internal bypass | Code | Missing | T | Recipient set + D10 | Hooked from Task on_update; record read authority remains separate |
| Waiting for Customer daily: “Action required on your service request” / General | `api/workflow_automation.py:164`, `run_daily_workflow_checks` | Case customer | Customer needing information/correction | S | Code | Missing | C | 72h + D10 | Type is Reminder → General; not document preference |
| Waiting for Payment daily: “Payment pending” / Payment | `api/workflow_automation.py:178` | Case customer | Customer owing payment | P | Code | Missing | C | 72h + D10 | Opens case, not a fabricated payment ID |
| Overdue open case: “Service request overdue” / General | `api/workflow_automation.py:199` | Enabled System User OMC Admin/Manager role holders union assigned staff | Escalation staff; role-based recipient selection | Internal bypass | Code | Missing | C | 24h + D10 | Current daily job; deployed capability consistency unverified |
| Customer cancellation: “Customer cancelled service request” / Service Request | `api/workflow_automation.py:434`, `finalize_cancelled_case` | Assigned staff, if present | Case assignee | Internal bypass | Code | Missing | C | D10; terminal transition | Current producer |
| Non-customer cancellation: “Service request cancelled” / Service Request | `api/workflow_automation.py:447` | Customer profile, if present | Affected customer | S | Code | Missing | C | D10; terminal transition | Current producer |
| Completion: “Service completed” / Service Request | `api/workflow_automation.py:484`, `finalize_completed_case` | Case customer | Customer after trusted completion | S | Code | Missing | C | D10; lifecycle completion guards | Canonical lifecycle and ERP sync callers |
| Pending request expiry: “Service request expired” / Service Request | `api/request_lifecycle.py:202`, `_terminal_cleanup` | Request customer | Expired request customer | S | Code | Missing | C | 365 days + D10 | Hourly bridge expiration → lifecycle |
| Staff support reply/attachment: “Support reply received” / Support | `api/support_chat.py:742`, `_add_support_ticket_reply` | Ticket customer | Customer receiving internal reply | S | Code | Missing | H | D10; reply mutation intent | Customer reply does not imply a staff OMC Notification event |
| Support status: “Support Ticket {status}” / Support | `api/support_chat.py:791`, `update_support_ticket_status` | Ticket customer | Customer | S | Code | Missing | H | D10; status no-op guard | Current status override delegates here |
| Unsupported depends_on: “Unsupported service form condition” / Service Request | `api/submission_integrity.py:231`, `_escalate_unsupported_conditions` | First sorted enabled System User holding Admin/Manager role | Configuration escalation staff | Internal bypass | Code | Missing | No mapped OMC Service route | 24h/service + D10 | Alert text usable; no specific app destination |
| Legacy create: “Request received” / Service Request | `api/mobile.py:1317`, `create_service` | Profile else requested_by | Customer/request owner | S for profile | Legacy code | Missing | C | Service helper + D10 | Current Flutter create uses `api.service_requests`; do not claim this fires there |
| Legacy status: “Service status: {status}” / Service Request | `api/mobile.py:1959`, `update_service_case_status` | Profile else requested_by | Customer/request owner | S | Legacy code | Missing | C | Service helper + D10 | Current status override uses canonical lifecycle; ordinary timeline updates are not proof of this event |
| Legacy document wrapper: approved/correction/status title / Document | `api/mobile.py:2347`, `update_service_document_status` | Parent request owner | Customer | D | Legacy wrapper code | Missing | D-route | Service helper + D10 | Current configured override bypasses this wrapper |

`_create_customer_notification`, `_create_service_notification`, `_notify_once`, `_notify_reviewers_once`, and payment `_notify_customer` are helper infrastructure, not additional business events. `_notify_reviewers_once` has no independently discovered current caller. Direct `OMC Notification` writes found outside the creator were read/dismiss/cleanup and related state operations, not an additional producer.

Registration/activation/password reset primarily use email/token workflows; no additional OMC Notification producer was found for them. No current tax-alert, email-preference-driven notification transport, or WhatsApp notification sender was found in this chain. WhatsApp contact launch is a separate user action.

Preferences end-to-end: Service, Document and Payment switches serialize their corresponding fields; backend saves them and creation checks them. Tax field saves but lacks an active tax event, and the creator has no Tax normalization alias. Email/WhatsApp fields remain compatibility data but their switches are not surfaced as active delivery options. Push switch is hidden unless `push_provider_operational` is true; backend does not supply an operational provider flag. In-app master is the confirmed F003 mismatch. Stored rows are not a delivery audit trail for an external provider.

## 9. Push Delivery Readiness

Exactly one requested classification is assigned to each capability below. Scaffold verification does not mean runtime delivery verification.

| Capability | Classification | Evidence |
|---|---|---|
| Concrete device provider | Missing/broken | Only unavailable/null source; no production override |
| Android 13+ permission and runtime request | Missing/broken | No POST_NOTIFICATIONS declaration/request in app implementation |
| Notification channel/importance/icon | Missing/broken | No notification channel/display implementation |
| Token registration endpoint | Code/config verified | Authenticated POST guard, canonical token ownership/reassignment, active token storage |
| Real token acquisition/refresh | Missing/broken | Empty/null source; refresh listener is scaffold only |
| Logout unregister integration | Missing/broken | Coordinator contains a call, but no real token lifecycle; auth/logout ordering and failures not runtime proved |
| Account switch ownership | Code/config verified | Backend reassigns canonical token record to authenticated user; no concrete device proof |
| Foreground display | Missing/broken | No message/display handler |
| Background display | Missing/broken | No concrete messaging setup |
| Killed-app delivery | Missing/broken | No concrete messaging setup |
| Notification tap/cold-start binding | Missing/broken | `openedRoutes` abstraction has no production consumption; ordinary app links are separate |
| Permission denial/permanent denial recovery | Missing/broken | No push permission flow |
| Duplicate display prevention | Missing/broken | No display path to assess |
| Backend provider send/queue/response | Missing/broken | Creator ends after insert; no provider dispatch/response handling |
| In-app category preference enforcement | Code/config verified | Creator checks category preference; F003 master excluded |
| Push preference enforcement | Missing/broken | Token-selection helper alone is not a dispatch decision |
| Retry/provider error handling | Missing/broken | No sender/job |
| Invalid-provider-token cleanup | Missing/broken | No provider responses to invalidate failed tokens |
| Provider project/production credentials | External production configuration required | No credentials invented or exposed |
| Physical foreground/background/killed/tap acceptance | Environment-blocked | No Android device; implementation also missing |

Token unregister is owner-filtered on the backend; inactive tokens are excluded by selection helpers. Notification cleanup bounds old/expired/read/dismissed rows, but is not push-token failure cleanup. No event in section 8 qualifies as Runtime verified OS delivery.

## 10. Android / Release / Security

- **Identity/config verified:** `com.wajid.omc_house` namespace and application ID; `OMC House` label; launcher resources present; pubspec `9.0.0+13`. No rename performed. Installed Flutter Gradle defaults resolve compile/target SDK 36 and min SDK 24. Java/Kotlin target 17; AGP 9.0.1, Kotlin plugin 2.3.20 in source.
- **Signing verified locally:** Release explicitly uses the release signing config, not debug signing. Gradle rejects missing/incomplete key properties or missing keystore. Local key properties and keystore exist; `keytool` opened the keystore with the configured password and the configured alias was present. No password/certificate private material was printed. The real Play upload/app-signing identity and accepted versionCode were not verified.
- **Release startup guard verified:** `main` validates release environment, HTTPS production host/API origin, production link host, and non-empty HTTPS Sentry define. Development mock auth/catalogue/support previews and Google login cannot pass this production startup profile. No current `OMC_SENTRY_DSN` environment value was available. A production launch was not performed; a signed release bundle was not built in this audit.
- **Native surface:** Exported launcher `MainActivity` uses `FlutterFragmentActivity` and singleTop. Custom scheme `omchouse://auth`; HTTPS app links restricted to `erp.omchouse.com/app/`. Device association/assetlinks and cold-start behavior are not verified. INTERNET, coarse/fine location and USE_BIOMETRIC are declared. No push permission implementation.
- **Cleartext/backup:** Main manifest declares `usesCleartextTraffic=true`; debug/profile have network-security config. No main backup/data-extraction rules were found. These are configuration observations requiring release/device assessment, not a proven account compromise. API release guard rejects an HTTP API origin. Absolute authenticated-file requests check same scheme/host/port before attaching the OMC session.
- **Files:** Private business documents/receipts use authenticated byte downloads and backend file/record permission checks. Profile avatar upload intentionally uses public files and unauthenticated image widgets; it is not treated as private document storage. Service/support uploads restrict allowed extensions and 10 MB on the client; service linking validates ownership/content and terminal state. Payment multipart upload has a separate validated/idempotent backend path. Expense receipt is separately broken by F002. Scanner enforcement/deployment and real camera/file-picker behavior remain unverified.
- **Storage/session:** Session cookie/API credentials/biometric credentials use secure storage. Expense records/budgets use local SharedPreferences namespaced by identity, with legacy quarantine; this is real local financial data, not a claim of encrypted financial storage. Physical backup/extraction behavior was not proven. Public branding/catalogue caches are distinct from identity-owned data; session-epoch and support-generation tests passed.
- **Diagnostics/errors:** Release Sentry disables request bodies, default PII, screenshots/replay and several breadcrumbs; reconstructs scrubbed events. Error-classification/redaction tests passed. No committed runtime credential was identified by targeted source/config inspection; this was not an exhaustive binary/history secret audit.
- **Biometrics:** Enrolled biometrics are required; authenticate uses `biometricOnly:true`, not device PIN fallback. Failure returns a recoverable retry/account-switch path; manual password login unlocks runtime session before authenticated UI. Hardware denial/lockout/resume and secure-storage extraction are device-blocked.
- **Maps:** Work-address maps are explicitly disabled by default; manual address remains available. Maps secrets file absent. Billing/key restriction/location permission acceptance not exercised. Google login remains development-only.

## 11. Hardcoded / Fallback / Placeholder / No-op Inventory

| Item | Classification | Evidence / actual effect |
|---|---|---|
| Development localhost API | Safe development-only | Release build-profile validation rejects non-production origin/environment |
| Catalogue asset/sample cases/mock-auth/support preview | Safe development-only | Explicit flags + production startup guard; normal catalogue failure rethrows |
| E2E picker PNG/diagnostic instrumentation | Safe development-only | Development/test switches; not reported as fabricated release documents |
| Static brand/semantic icons/loading skeletons | Intentional | Presentation defaults, not fake business records |
| Expense default categories/local mode | Intentional | Honest local mode; fallback disables sync/receipt/report availability |
| Mobile feature defaults on failed config | Defect | F004 |
| In-app master settings switch | Defect | F003 |
| Tax-alert preference without a producer | Production risk | Saves but active tax-alert delivery not demonstrated; included with settings contract limitation |
| Maintenance/forced update labels | Defect | F005; backend fields exist but app ignores them |
| Account-sync/about/version informational taps | Intentional | Informational actions; version is fetched with package info, not update enforcement |
| Unavailable push source | Defect | F001 given explicit OS-push requirement |
| Tune icon empty callback in non-payment operations branch | Intentional (unreachable retained branch) | Current router only constructs this class for its separate payment branch; excluded from finding counts |
| Auth guest tracking fallback | Intentional | Analytics failure does not fabricate canonical authenticated identity |
| Stale support cache after transient read error | Intentional | Freshness reported; generation guards reject old-session responses; not reused for authorization errors |
| Built-in legal fallback | Production risk | Real fallback text/URL, not externally verified policy publication; no legal adequacy claim |
| “unknown” guest analytics app_version | Intentional | Analytics metadata only; not used as an update check |

No confirmed reachable fake success for service/payment completion was established. F003 is a concrete misleading settings success. Date/status/model fallbacks were scanned, but malformed payload coverage is not exhaustive.

## 12. Commands / Tests Executed

Full raw logs stayed under `/tmp`; this report records results rather than reproducing suite output.

| Command | Result | Relevant count/evidence |
|---|---|---|
| `git status --short`; `git branch --show-current` | PASS | Initially clean; main |
| `git fetch origin main`; `git rev-parse HEAD`; `git rev-parse origin/main` | PASS | Both exact audited SHA |
| `flutter --version`; `java -version`; `flutter doctor -v`; `adb devices` | Executed | Versions in metadata; toolchain healthy; zero Android devices |
| Secret-safe environment/site checks | Executed | Required E2E actor vars absent; site allows tests; no secret values printed |
| `bash scripts/tests/run_e2e_static_checks.sh` | **FAIL: formatting stage** | Shell syntax and Python compilation passed first. Format inspected 319 files; six would change. `--output=none` left source untouched. Later stages did not run through this script. |
| `flutter analyze` | PASS | No issues found, 5.6 seconds |
| `flutter test --reporter=expanded` | PASS | **462 tests**, approximately 14 seconds |
| `bench --site omc-prod.local run-tests --app omc_app --skip-test-records` | **FAILED (errors=7)** | **963 tests / 182.272 seconds**. All seven errors were connection refusal at local Redis 127.0.0.1:13000, not failed application assertions. Bench's process exit alone was not trusted. |
| Temporary localhost Redis 13000, persistence disabled | Started/stopped | Used solely to isolate the failed test modules; owned process terminated afterward; no config files changed |
| `bench --site omc-prod.local run-tests --module omc_app.api.test_assisted_service --skip-test-records` | PASS | **19 tests**, 0.024 seconds |
| `bench --site omc-prod.local run-tests --module omc_app.api.test_guest_session --skip-test-records` | PASS | **6 tests**, 0.347 seconds |
| `flutter test -d linux integration_test/workflow_contract_test.dart` | PASS | **1 test**; Linux debug build. Constructed workflow/route projection, not live-backend E2E |
| `flutter test /tmp/omc_audit_probe_test.dart --reporter=expanded` | PASS as defect probes | **5 tests**: config fallback, settings master round trip, expense multipart fields, expense paging omission, discarded control metadata |
| `python3 /tmp/omc_audit_backend_probe.py` | Defects reproduced | Actual extracted Frappe argument filtering/expense guard and actual settings update/serializer; in-memory stubs, no business mutations |
| Local HTTP ping with `curl --resolve omc-prod.local:8000:127.0.0.1 .../api/method/ping` | Environment-blocked | Connection failed, HTTP 000 |
| Production source/route/API/notification AST and text indexes | Executed | 216 Dart files; 59 GoRoutes; 119 central method constants; 113 direct ApiConfig HTTP call sites checked |
| Secret-safe `keytool -list` using password environment argument | PASS | Local configured keystore/alias usable; no Play certificate comparison |
| `git diff --check`; final `git status --short` | PASS | Only `?? flutter_results.md`; no tracked source/dependency changes |

The full backend command did **not** pass as a single run; the two affected modules subsequently passed. Other suite cases were not repeatedly rerun. Errors were one assisted-service case and six guest-session boundary cases. No full E2E release script was launched because required actors and an Android target were absent, and local HTTP was unavailable. No mutating request was sent to `https://erp.omchouse.com` or another client production environment.

Formatting-only gate failures (not counted as production defects):

- `lib/features/app_config/data/mobile_app_config.dart`
- `lib/features/expense_tracker/data/local_expense_budget_store.dart`
- `lib/features/expense_tracker/presentation/expense_budget_screen.dart`
- `lib/features/expense_tracker/presentation/expense_tracker_screen.dart`
- `lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart`
- `lib/features/service_requests/presentation/service_request_draft_form_sections.dart`

## 13. Environment-Blocked Verification

- Real customer smoke/payment-first journey, internal operations journey, HTTP auth-negative/cross-customer journey: actor credentials absent and local HTTP unavailable. Tests were not pointed at production as a substitute.
- Physical Android: none connected. OS permission denial/permanent denial, notifications when killed, app resume, real picker/camera/share/PDF, maps, biometric lockout and all screen-size/keyboard/back combinations remain open.
- Production push credentials/project configuration and actual provider delivery receipts: external configuration required **in addition to** missing code F001.
- Production Sentry define: absent from current environment; no dummy DSN invented. Release startup and signed AAB acceptance not performed.
- Play Console/upload identity/app-signing certificate/version-code continuity: unavailable; local alias existence is not proof of Play update compatibility.
- Production domain/App Links asset association, email delivery and reset/activation link opening: not externally verified.
- Maps provider key/billing/restrictions: not configured/tested; optional feature defaults off.
- Redis initially blocked seven backend cases; this specific limitation was resolved temporarily for focused reruns. The original whole-suite failure is retained honestly.

Separate from environment blocks, a full manual statement-level review of all 87,667 lines and exhaustive per-action malformed-data/concurrency/visual verification was **not established**. Structural coverage and passing regression suites are narrower evidence. Every active endpoint was indexed, but the full required per-endpoint field/type/error/ownership truth table was not independently exercised. Those remain audit-coverage limits, not environment excuses or fabricated passes.

## 14. Production Blockers in Priority Order

1. **F001:** Real Android OS push is a stated requirement and is missing on both client and server.
2. **F002:** Synced expense receipt upload cannot resolve its target through the active override.
3. Before treating the release as verified, close the actual settings/control/list defects F003–F008 and the outstanding device/release/journey evidence. These are recorded separately from the two P1 implementation blockers; absent credentials are not additional application bugs.

## 15. Verified Pass Areas

- Authoritative-source preflight PASS: clean main matched freshly fetched origin/main at the exact recorded SHA.
- Flutter analysis PASS and executed unit/widget suite PASS (462). This is current evidence, not an older count.
- Auth repository/provider tests PASS for canonical login/session ownership. Failed/Guest canonical verification does not synthesize an authenticated identity.
- Route/capability/More/Quick Actions policy tests PASS within their explicit cases, including negative access and historical customer/internal route behavior.
- Error classification/redaction and selected UI recovery tests PASS; source test counts were not relabeled as visual acceptance.
- Service history/terminal-action widgets and model tests PASS; backend suite exercised lifecycle, pricing, payment, upload, ownership and staff authority areas. No new premature activation/payment completion defect was proven.
- Support generation/cache/session isolation tests PASS; transient stale recovery is explicitly marked, and old-session responses are rejected.
- Focused backend retry modules PASS after resolving local Redis prerequisite; no database metadata or application source fix was used to obtain those results.
- Release signing configuration has no debug-signing fallback; local keystore/alias verified. Production endpoint/environment validation tests PASS.
- Native Linux workflow contract test PASS; this provides no Android or production-provider proof.

## 16. Final Residual Risk

This audit found eight confirmed production-relevant defects, including two P1 blockers. It did not prove zero bugs, full runtime readiness, or all-account/all-device isolation. Structural inspection covered every production Flutter file; selected workflows received deeper code/contract review and executed regression/probe evidence. Backend source was restricted to custom mobile contracts, notification generation, authority and active overrides, with one narrowly required Frappe argument-filter inspection.

Runtime evidence consists of Flutter unit/widget tests, the Linux constructed contract test, local backend regression execution and isolated reruns, plus in-memory defect probes. Android behavior, real app-to-backend journeys, external delivery, signed release launch, and production account/provider configuration remain unproven. Passing source assertions do not fill those gaps.

No application/backend/test source, dependencies, lockfiles, signing configuration or client metadata was changed. No branch/commit/push/PR was created. The only reviewable repository change is this report. Standard test/build tools used their existing ignored build/cache locations; those caches are not offered as audit artifacts. Temporary probes/indexes/logs remained outside the repository, and the temporary Redis instance was stopped.

Final integrity result: `git diff --check` passed; `git status --short` showed exactly `?? flutter_results.md`.
