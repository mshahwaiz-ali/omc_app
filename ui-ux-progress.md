# OMC Flutter UI/UX Implementation Progress

Execution ledger for `ui-ux.md`. GitHub `main` is authoritative.

## Five-phase execution map

The approved blueprint scope is retained in full and executed in exactly five delivery phases:

1. **Design System V2 + shared primitives** — original Phase 1.
2. **App shell, navigation and global UI** — original Phase 2.
3. **Core customer journey + customer operations** — original Phases 3–4.
4. **Customer tools + Profile/Settings/Auth** — original Phases 5–6.
5. **Internal/Staff + accessibility/responsive/final regression closure** — original Phases 7–8.

No E001–E146 surface is removed by this consolidation.

## Current authority

- Baseline main SHA: `bd2c0d2c704b5ceb9ec7fae00cbf2e3746c94f9b`
- Latest Phase 4 implementation code head: `19aa7be3ddd04c52d130ade98d540f755f17e1b9`
- Latest Phase 5 implementation code head: `d67633724f952b787d13bf220f7cc25761e990e8`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed scope |
|---|---|---|
| 1 — Design System V2 + shared primitives | **SOURCE COMPLETE** — runtime validation pending | Shared design foundation and primitive migration |
| 2 — Shell/navigation/global UI | **SOURCE COMPLETE** — runtime validation pending | E042, E043, E062–E067, E090 plus shared shell/header work |
| 3 — Customer journey + operations | **SOURCE COMPLETE** — runtime validation pending | **E001–E025** plus their routed customer/document/payment/support presentation owners |
| 4 — Customer tools + account/auth | **SOURCE COMPLETE** — runtime validation pending | **E026–E041** plus applicable nested/modal/native tickets audited below |
| 5 — Internal/staff + final QA closure | **IN PROGRESS** — runtime validation pending | **E044–E047 source-complete**; next E048. Final analyze/test/device/accessibility closure remains pending |

## Phase 1 source batches

- `5285f62b3f69c9e882d2fe0e49ad274d6700fd7c` — semantic typography, spacing/radius/touch targets, semantic colors, runtime accent contrast roles, form/button contracts.
- `09e582082b9fa526fd2fe0e49ad274d6700fd7c` is not authoritative; the actual second shared batch is `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4` — neutral cards, wrapping info chips, freshness presentation.
- `262b07d69786d5a5bbd826862815bc69cb547399` — long-name reflow, 48px identity controls, adaptive legacy list cards and focused source tests.

## Phase 2 source batches

- `c3b5ac36084a6e42ed3b8023ffa632adbd6e6d35` — bottom navigation and adaptive Quick Actions.
- `a0e13620a64235e596ca56cb7734044e0f08920f` + `f157e0246bf49bac95c2502781f46a183a67457d` — More hierarchy and route-access presentation.
- `50c377b87adfbe0a436e2049522f9eb167471079` — E042 device lock semantics/input blocking.
- `71a4216e0d8df245e2bd2e295370d00011174f64` — E043/E090 readiness/update states.
- `f76831d6af7abd557d9652458e71fed5710ef44d` — route recovery.
- `715137d58151d5fa66ee603365bc87cf18732429` — adaptive shared back/page header.

## Phase 3 — E001–E025 source completion

### Home + dashboard

- **E001 Approved customer Home** — `7ec4b1f11ab0395d546958c9c48239a9d59d25fc`. Current service and required next action lead; summary counts are working links; content failures remain independent.
- **E002 Guest / pending / rejected Home** — `91a3d1337eaeee31acee02a563e9c6d1464fd2cc`. One persona-specific access note, public search/tools/content, concise account CTA; locked callbacks preserved.
- **E003 Internal Home** — `8b8b55ede3bbe65112a6f37869b93cb6e069442d`. Financial hold / activation failure outrank review queues, totals and activity; real capability contract retained.
- **E004 Dashboard variants** — `62a64288e266d996fdf24f95a721c6d9b9f2164a`. Direct route retained; next action → list → secondary summary → activity; failed providers no longer render invented live-looking zeros.

