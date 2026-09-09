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
- Latest Phase 4 implementation code head: `5321c3e0465e5e7c8ea5f408ed38142a87e1fb84`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed scope |
|---|---|---|
| 1 — Design System V2 + shared primitives | **SOURCE COMPLETE** — runtime validation pending | Shared design foundation and primitive migration |
| 2 — Shell/navigation/global UI | **SOURCE COMPLETE** — runtime validation pending | E042, E043, E062–E067, E090 plus shared shell/header work |
| 3 — Customer journey + operations | **SOURCE COMPLETE** — runtime validation pending | **E001–E025** |
| 4 — Customer tools + account/auth | **IN PROGRESS** | **E026–E037 source-complete**; continue with E038 |
| 5 — Internal/staff + final QA closure | PENDING | — |

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
- **E011 Assisted / Operational Request Detail** — `f0614a538c0a58e177af2e36d84150ddfaaace37`. New isolated operations-first owner behind the existing dispatcher; legacy 2,000+ line file remains untouched. Same cancel, upload, document review, reassign, ERP retry and discount-review repository calls/guards remain. Backend lifecycle/next-action evidence leads; payment preparation is distinct from an available payment record; document rejection remarks are visible; historical requests remain read-only.

### Documents

- **E012 Documents list** — `5738915d…`. Same first-page providers, assisted scope, load-more call/dedupe/filter/sort/detail route; readable rows and wrapped filters.
- **E013 Document detail** — final source replay retained in main. Document identity/status → primary file action → details; static timeline placeholder removed; upload and validated external-link policies unchanged.
- **E014 Document preview** — `4801a5f2239072f11acea7cf085165ee36d7eee5`. Supplied PDF/image bytes remain local; full filename, zoom guidance, semantics and safe unsupported/corrupt recovery added.
- **E015 Reviewer workspace** — `a64e3c08…`. Same `canReviewDocuments`, `Approved` / `Rejected`, mandatory rejection remarks, authenticated preview bytes and paging authority.

### Payments

- **E016 Payments list** — `92d49206…`. Exact backend status-to-action mapping retained; no unsafe local sum across formatted/currency values.
- **E017 Payment detail + review** — `2903c628…`. Exact receipt upload/progress/cancellation, authenticated invoice/proof, `Paid` / `Rejected` review payloads and URL whitelist retained. Static payment timeline removed; receipt submission is explicitly unverified until review.

### Tax + knowledge

- **E018 Tax calculator** — `7a9b52ec386ddc5784c4e784bde9a6df46d22f0c`. Same server calculation payload and service-start mutation; tax year → income → filer/refine → calculation → primary annual result → expandable details → CTA. Display currency comes from active backend tax-year config.
- **E019 Tax estimate history** — `11a8e505f65f5e242ccf0f69b00c1cdf2b1ad84d`. Same history source and case-insensitive filters; filters collapsed; source-empty distinct from filter-empty.
- **E020 Knowledge & news** — `4331bc80a9ac1ce6d59acb7a4237ae70c0e52135`. Featured headline + latest feed in backend order; no invented search/category API.
- **E021 Knowledge article** — `8ca0da7abd36e041cec4e4f5e37c3d4ddfa4e44b`. Full headline, 17/1.6 plain reading body, summary fallback, existing `http/https` external-link validation.

### Alerts + support

- **E022 Alerts feed** — source-complete, including visible non-swipe Clear action in `60187f95c7af39383c4e3d3e4107c41f911d55d8`. Paging/read/dismiss/restore/Undo authority unchanged.
- **E023 Alert detail** — `ca98d5ce…`. Auto-read, typed routing and safe URL policy preserved.
- **E024 Support hub** — `599f36a6…`. Staff queue first; approved customer tickets before create; public direct channels first; duplicate-ticket prevention, paging, assign-to-me and WhatsApp ready-message unchanged.
- **E025 Support conversation** — `e5ce61d4…`. 4-second refresh/read acknowledgement, reply/status calls, attachment constraints and retry cache unchanged.

## Phase 4 customer tools / account source completion so far

### E026 Expense Tracker

- V2 presentation created in `d8219848e990362c896c6bbd3866be50df2c2935`; routed in `457a320ebab9b7d6c3a108feaefc5031189c8a63`.
- Existing controller/repository remains authoritative. Session-epoch protections, local/cloud storage mode, bulk sync, cloud `start/month` paging, 100-row continuation, pending-local preservation, export cancellation, JSON import validation, archive/clear behavior, receipt extensions and transaction payload fields remain unchanged.
- Presentation now prioritizes balance/income/expenses → Add transaction → period/category filters → ledger rows → optional summaries → local/cloud status, with data tools in the existing header menu.

### E027 Monthly Budget

- V2 presentation created in `68aa7b146b7fd0fdc9f51190076867bcc82a49ec`; routed in `0ed4d633998987e6774923223822750480a8c2fc`.
- Exact month/category/`limit_amount`/threshold/active payload and local-vs-cloud save authority are retained, along with the same budget/spending providers and invalidations.
- Budget rows now show Spent, Limit, Remaining/Over by, warning threshold and explicit Within budget / Near warning threshold / Over budget text. Progress remains visually clamped while actual over-budget amount stays visible.

### E028 Profile

- V2 presentation created in `d427354476e8a22d202f7fe9f4d4af10e90472fb`; routed in `117eefad2dffadb65ddfb186c5f52837e957663e`.
- Gallery selection remains `1200×1200`, quality `88`; upload remains `uploadProfileImage(filePath, fileName)` with profile refresh. Support remains topic `Profile / account support` through `createSupportTicket`.
- Hierarchy is identity/photo → account state → personal/contact → business/tax or internal access → Manage profile → support. Verified identity values remain display-only on Profile.

