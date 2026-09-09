# OMC Flutter UI/UX Implementation Progress

Execution ledger for `ui-ux.md`. GitHub `main` is authoritative.

## Five-phase execution map

The approved `ui-ux.md` blueprint is retained in full and executed in exactly five delivery phases:

1. **Design System V2 + shared primitives**
2. **App shell, navigation and global UI**
3. **Core customer journey + customer operations**
4. **Customer tools + Profile / Settings / Auth**
5. **Internal / Staff + nested surfaces + final source regression closure**

No E001–E146 surface was removed by the five-phase consolidation.

## Current authority

- Baseline main SHA: `bd2c0d2c704b5ceb9ec7fae00cbf2e3746c94f9b`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Latest Phase 4 implementation code head: `19aa7be3ddd04c52d130ade98d540f755f17e1b9`
- Latest Phase 5 implementation code head: `1d753fb4bf2ce2218ec2605761f9d89eef70bf8b`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional, navigation, provider, payload, ownership, payment-first lifecycle and ERP authority remain frozen per `ui-ux.md` J1/J2.

## Phase status

| Phase | Status | Completed scope |
|---|---|---|
| 1 — Design System V2 + shared primitives | **SOURCE COMPLETE — runtime validation pending** | Shared typography, spacing, radius, touch targets, color roles, responsive primitives and common states |
| 2 — Shell / navigation / global UI | **SOURCE COMPLETE — runtime validation pending** | E042, E043, E062–E067, E090 plus shared shell/header/navigation work |
| 3 — Customer journey + operations | **SOURCE COMPLETE — runtime validation pending** | E001–E025 plus routed customer/document/payment/support owners |
| 4 — Customer tools + account/auth | **SOURCE COMPLETE — runtime validation pending** | E026–E041 plus applicable nested/modal/native tickets |
| 5 — Internal/staff + final source closure | **SOURCE COMPLETE — runtime validation pending** | E044–E061 primary surfaces plus all remaining nested/shared/native E-tickets and final E001–E146 accounting |

## Phase 1 — Design System V2

- `5285f62b3f69c9e882d2fe0e49ad274d6700fd7c` — semantic typography, spacing/radius/touch targets, semantic colors, runtime accent contrast roles, form/button contracts.
- `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4` — neutral cards, wrapping info chips and freshness presentation.
- `262b07d69786d5a5bbd826862815bc69cb547399` — long-name reflow, 48px identity controls, adaptive legacy list cards and focused source tests.

## Phase 2 — Shell / navigation / global UI

- `c3b5ac36084a6e42ed3b8023ffa632adbd6e6d35` — bottom navigation and adaptive Quick Actions.
- `a0e13620a64235e596ca56cb7734044e0f08920f` + `f157e0246bf49bac95c2502781f46a183a67457d` — More hierarchy and route-access presentation.
- `50c377b87adfbe0a436e2049522f9eb167471079` — E042 device-lock semantics and input blocking.
- `71a4216e0d8df245e2bd2e295370d00011174f64` — E043 / E090 readiness and update states.
- `f76831d6af7abd557d9652458e71fed5710ef44d` — route recovery.
- `715137d58151d5fa66ee603365bc87cf18732429` — adaptive shared back/page header.
- Final Phase 5 re-audit confirmed E062–E067 already meet the blueprint: branch restoration/reselect, dirty guard, safe route recovery, More dismissal, bottom-nav index bindings, adaptive Quick Actions and unsaved-change confirmation remain unchanged.

## Phase 3 — E001–E025 customer journey

### Home / dashboard

- E001 Approved customer Home — `7ec4b1f11ab0395d546958c9c48239a9d59d25fc`
- E002 Guest / pending / rejected Home — `91a3d1337eaeee31acee02a563e9c6d1464fd2cc`
- E003 Internal Home — `8b8b55ede3bbe65112a6f37869b93cb6e069442d`
- E004 Dashboard variants — `62a64288e266d996fdf24f95a721c6d9b9f2164a`

### Catalogue / service requests

