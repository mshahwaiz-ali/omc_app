# OMC Flutter UI/UX Implementation Progress

Execution ledger for `ui-ux.md`. GitHub `main` is authoritative.

## Five-phase execution map

The approved blueprint scope is retained in full, but the original implementation phases are consolidated into exactly five delivery phases:

1. **Design System V2 + shared primitives** — original Phase 1.
2. **App shell, navigation and global UI** — original Phase 2.
3. **Core customer journey + customer operations** — original Phases 3–4.
4. **Customer tools + Profile/Settings/Auth** — original Phases 5–6.
5. **Internal/Staff + accessibility/responsive/final regression closure** — original Phases 7–8.

No E001–E146 surface is removed by this consolidation.

## Current authority

- Baseline main SHA: `bd2c0d2c704b5ceb9ec7fae00cbf2e3746c94f9b`
- Current implementation head being assembled: `40db6ff4c0aa365cbd92f235c0e4bdc47078946d`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed E IDs / groups |
|---|---|---|
| 1 — Design System V2 + shared primitives | COMPLETE — source implementation; Flutter runtime validation pending | Shared foundation complete; no E ticket marked complete solely from theme/component work |
| 2 — Shell/navigation/global UI | COMPLETE — source implementation; Flutter/runtime/U validation pending | E042, E043, E062, E063, E064, E065, E066, E067 and E090 source-complete; runtime/device acceptance still pending |
| 3 — Customer journey + operations | IN PROGRESS | E005–E010, E013–E014 source-complete; E011 remains open due giant-file atomic-edit boundary; continuing documents/payments |
| 4 — Customer tools + account/auth | PENDING | — |
| 5 — Internal/staff + final QA closure | PENDING | — |

## Completed Phase 1 batches

### Foundation — `5285f62b3f69c9e882d2fe0e49ad274d6700fd7c`
Implemented C1–C5/C7 foundation: semantic typography, spacing/radius/touch targets, neutral + semantic colors, preserved runtime accent with derived `accentInk`/`accentFocus`, calmer surfaces, readable forms/actions, stable loading labels, and large-text component contracts.

### Shared surfaces — `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4`
Implemented neutral bordered cards, wrapping info chips, and readable stale-data/retry presentation while preserving source/timestamp/retry authority.

### Shared closure — `262b07d69786d5a5bbd826862815bc69cb547399`
Implemented long-name reflow, 48px identity controls, adaptive legacy list cards and focused 320px/2x source tests.

## Completed Phase 2 batches

### Shell actions — `c3b5ac36084a6e42ed3b8023ffa632adbd6e6d35`
Implemented content-driven bottom navigation with 12px labels and adaptive Quick Actions while preserving capability order and callbacks.

### More navigation — `a0e13620a64235e596ca56cb7734044e0f08920f` + `f157e0246bf49bac95c2502781f46a183a67457d`
Implemented customer More hierarchy with Tax calculator, Knowledge & news, Tools & help and neutral rows while retaining capability predicates.

### Device lock presentation — `50c377b87adfbe0a436e2049522f9eb167471079`
E042 source-complete. Router remains mounted while lock blocks pointer/focus/semantics/animations.

### Readiness/update presentation — `71a4216e0d8df245e2bd2e295370d00011174f64`
E043/E090 source-complete. Retry, maintenance/update policy, dismissal and saved-form behavior unchanged.

### Global recovery — `f76831d6af7abd557d9652458e71fed5710ef44d` + `f157e0246bf49bac95c2502781f46a183a67457d`
E066/E067 source-complete. Safe route recovery and Stay/Discard dirty-form contract preserved.

### Adaptive shared page header — `715137d58151d5fa66ee603365bc87cf18732429`
Header title/supporting text wraps and preferred size adapts to native text scaling while preserving navigation authority.

## Phase 3 completed customer journey batches

### E005 Service Catalogue — `426ab8cf5d5893ae28aecb9402a07ebe95248fad`
Responsive 2-column/list presentation, readable search/filter controls and assisted context; query/category/page provider authority unchanged.

### E006 Service Detail — `2ad6114ce65e6a56c29a0f94084b821ae7bec52d`
Service-first hierarchy with readable price/time/requirements/process/support and one dominant Start action; duplicate-active-request handling and role routing unchanged.

### E007 + E008 Request Draft + Assisted Customer — `c79f01ea840b4e798ca11c8d6088e62b324bfbd7`
One-form architecture retained. Exact `ServiceRequestPayload`, `attachments: const []`, assisted-customer fields, discount validation, MutationIntent/idempotency, dirty-form retention and submit navigation remain unchanged.

### E009 My Services / Requests — `1c533efa00b22aff1ad595331fbbea99fc810194`
Readable request cards prioritize service → status → next step → date/reference/action. Search corpus, filters, sorting, state derivation and assisted route parameters unchanged.

### E010 Canonical Customer Request Detail — `f9ec8afa866f59829423a06a973a661e09f52805`
Backend-authoritative next action now leads lifecycle. Required-document upload call/identity, payment routing and cancellation invalidations remain unchanged.

### E011 Assisted / Operational Request Detail — OPEN
The current fallback implementation is a 2,000+ line operational screen containing customer evidence plus privileged mutation owners. The connected GitHub editor supports full-file replacement rather than line patching; to avoid truncating or accidentally altering capability/historical/admin mutation rules, E011 has not been falsely marked complete. It will be migrated only at an atomic safe boundary.

### E014 Document Preview — `4801a5f2239072f11acea7cf085165ee36d7eee5`
Full file identity, zoom/pan guidance, viewer semantics and unsupported/corrupt recovery added. `PdfViewer.data(bytes, sourceName: fileName)`, local image bytes and no-unsafe-URL-fallback behavior preserved.

### E013 Document Detail — `40db6ff4c0aa365cbd92f235c0e4bdc47078946d`
Reordered to document identity/status → primary file action → details. Removed the static `_DocumentTimelinePlaceholder`; removed decorative gradient/three-equal-stat competition; assisted customer context now appears when provided. Exact document providers, attachment picker, `uploadDocumentAttachments`, `invalidateDocumentMutation`, and validated `http/https` external-link policy are preserved.

## Validation actually run

- GitHub `main` rechecked before editing batches; no unexpected concurrent source change was present.
- Changed source and representative callers were re-read after commits where available.
- Local Flutter/Dart: **NOT RUN — Flutter toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024 / 1.0–2.0 rendered matrix: **NOT RUN**.
- Biometric hardware/device flow: **NOT RUN**.

## Exact next batch

1. Fast-forward the E013 replay commit on top of the latest ledger head without force-push.
2. Continue E012 Documents list and E015 review workspace where edit boundaries are safe.
3. Move into E016–E017 Payments list/detail with exact status-to-action and review payload parity.
4. Return to E011 only through a safe atomic migration boundary; do not weaken historical/capability/admin mutation safeguards.