### Catalogue + service request journey

- **E005 Service Catalogue** — `426ab8cf5d5893ae28aecb9402a07ebe95248fad`.
- **E006 Service Detail** — `2ad6114ce65e6a56c29a0f94084b821ae7bec52d`.
- **E007 + E008 Request Draft + Assisted Customer** — `c79f01ea840b4e798ca11c8d6088e62b324bfbd7`.
- **E009 My Services / Requests** — `1c533efa00b22aff1ad595331fbbea99fc810194`.
- **E010 Canonical Customer Request Detail** — `f9ec8afa866f59829423a06a973a661e09f52805`.
- **E011 Assisted / Operational Request Detail** — `f0614a538c0a58e177af2e36d84150ddfaaace37`. Existing cancel, upload, document review, reassign, ERP retry and discount-review repository calls/guards remain authoritative.

### Documents

- **E012 Documents list** — `5738915d…`. Same first-page providers, assisted scope, load-more call/dedupe/filter/sort/detail route; readable rows and wrapped filters.
- **E013 Document detail** — final source replay retained in main. Document identity/status → primary file action → details; static timeline placeholder removed; upload and validated external-link policies unchanged.
- **E014 Document preview** — `4801a5f2239072f11acea7cf085165ee36d7eee5`. Supplied PDF/image bytes remain local; full filename, zoom guidance, semantics and safe unsupported/corrupt recovery added.
- **E015 Reviewer workspace** — `a64e3c08…`. Same `canReviewDocuments`, `Approved` / `Rejected`, mandatory rejection remarks, authenticated preview bytes and paging authority.

### Payments

- **E016 Payments list** — `92d49206…`. Exact backend status-to-action mapping retained; no unsafe local sum across formatted/currency values.
- **E017 Payment detail + review** — `2903c628…`. Exact receipt upload/progress/cancellation, authenticated invoice/proof, `Paid` / `Rejected` review payloads and URL whitelist retained. Receipt submission remains explicitly unverified until review.

### Tax + knowledge

- **E018 Tax calculator** — `7a9b52ec386ddc5784c4e784bde9a6df46d22f0c`. Same server calculation payload and service-start mutation; display currency comes from active backend tax-year config.
- **E019 Tax estimate history** — `11a8e505f65f5e242ccf0f69b00c1cdf2b1ad84d`. Same history source and case-insensitive filters; filters collapsed; source-empty distinct from filter-empty.
- **E020 Knowledge & news** — `4331bc80a9ac1ce6d59acb7a4237ae70c0e52135`. Featured headline + latest feed in backend order; no invented search/category API.
- **E021 Knowledge article** — `8ca0da7abd36e041cec4e4f5e37c3d4ddfa4e44b`. Full headline, 17/1.6 plain reading body, summary fallback and existing `http/https` external-link validation retained.

### Alerts + support

- **E022 Alerts feed** — source-complete, including visible non-swipe Clear action in `60187f95c7af39383c4e3d3e4107c41f911d55d8`. Paging/read/dismiss/restore/Undo authority unchanged.
- **E023 Alert detail** — `ca98d5ce…`. Auto-read, typed routing and safe URL policy preserved.
- **E024 Support hub** — `599f36a6…`. Staff queue first; approved customer tickets before create; public direct channels first; duplicate-ticket prevention, paging, assign-to-me and WhatsApp ready-message unchanged.
- **E025 Support conversation** — `e5ce61d4…`. 4-second refresh/read acknowledgement, reply/status calls, attachment constraints and retry cache unchanged.

## Phase 4 — customer tools / account / auth source completion

### E026 Expense Tracker

- V2 presentation created in `d8219848e990362c896c6bbd3866be50df2c2935`; routed in `457a320ebab9b7d6c3a108feaefc5031189c8a63`.
- Existing controller/repository remains authoritative. Session epoch, local/cloud storage mode, bulk sync, cloud paging, pending-local preservation, export cancellation, JSON import validation, archive/clear behavior, receipt picker and transaction payload remain unchanged.