- E005 Service Catalogue — `426ab8cf5d5893ae28aecb9402a07ebe95248fad`
- E006 Service Detail — `2ad6114ce65e6a56c29a0f94084b821ae7bec52d`
- E007 + E008 Request Draft / Assisted Customer — `c79f01ea840b4e798ca11c8d6088e62b324bfbd7`
- E009 My Services / Requests — `1c533efa00b22aff1ad595331fbbea99fc810194`
- E010 Canonical Customer Request Detail — `f9ec8afa866f59829423a06a973a661e09f52805`
- E011 Assisted / Operational Request Detail — `f0614a538c0a58e177af2e36d84150ddfaaace37`

### Documents / payments / tax / knowledge / support

- E012 Documents list — `5738915d…`
- E013 Document detail — source replay retained on `main`; static placeholder timeline removed while upload/external-link authority remains unchanged.
- E014 Document preview — `4801a5f2239072f11acea7cf085165ee36d7eee5`
- E015 Reviewer workspace — `a64e3c08…`
- E016 Payments list — `92d49206…`
- E017 Payment detail + review — `2903c628…`
- E018 Tax calculator — `7a9b52ec386ddc5784c4e784bde9a6df46d22f0c`
- E019 Tax estimate history — `11a8e505f65f5e242ccf0f69b00c1cdf2b1ad84d`
- E020 Knowledge & news — `4331bc80a9ac1ce6d59acb7a4237ae70c0e52135`
- E021 Knowledge article — `8ca0da7abd36e041cec4e4f5e37c3d4ddfa4e44b`
- E022 Alerts feed — includes visible Clear action in `60187f95c7af39383c4e3d3e4107c41f911d55d8`
- E023 Alert detail — `ca98d5ce…`
- E024 Support hub — `599f36a6…`
- E025 Support conversation — `e5ce61d4…`

All customer-journey repository calls, assisted/customer ownership scopes, payment-review states, service-request lifecycle authority, paging and route parameters were preserved.

## Phase 4 — E026–E041 customer tools / account / auth

- E026 Expense Tracker — V2 `d8219848e990362c896c6bbd3866be50df2c2935`; routed `457a320ebab9b7d6c3a108feaefc5031189c8a63`.
- E027 Monthly Budget — V2 `68aa7b146b7fd0fdc9f51190076867bcc82a49ec`; routed `0ed4d633998987e6774923223822750480a8c2fc`.
- E028 Profile — V2 `d427354476e8a22d202f7fe9f4d4af10e90472fb`; routed `117eefad2dffadb65ddfb186c5f52837e957663e`.
- E029 Profile details editor — V2 `f4b88ecf81005ad162f8a15cdc9ce8de61c2c4cf`; routed `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- E030 Settings — V2 `da8579e98df3db2992f0237d6436a38f6c261fc5`; routed with E029 in `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- E031 Change password — `defe4fc13d85480c7a0e90bcb66284b0ae5f7c10`
- E032 Splash / startup — `f175f259149a51f7d77cc3e75780150cdae957e4`
- E033 Onboarding — `ae1be130c12abbfdf28038f1562c9965649f147c`
- E034 Login — `c2fe41d25037d204d85fbf14bda4399370ea2b8d`
- E035 Signup flow — `d5e9f1d54f32e26a1c7f463efdd00984ed62caf5`
- E036 Forgot password — `d0454bb7a06a44f5fec7e4c2b045f7d041ac0b89`
- E037 Reset password — `5321c3e0465e5e7c8ea5f408ed38142a87e1fb84`
- E038 Activate existing account — `d1215605dc12279aaab8f9169896d4a07c0e4e7a`
- E039 Complete customer activation — `b4f6ecd0ac2d9991efb2bb169e5b7b7b3ac2102d`
- E040 Email verification / account completion — `bd6882de012f8e5739d1af98d3081afd686f67f8`
- E041 Under review — `2ae6e666d2d2f7ba8ab627ea61231d35f3f6951a`

### Phase 4 nested / modal / native closure