### E029 Profile details editor

- V2 presentation created in `f4b88ecf81005ad162f8a15cdc9ce8de61c2c4cf`; routed in `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- Existing payload builders are retained: full name; changed-only phone/WhatsApp/address; changed-only internal education/experience/remarks; protected CNIC/NTN/company single-field payloads.
- Backend `ProfileEditMode` policy remains the authority for Add / Update once / Locked / Unavailable. CNIC 13-digit, NTN 7–9 digit and company-name validation are retained, along with the one-time confirmation and `DirtyFormController` behavior.
- `Env.workAddressMapsEnabled` continues hiding the legacy address editor for non-internal users when the maps workflow owns that field.

### E030 Settings

- V2 presentation created in `da8579e98df3db2992f0237d6436a38f6c261fc5`; routed together with E029 in `fef551a364f30de59e3434e3f2a02e4018b60c00`.
- Hierarchy is Profile → Security → Notifications → Legal → About/version → Account actions. “Profile preferences” is renamed **Profile** while retaining `/profile/edit`. The static “Account sync” explanatory row is removed.
- Notification preference save/retry authority is unchanged; Push preference switch still renders only when `pushProviderOperational`. `PushDeviceSettingsTile` remains the Android device permission/registration owner.
- Biometric disable/enroll, current-password verification, secure enrollment invalidations, legal `http/https` launcher + backend-text fallback, deletion support request and logout/session clearing remain the same functional flows.

### E031–E037 Auth/account entry

- **E031 Change password** — `defe4fc13d85480c7a0e90bcb66284b0ae5f7c10`. Presentation polished only; current/new/confirm validation, `changePassword(...)`, biometric clearing, logout and `/login` transition remain unchanged.
- **E032 Splash / startup** — `f175f259149a51f7d77cc3e75780150cdae957e4`. `checkSession()`, onboarding preference routing, retry behavior and no-minimum-delay startup contract preserved.
- **E033 Onboarding** — `ae1be130c12abbfdf28038f1562c9965649f147c`. Backend slide order/source, fallbacks, completion persistence, retry and `/login` behavior preserved; explicit Page X of Y and reduced-motion presentation added.
- **E034 Login** — `c2fe41d25037d204d85fbf14bda4399370ea2b8d`. Identifier/password, biometric account selection, guest startup, pending/home redirects, activation/forgot/signup/help routes and normalized failure authority unchanged.
- **E035 Signup flow** — presentation commit `d5e9f1d54f32e26a1c7f463efdd00984ed62caf5`; source parity rechecked before closure. Four-step constructor/callback mapping is intact; `roles = ['Customer']` remains authoritative; username normalization/availability, referral validation/consent, exact signup payload, cooldown clamp/resend and `DirtyFormController` remain unchanged. `SignupBottomActions` stacks for narrow/large-text layouts.
- **E036 Forgot password** — `d0454bb7a06a44f5fec7e4c2b045f7d041ac0b89`. Presentation hierarchy now follows identifier → send reset link → neutral check-email result → login. Exact `requestPasswordReset(identifier: _identifierController.text.trim())` call and identifier validation remain unchanged; failure stays inline and success copy remains anti-enumeration-safe.
- **E037 Reset password** — `5321c3e0465e5e7c8ea5f408ed38142a87e1fb84`. `/reset-password` still receives the query token and `/app/reset-password` still preserves query parameters. Exact `resetPassword(token, newPassword, confirmPassword)` repository call and password validation remain unchanged. Missing tokens never show the form; authoritative backend `status == 'invalid_or_expired'` now replaces the form with the new-link recovery state, while validation/network failures keep entered form state. Completed state still returns to login.

## Source-level parity checks performed

- GitHub `main` rechecked before meaningful editing batches; all source changes remained on `main`, no feature branch was created.
- Critical repository calls, provider invalidations, capability gates, route parameters and payload strings were re-read after high-risk customer/document/payment/support/E011 and Phase 4 account changes.
- E011 operational rewrite was staged separately, checked against actual `AuthCapabilities`, `AdminCaseOptions`, `DocumentPickResult`, shared header/state/status constructors, then switched through the small dispatcher atomically.
- E026/E027 use isolated V2 presentations while legacy screens remain untouched; public providers/controllers/storage semantics are reused rather than reimplemented as backend state.
- E029/E030 were staged first and routed together only after their edit/security contracts were mapped.
- E035 was closed only after re-reading `signup_steps.dart` and `signup_screen.dart` on the current main and verifying shared widget constructors, callbacks, validators, form keys, payload fields, username/referral behavior, cooldown and dirty-form authority.
- E036 was re-read after commit; its repository call, identifier validation and neutral success/failure semantics remain unchanged.
- E037 was checked against the actual router, repository and backend reset contract. Only backend `invalid_or_expired` is treated as an invalid-link presentation state; thrown password-validation/network failures do not bypass or discard the form.
- No backend, API schema, provider authority, payment-first lifecycle or ERPNext core file was intentionally changed by these UI batches.

## Validation not yet available in this environment

- Local Flutter/Dart: **NOT RUN — Flutter/Dart toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024px / text scale 1.0–2.0 rendered matrix: **NOT RUN**.
- Android/iOS native picker, biometric and notification device flows: **NOT RUN**.

Source-complete does not mean runtime-validated. Phase 5 must close the final analyze/test/device matrix before the redesign can be called production-validated.

## Exact next batch

1. Continue with **E038 Activate existing account** in exact `ui-ux.md` order.
2. Preserve the registered-email request payload, existing validation, neutral check-email response and login action.
3. Do not introduce automatic login or reinterpret account activation as service/payment activation.
4. Continue updating this ledger only after code commits are authoritative on `main`.