### E027 Monthly Budget

- V2 presentation created in `68aa7b146b7fd0fdc9f51190076867bcc82a49ec`; routed in `0ed4d633998987e6774923223822750480a8c2fc`.
- Exact month/category/`limit_amount`/threshold/active payload and local-vs-cloud save authority are retained. >100% overspend remains explicit while progress display clamps safely.

### E028 Profile

- V2 presentation created in `d427354476e8a22d202f7fe9f4d4af10e90472fb`; routed in `117eefad2dffadb65ddfb186c5f52837e957663e`.
- Gallery remains 1200×1200 / quality 88; exact `uploadProfileImage(filePath, fileName)` plus profile refresh retained. Verified identity values remain display-only on Profile.

### E029 Profile details editor

- V2 presentation created in `f4b88ecf81005ad162f8a15cdc9ce8de61c2c4cf`; routed in `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- Existing payload builders, changed-only rules, `ProfileEditMode`, CNIC/NTN/company validation, one-time protected-field confirmation and `DirtyFormController` remain authoritative.

### E030 Settings

- V2 presentation created in `da8579e98df3db2992f0237d6436a38f6c261fc5`; routed with E029 in `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- Profile → Security → Notifications → Legal → About → Account actions hierarchy implemented. Push account preference remains separate from Android device permission/registration. Deletion remains a support request and logout remains real session logout.

### E031–E041 Auth/account entry

- **E031 Change password** — `defe4fc13d85480c7a0e90bcb66284b0ae5f7c10`. Validation, `changePassword(...)`, biometric clearing, logout and `/login` transition unchanged.
- **E032 Splash / startup** — `f175f259149a51f7d77cc3e75780150cdae957e4`. `checkSession()`, onboarding preference routing, retry and no-minimum-delay contract preserved.
- **E033 Onboarding** — `ae1be130c12abbfdf28038f1562c9965649f147c`. Backend slides/order/fallback, completion persistence, retry and `/login` preserved.
- **E034 Login** — `c2fe41d25037d204d85fbf14bda4399370ea2b8d`. Identifier/password, biometric stored-account selection, guest startup, pending/home redirects and public recovery/help routes unchanged.
- **E035 Signup flow** — `d5e9f1d54f32e26a1c7f463efdd00984ed62caf5`; constructor/callback/form-key/payload parity rechecked. `roles = ['Customer']`, username/referral/cooldown/DirtyForm authority unchanged.
- **E036 Forgot password** — `d0454bb7a06a44f5fec7e4c2b045f7d041ac0b89`. Exact `requestPasswordReset(identifier: trim)` and neutral anti-enumeration behavior retained.
- **E037 Reset password** — `5321c3e0465e5e7c8ea5f408ed38142a87e1fb84`. Query token aliases and exact reset payload retained; only authoritative `invalid_or_expired` closes the form.
- **E038 Activate existing account** — `d1215605dc12279aaab8f9169896d4a07c0e4e7a`. Exact registered-email request retained; neutral check-email state; no automatic login.
- **E039 Complete customer activation** — `b4f6ecd0ac2d9991efb2bb169e5b7b7b3ac2102d`. Exact activation token/password call retained. Backend `activated`, `invalid_or_expired` and `review_required` outcomes now render distinct account-access states; no service/payment wording drift.
- **E040 Email verification / account completion** — `bd6882de012f8e5739d1af98d3081afd686f67f8`. Read-only token inspection → password only for `awaiting_password` → completion → resulting account state preserved. Retry is only for transient inspection failure, never invalid token bypass.
- **E041 Under review** — `2ae6e666d2d2f7ba8ab627ea61231d35f3f6951a`. `checkSession()` remains approval authority; pending stays, unauthenticated returns to login, authenticated non-pending goes home. No ETA or local approval.

## Phase 4 nested / modal / native E-ticket closure