- E068 / E069 / E071 signup substeps — current shared widgets re-read against `signup_screen.dart`; role, field validation, terms/security and callback authority unchanged.
- E070 referral/preferences — `4cc167dedb6c733733a2d2aa79445afeeab7f302`.
- E072 pending registration success — `85801ea98c9c62ad91eba0c2e5cd052353d23417`.
- E081 / E082 tax result + advanced inputs — source-audited; all amounts remain backend/config-derived and no new validation invented.
- E086 expense cloud history/pending — source-audited; cloud failure never erases pending local entries.
- E091–E093 login biometric/help/review support — source-audited; no login/approval authority moved into presentation.
- E106 profile support request — `42424c502d5907a2266e67c978a46f0311b6c2ff` + `3ea92575aeffc2dd93aa1ce35fd7bc1264379286`.
- E107–E109 profile edit/confirmation/locked identity — routed V2 owner re-audited.
- E110–E113 Settings sheets — biometric verification/enrollment, deletion request, logout and external-policy behavior re-audited.
- E115–E126 Expense/Budget tools — routed V2 owners re-audited; E118 backup JSON typography `d32ca19b1bee2148fcdde00764b9651c2294978b`.
- E141 push-open failure recovery — `19aa7be3ddd04c52d130ade98d540f755f17e1b9`.
- E142 Android device notification state — `ede2a1c22ee6704d2ff024beca3d82423a880c65`.
- E143 platform notification interaction — native source re-audited.
- E145 profile photo picker/upload — `42424c502d5907a2266e67c978a46f0311b6c2ff`.

## Phase 5 — E044–E061 internal/staff primary surfaces

- E044 Customers directory — `708348dbfe3a08658a96231eece3a4eda2cc9a31` + `7943902f8fcb64e64fd83dc522a8b8a92df1f84a`
- E045 Customer detail — `1fecfb153c86e35b53d1ad5bfdde6bb2433e845f`
- E046 Internal workspace — `0b83057f1567dbb09c51e1c7892bb333187ac6d4`
- E047 Service case queue — `d67633724f952b787d13bf220f7cc25761e990e8`
- E048 Internal payment operations — `d7f5861d4aade5ebc5465a612c43d3e8c24427e9`
- E049 Internal case workspace — `f9d822b0e6267f23073044e4b2b4da162d1203d5`
- E050 Leads pipeline — `7f51ec59e077ad9b01be5ed852be0995eb0c7a21`
- E051 Lead detail — `76a46aca59f4976335157f2ffdc36931547f8bc7`
- E052 Tasks list — `461f6b068b11011d229b1980b8a04ba419284461`
- E053 Task detail — `ec8ffc0120613bf2831309bdbc398f1903161415`
- E054 My referrals — `9e1c859564131ad3d92457f170c820768028b4ee`
- E055 Referral detail — `8d583c3c999d3dc303edb2d0f6b64f9a6f6c1fb6`
- E056 My commissions — `fd0af842d2adb4449d9574f3e98e79ae78234bc3`
- E057 Commission detail — `20fcc79ab25917b8f499189b92b99e0c502e3170`
- E058 Commission operations — `1f588e6992269ca81f617b3d72ee3ada8f35b3a0`
- E059 Settlement exceptions — `706e4d4cb54f630bed820a44724c57c2b1b997b2`
- E060 Administration — `d0340d961f65157791a595d8e8e62264e982a5c8`
- E061 Operational controls — `8bd889fef2c70f3e2230b72157b85f4851e3b260`

### Phase 5 final nested / shared / native closure

- E073 Dynamic service fields — source-audited in `service_request_draft_form_sections.dart`; backend field names/types/validators/callbacks remain authoritative.
- E074 Discount input — source-audited in `service_request_draft_service_sections.dart`; percentage/fixed validation, reason and non-authoritative preview unchanged.
- E075 Request submit bar — source-audited; narrow/large-text stacking and exact submit locking retained.
- E076 Required-document rows — source-audited; requirement/status/rejection/upload authority unchanged.
- E077–E080 Payment/support nested surfaces — source-audited through their already-complete routed parent owners.
- E083 Home content rail — `694c6304c5f1a3643ce27b2bc888d110c4d3b382`. Readable metadata/body, adaptive rail/card sizing, image fallback and semantics added; item order/callback unchanged.
- E084 Home featured carousel — `e8875d234e6bde22961d90718bf6fded850655cb`. Adaptive banner height, readable headline/summary/CTA, image fallback, semantics and reduced-motion-aware indicator added; banner action authority unchanged.
- E085 Home service autocomplete — source-audited; keyboard/tap resolve the same `ServiceItem.id`, free text retains trimmed services query.
- E087 Stale-data banner — source-audited; timestamp/retry remain real and duplicate Retry is disabled.
- E088 Error state — source-audited; retryability remains classifier-driven.
- E089 Loading skeletons — source-audited; reduced-motion mode is static and skeletons are excluded from semantics.
- E094 Guest protected-action sheet — `1d753fb4bf2ce2218ec2605761f9d89eef70bf8b`. Scrollable large-text-safe sheet, 56px signup CTA and 48px sign-in target; guest-only gating and exact `/signup` / `/login` destinations unchanged.
- E095 Service-category filter — source-audited; exact category values and clear behavior unchanged.
- E096 Existing active requests sheet — source-audited; duplicate check, resume exact case and start-new behavior unchanged.
- E097 / E098 My Services sort/filter sheets — source-audited; local sort/filter/reset semantics unchanged.
- E099 Customer cancellation confirmation — source-audited; cancellation eligibility, exact ID, mutation and invalidations unchanged.
- E100–E103 Assisted/internal service-case dialogs and required-document upload — source-audited against the **actual routed owner** `operational_service_case_detail_screen.dart`. `service_case_detail_screen.dart` routes assisted/internal/non-canonical variants there; `service_case_detail_legacy_screen.dart` is historical safety reference only. Eligible-only reassignment, required discount rejection remarks, confirm-only cancellation, picker validation, upload mapping and dirty-form authority remain unchanged.
- E104 Document rejection — source-audited; required reason and exact selected-document status mutation retained.
- E105 Payment approval/rejection — source-audited; exact `Paid` / `Rejected` states and required rejection remarks retained.
- E114 Support ticket status sheet — source-audited; same permitted status values and mutation retained.
- E127 Advanced case filters — inherited from E047; server/local filter authority retained.
- E128 Task priority filter — inherited from E052; backend priority query retained.
- E129 Create lead sheet — inherited from E050; exact create fields, idempotency and dirty-form authority retained.
- E130–E133 Commission confirmations/reason/settlement/date — inherited from E058; approve/payable/paid remain distinct mutations and settlement reference/date preserved.
- E134 Settlement review confirmation — inherited from E059; resolve/ignore remain review dispositions only with required note.
- E135–E137 Admin staff/settings dialogs — inherited from E060; existing-staff-only grant, backend role list and settings payload retained.
- E138–E140 Operational reassignment/sync/discount dialogs — inherited from E061; eligible candidate query, explicit sync retry, discount decision and required reject remarks retained.
- E144 Document file selection/validation — source-audited; cancel is non-error, allowed picker types/MIME checks, 10MB limit, duplicate/max-file rules and path-or-bytes attachment shape unchanged.
- E146 Customer document external opening — source-audited; only valid `http` / `https` or rooted backend-relative paths are resolved, external application mode retained and invalid/unopenable links fail safely.

## P0 / high-risk parity checks completed