- **E068 / E069 / E071 Signup substeps** — current shared signup widgets re-read against `signup_screen.dart`; role authority, onboarding mode, field validators, final terms/security behavior and callbacks remain unchanged.
- **E070 Referral/preferences** — `4cc167dedb6c733733a2d2aa79445afeeab7f302`. Restored approved referral → verification → acquisition-source presentation order without changing referral/source callbacks or validation.
- **E072 Pending registration success** — `85801ea98c9c62ad91eba0c2e5cd052353d23417`. Same resend timer, backend cooldown clamp and `resendVerification(email)`; readable status → cooldown → resend → login hierarchy.
- **E081 Tax result/breakdown** — source parity re-read. Currency, tax year, breakdown/comparison/guidance and all amounts remain backend/config-derived; no local tax recalculation introduced.
- **E082 Advanced tax inputs** — source parity re-read. Current advanced fields are optional backend-configured inputs and have no hidden frontend validators; only non-empty selected values are sent. Therefore there is no existing collapsed-field validation failure to auto-expand, and no new validation was invented.
- **E086 Expense cloud history/pending** — cloud paging and pending-local preservation remain separate; cloud failure does not erase local pending entries.
- **E091–E093 Login biometric/help/review support** — existing enrolled-account selection, configured help contacts and under-review support/session authority retained; no login or approval authority moved into presentation.
- **E106 Profile support request** — `42424c502d5907a2266e67c978a46f0311b6c2ff` + follow-up `3ea92575aeffc2dd93aa1ce35fd7bc1264379286`. Exact topic/message support payload retained. Failed submitted message is retained for retry; ordinary sheet cancel does not create/overwrite a draft. Legacy source confirms Contact Support does not opt into profile-snapshot inclusion.
- **E107–E109 Profile edit/confirmation/locked identity** — V2 owner re-read: existing payload builders, Add/Update/Locked policy, confirmation-before-save and non-editable locked state retained.
- **E110–E113 Settings sheets** — biometric password verification/enrollment, deletion-request support flow, logout and validated external-policy/fallback-text behavior remain authoritative and readable.
- **E115–E126 Expense/Budget tools** — data-tools gating, transaction sheet, cancellable account export, import validation, archive, local clear, filters, edit/archive actions, picker/date bounds, budget month actions and exact save payload re-read against routed V2 owners.
- **E118 Backup JSON** — `d32ca19b1bee2148fcdde00764b9651c2294978b`. Selectable backup JSON now uses required monospace 14px presentation; export generation and dialog behavior unchanged.
- **E141 Push-open failure recovery** — `19aa7be3ddd04c52d130ade98d540f755f17e1b9`. Shared overlay now reflows actions at narrow/large text. Owner/binding/ready checks, terminal consume semantics, transient retained Retry and Dismiss clear behavior are unchanged.
- **E142 Android device notification state** — `ede2a1c22ee6704d2ff024beca3d82423a880c65`. Device permission, registration and account preference are visually distinct; exact enable/sync identity guard retained; no delivery promise.
- **E143 Platform notification interaction** — native source re-read. Permission is requested only from explicit Enable, blocked permission opens Android settings, binding guards and foreground notification content remain unchanged.
- **E145 Profile photo picker/upload** — `42424c502d5907a2266e67c978a46f0311b6c2ff`. Added avatar-adjacent persistent busy state while preserving Gallery source, 1200×1200 / quality 88, exact upload mutation, refresh, cancel and existing-image-on-failure behavior.

### Tickets intentionally outside Phase 4

- **E140** is the internal/staff discount-review dialog and belongs to Phase 5.
- **E144** document file selection/validation and **E146** customer document external opening belong to the already-routed document/customer-operation family and remain subject to final Phase 5 regression/runtime closure rather than being reclassified into Phase 4.
- E042/E043 remain Phase 2 source-complete and were not redone.

## Phase 5 — internal/staff source completion in progress