- E046 internal workspace: capability-derived focus, summary/case providers and routes unchanged.
- E047 service case queue: exact page size/search debounce/server filters/load-more/dedupe/local filter-count semantics and encoded detail route unchanged.
- E048 internal payments: exact `PaymentPageQuery`, backend status mapping, page arithmetic and payment-detail route unchanged.
- E049 internal case workspace: same `internalServiceCasesProvider`, exact case-ID lookup and existing routes; no invented detail endpoint.
- E050 leads: same backend search/paging, local stage filter, create-on-load behavior, create fields and encoded detail route.
- E051 lead detail: provider/detail authority unchanged; presentation remains read-only and no follow-up/conversion mutation was invented.
- E052 tasks: backend search/status/priority/page size 50, generation guard, dedupe and load-more failure retention unchanged.
- E053 task detail: read-only authority retained; linked case still requires capability + task-level access + non-empty reference.
- E054 referrals: code copy/share, active-code rule, server search and 20-row paging unchanged.
- E055 referral detail: assisted service still passes exact `assisted=1`, encoded customer profile/name and remains consent-gated.
- E056 / E057 own commissions: currency grouping, filters/paging, session-epoch detail fetch and accounting evidence unchanged.
- E058 commission operations: `approve`, `reject`, `markPayable`, `markPaid` repository calls, required reject reason and settlement reference/date unchanged.
- E059 settlement exceptions: exact query/pager, allowed-action gates and `resolve` / `ignore` + note payload unchanged; UI never claims payment repair/settlement.
- E060 Administration: registration review, existing-staff grant/update and business settings remain separate backend contracts; available roles remain backend-derived.
- E061 Operational controls: capability-derived queues, 20-row server paging/search, case-options fetch before mutation, eligible-assignee-only reassignment, explicit sync retry, discount approve/reject, required rejection remarks, busy locking and administrative invalidation unchanged.
- E083 / E084: post-commit diffs are presentation-only; content/banner callbacks and backend order are unchanged.
- E094: post-commit diff is presentation-only; guest-only predicate and signup/login routes are unchanged.
- E100–E103: routed-owner audit prevented dead legacy UI from being mistaken for runtime authority.

## Complete E001–E146 source accounting

Every blueprint ticket is now attached to an implementation commit or an explicit audit of its current routed owner:

- E001–E041 — Phases 3–4 complete.
- E042–E043 — Phase 2 complete.
- E044–E061 — Phase 5 complete.
- E062–E067 — Phase 2 complete and re-audited in Phase 5.
- E068–E072 — Phase 4 complete.
- E073–E080 — Phase 5 source-audited.
- E081–E082 — Phase 4 complete.
- E083–E085 — Phase 5 complete.
- E086 — Phase 4 complete.
- E087–E089 — Phase 5 source-audited.
- E090 — Phase 2 complete.
- E091–E093 — Phase 4 complete.
- E094–E105 — Phase 5 complete/source-audited.
- E106–E126 — Phase 4 complete.
- E127–E140 — Phase 5 complete through their authoritative parent flows.
- E141–E143 — Phase 4 complete.
- E144 — Phase 5 source-audited.
- E145 — Phase 4 complete.
- E146 — Phase 5 source-audited.

**Full ui-ux.md source scope E001–E146: COMPLETE. Runtime validation remains pending.**

## Authority / scope guarantees after source modernization

- No backend endpoint or API schema was intentionally changed by the UI/UX modernization.
- No ERPNext core source was intentionally changed.
- No payment-first lifecycle or accounting authority was moved into Flutter presentation.
- No capability was broadened by UI visibility.
- No local UI count was relabeled as a global backend total.
- No placeholder timeline/action was presented as real backend activity or mutation authority.
- No assisted-customer context was dropped from supported routes/mutations.
- No destructive action bypasses its existing confirmation/validation contract.

## Runtime validation status

The source scope is complete, but production validation is **not** complete until the following actually run:

- Local Flutter/Dart toolchain: **NOT RUN in this execution environment**.
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024px / text scale 1.0–2.0 rendered matrix: **NOT RUN**.
- Android/iOS native picker, biometric, push and notification device flows: **NOT RUN**.
- Final accessibility/focus/semantics and cross-feature device regression: **NOT RUN**.

**SOURCE COMPLETE does not mean production-validated.** Do not call the redesign production-validated until all runtime checks above pass.

## Exact next batch

1. Run `flutter analyze` from the authoritative Flutter project.
2. Run the Flutter test suite and focused UI/authority regressions.
3. Execute the 320–1024px / 1.0–2.0 text-scale rendered matrix.
4. Validate Android/iOS native picker, biometric, push and notification flows on real/supported devices.
5. Complete accessibility/focus/semantics and final cross-feature regression.
6. Only after those pass, mark the five-phase UI/UX modernization **production validated**.