- **E044 Customers directory** — `708348dbfe3a08658a96231eece3a4eda2cc9a31` + pager typing follow-up `7943902f8fcb64e64fd83dc522a8b8a92df1f84a`. Exact `customersResultPageProvider((start, search))`, 300ms debounce, backend `start`/`limit: 50`/trimmed search, server paging, local status filters, current-page-only counts and encoded customer-detail route retained.
- **E045 Customer detail** — `1fecfb153c86e35b53d1ad5bfdde6bb2433e845f`. `customerDetailProvider(customerId)`, scoped ownership, read-only behavior, CNIC/NTN/technical/activity metadata and avatar fallback retained. Missing profile values now render explicitly as `Not added`.
- **E046 Internal workspace** — `0b83057f1567dbb09c51e1c7892bb333187ac6d4`. P0 parity re-check completed. Existing capability-derived focus, summary/case providers, queue totals, ranking helpers, customer/case search handoff, settlement/admin/operations routes and capability gates remain unchanged.
- **E047 Service case queue** — `d67633724f952b787d13bf220f7cc25761e990e8`. P0 source audit and post-commit parity re-check completed. Exact `internalServiceCasePageRepositoryProvider.fetchPage(...)` query, page size 50, 350ms trimmed search debounce, server `status`/`document_status`, load-more paging/dedupe, local primary filters/counts and encoded case-detail route retained. UI now follows Title/count → search + filter summary → customer/service → current operational state → next required action → secondary case/document counts. Loaded primary-filter counts are explicitly identified as loaded-page counts, never global totals. Advanced filter choices/values and apply/reset semantics remain unchanged; sheet now scrolls/stacks safely for narrow/large-text layouts.

## Source-level parity checks performed

- GitHub `main` was rechecked before meaningful editing batches; all source changes remained on `main`, no feature branch or PR was created.
- Critical repository calls, provider invalidations, capability gates, route parameters and payload strings were re-read after high-risk customer/document/payment/support/auth/account changes.
- E035 was closed only after re-reading `signup_steps.dart` and `signup_screen.dart` and verifying constructors, callbacks, validators, form keys, payload fields, username/referral behavior, cooldown and dirty-form authority.
- E037/E039/E040 were checked against actual router/repository/backend token-status contracts before presentation states were changed.
- E070/E072 follow-ups changed presentation only; signup payload/controller authority stayed in `signup_screen.dart`.
- E106 was compared with the legacy Profile support owner; actual Contact Support uses topic/message and does not enable profile-snapshot inclusion. Cancellation parity was restored in the follow-up commit.
- E115–E126 were checked against active routed V2 owners before E118 was changed; only the backup JSON typography changed.
- E141 commit diff confirms intent lookup, `consumeOpen`, owner/binding/cancel checks and retry scheduling logic were untouched.
- E142/E143 were checked together so device registration presentation did not alter native permission behavior.
- E047 was re-read after commit against `internal_service_case_page_repository.dart`, `internal_service_case.dart`, route access, and backend `internal_workspace_read_guard.get_service_cases`; scope authority, query parameters, paging metadata, document filter mapping and route encoding remain authoritative.
- No backend, API schema, provider authority, payment-first lifecycle, ERP authority or ERPNext core file was intentionally changed by Phases 4–5 source modernization to this checkpoint.

## Validation not yet available in this environment

- Local Flutter/Dart: **NOT RUN — Flutter/Dart toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024px / text scale 1.0–2.0 rendered matrix: **NOT RUN**.
- Android/iOS native picker, biometric, push and notification device flows: **NOT RUN**.

**SOURCE COMPLETE does not mean production-validated.** Phase 5 must close analyze/tests, the 320–1024px and 1.0–2.0 text-scale matrix, device/native flows, accessibility and final cross-feature regression before the redesign is called production-validated.

## Exact next batch

1. Continue **Phase 5** with **E048 — Internal payment operations** only, in exact `ui-ux.md` order.
2. Re-check current GitHub `main`, read the exact E048 blueprint row, then read its complete current presentation owner and all repository/provider/query/mutation contracts before editing.
3. Do not begin E049 until E048 is source-audited, source-complete, post-diff parity-checked and safely checkpointed in this ledger.
4. Keep runtime/analyze/test/device/accessibility claims pending until they actually run.
