# OMC Mobile UI/UX Audit & Redesign Blueprint

**Status: Phase 0 design proposal; implementation requires explicit approval.** Only this document is delivered. No Flutter/backend code, API, provider, permission, route, payload, commit or push is part of this phase.

Source baseline: `mshahwaiz-ali/omc_app`, GitHub `main`, commit `b42ed754fdb58dcd672497ba2e2e612658e1b882`. On 2026-09-09, `git ls-remote origin refs/heads/main` matched local `git rev-parse HEAD`; branch was `main` and the working tree was clean. All application findings below refer to that immutable snapshot, not old screenshots or remembered implementations. Recompare main before implementation if it advances.

Evidence labels: **Observed** means present in source; **Risk** is a source-derived layout/interaction concern requiring rendered verification; **Proposed** is the future visual contract. This is a source audit, not a claim that every runtime state has been exercised. No Flutter analyze, Flutter tests, emulator, screenshot, hardware biometric, push-delivery or live backend suite was run in this documentation phase. The user's backend-suite status is a supplied constraint, not independently revalidated here.

Read in order: [Design System V2](#c-omc-mobile-design-system-v2--define-before-screen-changes), [Executive summary](#a-executive-summary), [route inventory](#b1-inventory-method-and-route-closure), [surface index](#b5-surface-audit-index), [navigation](#d-information-architecture-review), [migration map](#f-shared-component-migration-map), [old-to-new decisions](#g-old--new-decisions), [phases](#h-implementation-phases-and-review-gates), [QA](#i-regression--qa-plan), [frozen contracts/logic exceptions](#j-frozen-contracts-absence-findings-and-proposed-small-logic-adjustments). Section C intentionally comes first so the design system is defined before any screen proposal.

## C. OMC Mobile Design System V2 — define before screen changes

These exact defaults are the implementation proposal. Do not independently invent another screen scale. Flutter dimensions below are logical pixels; text sizes are the unscaled baseline and inherit the OS TextScaler. No application zoom preference.

### C1. Typography

Use the existing platform font family; do not add a font dependency in this phase. Establish the following semantic styles through one explicit `TextTheme` plus a small extension only for reading/financial roles that do not map naturally. Keep inherited text scaling. Titles use normal tracking (0); no global negative tracking or uppercase micro-labels.

| Token | Size | Weight | Height | Intended usage / theme mapping |
|---|---:|---:|---:|---|
| hero | 30 | 700 | 1.15 | One major Home/auth headline; headlineLarge |
| page | 26 | 700 | 1.20 | Standard page title; headlineMedium |
| section | 21 | 600 | 1.25 | Major section; titleLarge |
| title | 17 | 600 | 1.30 | List/card primary title; titleMedium |
| body | 16 | 400 | 1.45 | Primary explanatory copy; bodyLarge |
| supporting | 15 | 400 | 1.40 | Supporting copy; bodyMedium |
| fieldLabel | 15 | 500 | 1.35 | Persistent form label; labelLarge with explicit field role |
| input | 16 | 400 | 1.40 | User-entered value, including dropdown selection |
| button | 16 | 600 | 1.25 | Main/secondary action labels |
| navigation | 12 | 600 selected / 500 otherwise | 1.20 | Bottom destinations only |
| caption | 13 | 400 | 1.35 | Non-critical time/reference metadata; bodySmall |
| status | 14 | 500 | 1.30 | Meaningful workflow status, never caption-sized |
| helper/error | 14 | 400 / 500 | 1.40 | Input hint/help/error; error also has icon/text |
| reading | 17 | 400 | 1.60 | Article body; max reading width 680 |
| readingTitle | 28 | 700 | 1.20 | Full article heading, no ellipsis |
| amount | 28 | 700 | 1.20 | Main financial value with currency |
| amountSecondary | 20 | 600 | 1.25 | Secondary financial total |
| badgeCount | 11 | 600 | 1.20 | Exceptional numeric count only, full semantics |

Populate all used TextTheme slots so unused Material defaults cannot reintroduce a separate hierarchy. Routine w800/w900 becomes 600 or 700 according to role. A status, rejection reason, field label, or next action is meaningful information and cannot use badgeCount/navigation just to fit. No FittedBox, text-scale override or ellipsis for important values to “fix” overflow. List previews may truncate optional summaries at normal scale only when the full text exists in an obvious detail destination. Request instructions, amount/currency, names needed to disambiguate records, article headings and critical errors must remain fully available visually. At large text expand/reflow, not just expose a hidden semantics label.

### C2. Spacing, density and adaptive sizing

Retain `AppSpacing` values 4/8/12/16/20/24/32. Standard primary page inset is 20 at 360–430px; 16 at 320px; 24 at >=600px. Body maximum width 840 for general pages, 560 for forms, 680 for reading; centered at larger widths. Wider existing staff grids may use available width only with the same readable row minimums. No new master-detail routing or navigation rail is necessary. AppBackHeader currently declares preferredSize84/104 at app_back_header.dart:28; enlarged content cannot exceed an unchanged preferred height. During migration compute a sufficient header height from constraints/TextScaler, or place the wrapping page title below a standard toolbar. Test both header variants, including subtitles and trailing actions.

| Role | Exact proposed rule |
|---|---|
| Compact / normal / major section gap | 16 / 24 / 32 |
| Card padding | 20 normal; 16 compact staff/list group |
| List row padding | 16 horizontal, 14 vertical; min-height 64, grows with content |
| Simple settings/action row | min-height 56; 16 horizontal, 12 vertical |
| Icon/text gap | 12; 8 only inside a compact labeled control |
| Label/control and control/helper | 8 and 6 |
| Field-to-field / form section gap | 20 / 28 |
| Bottom content space | 24 + effective bottom safe inset when no bar; otherwise actual bar height + 16, never assumed 104 |
| Sticky CTA | 16 horizontal/12 vertical + bottom safe inset; measure content; keyboard inset applied once |
| Inline action separation | >=8; destructive versus affirmative >=12 |

All heights for text-bearing containers are minimums, not fixed maximums. Prefer vertical lists to nested cards. Main scroll remains reachable with keyboard shown. Use `LayoutBuilder` on actual content constraints; do not infer phone/tablet from device type. A two-column tile grid is allowed only when each tile has >=144 usable outer width at normal text. At content width <300 or effective text scale >=1.5, use one-column icon/title/action rows. At >=600 content width and scale <1.3, a three-column catalogue/action layout is allowed if each item gets >=176 width. Never reproduce the existing automatic 4/5/6 phone-like tile density at large widths. Tile height grows to fit title; use row-based Wrap or a measured grid extent, not a guessed aspect ratio. Service titles use title17, max three lines only where a separate list fallback exposes the full title. Quick Action labels use button16 and must fit fully.

### C3. Color and runtime brand

Keep neutral foundation: background `#F7F8FB`, surface `#FFFFFF`, tonal surface `#F8FAFC`, primary text `#0F172A`, secondary text `#475569`, caption `#64748B`, decorative divider `#E5EAF2`. Meaningful control outline `#64748B`; decorative borders are not sufficient as the sole field boundary/focus cue. Default light mode remains: `app.dart` currently sets `ThemeMode.light`. The existence of `darkTheme`/`ThemeController` does not establish a reachable dark-mode setting. Do not add or activate dark mode as this redesign's side effect.

Preserve `mobileAppConfigProvider → branding.accentColor → OmcAppColors.resolve → _withAccentTheme`, including six-digit parsing, fallback and computed black/white onAccent. Use the runtime accent for CTA fills, selected states, focus and active progress. Use onAccent for text/icons on accent fill. For accent text on white/soft surfaces, measure contrast independently: onAccent selection alone does not ensure that accent-on-white is readable. Proposed UI-only derived `accentInk`/`accentFocus` tones may darken the configured hue to meet contrast; do not replace the configured value or backend contract. Keep original accent fill. Test invalid hex, near-white, near-black, yellow, blue and red. Selected state also has icon/check/weight, so brand color matching a semantic color cannot hide meaning.

| Semantic role | Ink | Background | Communication |
|---|---|---|---|
| Success / verified | #166534 | #F0FDF4 | Check icon + exact state label |
| Warning / action needed | #92400E | #FFFBEB | Attention icon + specific next action |
| Error / destructive | #B91C1C | #FEF2F2 | Error icon + explanation/recovery |
| Information | #1D4ED8 | #EFF6FF | Info icon + message |
| Processing / review | #475569 | #F1F5F9 | Clock/progress icon + status |
| Closed / historical / cancelled | #475569 | #F1F5F9 | Exact terminal label; red only if actual error/destructive action |

These are proposed pairs, subject to measured normal-text >=4.5:1 and meaningful non-text indicators >=3:1. Do not change lifecycle/status enums to fit this table. An uploaded receipt is not verified payment; an uploaded document is not approved; human reconciliation review is not settlement. Keep all backend status distinctions.

Module colors currently defined for Services/Documents/Payments/Tax/Track/Leads/Tasks are recognition decoration, not authority. Proposed: neutral icons for default module destinations, runtime accent for selected/primary interactions, semantic colors only for actual state. Keep module icon identity. A subtle module tint may remain in a single catalogue illustration if it is not used as state. No saturated rainbow More menu, no multicolor financial totals, no gradient/glass/shadow-heavy replacement.

### C4. Surfaces, radius and icons

Use four surface purposes: plain page section (no card), divided list group, bounded interactive card, semantic notice. Remove inner rounded rectangles where indentation/divider expresses grouping. Cards use a 1px decorative border and zero shadow. Only modal elevation or a sticky CTA separation may use black 6% blur12 offset(0,4); avoid stacking shadows. Do not label a non-interactive information group as a button.

Radius family: controls/icon containers12; cards16; sheets24 top corners; pills999 only for compact status/filter shapes. Dialogs20. Avatar remains circular. Remove arithmetic `card + 2` and independent 14/15/18/20/22/28 variants during each component migration; do not globally replace numeric literals without checking intent.

Icons: keep Material icon family, outlined for navigation and ordinary action, filled only for selected or semantic emphasis. Glyph24 normally,20 inline; decorative hero32 maximum except existing brand artwork/media. Icon-only controls have >=48x48 hit area, not just a large glyph. Standard neutral icon container40x40/radius12 is non-interactive; if tappable wrap with >=48 target. No extra background for every inline icon. Decorative icons excluded from semantics; functional icon has tooltip/name. Use 8+ spacing between controls.

### C5. Buttons and form standard

Primary: runtime accent fill, onAccent, button16/600, min-height56, radius12, horizontal20. Secondary: surface/outline with accentInk, min-height52, same text token. Tertiary: text-only accentInk, min48 hit target. Destructive: semantic error fill/ink pair and explicit verb; never reuse a generic Continue for deletion/rejection. Icon button: 48 square minimum, icon24. Compact action: visual text14/500 but hit target48; never use on the screen's main CTA. One visually dominant action per decision area. Loading preserves prior width, maintains action label plus compact progress indicator when space allows, and announces busy. No replacing label with an unlabeled spinner that makes a dialog shrink.

All single-line fields: min-height56, radius12, input16. Persistent label above control at15; do not also show the same floating label redundantly. Hint is a format/example at14, not a substitute for label. Helper/error below at14/1.4, unlimited lines. Required marker explained once and included in semantics. Focus border2 with contrast-safe runtime accent; enabled outline1; error border2 with icon/message. Disabled values remain legible and explain why when relevant. Read-only values use text row + lock when necessary, without looking like editable controls.

Select/dropdown: same field size; full selected label wraps or expands; options min48/row title16. Dates use current picker only where already implemented; preserve allowed range/timezone/serialization. Currency input shows actual currency independently of placeholder, keeps existing parser/decimal rules. Multiline begins at three lines and grows/scrolls with keyboard; never constrain error text within field height. Switch/radio/checkbox row min56 and entire label target where consistent with existing callback. Upload control shows requirement, filename/type constraints from existing policy, progress, cancellation where supported, error and retry. OS file/media/biometric chooser styling is platform-owned: audit launch/cancel/result UI, do not invent a custom security prompt.

Validation on submit must keep data, show existing field error, and (if approved as small frontend behavior work) focus/scroll to first invalid field. Do not silently reset async dynamic fields when reorganizing form sections. Preserve UnsavedChangesGuard, MutationIntent/idempotency, disabled-in-flight controls and success invalidation.

### C6. Sheets, dialogs, navigation, feedback and motion

BottomSheetFrame: radius24, native handle, title21/600, body16, horizontal20, section24; `useSafeArea:true`; content scrollable up to 90% available height. With keyboard, consume viewInsets once, allow maximum remaining height and ensure primary action reachable. Bottom padding16 + safe inset. Form sheets: heading remains visible if feasible, scroll content, persistent action row min56; at 320px/2x stack actions vertically. More may retain an 82% maximum if all rows remain reachable; ordinary action sheets use content-fit height. Dialog width min(available minus32,480), radius20, padding24, title21, body16. Overflowing review/role dialogs scroll; buttons wrap/stack. Preserve original barrier/back/cancel rules, especially dirty forms and export progress.

Bottom bar: retain source index bindings and visual order Home / Services / central action / Requests (internal label variant retained) / More. Navigation label12; icon24; min48 per target; content-driven minimum72 height plus safe inset. Measure the longest two-line label at TextScaler; grow bar rather than clamp. At 320px/2x allow up to three text lines with a taller bar; central action can use a short visible label while full semantics says Quick actions. Do not add a route for the central action. Both shell implementations use the same bar and sheets. Draft form remains outside ShellNavScaffold.

Feedback: use inline error near failed form/review, snackbar for transient success/undo, persistent freshness warning beside cached data. Never show empty-success wording for unavailable data. Read/unread/severity include text/icon/weight, not just tint. Refresh keeps current content only when provider already supports it; do not introduce caching or retry policy under a style change.

Motion: keep AppMotion quick180ms/standard240ms; small state/expand/fade only. Loading pulse900ms only when existing work requires progress. `disableAnimations` makes transition zero and skeleton static. No decorative parallax, auto-scrolling focus or delayed CTA. New carousel auto-advance is not proposed. Respect accessibleNavigation for feedback timing; retain notification undo window until separately reviewed.

### C7. Accessibility and universal acceptance contract U

**U applies to every E table, modal, inline control and applicable state.** Test widths320/360/390/430/768/1024 at 1.0/1.3/1.5/2.0 text scale, including 320x568 and landscape/short-height keyboard. Also test platform nonlinear text scaling on actual devices. No important clipped text, RenderFlex overflow, hidden CTA or inaccessible last row. Test 80-character customer/company/service names, 200-character titles, long email/IDs, multiline rejection reasons and large amounts with currency; supported copy expansion/RTL where applicable without inventing translation support.

Hit targets >=48; focus order follows visual order; titles announced as headings; tappable rows as buttons only when interactive. Maintain separate accessible children when a card has multiple actions: do not use excludeSemantics on an entire card and erase its buttons. Announce upload/error/success once. Modal focus returns to opener. Locked/readiness overlay prevents underlying focus, semantics and input without dismantling the router. Contrast measured across configured accents and all state backgrounds; grayscale still communicates state.

Flutter's official [accessibility checklist](https://docs.flutter.dev/ui/accessibility) supports screen-reader checks, large-scale usability, contrast and >=48 targets. Its [adaptive design guidance](https://docs.flutter.dev/ui/adaptive-responsive/best-practices) supports testing touch first and sizing to actual available constraints. The precise OMC tokens/breakpoints above are this proposal, not claims that Flutter mandates them.

## A. Executive summary

Observed: the app has a restrained neutral base and useful touch/motion tokens, but no explicit app-wide TextTheme. Extensive local typography, heavy weights, module colors, card variants and small labels fragment the product. The catalogue has fixed-height three-column phone tiles; central Quick Actions has three columns and 10.8 labels. Bottom labels are10, More labels13, notification body12 and metadata10.5. These combine density, low hierarchy and limited room for scaled text; a uniform +2 font change cannot resolve them.

Already good: runtime contrast-selected onAccent, 48 touch-target concept, reduced-motion helpers, common error classifier/state adapters, persistent request submit bar, unsaved-change protection, capability-based IA, customer lifecycle/next-action Home/detail, independent support freshness state, and some adaptive header/button layouts. Preserve these behaviors. The source does not globally disable text scaling; existing layout-growth clamps are not text-scaling clamps.

Target: calm native mobile product with body16, list17, readable field15/16, neutral divided lists, a single next action per decision area, restrained brand emphasis and explicit status. Largest redesigns: catalogue/Quick Actions, request creation, request tracking/details, document review, payment detail, support workspace/conversation, internal workspace and dense CRM lists. Mostly polish: account-link forms, profile identity, read-only task/customer/referral details, preview, budget and administrative confirmations. Financial/audit workflows still have high regression risk even when visual changes are small.

No new backend feature, API, dark mode, app zoom, route or authentication fallback is proposed. Static future-timeline cards and redundant explanatory framing may be removed from UI; actual activity, tax/compliance content and business capability remain.

## B. Current product UI inventory and evidence

### B1. Inventory method and route closure

Inventory was derived from `router.dart`, its imports/exports, MainShell/ShellNavScaffold, every `features/*/presentation/` directory, all `core/widgets`, direct Navigator/MaterialPageRoute/DialogRoute calls, modal/menu/picker calls and role/state branches. Dart `part` files are part of the containing screen, not extra routes. Callback and wrapper tracing is necessary: filenames containing legacy are not evidence of dead code.

The source ledger B4 records every presentation/shared-widget file and its declared surfaces. Section E gives implementation contracts for routes and reachable independent interaction surfaces. Reusable visual children (individual rows, chips, icons, skeleton pieces) inherit the parent E contract and C/F component rules; they are enumerated in B4 rather than incorrectly counted as separate pages. Shared renderer variants are explicitly named (for example approve/reject, personal/contact/identity edits). Presence of a declared helper in B4 does not assert it is reachable.


**59 GoRoute declarations** (including three `/app/…` redirect aliases and route aliases sharing screens). The following table preserves actual names; E tables consolidate only identical implementation targets.

| Path | Route name | Source |
|---|---|---|

| `/` | `splash` | [router.dart:132](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L132) |

| `/onboarding` | `onboarding` | [router.dart:137](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L137) |

| `/login` | `login` | [router.dart:142](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L142) |

| `/forgot-password` | `forgot-password` | [router.dart:147](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L147) |

| `/activate-existing-account` | `activate-existing-account` | [router.dart:152](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L152) |

| `/activate-account` | `activate-account` | [router.dart:157](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L157) |

| `/app/activate-account` | `redirect alias` | [router.dart:164](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L164) |

| `/reset-password` | `reset-password` | [router.dart:171](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L171) |

| `/app/reset-password` | `redirect alias` | [router.dart:178](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L178) |

| `/signup` | `signup` | [router.dart:185](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L185) |

| `/verify-email` | `verify-email` | [router.dart:190](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L190) |

| `/app/verify-email` | `redirect alias` | [router.dart:197](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L197) |

| `/under-review` | `under-review` | [router.dart:204](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L204) |

| `/home` | `home` | [router.dart:222](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L222) |

| `/services` | `services` | [router.dart:238](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L238) |

| `/track` | `track` | [router.dart:255](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L255) |

| `/my-services` | `my-services` | [router.dart:260](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L260) |

| `/documents` | `documents` | [router.dart:271](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L271) |

| `/documents/:documentId` | `document-detail` | [router.dart:280](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L280) |

| `/more` | `more` | [router.dart:303](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L303) |

| `/services/:serviceId` | `service-detail` | [router.dart:312](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L312) |

| `/services/:serviceId/request` | `service-request-draft` | [router.dart:330](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L330) |

| `/dashboard` | `dashboard` | [router.dart:348](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L348) |

| `/payments` | `payments` | [router.dart:354](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L354) |

| `/payments/:paymentId` | `payment-detail` | [router.dart:360](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L360) |

| `/leads` | `leads` | [router.dart:377](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L377) |

| `/customers` | `customers` | [router.dart:387](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L387) |

| `/tasks` | `tasks` | [router.dart:393](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L393) |

| `/leads/:leadId` | `lead-detail` | [router.dart:399](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L399) |

| `/customers/:customerId` | `customer-detail` | [router.dart:412](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L412) |

| `/tasks/:taskId` | `task-detail` | [router.dart:425](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L425) |

| `/my-services/:caseId` | `service-case-detail` | [router.dart:438](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L438) |

| `/knowledge` | `knowledge` | [router.dart:455](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L455) |

| `/knowledge/:articleId` | `knowledge-detail` | [router.dart:461](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L461) |

| `/notifications` | `notifications` | [router.dart:474](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L474) |

| `/notifications/:notificationId` | `notification-detail` | [router.dart:480](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L480) |

| `/support` | `support` | [router.dart:493](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L493) |

| `/tax-calculator` | `tax-calculator` | [router.dart:499](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L499) |

| `/tax-calculator/history` | `tax-calculation-history` | [router.dart:505](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L505) |

| `/profile` | `profile` | [router.dart:513](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L513) |

| `/profile/edit` | `edit-profile` | [router.dart:519](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L519) |

| `/my-referrals` | `my-referrals` | [router.dart:525](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L525) |

| `/my-referrals/:customerId` | `my-referral-detail` | [router.dart:531](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L531) |

| `/my-commissions` | `my-commissions` | [router.dart:549](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L549) |

| `/my-commissions/:earningId` | `my-commission-detail` | [router.dart:555](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L555) |

| `/expense-tracker` | `expense-tracker` | [router.dart:567](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L567) |

| `/expense-budget` | `expense-budget` | [router.dart:575](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L575) |

| `/support-tickets/:ticketId` | `support-ticket-detail` | [router.dart:581](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L581) |

| `/settings` | `settings` | [router.dart:594](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L594) |

| `/change-password` | `change-password` | [router.dart:600](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L600) |

| `/internal-workspace` | `internal-workspace` | [router.dart:608](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L608) |

| `/admin-control` | `admin-control` | [router.dart:616](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L616) |

| `/admin-control/operations` | `admin-operations` | [router.dart:622](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L622) |

| `/internal-workspace/service-cases` | `internal-service-cases` | [router.dart:630](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L630) |

| `/internal-workspace/customers` | `internal-customers` | [router.dart:638](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L638) |

| `/internal-workspace/documents` | `internal-documents` | [router.dart:644](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L644) |

| `/internal-workspace/payments` | `internal-payments` | [router.dart:652](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L652) |

| `/internal-workspace/commissions` | `internal-commission-operations` | [router.dart:662](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L662) |

| `/internal-workspace/service-cases/:caseId` | `internal-service-case-workspace` | [router.dart:670](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/router.dart#L670) |


Query contracts: `token` on verify/reset/activation; `query`, `assisted=1`, `customer_profile`, `customer_name` across catalogue/detail/draft; `service_request` for assisted document list; assisted/customer_name for document/payment/case detail; `action=create` on leads; referral detail customer_name. Preserve URI encoding/decoding and current defaults, including missing-token handling. `/track` and `/my-services` have different access checks even though both use _TrackRootScreen. Do not conflate their policies.

### B2. Reachability and variants that a route list misses

| Source path / dispatch | Observed responsibility | Decision |
|---|---|---|
| home_screen.dart → home_screen_dispatcher.dart | Approved non-internal dashboard-capable accounts use ApprovedCustomerHomeView; others use role-aware Home | KEEP dispatch; audit both branches |
| home_screen_role_aware.dart | Non-internal early branch returns CustomerGuestHomeView; internal branch uses InternalHomeView; older helper declarations remain in same file | Migrate actually called views; do not count old helper layout as a separate routed screen |
| service_catalogue_screen.dart / _modern / _premium | All export service_catalogue_screen_impl.dart | One catalogue design; no three screen migrations |
| service_detail_screen.dart | Exports service_detail_screen_impl.dart | One detail implementation |
| service_case_detail_screen.dart | Approved non-assisted customer detail versus operational/assisted legacy fallback | KEEP both; legacy is reachable |
| support_screen.dart / support_ticket_detail_screen.dart | Freshness-aware wrappers around legacy UI | KEEP wrapper timers, stale snapshot, retry and session behavior |
| router _DocumentsRootScreen | Assisted gets DocumentsScreen; otherwise review-capable accounts get InternalDocumentReviewScreen | KEEP role switch and assisted precedence |
| InternalServiceCaseWorkspaceScreen | Second public screen class in internal_operations_center_screen.dart | Separate E table; do not overlook because file name differs |
| SettlementExceptionsScreen | Direct Navigator from workspace quick action, no GoRoute | KEEP and audit |
| DocumentPreviewScreen | Direct Navigator for review/invoice/proof; customer document detail opens validated external URLs separately | KEEP native media viewer and authenticated downloads |
| core/push/push_runtime.dart | Global push-open failure overlay; transient Retry versus terminal Dismiss | KEEP owner/binding/gate checks |
| core/push/push_device_settings_tile.dart | Android device permission/registration UI embedded in Settings, separate from account preferences | REDESIGN concise presentation; preserve enable/retry/platform hiding |
| Signup role/details/preferences/security + pending success | In-route step/state surfaces, not named routes | Separate E contracts; retain actual sequence |
| Readiness, device lock, dirty-form dialog, snackbar/Undo, native pickers | Global/non-route interaction surfaces | Must test on top of every applicable host |
| internal_operations_center_screen.dart non-payment AreaConfig branches | Source contains customers/documents variants; router uses dedicated customer/document screens | Inspect but do not reintroduce these variants as new destinations |
| theme_controller.dart and darkTheme | Definitions exist; app fixes ThemeMode.light | No dark-mode switch or feature claim |

### B3. Exact global style scan

Lexical scan over **all `omc_app/lib/**/*.dart`** at the baseline; counts include declarations, wrapper/legacy helpers and non-reachable code, not just rendered instances. A literal is an audit candidate, not automatically a defect. `size:` and width/height include non-icon/non-layout values; inspect context before migration.

| Pattern | Occurrences | Files |
|---|---:|---:|
| fontSize: | 816 | 74 |
| TextStyle( | 906 | 77 |
| FontWeight.w800 / w900 | 564 | 78 |
| Color(0x… | 800 | 61 |
| EdgeInsets. | 765 | 99 |
| BorderRadius. | 624 | 78 |
| BoxDecoration( | 445 | 74 |
| size: (candidate icon sizes) | 350 | 78 |
| width: / height: (all uses) | 2639 | 97 |
| GridView. | 7 | 5 |
| MediaQuery. | 29 | 21 |
| textScaler / textScaleFactor | 5 | 5 |

| Reported issue | Verification / replacement |
|---|---|
| No strong centralized typography | theme.dart builds ThemeData without explicit textTheme; design_tokens.dart has spacing/radius/touch/motion only. Define C1 first. Material defaults exist; do not say the app has no theme. |
| Settings small text | settings_screen.dart:1005–1057: tile14, body13, caption/footnote/support12. Replace by title17/support15/caption13. |
| More small labels | omc_more_sheet.dart:199 heading11.5; :281 label13; :518 access text11.5. Use heading14–15, rows16, access body15. |
| Bottom nav small | omc_bottom_nav.dart:302/:390 labels10; :424 badge8.5. Base bar already grows with text scale at :85. Use navigation12 and measured height. |
| Quick Action density | omc_quick_actions_sheet.dart:120 count3, :123 aspect1.05, :182 label10.8. Replace by adaptive 2/1 layout. |
| Catalogue density | service_catalogue_screen_impl.dart:203–219 count3 below content width480 and fixed extent114; :663 title12.25. Use 2/list with title17. |
| Notification text | notifications_screen.dart:402 title14; :429 body12; :415/:443 metadata10.5; group11 at :329. Use17/15/13. |
| Heavy weights / rainbow | OmcPremium module colors :16–23, moduleColor :46; local _TextStyles/_Palette/_Tone families across Home, requests, support, tax, expense. Replace appearance only; preserve labels/enums. |
| Card mismatch | PremiumCard uses radius24/shadow, PremiumListCard radius20/shadow, theme card radius22, OmcSurface caller radius. C4 unifies to16 and border/no-shadow. |
| Text-scale handling | Only selected layouts inspect TextScaler: bottom nav, approved Home actions, submit bar, freshness banner, PremiumListHeader. No global text-scale override found. Lack of explicit inspection alone does not prove overflow. |
| Misleading placeholders | Document/payment detail static timeline placeholders promise future events without fetching them; remove their framing/content. |

Reproduce the scan with `rg -n 'fontSize:|TextStyle\(|FontWeight\.w[89]00|Color\(0x|EdgeInsets\.|BorderRadius\.|BoxDecoration\(|crossAxisCount|mainAxisExtent|childAspectRatio|MediaQuery\.|textScaler|textScaleFactor' omc_app/lib`. B4 supplies exact per-file evidence anchors and E supplies replacement decisions.

### B4. Full source ownership ledger

**107 presentation/shared-widget files plus five external UI/interaction owners (112 ledger entries)** are listed below, including export-only and part files. “Styles” reports local numeric font range and local declaration count; inherited/part styles are additional. This ledger is a migration checklist, not proof of runtime layout tests. Declared classes include private data/helper classes to prevent accidental omissions during implementation. Each leaf widget inherits C/U and its owning E table. Feature providers/brand helpers have no standalone screen.


#### `omc_app/lib/core/forms/dirty_form_controller.dart`

Owner/contracts: Unsaved changes confirmation. Source: [dirty_form_controller.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/forms/dirty_form_controller.dart#L1). 184 lines.

Declared surfaces/helpers: `DirtyFormController@L4`; `ActiveDirtyFormNotifier@L47`; `UnsavedChangesGuard@L97`; `_UnsavedChangesGuardState@L114`.

modal/menu/picker: `L74@L74`.

state/recovery: `L97@L97`, `L98@L98`, `L110@L110`, `L111@L111`, `L114@L114`, `L126@L126`.



#### `omc_app/lib/core/push/firebase_push_source.dart`

Owner/contracts: Platform notification interaction. Source: [firebase_push_source.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/firebase_push_source.dart#L1). 287 lines.

Declared surfaces/helpers: `FirebasePushSource@L23`.



#### `omc_app/lib/core/push/push_device_settings_tile.dart`

Owner/contracts: Device notification permission / registration. Source: [push_device_settings_tile.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/push_device_settings_tile.dart#L1). 95 lines.

Declared surfaces/helpers: `PushDeviceSettingsTile@L7`; `_PushDeviceSettingsTileState@L14`.



#### `omc_app/lib/core/push/push_runtime.dart`

Owner/contracts: Push-open failure recovery. Source: [push_runtime.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/push_runtime.dart#L1). 268 lines.

Declared surfaces/helpers: `PushRuntimeHost@L31`; `_PushRuntimeHostState@L38`.



#### `omc_app/lib/core/widgets/app_back_header.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [app_back_header.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_back_header.dart#L1). 239 lines.

Declared surfaces/helpers: `AppBackHeader@L7`.



#### `omc_app/lib/core/widgets/app_button.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [app_button.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_button.dart#L1). 90 lines.

Declared surfaces/helpers: `AppButton@L6`.



#### `omc_app/lib/core/widgets/app_skeleton.dart`

Owner/contracts: Loading skeleton. Source: [app_skeleton.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_skeleton.dart#L1). 82 lines.

Declared surfaces/helpers: `AppSkeleton@L8`; `_AppSkeletonState@L24`.



#### `omc_app/lib/core/widgets/app_state.dart`

Owner/contracts: Shared empty / error / access / configuration state. Source: [app_state.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_state.dart#L1). 269 lines.

Declared surfaces/helpers: `AppEmptyState@L9`; `AppErrorState@L42`; `AppConfigurationState@L100`; `AppAccessState@L131`; `AppStateView@L162`.

state/recovery: `L42@L42`, `L43@L43`, `L53@L53`, `L67@L67`, `L131@L131`, `L132@L132`.



#### `omc_app/lib/core/widgets/data_freshness_banner.dart`

Owner/contracts: Freshness warning / retry. Source: [data_freshness_banner.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/data_freshness_banner.dart#L1). 147 lines.

Declared surfaces/helpers: `DataFreshnessBanner@L6`.

Styles: 2 numeric font declarations, 11.5–12.5; smallest `data_freshness_banner.dart@L64`. 

layout constraints: `L25@L25`, `L27@L27`.

state/recovery: `L6@L6`, `L7@L7`.



#### `omc_app/lib/core/widgets/empty_state.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [empty_state.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/empty_state.dart#L1). 35 lines.

Declared surfaces/helpers: `EmptyState@L9`.



#### `omc_app/lib/core/widgets/loading_view.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [loading_view.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/loading_view.dart#L1). 44 lines.

Declared surfaces/helpers: `LoadingView@L6`.



#### `omc_app/lib/core/widgets/omc_identity_header.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [omc_identity_header.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/omc_identity_header.dart#L1). 242 lines.

Declared surfaces/helpers: `OmcIdentityHeader@L7`; `_NotificationButton@L73`; `_Avatar@L153`.

Styles: 3 numeric font declarations, 9.5–26; smallest `omc_identity_header.dart@L138`. 



#### `omc_app/lib/core/widgets/omc_logo.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [omc_logo.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/omc_logo.dart#L1). 51 lines.

Declared surfaces/helpers: `OmcLogo@L5`.



#### `omc_app/lib/core/widgets/omc_premium.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [omc_premium.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/omc_premium.dart#L1). 434 lines.

Declared surfaces/helpers: `OmcPremium@L6`; `OmcSurface@L99`; `OmcIconBadge@L161`; `OmcStatusBadge@L194`; `OmcSectionHeader@L246`; `OmcMetricCard@L308`; `OmcLockedOverlay@L390`.

Styles: 4 numeric font declarations, 11–22; smallest `omc_premium.dart@L378`. 



#### `omc_app/lib/core/widgets/premium_card.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [premium_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/premium_card.dart#L1). 62 lines.

Declared surfaces/helpers: `PremiumCard@L5`.



#### `omc_app/lib/core/widgets/premium_empty_state.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [premium_empty_state.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/premium_empty_state.dart#L1). 33 lines.

Declared surfaces/helpers: `PremiumEmptyState@L7`.

state/recovery: `L7@L7`, `L8@L8`.



#### `omc_app/lib/core/widgets/premium_info_chip.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [premium_info_chip.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/premium_info_chip.dart#L1). 45 lines.

Declared surfaces/helpers: `PremiumInfoChip@L3`.



#### `omc_app/lib/core/widgets/premium_list_card.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [premium_list_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/premium_list_card.dart#L1). 105 lines.

Declared surfaces/helpers: `PremiumListCard@L3`.



#### `omc_app/lib/core/widgets/premium_list_header.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [premium_list_header.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/premium_list_header.dart#L1). 136 lines.

Declared surfaces/helpers: `PremiumListHeader@L5`; `_MetaBadge@L102`.

layout constraints: `L27@L27`, `L29@L29`.



#### `omc_app/lib/core/widgets/route_failure_screen.dart`

Owner/contracts: Unknown / invalid route recovery. Source: [route_failure_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/route_failure_screen.dart#L1). 102 lines.

Declared surfaces/helpers: `RouteFailureScreen@L7`.

Styles: 2 numeric font declarations, 14–24; smallest `route_failure_screen.dart@L64`. 



#### `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart`

Owner/contracts: Administration, Grant existing staff access dialog, Staff access profile dialog, Business numeric setting dialog. Source: [admin_control_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_control_screen.dart#L1). 733 lines.

Declared surfaces/helpers: `AdminControlScreen@L12`; `_ApplicationsCard@L285`; `_StaffCard@L387`; `_BusinessSettingsCard@L524`; `_LoadingCard@L679`; `_ErrorCard@L695`.

Styles: 8 numeric font declarations, 12.5–25; smallest `admin_control_screen.dart@L174`. 

modal/menu/picker: `L154@L154`, `L466@L466`, `L632@L632`.

state/recovery: `L87@L87`, `L88@L88`, `L113@L113`, `L114@L114`, `L157@L157`, `L469@L469`, `L635@L635`.



#### `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart`

Owner/contracts: Operational controls, Operational reassignment dialog, Exhausted sync retry dialog, Discount review dialog. Source: [admin_operations_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart#L1). 537 lines.

Declared surfaces/helpers: `AdminOperationsScreen@L12`; `_AdminOperationsScreenState@L20`; `_OperationCard@L485`.

Styles: 1 numeric font declarations, 16–16; smallest `admin_operations_screen.dart@L505`. 

modal/menu/picker: `L225@L225`, `L335@L335`, `L378@L378`.

state/recovery: `L99@L99`, `L105@L105`, `L228@L228`, `L344@L344`, `L381@L381`.



#### `omc_app/lib/features/app_config/presentation/app_brand_registry.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [app_brand_registry.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/app_config/presentation/app_brand_registry.dart#L1). 96 lines.

Declared surfaces/helpers: `OmcAppColors@L6`.



#### `omc_app/lib/features/app_config/presentation/app_readiness_gate.dart`

Owner/contracts: Readiness / maintenance / update gates, Recommended update state. Source: [app_readiness_gate.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/app_config/presentation/app_readiness_gate.dart#L1). 397 lines.

Declared surfaces/helpers: `_GatedBackDispatcher@L32`; `AppReadinessGate@L40`; `_AppReadinessGateState@L47`; `MobileReadinessOverlay@L246`; `AppGatePanel@L275`.

state/recovery: `L213@L213`.



#### `omc_app/lib/features/auth/presentation/activate_existing_account_screen.dart`

Owner/contracts: Activate existing account. Source: [activate_existing_account_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/activate_existing_account_screen.dart#L1). 156 lines.

Declared surfaces/helpers: `ActivateExistingAccountScreen@L11`; `_ActivateExistingAccountScreenState@L19`.



#### `omc_app/lib/features/auth/presentation/auth_entry_widgets.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [auth_entry_widgets.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/auth_entry_widgets.dart#L1). 185 lines.

Declared surfaces/helpers: `AuthEntryScaffold@L8`; `AuthEntryHeader@L83`; `AuthErrorBanner@L146`.

Styles: 2 numeric font declarations, 13–14.5; smallest `auth_entry_widgets.dart@L175`. 



#### `omc_app/lib/features/auth/presentation/complete_customer_activation_screen.dart`

Owner/contracts: Complete customer activation. Source: [complete_customer_activation_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/complete_customer_activation_screen.dart#L1). 270 lines.

Declared surfaces/helpers: `CompleteCustomerActivationScreen@L11`; `_CompleteCustomerActivationScreenState@L21`.



#### `omc_app/lib/features/auth/presentation/email_verification_screen.dart`

Owner/contracts: Email verification / account completion. Source: [email_verification_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/email_verification_screen.dart#L1). 308 lines.

Declared surfaces/helpers: `EmailVerificationScreen@L12`; `_EmailVerificationScreenState@L22`.

Styles: 1 numeric font declarations, 14–14; smallest `email_verification_screen.dart@L222`. 



#### `omc_app/lib/features/auth/presentation/forgot_password_screen.dart`

Owner/contracts: Forgot password. Source: [forgot_password_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/forgot_password_screen.dart#L1). 148 lines.

Declared surfaces/helpers: `ForgotPasswordScreen@L11`; `_ForgotPasswordScreenState@L19`.



#### `omc_app/lib/features/auth/presentation/login_screen.dart`

Owner/contracts: Login, Biometric account chooser, Login help sheet. Source: [login_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/login_screen.dart#L1). 542 lines.

Declared surfaces/helpers: `LoginScreen@L14`; `_LoginScreenState@L21`; `_AuthFooter@L451`; `_SupportContactRow@L481`.

Styles: 5 numeric font declarations, 12–22; smallest `login_screen.dart@L522`. 

modal/menu/picker: `L103@L103`, `L240@L240`.



#### `omc_app/lib/features/auth/presentation/reset_password_screen.dart`

Owner/contracts: Reset password. Source: [reset_password_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/reset_password_screen.dart#L1). 264 lines.

Declared surfaces/helpers: `ResetPasswordScreen@L11`; `_ResetPasswordScreenState@L21`.



#### `omc_app/lib/features/auth/presentation/signup_screen.dart`

Owner/contracts: Signup flow, Pending registration success. Source: [signup_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_screen.dart#L1). 936 lines.

Declared surfaces/helpers: `SignupScreen@L34`; `_SignupScreenState@L41`; `PendingRegistrationSuccessScreen@L761`; `_PendingRegistrationSuccessScreenState@L778`.

Styles: 2 numeric font declarations, 12.5–14; smallest `signup_screen.dart@L901`. 

state/recovery: `L547@L547`.



#### `omc_app/lib/features/auth/presentation/signup_steps.dart`

Owner/contracts: Signup role step, Signup details step, Signup preferences step, Signup security/review step. Source: [signup_steps.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_steps.dart#L1). 1034 lines.

Declared surfaces/helpers: `SignupProgress@L10`; `SignupRoleStep@L61`; `SignupDetailsStep@L147`; `SignupPreferencesStep@L441`; `SignupSecurityStep@L640`; `SignupBottomActions@L732`; `SignupStepTitle@L783`; `SignupRoleCard@L821`; `SignupReviewNotice@L912`; `SignupLoginFooter@L946`; `SignupSuccessScreen@L973`.

Styles: 15 numeric font declarations, 12–21; smallest `signup_steps.dart@L32`. 



#### `omc_app/lib/features/auth/presentation/under_review_screen.dart`

Owner/contracts: Under review, Review support sheet. Source: [under_review_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/under_review_screen.dart#L1). 234 lines.

Declared surfaces/helpers: `UnderReviewScreen@L14`; `_UnderReviewScreenState@L21`.

Styles: 4 numeric font declarations, 13–22; smallest `under_review_screen.dart@L194`. 

modal/menu/picker: `L82@L82`.



#### `omc_app/lib/features/commissions/presentation/commission_detail_screen.dart`

Owner/contracts: Commission detail. Source: [commission_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/commission_detail_screen.dart#L1). 90 lines.

Declared surfaces/helpers: `CommissionDetailScreen@L13`.

state/recovery: `L23@L23`, `L24@L24`.



#### `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart`

Owner/contracts: Commission operations, Record paid settlement sheet, Approve / mark-payable commission confirmation, Reject commission dialog, Commission settlement date picker. Source: [finance_commissions_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L1). 914 lines.

Declared surfaces/helpers: `FinanceCommissionsScreen@L11`; `_FinanceCommissionsScreenState@L19`; `_FinanceHeader@L408`; `_CommissionOperationCard@L441`; `_SettlementInput@L631`; `_SettlementSheet@L637`; `_SettlementSheetState@L644`; `_QueueMessage@L735`; `_MetaLine@L775`; `_InlineNotice@L815`; `_Pill@L851`.

Styles: 12 numeric font declarations, 10–20; smallest `finance_commissions_screen.dart@L869`. 

layout constraints: `L656@L656`.

modal/menu/picker: `L183@L183`, `L208@L208`, `L230@L230`, `L696@L696`.



#### `omc_app/lib/features/commissions/presentation/my_commissions_screen.dart`

Owner/contracts: My commissions. Source: [my_commissions_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/my_commissions_screen.dart#L1). 266 lines.

Declared surfaces/helpers: `MyCommissionsScreen@L7`; `_MyCommissionsScreenState@L15`; `_CommissionFilters@L165`; `_TotalCard@L228`; `_ErrorCard@L254`.



#### `omc_app/lib/features/crm/presentation/widgets/crm_detail_widgets.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [crm_detail_widgets.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/crm/presentation/widgets/crm_detail_widgets.dart#L1). 524 lines.

Declared surfaces/helpers: `CrmDetailHeaderCard@L6`; `CrmDetailInfoCard@L97`; `CrmInfoRow@L144`; `CrmActivityTimelineCard@L186`; `CrmTimelineItem@L239`; `_CrmStatusPill@L253`; `_TimelineEmptyMessage@L281`; `_TimelineItemTile@L309`; `CrmDetailLoadingView@L373`; `CrmDetailMetaFooter@L475`.

Styles: 15 numeric font declarations, 11–20; smallest `crm_detail_widgets.dart@L273`. 



#### `omc_app/lib/features/customers/presentation/customer_detail_screen.dart`

Owner/contracts: Customer detail. Source: [customer_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/customers/presentation/customer_detail_screen.dart#L1). 857 lines.

Declared surfaces/helpers: `CustomerDetailScreen@L14`; `_CustomerDetailBody@L64`; `_CustomerIdentityCard@L138`; `_CustomerProfileAvatar@L251`; `_CustomerOverviewCard@L303`; `_OverviewTile@L383`; `_CustomerDetailsCard@L435`; `_DetailRowData@L466`; `_DetailRow@L478`; `_ActivityCard@L531`; `_TechnicalDetailsCard@L611`; `_TechnicalRowData@L709`; `_TechnicalRow@L716`; `_SectionHeading@L759`; `_StatusPill@L793`; `_CustomerStatusStyle@L823`.

Styles: 16 numeric font declarations, 10–20; smallest `customer_detail_screen.dart@L815`. 

state/recovery: `L28@L28`, `L38@L38`, `L43@L43`.



#### `omc_app/lib/features/customers/presentation/customers_screen.dart`

Owner/contracts: Customers directory. Source: [customers_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/customers/presentation/customers_screen.dart#L1). 756 lines.

Declared surfaces/helpers: `CustomersScreen@L14`; `_CustomersScreenState@L21`; `_CustomerSummary@L249`; `_SummaryTile@L311`; `_CustomerCard@L390`; `_CustomerAvatar@L550`; `_CustomerAvatarInitials@L584`; `_InfoPill@L616`; `_StatusStyle@L655`; `_CustomersLoadingView@L697`; `_BackendUnavailableState@L723`.

Styles: 10 numeric font declarations, 10–21; smallest `customers_screen.dart@L473`. 

layout constraints: `L264@L264`.

state/recovery: `L111@L111`, `L112@L112`, `L214@L214`, `L738@L738`.



#### `omc_app/lib/features/dashboard/presentation/dashboard_screen.dart`

Owner/contracts: Dashboard customer / internal variants. Source: [dashboard_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/dashboard/presentation/dashboard_screen.dart#L1). 1693 lines.

Declared surfaces/helpers: `DashboardScreen@L13`; `_CustomerDashboardBody@L86`; `_InternalDashboardBody@L225`; `_CompactHeader@L438`; `_NextActionCard@L505`; `_MetricStrip@L588`; `_MetricCard@L606`; `_MetricData@L646`; `_MiniSummaryCard@L658`; `_ServiceSnapshotTile@L724`; `_InternalQueueTile@L824`; `_AttentionCard@L906`; `_AttentionTile@L928`; `_AttentionRow@L955`; `_QuickActionsCard@L962`; `_ShortcutAction@L995`; `_RecentActivitySection@L1007`; `_ActivityRow@L1044`; `_StatusBreakdownRow@L1112`; `_StatusRowData@L1180`; `_DashboardSection@L1192`; `_EmptyState@L1239`; `_SoftPill@L1286`; `_FallbackCard@L1314`; `_DashboardLoadingView@L1355`; `_LoadingMetricCard@L1416`; `_LoadingBox@L1440`; `_LoadingPill@L1464`; `_LoadingBar@L1482`; `_CustomerNextAction@L1503`.

Styles: 30 numeric font declarations, 11–26; smallest `dashboard_screen.dart@L636`. 

state/recovery: `L38@L38`, `L39@L39`.



#### `omc_app/lib/features/device_lock/presentation/device_lock_gate.dart`

Owner/contracts: Device lock / biometrics. Source: [device_lock_gate.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/device_lock/presentation/device_lock_gate.dart#L1). 268 lines.

Declared surfaces/helpers: `DeviceLockGate@L14`; `_DeviceLockGateState@L23`.

Styles: 2 numeric font declarations, 14–27; smallest `device_lock_gate.dart@L195`. 



#### `omc_app/lib/features/documents/application/document_attachment_controller.dart`

Owner/contracts: Document file selection and validation. Source: [document_attachment_controller.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/application/document_attachment_controller.dart#L1). 239 lines.

Declared surfaces/helpers: `DocumentAttachmentController@L12`.



#### `omc_app/lib/features/documents/presentation/document_detail_screen.dart`

Owner/contracts: Document detail, Customer document external opening. Source: [document_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/document_detail_screen.dart#L1). 761 lines.

Declared surfaces/helpers: `DocumentDetailScreen@L18`; `_DetailLoadingView@L76`; `_LoadingBar@L182`; `_DocumentHeroCard@L203`; `_DocumentQuickStats@L290`; `_DocumentStatTile@L327`; `_DocumentInfoCard@L386`; `_DocumentInfoRow@L429`; `_DocumentTimelinePlaceholder@L477`; `_DocumentDetailBody@L564`; `_DocumentDetailBodyState@L574`.

Styles: 12 numeric font declarations, 11–25; smallest `document_detail_screen.dart@L376`. 

state/recovery: `L54@L54`, `L59@L59`, `L61@L61`, `L62@L62`, `L602@L602`.



#### `omc_app/lib/features/documents/presentation/document_preview_screen.dart`

Owner/contracts: Document / invoice / proof preview. Source: [document_preview_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/document_preview_screen.dart#L1). 87 lines.

Declared surfaces/helpers: `DocumentPreviewScreen@L6`; `_UnsupportedPreview@L65`.

Styles: 1 numeric font declarations, 15–15; smallest `document_preview_screen.dart@L80`. 



#### `omc_app/lib/features/documents/presentation/documents_screen.dart`

Owner/contracts: Documents list. Source: [documents_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/documents_screen.dart#L1). 1161 lines.

Declared surfaces/helpers: `DocumentsScreen@L14`; `_DocumentsScreenState@L30`; `_DocumentsWorkspace@L206`; `_DocumentsWorkspaceState@L223`; `_Header@L357`; `_MetricTile@L464`; `_SearchField@L522`; `_FilterBar@L579`; `_FilterChip@L626`; `_DocumentRequestGroup@L663`; `_RequestDocumentCard@L734`; `_CompactDocumentRow@L865`; `_StatusPill@L994`; `_FilteredEmptyView@L1021`; `_EmptyDocumentsView@L1066`; `_DocumentsErrorView@L1114`; `_DocumentsLoadingView@L1139`.

Styles: 20 numeric font declarations, 9.5–27; smallest `documents_screen.dart@L1013`. 

state/recovery: `L101@L101`, `L102@L102`, `L103@L103`, `L1126@L1126`, `L1127@L1127`.



#### `omc_app/lib/features/documents/presentation/internal_document_review_screen.dart`

Owner/contracts: Document review workspace, Reject document dialog. Source: [internal_document_review_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/internal_document_review_screen.dart#L1). 1542 lines.

Declared surfaces/helpers: `InternalDocumentReviewScreen@L39`; `_InternalDocumentReviewScreenState@L47`; `_ReviewContent@L418`; `_CustomerFilterOption@L630`; `_InternalDocumentSearchField@L642`; `_CompactFilterPanel@L699`; `_CustomerFilterField@L771`; `_DocumentTypeFilterField@L813`; `_ServiceDocumentGroup@L850`; `_ServiceWorkspaceHeader@L936`; `_CompactCustomerMeta@L1087`; `_ReviewFilterBar@L1123`; `_ReviewDocumentCard@L1182`; `_CompactMetricsStrip@L1426`; `_CompactMetric@L1477`; `_ReviewLoadingView@L1518`.

Styles: 13 numeric font declarations, 10.5–14; smallest `internal_document_review_screen.dart@L1115`. 

modal/menu/picker: `L235@L235`, `L295@L295`.

state/recovery: `L238@L238`, `L337@L337`, `L338@L338`, `L548@L548`.



#### `omc_app/lib/features/documents/presentation/widgets/document_action_card.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [document_action_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/widgets/document_action_card.dart#L1). 225 lines.

Declared surfaces/helpers: `DocumentActionCard@L7`; `_ActionTile@L127`.

Styles: 4 numeric font declarations, 12–18; smallest `document_action_card.dart@L75`. 



#### `omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart`

Owner/contracts: Monthly budget, Budget action menu, Add / edit budget sheet. Source: [expense_budget_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart#L1). 868 lines.

Declared surfaces/helpers: `ExpenseBudgetItem@L49`; `ExpenseBudgetScreen@L80`; `_ExpenseBudgetScreenState@L88`; `_InternalLocalBudgetNote@L461`; `_BudgetMonthHeader@L498`; `_BudgetList@L559`; `_NoBudgetState@L633`; `_BudgetCard@L696`; `_BudgetLoadingCard@L839`.

Styles: 11 numeric font declarations, 10–15; smallest `expense_budget_screen.dart@L825`. 

layout constraints: `L322@L322`.

modal/menu/picker: `L142@L142`, `L313@L313`.

state/recovery: `L111@L111`, `L212@L212`, `L213@L213`, `L232@L232`, `L233@L233`, `L252@L252`, `L253@L253`, `L323@L323`.



#### `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart`

Owner/contracts: Expense Tracker, Cloud expense history / local pending entries, Tracker storage / data tools menu, Add / edit transaction sheet, Account history export progress dialog, Local JSON backup dialog, Import JSON backup dialog, Archive transaction confirmation, Clear local tracker confirmation, Tracker period filter menu, Transaction action menu, Transaction date picker. Source: [expense_tracker_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L1). 2461 lines.

Declared surfaces/helpers: `ExpenseTransactionsController@L36`; `ExpenseTrackerScreen@L259`; `_ExpenseTrackerBody@L834`; `_ExpenseTrackerBodyState@L859`; `_TrackerStats@L976`; `_AccessBanner@L1049`; `_HeroSummaryCard@L1134`; `_CompactStat@L1195`; `_QuickAddPanel@L1247`; `_TaxReadyCard@L1334`; `_FilterChips@L1394`; `_MonthSummaryCard@L1444`; `_CategorySummaryCard@L1497`; `_TransactionTile@L1551`; `_TransactionSheet@L1672`; `_TransactionSheetState@L1697`; `_DatePickerTile@L2129`; `_MiniChip@L2153`; `_IconBox@L2178`; `_TrackerLoadingView@L2197`; `_CloudExpenseBody@L2307`; `_CloudExpenseBodyState@L2320`.

Styles: 17 numeric font declarations, 10–15; smallest `expense_tracker_screen.dart@L1226`. 

layout constraints: `L1770@L1770`.

modal/menu/picker: `L305@L305`, `L497@L497`, `L534@L534`, `L596@L596`, `L617@L617`, `L745@L745`, `L792@L792`, `L1402@L1402`, `L1654@L1654`, `L2027@L2027`.

state/recovery: `L288@L288`, `L417@L417`, `L418@L418`, `L921@L921`, `L930@L930`, `L1776@L1776`, `L2369@L2369`, `L2370@L2370`.



#### `omc_app/lib/features/home/presentation/approved_customer_home_actions.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [approved_customer_home_actions.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_actions.dart#L1). 359 lines.

Declared surfaces/helpers: `_AtAGlance@L3`; `_MiniMetric@L45`; `_QuickActions@L115`; `_ExploreCard@L242`; `_ExploreRow@L278`; `_QuickAction@L352`.

Styles: 5 numeric font declarations, 10.8–20; smallest `approved_customer_home_actions.dart@L104`. 

layout constraints: `L172@L172`, `L174@L174`, `L184@L184`, `L187@L187`.



#### `omc_app/lib/features/home/presentation/approved_customer_home_content.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [approved_customer_home_content.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_content.dart#L1). 153 lines.

Declared surfaces/helpers: `_CustomerHomeContentSections@L3`; `_HomeContentLoading@L77`; `_HomeContentError@L97`.

Styles: 2 numeric font declarations, 11.5–13.5; smallest `approved_customer_home_content.dart@L137`. 

state/recovery: `L19@L19`, `L20@L20`.



#### `omc_app/lib/features/home/presentation/approved_customer_home_service_widgets.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [approved_customer_home_service_widgets.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_service_widgets.dart#L1). 667 lines.

Declared surfaces/helpers: `_HomeHeader@L3`; `_HeaderButton@L81`; `_CurrentServiceCard@L153`; `_ProgressBadge@L293`; `_MilestoneRow@L325`; `_NextStepPanel@L395`; `_CompactServiceCard@L457`; `_NoActiveServiceCard@L530`; `_ActiveServiceCountCard@L599`.

Styles: 17 numeric font declarations, 9–26; smallest `approved_customer_home_service_widgets.dart@L137`. 



#### `omc_app/lib/features/home/presentation/approved_customer_home_support.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [approved_customer_home_support.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_support.dart#L1). 106 lines.

Declared surfaces/helpers: `_CustomerHomeLoading@L3`; `_LoadingPanel@L30`.



#### `omc_app/lib/features/home/presentation/approved_customer_home_view.dart`

Owner/contracts: Approved customer Home. Source: [approved_customer_home_view.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_view.dart#L1). 301 lines.

Declared surfaces/helpers: `ApprovedCustomerHomeView@L27`; `_CustomerHomeContent@L191`.

state/recovery: `L116@L116`, `L117@L117`, `L132@L132`.



#### `omc_app/lib/features/home/presentation/customer_guest_home_view.dart`

Owner/contracts: Guest / pending / rejected Home, Home service-search suggestions. Source: [customer_guest_home_view.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/customer_guest_home_view.dart#L1). 2201 lines.

Declared surfaces/helpers: `CustomerGuestHomeView@L18`; `_NeedsAttentionCard@L287`; `_Background@L408`; `_HomeHeader@L426`; `_NotificationButton@L515`; `_Avatar@L574`; `_SearchField@L629`; `_SearchFieldState@L644`; `_SearchSuggestion@L864`; `_HeroArea@L940`; `_CustomerEmptyHeroCard@L982`; `_GuestHeroCard@L1066`; `_ServiceHeroCard@L1172`; `_QuickActionStrip@L1427`; `_QuickActionTile@L1479`; `_ServiceListCard@L1558`; `_ServiceRow@L1585`; `_ActivityCard@L1705`; `_ActivityRow@L1729`; `_EmptyServicesCard@L1806`; `_EmptyActivityCard@L1826`; `_LockedPreviewCard@L1851`; `_SectionHeading@L1925`; `_StatusPill@L1976`; `_SurfaceCard@L2012`; `_ActionPalette@L2044`; `_ActivityPalette@L2120`; `_HomeLoadNotice@L2160`.

Styles: 38 numeric font declarations, 10–31; smallest `customer_guest_home_view.dart@L560`. 

layout constraints: `L1444@L1444`.



#### `omc_app/lib/features/home/presentation/home_screen.dart`

Owner/contracts: Export/part/support definitions; resolve containing screen. Source: [home_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/home_screen.dart#L1). 1 lines.

Declared surfaces/helpers: No class declaration; export/part/functions..



#### `omc_app/lib/features/home/presentation/home_screen_dispatcher.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [home_screen_dispatcher.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/home_screen_dispatcher.dart#L1). 55 lines.

Declared surfaces/helpers: `HomeScreen@L9`.



#### `omc_app/lib/features/home/presentation/home_screen_role_aware.dart`

Owner/contracts: Guest protected-action sheet. Source: [home_screen_role_aware.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/home_screen_role_aware.dart#L1). 2750 lines.

Declared surfaces/helpers: `HomeScreen@L42`; `_HomeMode@L863`; `_Backdrop@L886`; `_Header@L906`; `_HeaderIconButton@L967`; `_AvatarBadge@L1026`; `_SearchBar@L1110`; `_FilterChip@L1160`; `_CustomerServiceFocusCard@L1183`; `_BannerCard@L1469`; `_SectionTitle@L1564`; `_QuickActionsRow@L1599`; `_ActionTile@L1647`; `_MoreTile@L1736`; `_CTASection@L1780`; `_MetricItem@L1891`; `_InternalSummaryGrid@L1900`; `_CustomerSummaryGrid@L1942`; `_StatsGrid@L2014`; `_MetricCard@L2035`; `_TrendLine@L2125`; `_ServiceList@L2148`; `_ServiceCard@L2192`; `_ProgressBar@L2306`; `_ActivityList@L2341`; `_ActivityItem@L2400`; `_ActionPill@L2480`; `_ColorPalette@L2505`.

Styles: 35 numeric font declarations, 9.8–28; smallest `home_screen_role_aware.dart@L2080`. 

layout constraints: `L2025@L2025`, `L2028@L2028`.

modal/menu/picker: `L717@L717`.



#### `omc_app/lib/features/home/presentation/internal_home_view.dart`

Owner/contracts: Internal Home. Source: [internal_home_view.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/internal_home_view.dart#L1). 1712 lines.

Declared surfaces/helpers: `InternalHomeView@L18`; `_Header@L458`; `_NotificationButton@L551`; `_Avatar@L619`; `_InitialsAvatar@L659`; `_OperationsHero@L681`; `_HeroMetric@L865`; `_VerticalDivider@L917`; `_SectionCard@L931`; `_QuickActions@L999`; `_ActionCountPill@L1149`; `_AttentionList@L1178`; `_AttentionRow@L1198`; `_OperationsGrid@L1317`; `_RecentActivityList@L1384`; `_ActivityRow@L1404`; `_EmptyState@L1471`; `_LockBadge@L1515`; `_AttentionItem@L1533`; `_MetricItem@L1555`; `_Visual@L1571`; `_HomeLoadNotice@L1671`.

Styles: 19 numeric font declarations, 10–29; smallest `internal_home_view.dart@L608`. 

layout constraints: `L486@L486`, `L715@L715`, `L1022@L1022`, `L1325@L1325`.



#### `omc_app/lib/features/home/presentation/widgets/home_content_rail.dart`

Owner/contracts: Home content rail. Source: [home_content_rail.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/widgets/home_content_rail.dart#L1). 211 lines.

Declared surfaces/helpers: `HomeContentRail@L5`; `_HomeContentCardView@L40`; `_ImageFallback@L193`.

Styles: 5 numeric font declarations, 9–15.5; smallest `home_content_rail.dart@L120`. 



#### `omc_app/lib/features/home/presentation/widgets/home_featured_carousel.dart`

Owner/contracts: Home featured carousel. Source: [home_featured_carousel.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/widgets/home_featured_carousel.dart#L1). 239 lines.

Declared surfaces/helpers: `HomeFeaturedCarousel@L5`; `_HomeFeaturedCarouselState@L19`; `_FeaturedBannerCard@L88`.

Styles: 4 numeric font declarations, 10.5–22; smallest `home_featured_carousel.dart@L169`. 



#### `omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart`

Owner/contracts: Internal payment operations, Internal case workspace. Source: [internal_operations_center_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart#L1). 3576 lines.

Declared surfaces/helpers: `InternalOperationsCenterScreen@L18`; `_InternalOperationsCenterScreenState@L28`; `_PaymentPager@L423`; `InternalServiceCaseWorkspaceScreen@L477`; `_InternalPaymentFilters@L572`; `_InternalPaymentSummary@L655`; `_InternalPaymentMetric@L704`; `_InternalPaymentCard@L751`; `_AreaConfig@L915`; `_OperationsSearchAndFilters@L1002`; `_OpsFilterChip@L1104`; `_OperationsSummary@L1180`; `_OpsMetric@L1331`; `_OperationsCaseCard@L1412`; `_PaymentReviewCard@L1528`; `_PaymentMetaItem@L1755`; `_PaymentCountTag@L1803`; `_Customer360Card@L1834`; `_CustomerStatusPill@L2034`; `_CustomerDocumentTag@L2063`; `_StatusPill@L2131`; `_MiniTag@L2162`; `_ServiceWorkspaceHeader@L2208`; `_NextCaseAction@L2308`; `_WorkspaceOverview@L2397`; `_OverviewItem@L2452`; `_StatusProgressBlock@L2521`; `_WorkspaceProgressTracker@L2562`; `_ProgressStage@L2623`; `_DocumentsBlock@L2699`; `_DocumentMetric@L2787`; `_PaymentsBlock@L2828`; `_ActivityTimelineBlock@L2860`; `_CaseNavigationAction@L2893`; `_CompactActivityItem@L2945`; `_ActivityDivider@L3000`; `_CaseDetailsLoading@L3019`; `_CaseSkeletonCard@L3040`; `_CaseDetailsState@L3090`; `_CaseProgressState@L3175`; `_WorkspaceSection@L3272`; `_WorkspaceIconTile@L3323`; `_WorkspaceColors@L3353`; `_OperationsLoading@L3433`; `_LoadingCard@L3462`; `_OperationsError@L3479`; `_OperationsEmpty@L3539`.

Styles: 55 numeric font declarations, 9.5–24; smallest `internal_operations_center_screen.dart@L841`. 

layout constraints: `L1205@L1205`, `L1660@L1660`, `L2408@L2408`.

state/recovery: `L86@L86`, `L87@L87`, `L175@L175`, `L176@L176`, `L505@L505`, `L506@L506`.



#### `omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart`

Owner/contracts: Service case queue, Internal case advanced filters. Source: [internal_service_cases_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart#L1). 1030 lines.

Declared surfaces/helpers: `InternalServiceCasesScreen@L29`; `_InternalServiceCasesScreenState@L37`; `_CaseSearchBar@L338`; `_PrimaryFilters@L401`; `_ActiveFilters@L465`; `_ServiceCaseCard@L504`; `_InfoChip@L667`; `_StatusPill@L706`; `_CaseFilterSelection@L736`; `_CaseFilterSheet@L742`; `_CaseFilterSheetState@L752`; `_CasesEmptyState@L873`; `_CasesLoadingView@L936`; `_CasesErrorView@L962`.

Styles: 11 numeric font declarations, 9.5–20; smallest `internal_service_cases_screen.dart@L728`. 

layout constraints: `L771@L771`.

modal/menu/picker: `L169@L169`.

state/recovery: `L221@L221`, `L982@L982`, `L983@L983`.



#### `omc_app/lib/features/internal_workspace/presentation/internal_workspace_providers.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [internal_workspace_providers.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_workspace_providers.dart#L1). 51 lines.

Declared surfaces/helpers: `InternalServiceCaseFiltersNotifier@L29`.



#### `omc_app/lib/features/internal_workspace/presentation/internal_workspace_screen.dart`

Owner/contracts: Internal workspace. Source: [internal_workspace_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_workspace_screen.dart#L1). 1494 lines.

Declared surfaces/helpers: `InternalWorkspaceScreen@L18`; `_WorkspaceContent@L59`; `_WorkspaceHeader@L192`; `_CustomerSearchCard@L256`; `_CustomerSearchCardState@L265`; `_OverviewCard@L302`; `_OverviewMetricCard@L372`; `_SectionHeader@L424`; `_PriorityPreview@L453`; `_PriorityCaseCard@L496`; `_QueueUnavailable@L568`; `_PriorityLoading@L607`; `_WorkQueues@L622`; `_WorkQueueCard@L711`; `_QuickActions@L772`; `_QuickActionCard@L862`; `_ServicePerformanceCard@L914`; `_PerformanceMetric@L977`; `_WorkspaceUnavailable@L1020`; `_WorkspaceLoading@L1044`; `_LoadingPanel@L1067`; `_QueueItem@L1092`; `_QuickAction@L1106`.

Styles: 15 numeric font declarations, 11–30; smallest `internal_workspace_screen.dart@L411`. 

layout constraints: `L358@L358`, `L361@L361`, `L701@L701`, `L704@L704`, `L852@L852`, `L855@L855`.

modal/menu/picker: `L816@L816`.

state/recovery: `L38@L38`, `L39@L39`, `L109@L109`, `L115@L115`, `L140@L140`, `L141@L141`, `L165@L165`, `L171@L171`, `L1032@L1032`.



#### `omc_app/lib/features/knowledge/presentation/knowledge_detail_screen.dart`

Owner/contracts: Knowledge article. Source: [knowledge_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/knowledge/presentation/knowledge_detail_screen.dart#L1). 336 lines.

Declared surfaces/helpers: `KnowledgeDetailScreen@L14`; `_KnowledgeDetailLoadingView@L200`; `_ArticleMetaRow@L275`; `_MetaChip@L312`.

Styles: 5 numeric font declarations, 11–26; smallest `knowledge_detail_screen.dart@L330`. 

state/recovery: `L27@L27`, `L28@L28`, `L30@L30`, `L31@L31`.



#### `omc_app/lib/features/knowledge/presentation/knowledge_screen.dart`

Owner/contracts: Knowledge & news. Source: [knowledge_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/knowledge/presentation/knowledge_screen.dart#L1). 565 lines.

Declared surfaces/helpers: `KnowledgeScreen@L14`; `_KnowledgeHeroCard@L94`; `_SectionHeader@L214`; `_KnowledgeLoadingView@L268`; `_KnowledgeArticleTile@L383`; `_KnowledgeEmptyState@L496`.

Styles: 10 numeric font declarations, 11–23; smallest `knowledge_screen.dart@L449`. 

state/recovery: `L25@L25`, `L26@L26`, `L28@L28`, `L29@L29`.



#### `omc_app/lib/features/leads/presentation/lead_detail_screen.dart`

Owner/contracts: Lead detail. Source: [lead_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/leads/presentation/lead_detail_screen.dart#L1). 158 lines.

Declared surfaces/helpers: `LeadDetailScreen@L11`; `_LeadDetailBody@L60`.

state/recovery: `L25@L25`, `L35@L35`, `L40@L40`.



#### `omc_app/lib/features/leads/presentation/leads_screen.dart`

Owner/contracts: Leads pipeline, Create lead sheet. Source: [leads_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/leads/presentation/leads_screen.dart#L1). 1841 lines.

Declared surfaces/helpers: `LeadsScreen@L15`; `_LeadsScreenState@L24`; `_LeadFormSectionTitle@L530`; `_LeadFormField@L563`; `_BackendUnavailableState@L649`; `_LeadsContent@L680`; `_LeadsHeader@L801`; `_HeaderBackButton@L925`; `_HeaderCountBadge@L951`; `_LeadSearchField@L977`; `_LeadSearchFieldState@L987`; `_LeadStatusFilters@L1063`; `_StatusFilterButton@L1109`; `_LeadOverviewGrid@L1177`; `_LeadMetricCard@L1247`; `_SectionHeading@L1335`; `_LeadCard@L1369`; `_LeadAvatar@L1562`; `_LeadStatusBadge@L1590`; `_LeadMetadata@L1616`; `_LeadStageTag@L1649`; `_LeadListFooter@L1682`; `_LeadsLoadingView@L1768`.

Styles: 16 numeric font declarations, 11.5–27; smallest `leads_screen.dart@L1672`. 

layout constraints: `L260@L260`, `L1185@L1185`.

modal/menu/picker: `L180@L180`.

state/recovery: `L124@L124`, `L127@L127`, `L264@L264`, `L668@L668`, `L738@L738`, `L747@L747`.



#### `omc_app/lib/features/notifications/presentation/notification_detail_screen.dart`

Owner/contracts: Notification detail. Source: [notification_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/notifications/presentation/notification_detail_screen.dart#L1). 919 lines.

Declared surfaces/helpers: `NotificationDetailScreen@L18`; `_NotificationDetailBody@L66`; `_NotificationDetailBodyState@L76`; `_NotificationHeroCard@L407`; `_DetailSection@L507`; `_ActionsCard@L553`; `_InfoPill@L605`; `_DetailTile@L635`; `_ActionButton@L695`; `_NotificationDetailLoadingView@L766`; `_LoadingDetailTile@L822`; `_LoadingBox@L849`; `_LoadingPill@L873`; `_LoadingBar@L891`; `_DividerIndent@L912`.

Styles: 10 numeric font declarations, 11–23; smallest `notification_detail_screen.dart@L626`. 

state/recovery: `L48@L48`, `L49@L49`, `L51@L51`, `L52@L52`.



#### `omc_app/lib/features/notifications/presentation/notifications_screen.dart`

Owner/contracts: Alerts / notifications. Source: [notifications_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/notifications/presentation/notifications_screen.dart#L1). 554 lines.

Declared surfaces/helpers: `NotificationsScreen@L13`; `_NotificationsScreenState@L21`; `_Header@L243`; `_NotificationList@L290`; `_NotificationRow@L350`; `_EmptyState@L474`; `_ErrorView@L513`; `_LoadingView@L536`.

Styles: 9 numeric font declarations, 10.5–24; smallest `notifications_screen.dart@L415`. 

state/recovery: `L89@L89`, `L90@L90`, `L524@L524`, `L525@L525`.



#### `omc_app/lib/features/onboarding/presentation/onboarding_screen.dart`

Owner/contracts: Onboarding. Source: [onboarding_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/onboarding/presentation/onboarding_screen.dart#L1). 316 lines.

Declared surfaces/helpers: `OnboardingScreen@L13`; `_OnboardingScreenState@L20`; `_OnboardingSlideView@L148`; `_SlideImage@L224`; `_PageDots@L291`.

Styles: 2 numeric font declarations, 15.5–31; smallest `onboarding_screen.dart@L197`. 

layout constraints: `L160@L160`.



#### `omc_app/lib/features/payments/presentation/payment_detail_screen.dart`

Owner/contracts: Payment detail and review, Payment approve / reject review dialog. Source: [payment_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/payment_detail_screen.dart#L1). 1071 lines.

Declared surfaces/helpers: `PaymentDetailScreen@L24`; `_DetailLoadingView@L87`; `_LoadingBar@L193`; `_PaymentHeroCard@L214`; `_PaymentQuickStats@L292`; `_PaymentStatTile@L321`; `_PaymentInfoCard@L377`; `_PaymentInfoRow@L438`; `_PaymentTimelinePlaceholder@L485`; `_PaymentAdminReviewCard@L557`; `_PaymentDetailBody@L644`; `_PaymentDetailBodyState@L659`.

Styles: 12 numeric font declarations, 11–25; smallest `payment_detail_screen.dart@L367`. 

modal/menu/picker: `L759@L759`, `L847@L847`, `L878@L878`.

state/recovery: `L65@L65`, `L70@L70`, `L72@L72`, `L73@L73`.



#### `omc_app/lib/features/payments/presentation/payments_screen.dart`

Owner/contracts: Payments list. Source: [payments_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/payments_screen.dart#L1). 604 lines.

Declared surfaces/helpers: `PaymentsScreen@L12`; `_PaymentsList@L43`; `_PaymentsHeader@L108`; `_PaymentCard@L235`; `_StatusPill@L395`; `_EmptyPaymentsView@L512`; `_PaymentsErrorView@L537`; `_PaymentsLoadingView@L564`.

Styles: 13 numeric font declarations, 10–22; smallest `payments_screen.dart@L421`. 

state/recovery: `L31@L31`, `L32@L32`, `L33@L33`, `L551@L551`, `L552@L552`.



#### `omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart`

Owner/contracts: Settlement exceptions, Resolve / ignore exception confirmation. Source: [settlement_exceptions_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart#L1). 566 lines.

Declared surfaces/helpers: `SettlementExceptionsScreen@L9`; `_SettlementExceptionsScreenState@L17`; `_Filters@L272`; `_ReviewCard@L336`; `_StatusChip@L467`; `_Pager@L481`; `_InfoBanner@L523`.

Styles: 1 numeric font declarations, 16–16; smallest `settlement_exceptions_screen.dart@L379`. 

modal/menu/picker: `L191@L191`.

state/recovery: `L63@L63`, `L64@L64`.



#### `omc_app/lib/features/payments/presentation/widgets/payment_action_card.dart`

Owner/contracts: Receipt upload action/progress. Source: [payment_action_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/widgets/payment_action_card.dart#L1). 323 lines.

Declared surfaces/helpers: `PaymentActionCard@L8`; `_UploadProgressPanel@L151`; `_ActionHeaderIcon@L207`; `_ActionTile@L225`.

Styles: 5 numeric font declarations, 12–18; smallest `payment_action_card.dart@L75`. 



#### `omc_app/lib/features/profile/presentation/edit_profile_screen.dart`

Owner/contracts: Profile details editor, Personal / contact / professional / identity edit sheets, Verified identity confirmation dialog, Locked identity explanation sheet. Source: [edit_profile_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/edit_profile_screen.dart#L1). 1302 lines.

Declared surfaces/helpers: `EditProfileScreen@L15`; `_ProfileEditorOverview@L46`; `_CompletionCard@L158`; `_ProfileEditSectionCard@L229`; `_ProfileValueRow@L305`; `_InternalAccountCard@L354`; `_IdentityBusinessCard@L397`; `_IdentityBusinessRow@L500`; `_LockedValueTile@L587`; `_ProfileEditSheet@L921`; `_ProfileEditSheetState@L944`; `_SheetTextField@L1126`; `_ProfileEditorLoading@L1165`; `_ProfileEditorUnavailable@L1174`; `_ProfileEditorError@L1191`.

Styles: 16 numeric font declarations, 11.5–21; smallest `edit_profile_screen.dart@L545`. 

layout constraints: `L1034@L1034`.

modal/menu/picker: `L904@L904`, `L963@L963`, `L1215@L1215`.

state/recovery: `L39@L39`, `L40@L40`, `L1036@L1036`.



#### `omc_app/lib/features/profile/presentation/my_referrals_screen.dart`

Owner/contracts: My referrals. Source: [my_referrals_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/my_referrals_screen.dart#L1). 601 lines.

Declared surfaces/helpers: `MyReferralsScreen@L16`; `_MyReferralsScreenState@L23`; `_ReferralHero@L245`; `_PrimaryMetrics@L348`; `_SecondaryMetrics@L370`; `_Metric@L386`; `_CompactMetric@L419`; `_SearchCard@L443`; `_ReferralCustomerCard@L476`; `_StatusChip@L570`.

Styles: 12 numeric font declarations, 10.5–26; smallest `my_referrals_screen.dart@L410`. 

state/recovery: `L142@L142`, `L143@L143`.



#### `omc_app/lib/features/profile/presentation/profile_screen.dart`

Owner/contracts: Profile, Profile support request sheet, Profile photo selection / upload. Source: [profile_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/profile_screen.dart#L1). 1207 lines.

Declared surfaces/helpers: `ProfileScreen@L18`; `_ProfileLoadingView@L98`; `_ProfileHeroSkeleton@L115`; `_ProfileSectionSkeleton@L152`; `_LoadingProfileTile@L173`; `_ProfileUnavailableView@L200`; `_ProfileContent@L293`; `_ProfileRequestSheet@L572`; `_ProfileHeroCard@L669`; `_ProfileStatusChip@L744`; `_ProfileChipStyle@L775`; `_ProfileAvatar@L882`; `_ProfileSection@L994`; `_ProfileTile@L1045`; `_DividerIndent@L1120`; `_ProfileFootnote@L1135`; `_LoadingBar@L1153`; `_LoadingPill@L1175`; `_LoadingIconBox@L1193`.

Styles: 14 numeric font declarations, 12–25; smallest `profile_screen.dart@L766`. 

layout constraints: `L589@L589`.

modal/menu/picker: `L495@L495`.

state/recovery: `L47@L47`, `L48@L48`.



#### `omc_app/lib/features/profile/presentation/referral_detail_screen.dart`

Owner/contracts: Referral detail. Source: [referral_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/referral_detail_screen.dart#L1). 461 lines.

Declared surfaces/helpers: `ReferralDetailScreen@L14`; `_ReferralDetailScreenState@L29`; `_MetricGrid@L233`; `_Metric@L252`; `_ServiceCard@L287`; `_RequestCard@L323`; `_SectionTitle@L385`; `_Chip@L402`; `_CountChip@L428`.

Styles: 10 numeric font declarations, 10.5–22; smallest `referral_detail_screen.dart@L420`. 

state/recovery: `L77@L77`, `L78@L78`.



#### `omc_app/lib/features/profile/presentation/widgets/profile_action_card.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [profile_action_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/widgets/profile_action_card.dart#L1). 141 lines.

Declared surfaces/helpers: `ProfileActionCard@L6`; `_ProfileActionTile@L70`.

Styles: 4 numeric font declarations, 11.5–18; smallest `profile_action_card.dart@L123`. 



#### `omc_app/lib/features/profile/presentation/widgets/referral_summary_card.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [referral_summary_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/widgets/referral_summary_card.dart#L1). 255 lines.

Declared surfaces/helpers: `ReferralSummaryCard@L9`; `_StatusBadge@L184`; `_CountTile@L217`.

Styles: 7 numeric font declarations, 10.5–22; smallest `referral_summary_card.dart@L247`. 



#### `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen.dart`

Owner/contracts: Export/part/support definitions; resolve containing screen. Source: [service_catalogue_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen.dart#L1). 1 lines.

Declared surfaces/helpers: No class declaration; export/part/functions..



#### `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart`

Owner/contracts: Service catalogue, Catalogue category filters. Source: [service_catalogue_screen_impl.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart#L1). 828 lines.

Declared surfaces/helpers: `ServiceCatalogueScreen@L20`; `_ServiceCatalogueScreenState@L39`; `_PageHeading@L362`; `_SearchField@L395`; `_CategoryStrip@L487`; `_ServiceFilterChip@L523`; `_SectionHeader@L577`; `_ServiceIconTile@L615`; `_ServiceListEmptyState@L678`; `_FilterPill@L735`.

Styles: 9 numeric font declarations, 12.25–27; smallest `service_catalogue_screen_impl.dart@L663`. 

layout constraints: `L200@L200`, `L216@L216`, `L219@L219`.

modal/menu/picker: `L268@L268`.

state/recovery: `L90@L90`, `L91@L91`.



#### `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_modern.dart`

Owner/contracts: Export/part/support definitions; resolve containing screen. Source: [service_catalogue_screen_modern.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_modern.dart#L1). 1 lines.

Declared surfaces/helpers: No class declaration; export/part/functions..



#### `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_premium.dart`

Owner/contracts: Export/part/support definitions; resolve containing screen. Source: [service_catalogue_screen_premium.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_premium.dart#L1). 1 lines.

Declared surfaces/helpers: No class declaration; export/part/functions..



#### `omc_app/lib/features/service_catalogue/presentation/service_detail_screen.dart`

Owner/contracts: Export/part/support definitions; resolve containing screen. Source: [service_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_detail_screen.dart#L1). 1 lines.

Declared surfaces/helpers: No class declaration; export/part/functions..



#### `omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart`

Owner/contracts: Service detail, Existing / in-progress requests sheet. Source: [service_detail_screen_impl.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart#L1). 1254 lines.

Declared surfaces/helpers: `ServiceDetailScreen@L29`; `_ExistingServiceRequestsSheet@L365`; `_ServiceDetailLoadingView@L540`; `_LoadingSection@L608`; `_LoadingStatCard@L652`; `_HeroCard@L671`; `_SectionCard@L818`; `_ChecklistCard@L866`; `_SupportCard@L917`; `_ChecklistRow@L992`; `_ProcessCard@L1041`; `_ProcessRow@L1085`; `_NoticePill@L1139`; `_LoadingBlock@L1168`; `_WizardBadge@L1194`; `_Tone@L1223`.

Styles: 20 numeric font declarations, 11–22; smallest `service_detail_screen_impl.dart@L1114`. 

modal/menu/picker: `L276@L276`.

state/recovery: `L57@L57`, `L61@L61`, `L63@L63`, `L85@L85`.



#### `omc_app/lib/features/service_catalogue/presentation/service_visual_registry.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [service_visual_registry.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_visual_registry.dart#L1). 194 lines.

Declared surfaces/helpers: `ServiceVisual@L6`.



#### `omc_app/lib/features/service_requests/presentation/assisted_customer_card.dart`

Owner/contracts: Assisted customer selector. Source: [assisted_customer_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/assisted_customer_card.dart#L1). 333 lines.

Declared surfaces/helpers: `AssistedCustomerDraftSelection@L8`; `AssistedCustomerCard@L22`; `_AssistedCustomerCardState@L39`.

Styles: 2 numeric font declarations, 12–15; smallest `assisted_customer_card.dart@L211`. 

layout constraints: `L270@L270`.



#### `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart`

Owner/contracts: Customer required-document upload rows. Source: [customer_service_case_detail_evidence.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart#L1). 616 lines.

Declared surfaces/helpers: `_DocumentsCard@L3`; `_DocumentsCardState@L18`; `_DocumentRow@L181`; `_PaymentCard@L349`; `_RecentActivityCard@L481`; `_CancelRequestCard@L569`.

Styles: 16 numeric font declarations, 10.5–17; smallest `customer_service_case_detail_evidence.dart@L287`. 

state/recovery: `L87@L87`.



#### `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart`

Owner/contracts: Customer request detail, Customer cancel request confirmation. Source: [customer_service_case_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart#L1). 201 lines.

Declared surfaces/helpers: `CustomerServiceCaseDetailScreen@L26`; `_CustomerServiceCaseDetailScreenState@L36`.

modal/menu/picker: `L154@L154`.

state/recovery: `L68@L68`, `L69@L69`.



#### `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_sections.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [customer_service_case_detail_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_sections.dart#L1). 504 lines.

Declared surfaces/helpers: `_ServiceHero@L3`; `_StatusPill@L102`; `_Meta@L131`; `_LifecycleCard@L170`; `_MilestoneRow@L266`; `_NextStepCard@L366`.

Styles: 14 numeric font declarations, 10.5–20; smallest `customer_service_case_detail_sections.dart@L149`. 



#### `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_support.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [customer_service_case_detail_support.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_support.dart#L1). 115 lines.

Declared surfaces/helpers: `_LoadingView@L3`; `_ErrorView@L21`.

state/recovery: `L33@L33`.



#### `omc_app/lib/features/service_requests/presentation/my_services_screen.dart`

Owner/contracts: My Services / Requests, Request sort sheet, Request filter sheet. Source: [my_services_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/my_services_screen.dart#L1). 1412 lines.

Declared surfaces/helpers: `MyServicesScreen@L15`; `_MyServicesScreenState@L22`; `_TrackHeader@L364`; `_SearchAndFilterRow@L429`; `_FilterRow@L516`; `_ServiceCard@L589`; `_StatusPill@L863`; `_LoadingState@L889`; `_LoadingBlock@L931`; `_ErrorState@L957`; `_EmptyState@L1000`; `_FilterEmptyState@L1057`; `_Counts@L1099`; `_ServiceCaseState@L1163`; `_Palette@L1279`.

Styles: 21 numeric font declarations, 10–27; smallest `my_services_screen.dart@L812`. 

layout constraints: `L217@L217`, `L282@L282`.

modal/menu/picker: `L198@L198`, `L263@L263`.

state/recovery: `L45@L45`, `L46@L46`, `L47@L47`, `L976@L976`, `L977@L977`.



#### `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart`

Owner/contracts: Assisted / operational request detail, Legacy reassign dialog, Legacy discount rejection dialog, Operational/assisted cancellation dialog, Required document upload sheet. Source: [service_case_detail_legacy_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L1). 3074 lines.

Declared surfaces/helpers: `ServiceCaseDetailScreen@L20`; `_ServiceCaseDetailScreenState@L37`; `_DiscountRejectionDialog@L568`; `_DiscountRejectionDialogState@L576`; `_RequestAttributionNotice@L635`; `_DocumentUploadSheet@L727`; `_DocumentUploadSheetState@L746`; `_SelectedFileTile@L1104`; `_LoadingView@L1228`; `_ErrorView@L1237`; `_AdminOperationsCard@L1323`; `_CaseHero@L1407`; `_HeroMeta@L1569`; `_CaseStatusBadge@L1632`; `_ProgressCard@L1702`; `_HorizontalProgressContent@L1923`; `_HorizontalProgressStep@L1967`; `_RecentActivityCard@L2072`; `_ActivityRow@L2139`; `_CaseInfoCard@L2223`; `_RequiredDocumentsCard@L2303`; `_DocumentRequirementRow@L2406`; `_CaseActionsCard@L2573`; `_ResolvedCaseAction@L2877`; `_PrimaryCaseActionButton@L2895`; `_SecondaryCaseAction@L2978`; `_InfoRow@L3033`.

Styles: 49 numeric font declarations, 9.5–34; smallest `service_case_detail_legacy_screen.dart@L2063`. 

layout constraints: `L768@L768`, `L1422@L1422`, `L1717@L1717`, `L2703@L2703`.

modal/menu/picker: `L216@L216`, `L258@L258`, `L301@L301`, `L445@L445`.

state/recovery: `L79@L79`, `L80@L80`, `L131@L131`, `L160@L160`, `L602@L602`, `L772@L772`, `L2693@L2693`.



#### `omc_app/lib/features/service_requests/presentation/service_case_detail_screen.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [service_case_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_screen.dart#L1). 41 lines.

Declared surfaces/helpers: `ServiceCaseDetailScreen@L8`.



#### `omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart`

Owner/contracts: Dynamic service form controls, Request submit bar. Source: [service_request_draft_form_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart#L1). 594 lines.

Declared surfaces/helpers: `_DynamicFormCard@L3`; `_DynamicField@L68`; `_StagesCard@L153`; `_CompactStageRow@L214`; `_RequiredDocumentsCard@L300`; `_SubmitRequestBar@L376`; `_CardTitle@L456`.

Styles: 9 numeric font declarations, 11–16; smallest `service_request_draft_form_sections.dart@L247`. 

layout constraints: `L411@L411`, `L415@L415`.



#### `omc_app/lib/features/service_requests/presentation/service_request_draft_screen.dart`

Owner/contracts: Service request creation. Source: [service_request_draft_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_screen.dart#L1). 658 lines.

Declared surfaces/helpers: `ServiceRequestDraftScreen@L32`; `_ServiceRequestDraftScreenState@L51`.

state/recovery: `L128@L128`, `L132@L132`, `L136@L136`, `L137@L137`, `L176@L176`.



#### `omc_app/lib/features/service_requests/presentation/service_request_draft_service_sections.dart`

Owner/contracts: Internal discount form. Source: [service_request_draft_service_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_service_sections.dart#L1). 318 lines.

Declared surfaces/helpers: `_InternalDiscountCard@L3`; `_DiscountSummaryRow@L125`; `_SelectedServiceCard@L150`; `_ContactDetailsCard@L234`.

Styles: 3 numeric font declarations, 11.5–16; smallest `service_request_draft_service_sections.dart@L212`. 



#### `omc_app/lib/features/settings/presentation/change_password_screen.dart`

Owner/contracts: Change password. Source: [change_password_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/change_password_screen.dart#L1). 294 lines.

Declared surfaces/helpers: `ChangePasswordScreen@L15`; `_ChangePasswordScreenState@L23`.

state/recovery: `L157@L157`.



#### `omc_app/lib/features/settings/presentation/settings_screen.dart`

Owner/contracts: Settings, Enable biometric sign-in password dialog, Account deletion request sheet, Logout confirmation sheet, Privacy / terms fallback sheets. Source: [settings_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L1). 1057 lines.

Declared surfaces/helpers: `SettingsScreen@L31`; `_SettingsHero@L623`; `_PreferencesSection@L671`; `_PreferencesLoadingSection@L745`; `_SettingsSection@L759`; `_SettingsTile@L795`; `_SwitchTile@L826`; `_AccountRequestSheet@L853`; `_InlineError@L917`; `_SettingsFootnote@L939`; `_DividerIndent@L952`; `_LargeIcon@L961`; `_SmallIcon@L981`; `_TextStyles@L1005`.

Styles: 8 numeric font declarations, 12–26; smallest `settings_screen.dart@L1041`. 

layout constraints: `L870@L870`.

modal/menu/picker: `L358@L358`, `L433@L433`, `L473@L473`, `L549@L549`.

state/recovery: `L142@L142`, `L143@L143`.



#### `omc_app/lib/features/splash/presentation/splash_screen.dart`

Owner/contracts: Splash / startup. Source: [splash_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/splash/presentation/splash_screen.dart#L1). 210 lines.

Declared surfaces/helpers: `SplashScreen@L15`; `_SplashScreenState@L22`; `_SplashFailure@L99`; `_SplashContent@L151`.

Styles: 3 numeric font declarations, 13–22; smallest `splash_screen.dart@L190`. 



#### `omc_app/lib/features/support/presentation/support_screen.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [support_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_screen.dart#L1). 169 lines.

Declared surfaces/helpers: `SupportScreen@L12`; `_SupportScreenState@L19`.

state/recovery: `L73@L73`.



#### `omc_app/lib/features/support/presentation/support_screen_legacy.dart`

Owner/contracts: Support customer / public / internal workspace, Create support ticket form, Support FAQ/topics/contact sections. Source: [support_screen_legacy.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_screen_legacy.dart#L1). 1698 lines.

Declared surfaces/helpers: `SupportScreen@L19`; `_SupportScreenState@L26`; `_SupportHeroCard@L246`; `_SupportMetric@L325`; `_SupportCategoriesCard@L377`; `_CreateSupportTicketCard@L413`; `_SupportTicketsCard@L502`; `_SupportTicketsCardState@L512`; `_SupportTicketTabs@L809`; `_SupportTabButton@L857`; `_BackendFaqCard@L945`; `_SupportContactChannelsCard@L977`; `_TopicRow@L1008`; `_TicketTile@L1073`; `_FaqTile@L1300`; `_ChannelTile@L1322`; `_InfoRow@L1371`; `_SectionHeader@L1404`; `_LockedNote@L1423`; `_EmptyTickets@L1438`; `_ErrorNote@L1456`; `_InlineNote@L1483`; `_IconBox@L1506`; `_TextStyles@L1533`.

Styles: 16 numeric font declarations, 10–22; smallest `support_screen_legacy.dart@L932`. 

state/recovery: `L79@L79`, `L782@L782`, `L786@L786`.



#### `omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart`

Owner/contracts: Support conversation, Conversation composer / attachments, Internal ticket status sheet. Source: [support_ticket_detail_legacy_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart#L1). 1603 lines.

Declared surfaces/helpers: `SupportTicketDetailScreen@L21`; `_SupportTicketChatBody@L98`; `_SupportTicketChatBodyState@L108`; `_TicketInfoCard@L477`; `_CustomerInformationCard@L563`; `_CustomerBadge@L660`; `_ContextRow@L683`; `_ConversationHeader@L723`; `_EmptyConversationBubble@L739`; `_ChatBubble@L765`; `_AttachmentTile@L875`; `_SupportChatComposer@L980`; `_PickedAttachmentPreview@L1134`; `_SupportAdminStatusBar@L1199`; `_StatusSheetOption@L1311`; `_StatusPill@L1407`; `_TicketDetailLoadingView@L1448`; `_TicketLoadingBlock@L1507`; `_PickedSupportAttachment@L1533`.

Styles: 26 numeric font declarations, 10–18; smallest `support_ticket_detail_legacy_screen.dart@L675`. 

modal/menu/picker: `L1255@L1255`.

state/recovery: `L81@L81`, `L82@L82`, `L84@L84`, `L85@L85`, `L177@L177`.



#### `omc_app/lib/features/support/presentation/support_ticket_detail_screen.dart`

Owner/contracts: Owning imported/part screen; shared component migration in F. Source: [support_ticket_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_ticket_detail_screen.dart#L1). 58 lines.

Declared surfaces/helpers: `SupportTicketDetailScreen@L8`.

state/recovery: `L30@L30`.



#### `omc_app/lib/features/tasks/presentation/task_detail_screen.dart`

Owner/contracts: Task detail. Source: [task_detail_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tasks/presentation/task_detail_screen.dart#L1). 419 lines.

Declared surfaces/helpers: `TaskDetailScreen@L13`; `_TaskDetailScreenState@L22`; `_TaskHero@L131`; `_ReadOnlyNotice@L206`; `_TaskDetails@L249`; `_DetailRow@L320`; `_Pill@L358`; `_MissingTask@L385`.

Styles: 10 numeric font declarations, 10–19; smallest `task_detail_screen.dart@L377`. 

state/recovery: `L39@L39`, `L40@L40`, `L44@L44`, `L45@L45`.



#### `omc_app/lib/features/tasks/presentation/tasks_screen.dart`

Owner/contracts: Tasks list, Task priority filter sheet. Source: [tasks_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tasks/presentation/tasks_screen.dart#L1). 998 lines.

Declared surfaces/helpers: `TasksScreen@L13`; `_TasksScreenState@L23`; `_TasksContent@L307`; `_TasksPageHeader@L464`; `_TaskHeaderBackButton@L520`; `_TaskHeaderCountBadge@L546`; `_SearchBar@L572`; `_SearchBarState@L589`; `_StatusTabs@L684`; `_TaskCard@L715`; `_TaskStatusBadge@L846`; `_TaskMetadata@L889`; `_TasksLoadingView@L929`; `_TasksErrorView@L946`.

Styles: 9 numeric font declarations, 10.5–20; smallest `tasks_screen.dart@L881`. 

modal/menu/picker: `L188@L188`.

state/recovery: `L286@L286`, `L391@L391`, `L960@L960`.



#### `omc_app/lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart`

Owner/contracts: Tax estimate history. Source: [tax_calculation_history_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart#L1). 526 lines.

Declared surfaces/helpers: `TaxCalculationHistoryScreen@L6`; `_TaxCalculationHistoryScreenState@L14`; `_HistoryFiltersCard@L127`; `_FilterRow@L206`; `_FilterChip@L252`; `_InlineEmptyState@L287`; `_HistoryCard@L323`; `_Chip@L415`; `_KeyValue@L439`; `_StateMessage@L474`.

Styles: 4 numeric font declarations, 16–20; smallest `tax_calculation_history_screen.dart@L174`. 



#### `omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart`

Owner/contracts: Tax calculator, Tax result / breakdown / comparison, Advanced tax inputs. Source: [tax_calculator_screen.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart#L1). 1311 lines.

Declared surfaces/helpers: `TaxCalculatorScreen@L16`; `_TaxCalculatorScreenState@L24`; `_HeaderCard@L426`; `_InputCard@L552`; `_AdvancedSection@L630`; `_AdvancedField@L692`; `_ResultSection@L757`; `_BreakdownCard@L895`; `_ComparisonCard@L948`; `_StepsCard@L984`; `_SegmentBlock@L1021`; `_MetricTile@L1064`; `_NoticeCard@L1093`; `_Card@L1133`; `_SectionTitle@L1155`; `_Chip@L1179`; `_KeyValue@L1217`.

Styles: 3 numeric font declarations, 16–20; smallest `tax_calculator_screen.dart@L875`. 

state/recovery: `L108@L108`, `L109@L109`, `L122@L122`, `L250@L250`.




### B5. Surface audit index

**146 audit tables**: route screens/variants, independent inline steps, modal renderers and global/platform interactions. Related row/icon/skeleton children are enumerated in B4 and inherit the relevant E/C/F contract.

| Audit | Route / entry | Priority |
|---|---|---|
| [E001: Approved customer Home](#e001-approved-customer-home) | /home | P0 |
| [E002: Guest / pending / rejected Home](#e002-guest--pending--rejected-home) | /home via home_screen_role_aware.dart | P1 |
| [E003: Internal Home](#e003-internal-home) | /home via home_screen_role_aware.dart | P1 |
| [E004: Dashboard customer / internal variants](#e004-dashboard-customer--internal-variants) | /dashboard | P2 |
| [E005: Service catalogue](#e005-service-catalogue) | /services | P0 |
| [E006: Service detail](#e006-service-detail) | /services/:serviceId | P0 |
| [E007: Service request creation](#e007-service-request-creation) | /services/:serviceId/request | P0 |
| [E008: Assisted customer selector](#e008-assisted-customer-selector) | Request draft inline | P0 |
| [E009: My Services / Requests](#e009-my-services--requests) | /track and /my-services | P0 |
| [E010: Customer request detail](#e010-customer-request-detail) | /my-services/:caseId canonical variant | P0 |
| [E011: Assisted / operational request detail](#e011-assisted--operational-request-detail) | /my-services/:caseId fallback | P0 |
| [E012: Documents list](#e012-documents-list) | /documents customer or assisted | P0 |
| [E013: Document detail](#e013-document-detail) | /documents/:documentId | P0 |
| [E014: Document / invoice / proof preview](#e014-document--invoice--proof-preview) | Navigator route; document review / invoice / payment proof, plus shared preview flow | P1 |
| [E015: Document review workspace](#e015-document-review-workspace) | /internal-workspace/documents; /documents reviewer variant | P0 |
| [E016: Payments list](#e016-payments-list) | /payments | P0 |
| [E017: Payment detail and review](#e017-payment-detail-and-review) | /payments/:paymentId | P0 |
| [E018: Tax calculator](#e018-tax-calculator) | /tax-calculator | P0 |
| [E019: Tax estimate history](#e019-tax-estimate-history) | /tax-calculator/history | P1 |
| [E020: Knowledge & news](#e020-knowledge--news) | /knowledge | P1 |
| [E021: Knowledge article](#e021-knowledge-article) | /knowledge/:articleId | P1 |
| [E022: Alerts / notifications](#e022-alerts--notifications) | /notifications | P0 |
| [E023: Notification detail](#e023-notification-detail) | /notifications/:notificationId | P1 |
| [E024: Support customer / public / internal workspace](#e024-support-customer--public--internal-workspace) | /support inside freshness wrapper | P0 |
| [E025: Support conversation](#e025-support-conversation) | /support-tickets/:ticketId inside freshness wrapper | P0 |
| [E026: Expense Tracker](#e026-expense-tracker) | /expense-tracker | P1 |
| [E027: Monthly budget](#e027-monthly-budget) | /expense-budget | P1 |
| [E028: Profile](#e028-profile) | /profile | P1 |
| [E029: Profile details editor](#e029-profile-details-editor) | /profile/edit | P1 |
| [E030: Settings](#e030-settings) | /settings | P1 |
| [E031: Change password](#e031-change-password) | /change-password | P0 |
| [E032: Splash / startup](#e032-splash--startup) | / | P1 |
| [E033: Onboarding](#e033-onboarding) | /onboarding | P1 |
| [E034: Login](#e034-login) | /login | P0 |
| [E035: Signup flow](#e035-signup-flow) | /signup | P0 |
| [E036: Forgot password](#e036-forgot-password) | /forgot-password | P1 |
| [E037: Reset password](#e037-reset-password) | /reset-password?token=…; /app/reset-password alias | P0 |
| [E038: Activate existing account](#e038-activate-existing-account) | /activate-existing-account | P1 |
| [E039: Complete customer activation](#e039-complete-customer-activation) | /activate-account?token=…; /app/activate-account alias | P0 |
| [E040: Email verification / account completion](#e040-email-verification--account-completion) | /verify-email?token=…; /app/verify-email alias | P0 |
| [E041: Under review](#e041-under-review) | /under-review | P1 |
| [E042: Device lock / biometrics](#e042-device-lock--biometrics) | Global DeviceLockGate overlay | P0 |
| [E043: Readiness / maintenance / update gates](#e043-readiness--maintenance--update-gates) | Global AppReadinessGate / MobileReadinessOverlay | P0 |
| [E044: Customers directory](#e044-customers-directory) | /customers; /internal-workspace/customers | P1 |
| [E045: Customer detail](#e045-customer-detail) | /customers/:customerId | P1 |
| [E046: Internal workspace](#e046-internal-workspace) | /internal-workspace | P0 |
| [E047: Service case queue](#e047-service-case-queue) | /internal-workspace/service-cases | P0 |
| [E048: Internal payment operations](#e048-internal-payment-operations) | /internal-workspace/payments | P0 |
| [E049: Internal case workspace](#e049-internal-case-workspace) | /internal-workspace/service-cases/:caseId | P0 |
| [E050: Leads pipeline](#e050-leads-pipeline) | /leads; ?action=create | P1 |
| [E051: Lead detail](#e051-lead-detail) | /leads/:leadId | P2 |
| [E052: Tasks list](#e052-tasks-list) | /tasks | P1 |
| [E053: Task detail](#e053-task-detail) | /tasks/:taskId | P1 |
| [E054: My referrals](#e054-my-referrals) | /my-referrals | P1 |
| [E055: Referral detail](#e055-referral-detail) | /my-referrals/:customerId?customer_name=… | P0 |
| [E056: My commissions](#e056-my-commissions) | /my-commissions | P1 |
| [E057: Commission detail](#e057-commission-detail) | /my-commissions/:earningId | P1 |
| [E058: Commission operations](#e058-commission-operations) | /internal-workspace/commissions | P0 |
| [E059: Settlement exceptions](#e059-settlement-exceptions) | Navigator from internal workspace; no GoRoute | P0 |
| [E060: Administration](#e060-administration) | /admin-control | P0 |
| [E061: Operational controls](#e061-operational-controls) | /admin-control/operations | P0 |
| [E062: Application shell and back navigation](#e062-application-shell-and-back-navigation) | StatefulShellRoute + ShellNavScaffold | P0 |
| [E063: Bottom navigation](#e063-bottom-navigation) | Persistent shell bottom navigation | P0 |
| [E064: More menu](#e064-more-menu) | /more or bottom More | P0 |
| [E065: Quick Actions](#e065-quick-actions) | Central action sheet | P0 |
| [E066: Unknown / invalid route recovery](#e066-unknown--invalid-route-recovery) | GoRouter errorBuilder | P1 |
| [E067: Unsaved changes confirmation](#e067-unsaved-changes-confirmation) | Global form discard dialog | P0 |
| [E068: Signup role step](#e068-signup-role-step) | Inline / state surface: Signup role step | P1 |
| [E069: Signup details step](#e069-signup-details-step) | Inline / state surface: Signup details step | P1 |
| [E070: Signup preferences step](#e070-signup-preferences-step) | Inline / state surface: Signup preferences step | P1 |
| [E071: Signup security/review step](#e071-signup-securityreview-step) | Inline / state surface: Signup security/review step | P1 |
| [E072: Pending registration success](#e072-pending-registration-success) | Inline / state surface: Pending registration success | P0 |
| [E073: Dynamic service form controls](#e073-dynamic-service-form-controls) | Inline / state surface: Dynamic service form controls | P1 |
| [E074: Internal discount form](#e074-internal-discount-form) | Inline / state surface: Internal discount form | P1 |
| [E075: Request submit bar](#e075-request-submit-bar) | Inline / state surface: Request submit bar | P1 |
| [E076: Customer required-document upload rows](#e076-customer-required-document-upload-rows) | Inline / state surface: Customer required-document upload rows | P1 |
| [E077: Receipt upload action/progress](#e077-receipt-upload-actionprogress) | Inline / state surface: Receipt upload action/progress | P1 |
| [E078: Create support ticket form](#e078-create-support-ticket-form) | Inline / state surface: Create support ticket form | P0 |
| [E079: Support FAQ/topics/contact sections](#e079-support-faqtopicscontact-sections) | Inline / state surface: Support FAQ/topics/contact sections | P0 |
| [E080: Conversation composer / attachments](#e080-conversation-composer--attachments) | Inline / state surface: Conversation composer / attachments | P0 |
| [E081: Tax result / breakdown / comparison](#e081-tax-result--breakdown--comparison) | Inline / state surface: Tax result / breakdown / comparison | P0 |
| [E082: Advanced tax inputs](#e082-advanced-tax-inputs) | Inline / state surface: Advanced tax inputs | P0 |
| [E083: Home content rail](#e083-home-content-rail) | Inline / state surface: Home content rail | P1 |
| [E084: Home featured carousel](#e084-home-featured-carousel) | Inline / state surface: Home featured carousel | P1 |
| [E085: Home service-search suggestions](#e085-home-service-search-suggestions) | Inline / state surface: Home service-search suggestions | P1 |
| [E086: Cloud expense history / local pending entries](#e086-cloud-expense-history--local-pending-entries) | Inline / state surface: Cloud expense history / local pending entries | P1 |
| [E087: Freshness warning / retry](#e087-freshness-warning--retry) | Inline / state surface: Freshness warning / retry | P1 |
| [E088: Shared empty / error / access / configuration state](#e088-shared-empty--error--access--configuration-state) | Inline / state surface: Shared empty / error / access / configuration state | P1 |
| [E089: Loading skeleton](#e089-loading-skeleton) | Inline / state surface: Loading skeleton | P1 |
| [E090: Recommended update state](#e090-recommended-update-state) | Inline / state surface: Recommended update state | P0 |
| [E091: Biometric account chooser](#e091-biometric-account-chooser) | Biometric account chooser; call site L103 | P0 |
| [E092: Login help sheet](#e092-login-help-sheet) | Login help sheet; call site L240 | P0 |
| [E093: Review support sheet](#e093-review-support-sheet) | Review support sheet; call site L82 | P1 |
| [E094: Guest protected-action sheet](#e094-guest-protected-action-sheet) | Guest protected-action sheet; call site L717 | P0 |
| [E095: Catalogue category filters](#e095-catalogue-category-filters) | Catalogue category filters; call site L268 | P0 |
| [E096: Existing / in-progress requests sheet](#e096-existing--in-progress-requests-sheet) | Existing / in-progress requests sheet; call site L276 | P0 |
| [E097: Request sort sheet](#e097-request-sort-sheet) | Request sort sheet; call site L198 | P0 |
| [E098: Request filter sheet](#e098-request-filter-sheet) | Request filter sheet; call site L263 | P0 |
| [E099: Customer cancel request confirmation](#e099-customer-cancel-request-confirmation) | Customer cancel request confirmation; call site L154 | P0 |
| [E100: Legacy reassign dialog](#e100-legacy-reassign-dialog) | Legacy reassign dialog; call site L216 | P0 |
| [E101: Legacy discount rejection dialog](#e101-legacy-discount-rejection-dialog) | Legacy discount rejection dialog; call site L258 | P0 |
| [E102: Operational/assisted cancellation dialog](#e102-operationalassisted-cancellation-dialog) | Operational/assisted cancellation dialog; call site L301 | P0 |
| [E103: Required document upload sheet](#e103-required-document-upload-sheet) | Required document upload sheet; call site L445 | P0 |
| [E104: Reject document dialog](#e104-reject-document-dialog) | Reject document dialog; call site L235 | P0 |
| [E105: Payment approve / reject review dialog](#e105-payment-approve--reject-review-dialog) | Payment approve / reject review dialog; call site L759 | P0 |
| [E106: Profile support request sheet](#e106-profile-support-request-sheet) | Profile support request sheet; call site L495 | P1 |
| [E107: Personal / contact / professional / identity edit sheets](#e107-personal--contact--professional--identity-edit-sheets) | Personal / contact / professional / identity edit sheets; call site L904 | P1 |
| [E108: Verified identity confirmation dialog](#e108-verified-identity-confirmation-dialog) | Verified identity confirmation dialog; call site L963 | P1 |
| [E109: Locked identity explanation sheet](#e109-locked-identity-explanation-sheet) | Locked identity explanation sheet; call site L1215 | P1 |
| [E110: Enable biometric sign-in password dialog](#e110-enable-biometric-sign-in-password-dialog) | Enable biometric sign-in password dialog; call site L358 | P1 |
| [E111: Account deletion request sheet](#e111-account-deletion-request-sheet) | Account deletion request sheet; call site L433 | P1 |
| [E112: Logout confirmation sheet](#e112-logout-confirmation-sheet) | Logout confirmation sheet; call site L473 | P1 |
| [E113: Privacy / terms fallback sheets](#e113-privacy--terms-fallback-sheets) | Privacy / terms fallback sheets; call site L549 | P1 |
| [E114: Internal ticket status sheet](#e114-internal-ticket-status-sheet) | Internal ticket status sheet; call site L1255 | P0 |
| [E115: Tracker storage / data tools menu](#e115-tracker-storage--data-tools-menu) | Tracker storage / data tools menu; call site L305 | P1 |
| [E116: Add / edit transaction sheet](#e116-add--edit-transaction-sheet) | Add / edit transaction sheet; call site L497 | P1 |
| [E117: Account history export progress dialog](#e117-account-history-export-progress-dialog) | Account history export progress dialog; call site L535 | P1 |
| [E118: Local JSON backup dialog](#e118-local-json-backup-dialog) | Local JSON backup dialog; call site L596 | P1 |
| [E119: Import JSON backup dialog](#e119-import-json-backup-dialog) | Import JSON backup dialog; call site L617 | P1 |
| [E120: Archive transaction confirmation](#e120-archive-transaction-confirmation) | Archive transaction confirmation; call site L745 | P1 |
| [E121: Clear local tracker confirmation](#e121-clear-local-tracker-confirmation) | Clear local tracker confirmation; call site L792 | P1 |
| [E122: Tracker period filter menu](#e122-tracker-period-filter-menu) | Tracker period filter menu; call site L1402 | P1 |
| [E123: Transaction action menu](#e123-transaction-action-menu) | Transaction action menu; call site L1654 | P1 |
| [E124: Transaction date picker](#e124-transaction-date-picker) | Transaction date picker; call site L2027 | P1 |
| [E125: Budget action menu](#e125-budget-action-menu) | Budget action menu; call site L142 | P1 |
| [E126: Add / edit budget sheet](#e126-add--edit-budget-sheet) | Add / edit budget sheet; call site L313 | P1 |
| [E127: Internal case advanced filters](#e127-internal-case-advanced-filters) | Internal case advanced filters; call site L169 | P0 |
| [E128: Task priority filter sheet](#e128-task-priority-filter-sheet) | Task priority filter sheet; call site L188 | P1 |
| [E129: Create lead sheet](#e129-create-lead-sheet) | Create lead sheet; call site L180 | P1 |
| [E130: Record paid settlement sheet](#e130-record-paid-settlement-sheet) | Record paid settlement sheet; call site L183 | P0 |
| [E131: Approve / mark-payable commission confirmation](#e131-approve--mark-payable-commission-confirmation) | Approve / mark-payable commission confirmation; call site L208 | P0 |
| [E132: Reject commission dialog](#e132-reject-commission-dialog) | Reject commission dialog; call site L230 | P0 |
| [E133: Commission settlement date picker](#e133-commission-settlement-date-picker) | Commission settlement date picker; call site L696 | P0 |
| [E134: Resolve / ignore exception confirmation](#e134-resolve--ignore-exception-confirmation) | Resolve / ignore exception confirmation; call site L191 | P0 |
| [E135: Grant existing staff access dialog](#e135-grant-existing-staff-access-dialog) | Grant existing staff access dialog; call site L154 | P0 |
| [E136: Staff access profile dialog](#e136-staff-access-profile-dialog) | Staff access profile dialog; call site L466 | P0 |
| [E137: Business numeric setting dialog](#e137-business-numeric-setting-dialog) | Business numeric setting dialog; call site L632 | P0 |
| [E138: Operational reassignment dialog](#e138-operational-reassignment-dialog) | Operational reassignment dialog; call site L225 | P0 |
| [E139: Exhausted sync retry dialog](#e139-exhausted-sync-retry-dialog) | Exhausted sync retry dialog; call site L335 | P0 |
| [E140: Discount review dialog](#e140-discount-review-dialog) | Discount review dialog; call site L378 | P0 |
| [E141: Push-open failure recovery](#e141-push-open-failure-recovery) | Global PushRuntimeHost error overlay | P0 |
| [E142: Device notification permission / registration](#e142-device-notification-permission--registration) | Settings inline Android device notifications card | P1 |
| [E143: Platform notification interaction](#e143-platform-notification-interaction) | Native Android permission/settings and foreground notification | P0 |
| [E144: Document file selection and validation](#e144-document-file-selection-and-validation) | Native file chooser from upload actions | P0 |
| [E145: Profile photo selection / upload](#e145-profile-photo-selection--upload) | Native image picker → Profile photo upload | P1 |
| [E146: Customer document external opening](#e146-customer-document-external-opening) | External app from Preview / Download actions | P0 |

### B6. Overlay, menu and platform closure

All explicit modal/menu/picker call sites in lib are accounted for by E tables. Shared renderer variants (payment approve/reject, commission approve/payable, finance resolve/ignore, profile personal/contact/professional/identity fields, privacy/terms) retain their separately named choices in the corresponding table. Direct `MaterialPageRoute` edges are: internal_workspace_screen.dart:816 → SettlementExceptionsScreen; internal_document_review_screen.dart:295 → DocumentPreviewScreen; payment_detail_screen.dart:847/:878 → invoice/proof DocumentPreviewScreen. These are covered by E059 and E014 respectively. Customer document detail uses the external launcher in E146, not those Navigator paths.

The global form discard dialog is E067; More/Quick Actions are E064/E065; the export `DialogRoute` at expense_tracker_screen.dart:535 is E117. Shared UI outside presentation/widgets is also included: PushRuntimeHost, PushDeviceSettingsTile, DirtyFormController/UnsavedChangesGuard, FirebasePushSource native interaction and DocumentAttachmentController selection/validation.

Inline dropdowns, checkboxes, radio/segmented controls, expansion tiles, file-removal buttons, copy/share, previous/next and load-more controls are owned by their E screen/inline table and inherit C5/C6/U. They are not additional backend features. Native OS permission, biometric, file/gallery chooser, external browser and share UI cannot be pixel-redesigned by Flutter: preserve the trigger/payload and verify return/cancel/failure. App-owned initiation, progress, validation, resulting error and safe back navigation are in scope. Snackbar success/failure/access messages and notification Undo remain covered by each mutation's state row and I3, with no invented undo operation for irreversible finance/admin actions.

## D. Information architecture review

### Customer navigation

KEEP the current bottom-navigation concept and exact branch indices. Actual visual order is Home, Services, central action, Requests, More. Documents is still a shell branch but appears via More; do not delete that branch because it is absent as a visible tab. Internal labels remain Home / Catalogue / central action / Cases / More; capability gating remains. The central action remains a sheet, not a selected page. Detail wrappers retain selected parent destination, and request creation remains outside the shell to avoid competing bottom bars.

Proposed More groups, in this order: **My OMC** (Documents, Payments, Alerts); **Tax & knowledge** (Tax calculator, Knowledge & news); **Tools & help** (Expense tracker, Budget when enabled, Support); **Account** (Profile, Settings, current login/logout choice). Groups collapse when their existing gated items are unavailable. Tax and Knowledge must be visible as first-level More rows, with Home/Quick Action shortcuts where already permitted. They are not nested below another tools screen. Maintain backend feature flags even though these are mandatory product capabilities: if disabled by config, do not bypass the gate to satisfy discoverability.

Do not add Profile→Settings→Profile loops. Settings “Profile preferences” becomes “Profile” while keeping its `/profile/edit` destination; Profile keeps Manage profile. This preserves edit access while simplifying terminology. The More identity header continues opening Profile. Keep direct Alerts from Home plus More, direct current-service actions and Home Tax/exploration access. These useful contextual duplicates are not clutter to remove.

### Staff navigation

Keep capability-based Work / Review / Manage / Tools / Account grouping from `omc_navigation_ia.dart`, with module-neutral icons and readable labels. Workspace remains the operational hub; tasks, own referrals/commissions, payment/document review, finance commission operations and support remain distinct. Displaying a review queue does not imply approval authority. Reassignment, retry sync, staff grants and business configuration retain separate gates. Settlement exceptions stays accessible from workspace; no new route required.

### Back, links and limited access

Preserve app_back_navigation_guard, navigation_coordinator, link_coordinator, route_failure_recovery, auth_route_redirect and route_access_policy. More selection pops the sheet before invoking its callback; `/more` dismissed without selection returns to `/home`. Shell reselect/restoration, dirty form guard, root navigator, auth link queuing and decoded IDs are contracts. Guest/pending/rejected access notes use distinct wording. Public Services, Knowledge, Tax and Support do not become locked merely because account services are protected. Never route a denied action to an unauthorized data page just to show an empty state.

## E. Screen-by-screen and interaction audit

Each table is an implementation ticket. **U** means the full C7 matrix and semantics contract, not a claim that it passed. Priority: P0 = foundational legibility or workflow/authority-critical; P1 = major consistency/usability; P2 = low-impact secondary polish. “Keep” always includes existing data, actions, state transitions, capability checks and routes. Risk refers to later implementation, not a verified live defect.

Provider names and repository imports below are extracted from the owning source plus Dart part files. They identify frozen entrypoints; API schemas remain in those repositories and are not duplicated into this visual specification. Where callbacks are injected, preserve the host callback and parameters. “Observed state anchors” only reports source branches; target state scenarios are specified separately. Platform interactions and all transient snackbars inherit C6/U and retain their current callbacks/timing.


### E001. Approved customer Home


| Field | Required detail |
|---|---|
| Route / Surface | /home — [approved_customer_home_view.dart:27](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/approved_customer_home_view.dart#L27); file `omc_app/lib/features/home/presentation/approved_customer_home_view.dart` |
| Persona | Approved non-internal customer with dashboard capability; retain exact capability/feature predicates. |
| Purpose | Approved customer Home: complete this existing user task while preserving its scope and authority. |
| Current UI | Identity and alerts, current service, at-a-glance counts, other services, Quick actions, backend content and Explore OMC. Parts: approved_customer_home_{actions,content,service_widgets,support}.dart. |
| Current UX | Refreshes dashboard/content independently; current service and count/action callbacks open existing destinations. |
| Problems | Current-service hierarchy is already useful; three counts, nested next-step panels, action tiles and multiple content rails still compete. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Identity + alerts → current service and required next action → three plain summary links → other services → quick actions → Tax & business updates → learning/explore. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Identity + alerts → current service and required next action → three plain summary links → other services → quick actions → Tax & business updates → learning/explore. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Dashboard loading/error, content-only failure, no current service, terminal service, zero/nonzero counts, missing profile, refresh. Observed state anchors: `L82`, `L88`, `L116`, `L117` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `effectiveCapabilitiesProvider`, `homeContentProvider`, `homeDashboardSummaryProvider`, `profileSummaryProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../profile/data/profile_repository.dart`, `../data/home_content_repository.dart`, `../data/home_dashboard_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Current service and its next action dominate at 390px; counts remain links; independent content failure never removes service status. Pass U; preserve J1. |




### E002. Guest / pending / rejected Home


| Field | Required detail |
|---|---|
| Route / Surface | /home via home_screen_role_aware.dart — [customer_guest_home_view.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/customer_guest_home_view.dart#L18); file `omc_app/lib/features/home/presentation/customer_guest_home_view.dart` |
| Persona | Guest, pending, rejected and remaining non-internal fallback; retain exact capability/feature predicates. |
| Purpose | Guest / pending / rejected Home: complete this existing user task while preserving its scope and authority. |
| Current UI | Search suggestions, guest/service hero, horizontal quick actions, tax updates, learning, attention, services and activity; locked previews and access copy. |
| Current UX | Search opens catalogue/detail; permitted public actions open normally, protected actions show the existing persona-specific access feedback. |
| Problems | Locked preview cards and equal-weight content can make public utility access look unavailable; numerous local palettes and tiny labels. File-level style anchors: `L355` `fontSize: 12,`; `L384` `fontSize: 11.5,`; `L560` `fontSize: 10,`; `L808` `fontSize: 13.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Identity/access note → public service search → Tax calculator and Knowledge & news → published content → concise account CTA. Apply C1–C6. |
| Move/Remove | CONSOLIDATE repetitive locked explanatory blocks into one access note; retain protected-entry feedback and all allowed public actions. |
| New Hierarchy | Identity/access note → public service search → Tax calculator and Knowledge & news → published content → concise account CTA. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Guest, pending, rejected, empty content, partial refresh failure, long suggestions. Observed state anchors: `L280`, `L510`, `L671`, `L690` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; imports `../../auth/application/auth_state.dart`, `../data/home_dashboard_repository.dart`, `../data/mobile_quick_actions_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Each access state has correct wording; public tools remain usable; no protected data appears in locked previews. Pass U; preserve J1. |




### E003. Internal Home


| Field | Required detail |
|---|---|
| Route / Surface | /home via home_screen_role_aware.dart — [internal_home_view.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/internal_home_view.dart#L18); file `omc_app/lib/features/home/presentation/internal_home_view.dart` |
| Persona | Capability-scoped staff; retain exact capability/feature predicates. |
| Purpose | Internal Home: complete this existing user task while preserving its scope and authority. |
| Current UI | Operations hero, quick actions, needs-attention list, metrics grid and recent activity. |
| Current UX | Capability-scoped attention and queue callbacks open operational destinations; summary/load notices remain independent. |
| Problems | Several saturated metric/icon families and repeated totals reduce urgency contrast. File-level style anchors: `L608` `fontSize: 10,`; `L904` `fontSize: 11.5,`; `L1083` `fontSize: 12.5,`; `L1170` `fontSize: 10.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Identity → highest priority work → queue shortcuts → compact totals → recent activity. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Identity → highest priority work → queue shortcuts → compact totals → recent activity. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Scoped/no actions, attention empty, partial load failure, stale summary. Observed state anchors: `L212`, `L382`, `L420`, `L1014` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `homeDashboardSummaryProvider`, `mobileQuickActionsProvider`, `unreadNotificationsProvider`; imports `../../auth/application/auth_state.dart`, `../../notifications/data/notifications_repository.dart`, `../data/home_dashboard_repository.dart`, `../data/mobile_quick_actions_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | User sees only permitted queues; absent capability and zero count are distinguishable; financial hold/activation failure outrank decorative metrics. Pass U; preserve J1. |




### E004. Dashboard customer / internal variants


| Field | Required detail |
|---|---|
| Route / Surface | /dashboard — [dashboard_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/dashboard/presentation/dashboard_screen.dart#L13); file `omc_app/lib/features/dashboard/presentation/dashboard_screen.dart` |
| Persona | Dashboard-authorized customer or staff; retain exact capability/feature predicates. |
| Purpose | Dashboard customer / internal variants: complete this existing user task while preserving its scope and authority. |
| Current UI | Separate customer and operations bodies with summary, next action, snapshot, attention, actions, activity and fallback card. |
| Current UX | Dashboard capability selects customer/internal body; refresh reloads summary; actions route to existing service/queue destinations. |
| Problems | Duplicates Home/workspace mental models and many summary cards; fallback values must not look live. File-level style anchors: `L485` `fontSize: 12.5,`; `L545` `fontSize: 12,`; `L568` `fontSize: 12.5,`; `L636` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | CONSOLIDATE: Preserve direct route; prioritize next action → service/queue list → secondary summary → activity; shared visual sections with Home. Apply C1–C6. |
| Move/Remove | CONSOLIDATE presentation with corresponding Home/workspace components; retain /dashboard and its direct-link behavior. No new first-level destination. |
| New Hierarchy | Preserve direct route; prioritize next action → service/queue list → secondary summary → activity; shared visual sections with Home. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading, summary error fallback, no activity, customer/internal. Observed state anchors: `L38`, `L39`, `L1601`, `L1663` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `homeDashboardSummaryProvider`, `internalServiceCasesProvider`, `internalWorkspaceSummaryProvider`; imports `../../auth/application/auth_controller.dart`, `../../home/data/home_dashboard_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P2 |
| Acceptance Criteria | Customer/internal bodies retain distinct permission and data paths; fallback notice stays visible next to affected values. Pass U; preserve J1. |




### E005. Service catalogue


| Field | Required detail |
|---|---|
| Route / Surface | /services — [service_catalogue_screen_impl.dart:20](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart#L20); file `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart` |
| Persona | Public; assisted context for eligible staff; retain exact capability/feature predicates. |
| Purpose | Service catalogue: complete this existing user task while preserving its scope and authority. |
| Current UI | Search, category chips/filter sheet, paged catalogue, 3/4/5/6-column grid at content widths below 480/650/900 and above; fixed tile extent 114, titles 12.25. |
| Current UX | Search/category/page state selects the page provider; selecting a service passes encoded ID and assisted context to detail. |
| Problems | Phone tiles spend width on icons and restrict readable service titles; category labels 11–11.5. File-level style anchors: `L216` `crossAxisCount: crossAxisCount,`; `L219` `mainAxisExtent: 114,`; `L311` `fontSize: 13,`; `L385` `fontSize: 13.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Page title → full-width search → category control → results/count/pager → readable two-column tiles; one-column list when narrow/large text. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Page title → full-width search → category control → results/count/pager → readable two-column tiles; one-column list when narrow/large text. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Initial loading, unavailable, globally empty, filtered empty, previous/next page, assisted missing/long customer. Observed state anchors: `L90`, `L91`, `L181`, `L190`, `L771` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `pageProvider`, `serviceCataloguePageProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../application/service_catalogue_controller.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | At 320px or 1.5–2x use list; at 360–430px 1x use two columns; no service title clipped in list; query, category and pagination preserve current semantics. Pass U; preserve J1. |




### E006. Service detail


| Field | Required detail |
|---|---|
| Route / Surface | /services/:serviceId — [service_detail_screen_impl.dart:29](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart#L29); file `omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart` |
| Persona | Public, customer, eligible assisted staff; retain exact capability/feature predicates. |
| Purpose | Service detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Hero with price/time/government-fee and wizard badge; overview, requirements, documents, process, support and start CTA; existing-request lookup sheet. |
| Current UX | Start action checks existing active cases before new draft; users can choose an existing request; public access behavior is capability-dependent. |
| Problems | Many bordered sections and badges compete with decision information; long requirements need untruncated text. File-level style anchors: `L144` `fontSize: 13.5,`; `L425` `fontSize: 13.5,`; `L492` `fontSize: 12,`; `L716` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Service title → price/time → overview → requirements/documents → process → support → start CTA. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Service title → price/time → overview → requirements/documents → process → support → start CTA. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading, error, absent service, empty requirements, duplicate lookup in-flight/failure, assisted. Observed state anchors: `L57`, `L61`, `L271`, `L903`, `L1060` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `mobileAppConfigProvider`, `serviceCasesProvider`, `serviceDetailProvider`; imports `../../app_config/data/mobile_app_config_repository.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../service_requests/data/service_case_repository.dart`, `../application/service_catalogue_controller.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Starting with active requests opens the existing sheet; unknown/unpublished service stays unavailable; guest start CTA keeps account flow. Pass U; preserve J1. |




### E007. Service request creation


| Field | Required detail |
|---|---|
| Route / Surface | /services/:serviceId/request — [service_request_draft_screen.dart:32](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_screen.dart#L32); file `omc_app/lib/features/service_requests/presentation/service_request_draft_screen.dart` |
| Persona | Customer creator or scoped assisted staff; retain exact capability/feature predicates. |
| Purpose | Service request creation: complete this existing user task while preserving its scope and authority. |
| Current UI | One ListView form: selected service, internal customer and discount controls, contact fields, dynamic fields/notes, documents-you-may-need and stages; persistent submit bar and UnsavedChangesGuard. |
| Current UX | Prefills allowed profile values, validates contact/dynamic/internal fields, creates an idempotent request, refreshes tracking and opens returned request; failures retain inputs. |
| Problems | Large ERP-like form with multiple equal cards; section validation is scattered; draft has no upload and must not be presented as an upload step. See B4 for inherited/shared style locations. |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Service summary → customer context → Contact details → Service information → Review summary with price and document guidance → Submit; preserve one form state across visual sections. Apply C1–C6. |
| Move/Remove | RELOCATE static process/stage preview into expandable “What happens after submission”. A multi-step form controller is a separately approved frontend logic change, not implicit in visual refactoring. |
| New Hierarchy | Service summary → customer context → Contact details → Service information → Review summary with price and document guidance → Submit; preserve one form state across visual sections. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Prefill pending, dynamic select/check/text validation, internal no selection/discount errors, submit, timeout/retry, duplicate, exit guard. Observed state anchors: `L128`, `L132`, `L137`, `L176`, `L319` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `internalServiceCasesProvider`, `internalWorkspaceSummaryProvider`, `profileSummaryProvider`, `serviceCaseDetailProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`, `serviceRequestTemplateProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../profile/data/profile_repository.dart`, `../data/service_case_repository.dart`, `../../service_catalogue/application/service_catalogue_controller.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | ServiceRequestPayload remains byte-equivalent for identical inputs, including attachments: []; idempotency key/retry intent remains; duplicate result opens existing request; keyboard never covers active field/submit. Pass U; preserve J1. |




### E008. Assisted customer selector


| Field | Required detail |
|---|---|
| Route / Surface | Request draft inline — [assisted_customer_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/assisted_customer_card.dart#L1); file `omc_app/lib/features/service_requests/presentation/assisted_customer_card.dart` |
| Persona | Eligible internal creator; retain exact capability/feature predicates. |
| Purpose | Assisted customer selector: complete this existing user task while preserving its scope and authority. |
| Current UI | Customer mode, search eligible customers, selection and consent-reference input; provider-based eligible choices. |
| Current UX | Loads eligible customer choices, applies mode/search/selection and returns selected customer/consent context to draft. |
| Problems | Customer attribution can be visually lost among service details; search failures must not resemble no customers. File-level style anchors: `L211` `style: TextStyle(fontSize: 12),` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Context heading → mode → search/results → selected identity → required consent reference → continue with draft. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Context heading → mode → search/results → selected identity → required consent reference → continue with draft. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading eligible customers, retry, empty matches, selection change, missing consent. Observed state anchors: `L214`, `L216`, `L305`, `L321` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `serviceRequestRepositoryProvider`; imports `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Changing customer preserves existing clearing/prefill rules; selected ID and consent reference stay unchanged in payload; long customer names wrap. Pass U; preserve J1. |




### E009. My Services / Requests


| Field | Required detail |
|---|---|
| Route / Surface | /track and /my-services — [my_services_screen.dart:15](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/my_services_screen.dart#L15); file `omc_app/lib/features/service_requests/presentation/my_services_screen.dart` |
| Persona | canTrackRequests or /track-authorized case viewer; retain exact capability/feature predicates. |
| Purpose | My Services / Requests: complete this existing user task while preserving its scope and authority. |
| Current UI | Search, chips, sort and filter sheets; request cards with status/progress/action; empty and filtered-empty variants. |
| Current UX | Filters/sorts existing request data, opens case detail and preserves differentiated active, action-needed and historical/terminal behavior. |
| Problems | Cards give status, identifiers and multiple signals similar emphasis; historical/terminal state must not resemble active work. File-level style anchors: `L311` `fontSize: 12,`; `L417` `fontSize: 13.5,`; `L463` `fontSize: 13,`; `L470` `fontSize: 13,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Requests title → search/filter → action-needed cases in existing sort order → other results; each row: service → state → next step → date/id. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Requests title → search/filter → action-needed cases in existing sort order → other results; each row: service → state → next step → date/id. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error, empty, filtered empty, overdue, historical, action needed, closed/completed/cancelled. Observed state anchors: `L45`, `L46`, `L47`, `L52`, `L124` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `effectiveCapabilitiesProvider`, `serviceCasesProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_state.dart`, `../data/service_case_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Filter/sort results are identical; terminal/historical records never show active upload/payment CTA; service identity and action are readable within seconds. Pass U; preserve J1. |




### E010. Customer request detail


| Field | Required detail |
|---|---|
| Route / Surface | /my-services/:caseId canonical variant — [customer_service_case_detail_screen.dart:26](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart#L26); file `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart` |
| Persona | Approved non-internal, not assisted, canTrackRequests; retain exact capability/feature predicates. |
| Purpose | Customer request detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Canonical detail with service hero, lifecycle, next step, documents, payment, activity, cancellation; four part files. |
| Current UX | Refreshes canonical case detail; document uploads use requirement identity; next action opens current payment/document destination; cancellation is confirmed. |
| Problems | Repeated state across hero/lifecycle/next-step cards can dilute the one task needed now; document and payment evidence need clear priority. See B4 for inherited/shared style locations. |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Service/status → next action → lifecycle → required documents → payment evidence → activity → secondary cancellation. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Service/status → next action → lifecycle → required documents → payment evidence → activity → secondary cancellation. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Not found, permission/error, terminal, awaiting payment preparation, documents rejected/missing, upload progress/error, cancel busy/failure. Observed state anchors: `L68`, `L69` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `customerServiceCaseDetailProvider`, `customerServiceCaseRepositoryProvider`, `documentAttachmentControllerProvider`, `documentPageProvider`, `documentsProvider`, `documentsRepositoryProvider`, `effectiveCapabilitiesProvider`, `homeDashboardSummaryProvider`, `serviceCasesProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../documents/application/document_attachment_controller.dart`, `../../documents/data/documents_repository.dart`, `../../home/data/home_dashboard_repository.dart`, `../data/customer_service_case_repository.dart`, `../data/service_case_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Display backend lifecycle/next action without recomputing authority; payment preparation is distinct from pay-now; document rejection instructions are visible; cancel state refreshes correctly. Pass U; preserve J1. |




### E011. Assisted / operational request detail


| Field | Required detail |
|---|---|
| Route / Surface | /my-services/:caseId fallback — [service_case_detail_legacy_screen.dart:20](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L20); file `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart` |
| Persona | Assisted staff and non-canonical authorized variants; retain exact capability/feature predicates. |
| Purpose | Assisted / operational request detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Attribution, hero, progress, request info, documents, activity, primary actions; admin reassignment, sync retry and discount review; upload sheet. |
| Current UX | Uses legacy repository detail for assisted/operational context, uploads and review/admin actions with per-capability checks and mutation refresh. |
| Problems | Customer-style timeline and administrative tools share visual weight; repeated status labels and horizontal steps risk small-width overflow. File-level style anchors: `L702` `fontSize: 12.5,`; `L713` `fontSize: 11,`; `L838` `fontSize: 12.5,`; `L853` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Assisted identity → service/status/next operation → evidence → expanded operational details → authorized admin controls. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Assisted identity → service/status/next operation → evidence → expanded operational details → authorized admin controls. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Missing case, permission failure, historical, discount waiting, sync failure, uploaded/rejected documents, admin busy/error. Observed state anchors: `L79`, `L80`, `L131`, `L160`, `L212` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminControlRepositoryProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `serviceCaseDetailProvider`, `serviceCaseRepositoryProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../admin_control/data/admin_control_repository.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/service_case_repository.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Dispatcher condition stays identical; internal operational statuses and historical safeguards survive; reassign/review/upload actions retain repositories and invalidation. Pass U; preserve J1. |




### E012. Documents list


| Field | Required detail |
|---|---|
| Route / Surface | /documents customer or assisted — [documents_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/documents_screen.dart#L14); file `omc_app/lib/features/documents/presentation/documents_screen.dart` |
| Persona | Customer or assisted context; router redirects eligible reviewers to review UI; retain exact capability/feature predicates. |
| Purpose | Documents list: complete this existing user task while preserving its scope and authority. |
| Current UI | Paged request groups with search, Action/Review/Approved counts, status filters, nested compact document rows. |
| Current UX | Search/status filtering operates on loaded paged document data grouped by request; a document opens its detail with assisted scope where applicable. |
| Problems | Nested request cards and compact metadata obscure which document requires attention. File-level style anchors: `L285` `fontSize: 11.5,`; `L419` `fontSize: 13,`; `L509` `fontSize: 10,`; `L548` `fontSize: 13.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Documents title → action-needed count → search/filter → request section heading → document rows: name, requirement/status, action. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Documents title → action-needed count → search/filter → request section heading → document rows: name, requirement/status, action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Paged load/refresh/error, empty/filtered empty, missing/rejected/reviewed, assisted service context. Observed state anchors: `L101`, `L102`, `L103`, `L292`, `L294` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `assistedDocumentPageProvider`, `documentPageProvider`, `documentsRepositoryProvider`; imports `../data/documents_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Same request grouping and filter counts; uploaded is distinct from approved; assisted service_request remains scoped. Pass U; preserve J1. |




### E013. Document detail


| Field | Required detail |
|---|---|
| Route / Surface | /documents/:documentId — [document_detail_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/document_detail_screen.dart#L18); file `omc_app/lib/features/documents/presentation/document_detail_screen.dart` |
| Persona | Authorized customer/staff; assisted provider variant; retain exact capability/feature predicates. |
| Purpose | Document detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Hero, status/file-link/update stats, info rows, action card for preview/upload/download, static timeline placeholder. |
| Current UX | Selects ordinary/assisted detail provider; generic attachments require linked request; preview/download launch validated external URLs; mutation invalidates related data. |
| Problems | File-link availability repeats as stats/details while reupload reason is secondary; placeholder suggests future timeline capability. File-level style anchors: `L148` `fontSize: 13,`; `L251` `fontSize: 12,`; `L376` `fontSize: 11,`; `L452` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Document name → requirement + status/rejection note → upload or preview primary action → file/service details → download. Apply C1–C6. |
| Move/Remove | REMOVE FROM UI _DocumentTimelinePlaceholder; no activity is fetched by this static widget. Preserve existing metadata and any real activity elsewhere. |
| New Hierarchy | Document name → requirement + status/rejection note → upload or preview primary action → file/service details → download. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/not found/error, no file, unsupported preview, upload busy/cancel/failure, rejected and approved. Observed state anchors: `L54`, `L59`, `L62`, `L437`, `L602` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `assistedDocumentDetailProvider`, `documentAttachmentControllerProvider`, `documentDetailProvider`, `documentsRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../application/document_attachment_controller.dart`, `../data/documents_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Upload retains attachment policy, document ownership and assisted selection; cancellation/error does not show success; preview/download retain the current validated external-URL launcher; staff review and payment preview use authenticated downloads separately. Pass U; preserve J1. |




### E014. Document / invoice / proof preview


| Field | Required detail |
|---|---|
| Route / Surface | Navigator route; document review / invoice / payment proof, customer document URL opening is a separate external surface — [document_preview_screen.dart:6](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/document_preview_screen.dart#L6); file `omc_app/lib/features/documents/presentation/document_preview_screen.dart` |
| Persona | Authorized caller; retain exact capability/feature predicates. |
| Purpose | Document / invoice / proof preview: complete this existing user task while preserving its scope and authority. |
| Current UI | Black scaffold, filename app bar, pdfrx PDF viewer or zoomable JPEG/PNG; unsupported/error message. |
| Current UX | Caller supplies downloaded bytes and filename; PDF/image renders locally; back returns to caller; unsupported type/corrupt image has explicit message. |
| Problems | Filename is one-line ellipsized; viewer gestures need accessible alternative and unsupported recovery context. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: File identity → media viewer → readable unsupported/error explanation; retain back to source action. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | File identity → media viewer → readable unsupported/error explanation; retain back to source action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: PDF, JPEG/PNG, corrupt image, unsupported format; download failure belongs to initiating screen. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | PDF/image bytes and sourceName unchanged; unsupported type does not trigger unsafe URL fallback; filename accessible in full semantics. Pass U; preserve J1. |




### E015. Document review workspace


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace/documents; /documents reviewer variant — [internal_document_review_screen.dart:39](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/internal_document_review_screen.dart#L39); file `omc_app/lib/features/documents/presentation/internal_document_review_screen.dart` |
| Persona | Document queue/review capabilities; retain exact capability/feature predicates. |
| Purpose | Document review workspace: complete this existing user task while preserving its scope and authority. |
| Current UI | Server queue, customer/type/request filters, compact metrics, grouped review cards, preview/approve/reject, rejection dialog. |
| Current UX | Queries scoped document queue and filters; preview downloads authenticated bytes; approve/reject targets selected document, with required rejection instruction. |
| Problems | Many small chips and filter layers precede actual evidence; approve/reject targets must be separated. File-level style anchors: `L668` `fontSize: 13.5,`; `L675` `fontSize: 12.5,`; `L742` `fontSize: 13,`; `L750` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Queue title → review count → collapsed advanced filters → customer/request context → document preview/name/status → review actions. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Queue title → review count → collapsed advanced filters → customer/request context → document preview/name/status → review actions. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Initial/error, filtered empty, review/approved/rejected/archive, per-row busy, preview failure, rejection dirty form. Observed state anchors: `L238`, `L280`, `L332`, `L338`, `L475` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `documentsRepositoryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/documents_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Visibility and mutation capability remain separate; rejection reason stays required; no stale row reviewed after refresh; pagination scope and selected request preserved. Pass U; preserve J1. |




### E016. Payments list


| Field | Required detail |
|---|---|
| Route / Surface | /payments — [payments_screen.dart:12](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/payments_screen.dart#L12); file `omc_app/lib/features/payments/presentation/payments_screen.dart` |
| Persona | Payment-authorized account; retain exact capability/feature predicates. |
| Purpose | Payments list: complete this existing user task while preserving its scope and authority. |
| Current UI | Summary header and payment cards with status-specific Continue/Pay now/Replace receipt/View status actions. |
| Current UX | Loads account payment data; status-derived card action opens existing detail; refresh refetches payments. |
| Problems | Module-tinted financial surfaces and repeated rounded sections diminish amount/status hierarchy. File-level style anchors: `L164` `fontSize: 12,`; `L181` `fontSize: 11,`; `L222` `fontSize: 12.5,`; `L293` `fontSize: 11.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Title → amount due summary → payment rows: currency + amount, service, status, next action → due date/reference. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Title → amount due summary → payment rows: currency + amount, service, status, next action → due date/reference. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading/error, no due payment, pending/overdue/rejected/receipt-submitted/under-review/paid/cancelled. Observed state anchors: `L31`, `L32`, `L33`, `L552` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `paymentsProvider`; imports `../data/payments_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Exact status-to-action mapping retained; paid/cancelled entries never display payment CTA; totals keep existing semantics. Pass U; preserve J1. |




### E017. Payment detail and review


| Field | Required detail |
|---|---|
| Route / Surface | /payments/:paymentId — [payment_detail_screen.dart:24](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/payment_detail_screen.dart#L24); file `omc_app/lib/features/payments/presentation/payment_detail_screen.dart` |
| Persona | Payment owner, assisted staff, authorized reviewer; retain exact capability/feature predicates. |
| Purpose | Payment detail and review: complete this existing user task while preserving its scope and authority. |
| Current UI | Amount hero, quick stats, bank/channel/instructions/reference/dates, payment actions, receipt upload progress/cancel, invoice/proof viewers and review card. |
| Current UX | Opens invoice/proof through authenticated downloads; upload supports receipt progress/cancel; staff review submits Paid/Rejected and refreshes dependent state. |
| Problems | Instructions and financial action compete with static stats/timeline; review action currently says Mark Paid and cannot be semantically relabeled as merely receipt received. File-level style anchors: `L159` `fontSize: 13,`; `L257` `fontSize: 12,`; `L367` `fontSize: 11,`; `L461` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Amount + currency → verification state → next action/bank instructions → proof/invoice → service/reference/dates → staff review. Apply C1–C6. |
| Move/Remove | REMOVE FROM UI _PaymentTimelinePlaceholder only; preserve invoice/proof and real reconciliation/status information. |
| New Hierarchy | Amount + currency → verification state → next action/bank instructions → proof/invoice → service/reference/dates → staff review. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Gateway unavailable, missing invoice/proof, download failure, upload cancelled/retry, review busy/error, assisted. Observed state anchors: `L65`, `L70`, `L73`, `L446`, `L787` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `assistedPaymentDetailProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `paymentDetailProvider`, `paymentsRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../auth/application/auth_controller.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/payments_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Online gateway flag, receipt replacement, upload cancel, review remarks and status payload remain identical; uploading proof never visually claims payment verification. Pass U; preserve J1. |




### E018. Tax calculator


| Field | Required detail |
|---|---|
| Route / Surface | /tax-calculator — [tax_calculator_screen.dart:16](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart#L16); file `omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart` |
| Persona | Guest/pending/approved/staff according to capabilities/config; retain exact capability/feature predicates. |
| Purpose | Tax calculator: complete this existing user task while preserving its scope and authority. |
| Current UI | Config FutureBuilder, tax year/deadline, income type/mode/amount/filer, refine-calculation advanced fields, result metrics, readiness insights, breakdown, comparison, steps and linked-service CTA. |
| Current UX | Loads configuration, validates active fields, requests server estimate and may start linked tax service through existing role flow; history opens separate route. |
| Problems | Result has many equal cards; segmented labels ellipsize; header/filter density reduces input focus. See B4 for inherited/shared style locations. |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Tax year/deadline → income type/mode → amount → filer → optional refine section → Calculate → estimated annual tax → monthly/effective-rate → expandable breakdown/comparison/guidance → linked service. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Tax year/deadline → income type/mode → amount → filer → optional refine section → Calculate → estimated annual tax → monthly/effective-rate → expandable breakdown/comparison/guidance → linked service. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Config loading/error/unconfigured, invalid input, calculate busy/failure, returned result/warnings, service creation busy/duplicate. Observed state anchors: `L105`, `L109`, `L307`, `L374`, `L388` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `effectiveCapabilitiesProvider`, `taxCalculationRepositoryProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../data/tax_calculation_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Advanced field values and tax computation remain server-owned; invalid result is not fabricated; guest/pending CTA preserves access flow; existing history remains one tap. Pass U; preserve J1. |




### E019. Tax estimate history


| Field | Required detail |
|---|---|
| Route / Surface | /tax-calculator/history — [tax_calculation_history_screen.dart:6](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart#L6); file `omc_app/lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart` |
| Persona | Non-guest with tax capability; retain exact capability/feature predicates. |
| Purpose | Tax estimate history: complete this existing user task while preserving its scope and authority. |
| Current UI | History FutureBuilder, income/filer filters and cards with annual income, annual/monthly tax, rate and linked request. |
| Current UX | Fetches saved estimates and applies current income/filer filters; renders existing linked-request information. |
| Problems | Four numeric pairs per card are equal weight; filter rows consume initial viewport. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Title → filter summary → dated estimate row with annual tax primary → income/year secondary → expanded breakdown/linked request. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Title → filter summary → dated estimate row with annual tax primary → income/year secondary → expanded breakdown/linked request. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading, unavailable, no saved estimates, no filter match, long linked request. Observed state anchors: `L48`, `L57`, `L94`, `L522` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `taxCalculationRepositoryProvider`; imports `../data/tax_calculation_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Filtering produces same records; no saved estimates differs from no filter matches; tax year/date remain visible. Pass U; preserve J1. |




### E020. Knowledge & news


| Field | Required detail |
|---|---|
| Route / Surface | /knowledge — [knowledge_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/knowledge/presentation/knowledge_screen.dart#L14); file `omc_app/lib/features/knowledge/presentation/knowledge_screen.dart` |
| Persona | Public including limited-access accounts; retain exact capability/feature predicates. |
| Purpose | Knowledge & news: complete this existing user task while preserving its scope and authority. |
| Current UI | Featured hero, latest updates list; article type/date/count metadata and empty/retry widgets. |
| Current UX | Loads article feed, chooses existing featured/latest presentation and opens article detail by encoded ID. |
| Problems | Large hero and decorative counts can crowd authoritative updates; category/type is metadata, not a proven interactive category-filter feature. File-level style anchors: `L148` `fontSize: 12,`; `L255` `fontSize: 12,`; `L436` `fontSize: 12,`; `L449` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Knowledge & news → featured headline → latest tax/FBR/compliance updates in current feed order → article rows with type/date. Apply C1–C6. |
| Move/Remove | CONSOLIDATE decorative article/featured counts into optional caption; retain Tax/FBR/compliance entry visibility. |
| New Hierarchy | Knowledge & news → featured headline → latest tax/FBR/compliance updates in current feed order → article rows with type/date. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/empty, featured absent, long titles, missing dates. Observed state anchors: `L25`, `L26`, `L29`, `L36` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `knowledgeArticlesProvider`; imports `../data/knowledge_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | All existing articles/types remain; no invented search/category API; featured and latest cards open same article IDs; content failure distinguishable from unpublished feed. Pass U; preserve J1. |




### E021. Knowledge article


| Field | Required detail |
|---|---|
| Route / Surface | /knowledge/:articleId — [knowledge_detail_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/knowledge/presentation/knowledge_detail_screen.dart#L14); file `omc_app/lib/features/knowledge/presentation/knowledge_detail_screen.dart` |
| Persona | Public; retain exact capability/feature predicates. |
| Purpose | Knowledge article: complete this existing user task while preserving its scope and authority. |
| Current UI | Title/summary card, Details card with plain Text body or summary fallback, metadata chips, validated external full-article CTA. |
| Current UX | Loads article by ID, displays body or summary fallback and opens validated full-article external URL when available. |
| Problems | Title capped/ellipsized; body already has 1.6 line height but 15px semibold and nested cards reduce reading comfort. File-level style anchors: `L330` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Type/date → full headline → summary → plain reading body → external article CTA. Apply C1–C6. |
| Move/Remove | REMOVE FROM UI redundant “Details” heading and outer body card; underlying article content and link remain. |
| New Hierarchy | Type/date → full headline → summary → plain reading body → external article CTA. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. readingTitle28 and reading17/1.6; full body without card padding nesting. |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/not found, body missing, unsupported/external link failure. Observed state anchors: `L27`, `L28`, `L31`, `L143` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `knowledgeArticleDetailProvider`; imports `../data/knowledge_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Reading body uses reading token 17/1.6 regular; no heading/title truncation; summary fallback and supported-link validation remain; no HTML parsing behavior introduced. Pass U; preserve J1. |




### E022. Alerts / notifications


| Field | Required detail |
|---|---|
| Route / Surface | /notifications — [notifications_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/notifications/presentation/notifications_screen.dart#L13); file `omc_app/lib/features/notifications/presentation/notifications_screen.dart` |
| Persona | canViewNotifications; retain exact capability/feature predicates. |
| Purpose | Alerts / notifications: complete this existing user task while preserving its scope and authority. |
| Current UI | Paged list, read-all, date groups, dismissible rows, Undo; title/body/type/time and unread styling. |
| Current UX | Paginates alerts, marks all read, dismisses rows with existing Undo and opens detail; mutations update unread state. |
| Problems | Title 14, body 12 and time/type 10.5; meaningful text compressed into dense row. File-level style anchors: `L272` `fontSize: 12.5,`; `L329` `fontSize: 11,`; `L415` `fontSize: 10.5,`; `L429` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Alerts title + read-all → date group → unread indicator and full primary text → supporting body → type/time → related action in detail. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Alerts title + read-all → date group → unread indicator and full primary text → supporting body → type/time → related action in detail. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Initial/error/empty, loading more, unread/read, dismiss failure/undo, mark-all busy/error. Observed state anchors: `L65`, `L89`, `L90`, `L525` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `homeDashboardSummaryProvider`, `notificationPageProvider`, `notificationsProvider`, `notificationsRepositoryProvider`, `unreadNotificationsProvider`; imports `../../home/data/home_dashboard_repository.dart`, `../data/notifications_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Dismiss/undo operates on same ID and timing; pagination never duplicates rows; unread count agrees after read-all; non-swipe alternative exposes existing dismiss callback. Pass U; preserve J1. |




### E023. Notification detail


| Field | Required detail |
|---|---|
| Route / Surface | /notifications/:notificationId — [notification_detail_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/notifications/presentation/notification_detail_screen.dart#L18); file `omc_app/lib/features/notifications/presentation/notification_detail_screen.dart` |
| Persona | Authorized recipient; retain exact capability/feature predicates. |
| Purpose | Notification detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Hero with type/read/action pills, message, reference/time/raw action-link details and action card; mark read and guarded routing. |
| Current UX | Marks read through repository and resolves related destination through existing guarded link/reference rules. |
| Problems | Multiple pills and metadata card compete with message; raw action URI has too much customer prominence. File-level style anchors: `L537` `fontSize: 12,`; `L588` `fontSize: 12,`; `L626` `fontSize: 11,`; `L670` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Alert title/type → full message → related action → timestamp/read control → reference details. Apply C1–C6. |
| Move/Remove | RELOCATE raw action/reference information to expanded details; preserve diagnostic value and actual guarded action. |
| New Hierarchy | Alert title/type → full message → related action → timestamp/read control → reference details. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/not found, unread/read, action absent/unsupported/denied, mark-read failure. Observed state anchors: `L48`, `L49`, `L52`, `L201`, `L229` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `internalServiceCasesProvider`, `notificationDetailProvider`, `notificationsProvider`, `notificationsRepositoryProvider`, `paymentDetailProvider`, `paymentsProvider`, `serviceCaseDetailProvider`, `serviceCasesProvider`; imports `../../payments/data/payments_repository.dart`, `../../service_requests/data/service_case_repository.dart`, `../data/notifications_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Mark-read semantics and notification link normalization remain; inaccessible/deleted targets recover through existing policy; no raw backend exception shown. Pass U; preserve J1. |




### E024. Support customer / public / internal workspace


| Field | Required detail |
|---|---|
| Route / Surface | /support inside freshness wrapper — [support_screen_legacy.dart:19](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_screen_legacy.dart#L19); file `omc_app/lib/features/support/presentation/support_screen_legacy.dart` |
| Persona | Public contacts; authorized own tickets or internal queue; retain exact capability/feature predicates. |
| Purpose | Support customer / public / internal workspace: complete this existing user task while preserving its scope and authority. |
| Current UI | Topics open WhatsApp, inline create-ticket form, active/closed tickets and staff assignment, FAQ expansions, contact channels/business hours/office; wrapper adds sync banner. |
| Current UX | Public contact/topics launch channels; permitted users create/read tickets; staff may assign to self; wrapper refreshes feed and labels cached/stale data. |
| Problems | Hero counters, topics, form, queue and contacts all compete; internal queue needs priority over customer introduction. File-level style anchors: `L283` `fontSize: 11,`; `L679` `fontSize: 10.5,`; `L912` `fontSize: 12,`; `L932` `fontSize: 10,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Customer: help heading → active tickets/new ticket → direct channels → topics/FAQ/hours. Staff: assigned/unassigned ticket queue → filters → direct channels. Public: channels → FAQ → access note. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Customer: help heading → active tickets/new ticket → direct channels → topics/FAQ/hours. Staff: assigned/unassigned ticket queue → filters → direct channels. Public: channels → FAQ → access note. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Public locked ticket section, independent FAQ/config failures, stale cached feed, no tickets, create/assign busy/error. Observed state anchors: `L52`, `L79`, `L164`, `L397`, `L599` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `activeSupportTicketProvider`, `appFaqsProvider`, `authControllerProvider`, `supportConfigProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketPageProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../content/data/app_content_repository.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Ticket ownership/assign-to-me and active/closed pagination remain; WhatsApp ready-message remains; stale config/feed/unread is visible and retryable. Pass U; preserve J1. |




### E025. Support conversation


| Field | Required detail |
|---|---|
| Route / Surface | /support-tickets/:ticketId inside freshness wrapper — [support_ticket_detail_legacy_screen.dart:21](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart#L21); file `omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart` |
| Persona | Ticket owner or support workspace; retain exact capability/feature predicates. |
| Purpose | Support conversation: complete this existing user task while preserving its scope and authority. |
| Current UI | Ticket/customer context, conversation bubbles/attachments, picked-file preview, keyboard composer; internal status sheet; wrapper retains stale conversation. |
| Current UX | Refreshes conversation, sends text/validated attachment, opens attachment URLs and allows scoped staff status change; closed tickets reject replies. |
| Problems | Large context cards delay conversation; timestamps/attachments and action bar need large-text behavior. File-level style anchors: `L514` `fontSize: 12,`; `L542` `fontSize: 12,`; `L597` `fontSize: 12,`; `L624` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Compact ticket status → expandable customer/reference context → conversation → safe-area composer → internal status action. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Compact ticket status → expandable customer/reference context → conversation → safe-area composer → internal status action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/not found/error, stale/refresh snapshot, empty conversation, attachment validation/open error, send failure, closed, internal status mutation. Observed state anchors: `L81`, `L82`, `L85`, `L177`, `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Closed tickets cannot receive replies; attachment size/type/empty checks retained; failed sends retain draft; session switch cannot display another identity conversation. Pass U; preserve J1. |




### E026. Expense Tracker


| Field | Required detail |
|---|---|
| Route / Surface | /expense-tracker — [expense_tracker_screen.dart:259](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L259); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Expense Tracker: complete this existing user task while preserving its scope and authority. |
| Current UI | Local controller plus cloud body, income/expense summary, categories, period filter, transactions, add/edit sheet, export/import/storage menu, archive/clear dialogs. |
| Current UX | Maintains local or account-sync storage, filters transaction history, adds/edits/archives entries, imports/exports and clears local data through existing guarded flows. |
| Problems | Summary/category panels and tiny tags overwhelm ledger; local/cloud status must stay explicit without becoming a diagnostics dashboard. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Balance/income/expenses → add transaction → period/category filters → transaction rows → account/local status → data tools in menu. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Balance/income/expenses → add transaction → period/category filters → transaction rows → account/local status → data tools in menu. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Local-only, account sync, cloud unavailable, local unsynced, period empty, pagination, import/export failure/cancel, archive/clear. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Local/cloud storage choices and pending local entries remain accurate; refresh/export/import/archive do not cross session epoch; edit/save preserves IDs and sync semantics. Pass U; preserve J1. |




### E027. Monthly budget


| Field | Required detail |
|---|---|
| Route / Surface | /expense-budget — [expense_budget_screen.dart:80](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart#L80); file `omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart` |
| Persona | Approved or internal; local/internal note as applicable; retain exact capability/feature predicates. |
| Purpose | Monthly budget: complete this existing user task while preserving its scope and authority. |
| Current UI | Month navigation, budget cards/progress, add/edit category limit and threshold sheet, add/refresh menu. |
| Current UX | Changes month, loads local/account budget data, adds/edits category limit and threshold and refreshes spending progress. |
| Problems | Repeated card boundaries and equal numeric weights reduce visibility of remaining/over budget; threshold must not be a color-only signal. File-level style anchors: `L202` `fontSize: 11,`; `L486` `fontSize: 10.5,`; `L532` `fontSize: 10.5,`; `L670` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Month → total/context → category budget: spent/limit/remaining → labeled progress → add/edit. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Month → total/context → category budget: spent/limit/remaining → labeled progress → add/edit. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading/error, no budget, month change, valid/invalid amount/threshold, save failure, local internal. Observed state anchors: `L212`, `L213`, `L232`, `L233`, `L252` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `authControllerProvider`, `expenseBudgetSummaryProvider`, `expenseBudgetsProvider`, `expenseTrackerRepositoryProvider`, `localExpenseBudgetEntriesProvider`, `localExpenseBudgetsProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Budget month/category/threshold payload and local storage semantics unchanged; >100% shows explicit over-budget amount even if progress bar clamps. Pass U; preserve J1. |




### E028. Profile


| Field | Required detail |
|---|---|
| Route / Surface | /profile — [profile_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/profile_screen.dart#L18); file `omc_app/lib/features/profile/presentation/profile_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Profile: complete this existing user task while preserving its scope and authority. |
| Current UI | Profile hero/photo/status, account fields, manage/refresh/support actions; sync skeleton/error fallback. |
| Current UX | Loads/refetches identity, selects gallery image for upload, opens editor and sends support request with current profile context. |
| Problems | Multiple status chips and explanatory section copy repeat account state; profile actions could be mistaken for settings controls. File-level style anchors: `L271` `fontSize: 13,`; `L417` `fontSize: 13,`; `L722` `fontSize: 13,`; `L766` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Identity/photo → approval/account state → personal/contact → business/tax or internal access → Manage profile → support. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Identity/photo → approval/account state → personal/contact → business/tax or internal access → Manage profile → support. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Skeleton/error with fallback identity, refresh, photo upload, missing fields, support request busy/error. Observed state anchors: `L47`, `L48`, `L513`, `L789`, `L973` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `profileRepositoryProvider`, `profileSummaryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../support/data/support_repository.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Photo picker/upload failure preserves avatar; missing verified fields are not editable through presentation; internal role differs from customer type. Pass U; preserve J1. |




### E029. Profile details editor


| Field | Required detail |
|---|---|
| Route / Surface | /profile/edit — [edit_profile_screen.dart:15](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/edit_profile_screen.dart#L15); file `omc_app/lib/features/profile/presentation/edit_profile_screen.dart` |
| Persona | Signed-in scoped profile; retain exact capability/feature predicates. |
| Purpose | Profile details editor: complete this existing user task while preserving its scope and authority. |
| Current UI | Overview with completion card, personal/contact/professional edit sections; identity/business rows launch add/update sheets; locked info and confirmations. |
| Current UX | Editable sections open payload-specific sheets; protected identity is locked or confirmed according to current field rules; save refreshes profile. |
| Problems | Repeated explanatory subtitles and completion card compete with editable rows; locked vs editable field behavior must be immediately clear. File-level style anchors: `L205` `fontSize: 12.5,`; `L282` `fontSize: 12,`; `L329` `fontSize: 12,`; `L343` `fontSize: 13,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Profile details → editable personal/contact sections → business/tax identity with explicit locked/add state → professional details where applicable. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Profile details → editable personal/contact sections → business/tax identity with explicit locked/add state → professional details where applicable. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Loading/error/unavailable, empty optional field, locked identity, save/confirm/retry. Observed state anchors: `L39`, `L40`, `L835`, `L1036` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `profileRepositoryProvider`, `profileSummaryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | All existing field payload builders retained; verified identity confirmations remain; locked fields never become editable; sheet error keeps values. Pass U; preserve J1. |




### E030. Settings


| Field | Required detail |
|---|---|
| Route / Surface | /settings — [settings_screen.dart:31](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L31); file `omc_app/lib/features/settings/presentation/settings_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Settings: complete this existing user task while preserving its scope and authority. |
| Current UI | Account/security/biometric/deletion/logout, persisted notification switches, legal links/fallback sheets, version and account-sync copy. |
| Current UX | Loads/saves account notification preferences, enrolls biometrics with current password, opens policies/editor, requests deletion through support and confirms logout. |
| Problems | 12–14px tile/support scale and repeated section subtitles make settings document-like; Profile preferences is ambiguous. File-level style anchors: `L1034` `fontSize: 13,`; `L1041` `fontSize: 12,`; `L1048` `fontSize: 12,`; `L1054` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Profile link → Security (password/biometric) → Notifications → Legal → About/version → Account actions. Apply C1–C6. |
| Move/Remove | RELOCATE logout/deletion to final Account actions group; REMOVE FROM UI redundant section subtitles and static “Account sync” explanatory row, retaining real sync errors and retry. |
| New Hierarchy | Profile link → Security (password/biometric) → Notifications → Legal → About/version → Account actions. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Preferences loading/error/save failure, biometric unavailable/enrollment failure, policy URL fallback, deletion pending/error, logout failure. Observed state anchors: `L142`, `L143`, `L303`, `L307`, `L448` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `appPackageInfoProvider`, `authControllerProvider`, `authRepositoryProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `settingsPreferencesProvider`, `settingsRepositoryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`, `../../app_config/data/mobile_app_config_repository.dart`, `../../profile/data/profile_repository.dart`, `../../support/data/support_repository.dart`, `../data/settings_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Rename Profile preferences to Profile but retain /profile/edit target; push switch appears only when provider operational; deletion remains a support request; logout and preference error/retry preserved. Pass U; preserve J1. |




### E031. Change password


| Field | Required detail |
|---|---|
| Route / Surface | /change-password — [change_password_screen.dart:15](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/change_password_screen.dart#L15); file `omc_app/lib/features/settings/presentation/change_password_screen.dart` |
| Persona | Signed-in account; retain exact capability/feature predicates. |
| Purpose | Change password: complete this existing user task while preserving its scope and authority. |
| Current UI | Current/new/confirmation inputs, visibility toggles and save; clears biometric login and logs out on success. |
| Current UX | Validates current/new/confirm password, submits change, clears biometric login and signs out after success. |
| Problems | Explanatory/security surfaces and field sizing need common form standard. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Title → current password → new password/requirements → confirmation → save → existing login transition. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Title → current password → new password/requirements → confirmation → save → existing login transition. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Validation, incorrect current password, submitting/failure/success; keyboard. Observed state anchors: `L54`, `L157` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `authRepositoryProvider`, `deviceLockServiceProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Password validations unchanged; successful change clears biometric enrollment and logs out; failure keeps appropriate form state without exposing password. Pass U; preserve J1. |




### E032. Splash / startup


| Field | Required detail |
|---|---|
| Route / Surface | / — [splash_screen.dart:15](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/splash/presentation/splash_screen.dart#L15); file `omc_app/lib/features/splash/presentation/splash_screen.dart` |
| Persona | All sessions; retain exact capability/feature predicates. |
| Purpose | Splash / startup: complete this existing user task while preserving its scope and authority. |
| Current UI | Startup bootstrap with brand mark/status and failure retry; session/preferences gating. |
| Current UX | Bootstraps preferences/session and routes according to existing auth/onboarding state; failed bootstrap exposes retry. |
| Problems | Large logo treatment should not disguise unavailable initialization or extend waiting with decorative animation. File-level style anchors: `L190` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Brand → concise Starting OMC status → actionable failure/retry when needed. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Brand → concise Starting OMC status → actionable failure/retry when needed. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Startup/checking, preferences failure, retry; subsequent readiness gate. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `preferencesServiceProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Startup routing and pending auth-link replay unchanged; reduced motion shows static mark; no artificial minimum splash delay. Pass U; preserve J1. |




### E033. Onboarding


| Field | Required detail |
|---|---|
| Route / Surface | /onboarding — [onboarding_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/onboarding/presentation/onboarding_screen.dart#L13); file `omc_app/lib/features/onboarding/presentation/onboarding_screen.dart` |
| Persona | First-run/public; retain exact capability/feature predicates. |
| Purpose | Onboarding: complete this existing user task while preserving its scope and authority. |
| Current UI | Backend slides with image fallback, PageView/dots and completion controls; preference save. |
| Current UX | Moves among backend slides; completion/skip persists existing onboarding preference before navigation. |
| Problems | Slide heading/body must fit short phone with 2x text and image; dots alone insufficient page state. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Image flexible → page title/body → page count → Continue/Get started and existing skip control. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Image flexible → page title/body → page count → Continue/Get started and existing skip control. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading slide content, image fallback, first/middle/last page, preference failure. Observed state anchors: `L271` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `onboardingSlidesProvider`, `preferencesServiceProvider`; imports `../data/onboarding_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Slide order and completion persistence unchanged; image error fallback remains; save failure remains retryable. Pass U; preserve J1. |




### E034. Login


| Field | Required detail |
|---|---|
| Route / Surface | /login — [login_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/login_screen.dart#L14); file `omc_app/lib/features/auth/presentation/login_screen.dart` |
| Persona | Signed-out/guest entry; retain exact capability/feature predicates. |
| Purpose | Login: complete this existing user task while preserving its scope and authority. |
| Current UI | Shared auth scaffold, identifier/password, forgot link, biometric sign-in, signup/guest entry and help sheet; multi-account chooser. |
| Current UX | Signs in with identifier/password, permits existing guest entry and biometric enrolled-account selection, and routes via authoritative auth state. |
| Problems | Several footer actions can compete with sign-in; keyboard and password toggle need consistent spacing. File-level style anchors: `L522` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Welcome → identifier/password → forgot → Sign in → biometric secondary → create/activate account and guest/help footer. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Welcome → identifier/password → forgot → Sign in → biometric secondary → create/activate account and guest/help footer. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Busy/error, guest-start failure, biometric unavailable/multi-account/cancel/failure, keyboard. Observed state anchors: `L89`, `L162`, `L193`, `L337`, `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `biometricLoginAvailableProvider`, `deviceLockServiceProvider`; imports `../application/auth_controller.dart`, `../application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Identifier normalization, canonical session verification, password visibility and biometric per-account selection unchanged; failure readable inline. Pass U; preserve J1. |




### E035. Signup flow


| Field | Required detail |
|---|---|
| Route / Surface | /signup — [signup_screen.dart:34](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_screen.dart#L34); file `omc_app/lib/features/auth/presentation/signup_screen.dart` |
| Persona | New customer / public professional registration options allowed by source; retain exact capability/feature predicates. |
| Purpose | Signup flow: complete this existing user task while preserving its scope and authority. |
| Current UI | Four steps from signup_steps: role, details, preferences/referral/source, security/review; pending registration success and resend cooldown. |
| Current UX | Moves four local steps, checks username/referral and submits registration; used pending-success state supports timed resend. |
| Problems | Long details and review requirements need grouped readable fields and clear step progress, not new registration behavior. File-level style anchors: `L901` `fontSize: 12.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Step label/count → current section → field group → inline validation → Back/Continue; final email-check success. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Step label/count → current section → field group → inline validation → Back/Continue; final email-check success. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Four steps, username checking/taken/error, conditional WhatsApp/referral/source, submit/error, cooldown/success. Observed state anchors: `L152`, `L168`, `L181`, `L244`, `L507` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`, `signupSubmitProvider`, `signupUsernameAvailabilityProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Username debounce/availability, referral verification, consent and submit payload preserved; resend cooldown respected; no new public staff-authority selection. Pass U; preserve J1. |




### E036. Forgot password


| Field | Required detail |
|---|---|
| Route / Surface | /forgot-password — [forgot_password_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/forgot_password_screen.dart#L11); file `omc_app/lib/features/auth/presentation/forgot_password_screen.dart` |
| Persona | Public; retain exact capability/feature predicates. |
| Purpose | Forgot password: complete this existing user task while preserving its scope and authority. |
| Current UI | AuthEntryScaffold identifier input → send-reset result with back-to-login. |
| Current UX | Sends reset request for identifier then shows existing neutral check-email state or inline failure. |
| Problems | Needs form/header consistency and clear success state at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Title → identifier → send link → neutral email-check result → login. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Title → identifier → send link → neutral email-check result → login. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Invalid identifier, submitting/failure, submitted. Observed state anchors: `L125` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`; imports `../data/auth_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Existing anti-enumeration wording and identifier validation preserved; retry never claims email delivered without existing success response. Pass U; preserve J1. |




### E037. Reset password


| Field | Required detail |
|---|---|
| Route / Surface | /reset-password?token=…; /app/reset-password alias — [reset_password_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/reset_password_screen.dart#L11); file `omc_app/lib/features/auth/presentation/reset_password_screen.dart` |
| Persona | Token holder; retain exact capability/feature predicates. |
| Purpose | Reset password: complete this existing user task while preserving its scope and authority. |
| Current UI | Invalid-link branch, new/confirm password form, completed state and login/new-link actions. |
| Current UX | Uses query token to submit new/confirm password; invalid link offers new reset link; success returns to login. |
| Problems | Separate failure and success layouts need shared hierarchy and keyboard behavior. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Link state → new/confirm password → update → success/login. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Link state → new/confirm password → update → success/login. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Invalid/missing link, validation, busy/failure, completed. Observed state anchors: `L44`, `L103` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`; imports `../data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Token remains query parameter; missing/expired token never exposes form as valid; no auth behavior change. Pass U; preserve J1. |




### E038. Activate existing account


| Field | Required detail |
|---|---|
| Route / Surface | /activate-existing-account — [activate_existing_account_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/activate_existing_account_screen.dart#L11); file `omc_app/lib/features/auth/presentation/activate_existing_account_screen.dart` |
| Persona | Existing customer before activation; retain exact capability/feature predicates. |
| Purpose | Activate existing account: complete this existing user task while preserving its scope and authority. |
| Current UI | Registered email input and send activation link; email-check state. |
| Current UX | Requests activation email for registered customer email, then displays existing check-email response. |
| Problems | Small supporting copy and secondary actions need consistent auth spacing. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Purpose → registered email → Send activation link → check email/login. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Purpose → registered email → Send activation link → check email/login. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Invalid email, busy/failure, submitted. Observed state anchors: `L130` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`; imports `../data/auth_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Registered-email payload and neutral result wording stay unchanged; no automatic login. Pass U; preserve J1. |




### E039. Complete customer activation


| Field | Required detail |
|---|---|
| Route / Surface | /activate-account?token=…; /app/activate-account alias — [complete_customer_activation_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/complete_customer_activation_screen.dart#L11); file `omc_app/lib/features/auth/presentation/complete_customer_activation_screen.dart` |
| Persona | Activation token holder; retain exact capability/feature predicates. |
| Purpose | Complete customer activation: complete this existing user task while preserving its scope and authority. |
| Current UI | Invalid link, create/confirm password, account activated and login CTA. |
| Current UX | Uses activation token and password confirmation to activate account; success offers login. |
| Problems | Account activation must read distinctly from approval/service activation. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Token state → password fields → Activate account → success/login. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Token state → password fields → Activate account → success/login. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Missing/invalid/expired token, validation, submitting/error/completed. Observed state anchors: `L41`, `L55` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`; imports `../data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Token handling and password submission unchanged; success does not falsely claim service activation. Pass U; preserve J1. |




### E040. Email verification / account completion


| Field | Required detail |
|---|---|
| Route / Surface | /verify-email?token=…; /app/verify-email alias — [email_verification_screen.dart:12](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/email_verification_screen.dart#L12); file `omc_app/lib/features/auth/presentation/email_verification_screen.dart` |
| Persona | Registration token holder; retain exact capability/feature predicates. |
| Purpose | Email verification / account completion: complete this existing user task while preserving its scope and authority. |
| Current UI | Verification state then conditional new-password/confirmation and Create Account; retry/login. |
| Current UX | Verifies query token and follows existing conditional password/account-completion branch; offers retry/login by state. |
| Problems | Verification and creation states need strong distinction; duplicate taps could be encouraged by weak feedback. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Verification status → requested password completion → primary action → resulting login instruction. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Verification status → requested password completion → primary action → resulting login instruction. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Verifying, invalid/expired link, password validation, completing, activated, failure/retry. Observed state anchors: `L63` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`; imports `../data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Existing verify/complete sequence and activated flag preserved; retry does not bypass token errors. Pass U; preserve J1. |




### E041. Under review


| Field | Required detail |
|---|---|
| Route / Surface | /under-review — [under_review_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/under_review_screen.dart#L14); file `omc_app/lib/features/auth/presentation/under_review_screen.dart` |
| Persona | Pending approval path; retain exact capability/feature predicates. |
| Purpose | Under review: complete this existing user task while preserving its scope and authority. |
| Current UI | Review explanation, Refresh Status, contact sheet and sign out. |
| Current UX | Refresh Status calls checkSession; Contact Support opens sheet; sign out uses auth controller. |
| Problems | Long copy can dominate actions; pending approval needs one clear statement, not promises. File-level style anchors: `L194` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Account under review → short next-step explanation → refresh → support → sign out. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Account under review → short next-step explanation → refresh → support → sign out. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Checking/unchanged/approved redirect/failure, logging out. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`; imports `../application/auth_controller.dart`, `../application/auth_state.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | checkSession controls approval transition; refresh never grants access locally; no invented review ETA. Pass U; preserve J1. |




### E042. Device lock / biometrics


| Field | Required detail |
|---|---|
| Route / Surface | Global DeviceLockGate overlay — [device_lock_gate.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/device_lock/presentation/device_lock_gate.dart#L14); file `omc_app/lib/features/device_lock/presentation/device_lock_gate.dart` |
| Persona | Authenticated enrolled current identity, session locked; retain exact capability/feature predicates. |
| Purpose | Device lock / biometrics: complete this existing user task while preserving its scope and authority. |
| Current UI | Opaque lock overlay keeps router subtree mounted; identity, biometric action/failure retry and Use another account. |
| Current UX | Current-account enrollment and session-unlocked state control overlay; biometrics unlocks; Use another account follows logout path while router remains mounted. |
| Problems | Hard-coded OMC House heading ignores runtime company name; large identity must wrap; underlying semantics require device QA. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Runtime brand lock title → account identity → biometric action → retry explanation → use another account. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Runtime brand lock title → account identity → biometric action → retry explanation → use another account. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Enrollment pending, lock, authenticating/cancel/failure, unlock, app resume, account switch. Observed state anchors: `L32` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `authControllerProvider`, `biometricActionLabelProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Keep subtree and session identity checks; no PIN/password unlock fallback invented; alternate account retains logout path; underlying app cannot be focused or tapped while locked. Pass U; preserve J1. |




### E043. Readiness / maintenance / update gates


| Field | Required detail |
|---|---|
| Route / Surface | Global AppReadinessGate / MobileReadinessOverlay — [app_readiness_gate.dart:32](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/app_config/presentation/app_readiness_gate.dart#L32); file `omc_app/lib/features/app_config/presentation/app_readiness_gate.dart` |
| Persona | All; global and route-feature decisions; retain exact capability/feature predicates. |
| Purpose | Readiness / maintenance / update gates: complete this existing user task while preserving its scope and authority. |
| Current UI | App gate panel above application, server release controls, retry/store/update/logout actions and action errors. |
| Current UX | Global/feature policy gates content and back dispatch; update opens store; recommended update supports current deferral; retry rechecks configuration. |
| Problems | Blocking state needs clear recovery priority and long-message safe layout. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: State title → concise explanation → required available action → retry/error → account exit when allowed. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | State title → concise explanation → required available action → retry/error → account exit when allowed. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Checking, unavailable config, maintenance, required update, feature unavailable, open-store failure; actual policy is authoritative. Observed state anchors: `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `appGateDecisionProvider`, `appRouterProvider`, `authControllerProvider`, `installedMobileVersionProvider`, `mobileAppConfigProvider`, `mobileBackDispatcherProvider`, `optionalUpdateSuppressionProvider`, `routeInformationProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../application/app_gate_controller.dart`, `../data/mobile_app_config_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Keep gate decision/back-dispatch policy; unavailable config must not look like ordinary empty content; feature-gate restrictions remain. Pass U; preserve J1. |




### E044. Customers directory


| Field | Required detail |
|---|---|
| Route / Surface | /customers; /internal-workspace/customers — [customers_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/customers/presentation/customers_screen.dart#L14); file `omc_app/lib/features/customers/presentation/customers_screen.dart` |
| Persona | Manage/all/relevant customer capabilities; retain exact capability/feature predicates. |
| Purpose | Customers directory: complete this existing user task while preserving its scope and authority. |
| Current UI | Search, status chips, paged counts and customer cards with identity/contact/tax pills. |
| Current UX | Queries scoped paged customers by search/status and opens selected customer ID. |
| Problems | Many contact/tax chips per row make directory difficult to scan; page counts can be mistaken for global totals. File-level style anchors: `L206` `fontSize: 12,`; `L376` `fontSize: 11,`; `L452` `fontSize: 12,`; `L473` `fontSize: 10,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Title/search → filter → customer name/company → account status → one contact line → details. Apply C1–C6. |
| Move/Remove | RELOCATE secondary CNIC/NTN metadata from directory prominence into existing detail; retain it wherever operationally required. |
| New Hierarchy | Title/search → filter → customer name/company → account status → one contact line → details. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/unavailable, empty/matches, pagination, pending/active/attention. Observed state anchors: `L111`, `L112`, `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `customersResultPageProvider`; imports `../data/customers_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Maintain “Customers on this page” meaning; relevant-customer scope and page/search query unchanged; full tax info retained in detail. Pass U; preserve J1. |




### E045. Customer detail


| Field | Required detail |
|---|---|
| Route / Surface | /customers/:customerId — [customer_detail_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/customers/presentation/customer_detail_screen.dart#L14); file `omc_app/lib/features/customers/presentation/customer_detail_screen.dart` |
| Persona | Scoped customer viewer; retain exact capability/feature predicates. |
| Purpose | Customer detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Identity hero, overview, contact/identity, activity, expandable technical details. |
| Current UX | Fetches scoped customer record; shows contact, activity and expandable technical metadata without adding mutations. |
| Problems | Overview cards duplicate status; customer identifier/technical detail should not compete with contact needs. File-level style anchors: `L200` `fontSize: 13,`; `L413` `fontSize: 11,`; `L424` `fontSize: 13,`; `L508` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Identity/account status → contact/tax identity → activity → technical expansion. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Identity/account status → contact/tax identity → activity → technical expansion. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/not found, avatar failure, no activity, expanded technical info. Observed state anchors: `L38`, `L43`, `L225`, `L241` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `customerDetailProvider`; imports `../data/customers_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Technical fields remain available; missing values distinguish not-added from unavailable; scoped record stays same. Pass U; preserve J1. |




### E046. Internal workspace


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace — [internal_workspace_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_workspace_screen.dart#L18); file `omc_app/lib/features/internal_workspace/presentation/internal_workspace_screen.dart` |
| Persona | canAccessInternalWorkspace with individual queue capabilities; retain exact capability/feature predicates. |
| Purpose | Internal workspace: complete this existing user task while preserving its scope and authority. |
| Current UI | Customer search, overview/priority work, work queues, three-column quick actions, performance and settlement/admin links. |
| Current UX | Loads summary/priority queue, searches customer destination and opens permitted work/admin/settlement-review actions. |
| Problems | Dense quick-action grid and multiple metric cards create desktop-dashboard feel. File-level style anchors: `L222` `fontSize: 13.5,`; `L358` `crossAxisCount: 2,`; `L361` `childAspectRatio: 2.35,`; `L411` `fontSize: 11,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Search → priority work → queue rows → summary → permitted operational shortcuts. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Search → priority work → queue rows → summary → permitted operational shortcuts. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Summary/queue independent failures, no assigned work, denied sub-actions, refresh. Observed state anchors: `L38`, `L39`, `L92`, `L109`, `L115` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `effectiveCapabilitiesProvider`, `internalServiceCaseFiltersProvider`, `internalServiceCasesProvider`, `internalWorkspaceSummaryProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Focus/priority selection remains from existing helper; queue totals and role visibility unchanged; Settlement exceptions and admin remain one tap. Pass U; preserve J1. |




### E047. Service case queue


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace/service-cases — [internal_service_cases_screen.dart:29](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart#L29); file `omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart` |
| Persona | Scoped any-service-case viewer; retain exact capability/feature predicates. |
| Purpose | Service case queue: complete this existing user task while preserving its scope and authority. |
| Current UI | Server page/search, primary filters, advanced operational/document sheet, active filters, case cards with counts/priority. |
| Current UX | Loads scoped paged service cases; applies primary and advanced operational/document filters; opens selected case. |
| Problems | Metadata pills dominate readable customer/service identity; filters occupy too much vertical space. File-level style anchors: `L452` `fontSize: 11.5,`; `L567` `fontSize: 12,`; `L597` `fontSize: 10.5,`; `L653` `fontSize: 11.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Title/count → search + filter summary → customer/service → current operational state → next required action → secondary counts. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Title/count → search + filter summary → customer/service → current operational state → next required action → secondary counts. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Initial/error, filtered empty, loading more, overdue/priority, rejected/pending documents. Observed state anchors: `L191`, `L219`, `L221`, `L287`, `L983` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `internalServiceCasePageRepositoryProvider`; imports `../data/internal_service_case_page_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Query, paging, operational/document filters and scoped results remain identical; counts not silently reinterpreted as global. Pass U; preserve J1. |




### E048. Internal payment operations


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace/payments — [internal_operations_center_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart#L18); file `omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart` |
| Persona | canViewAnyPayment; review separately controlled; retain exact capability/feature predicates. |
| Purpose | Internal payment operations: complete this existing user task while preserving its scope and authority. |
| Current UI | Payment page filters, summary counts/pager, own/referral-customer payment cards and guarded detail link. Other area branches exist in file. |
| Current UX | Queries actual payment pages with filters and own/referral scope; selected payment opens review/detail preserving assisted context. |
| Problems | Review queue should lead with amount/customer/evidence, not many colored tags or service-derived metrics. File-level style anchors: `L643` `fontSize: 11,`; `L740` `fontSize: 10,`; `L820` `fontSize: 11.5,`; `L841` `fontSize: 9.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Review title → filter → payment amount/customer → verification state → evidence/review action → pager. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Review title → filter → payment amount/customer → verification state → evidence/review action → pager. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Page loading/error/empty, own/referral scope, review/paid/rejected, next/previous. Observed state anchors: `L86`, `L87`, `L124`, `L175`, `L176` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `internalServiceCasesProvider`, `paymentPageProvider`; imports `../../payments/data/payments_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | PaymentPageQuery and actual payment records retained; no conversion to generic service queue; assisted query propagation unchanged. Pass U; preserve J1. |




### E049. Internal case workspace


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace/service-cases/:caseId — [internal_operations_center_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart#L18); file `omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart` |
| Persona | Scoped case viewer; retain exact capability/feature predicates. |
| Purpose | Internal case workspace: complete this existing user task while preserving its scope and authority. |
| Current UI | InternalServiceCaseWorkspaceScreen resolves case from queue; header/next action, overview, documents, timeline, operations actions. |
| Current UX | Resolves case from current internal queue and opens related operational/evidence actions; missing queue item has dedicated state. |
| Problems | Queue-not-found is not proof backend record does not exist; overview/document metrics compete with next action. File-level style anchors: `L643` `fontSize: 11,`; `L740` `fontSize: 10,`; `L820` `fontSize: 11.5,`; `L841` `fontSize: 9.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Customer/service identity → next case action → evidence → overview/timeline → operations. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Customer/service identity → next case action → evidence → overview/timeline → operations. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Queue loading/error, not in queue, incomplete customer/docs, operational next action. Observed state anchors: `L86`, `L87`, `L124`, `L175`, `L176` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `internalServiceCasesProvider`, `paymentPageProvider`; imports `../../payments/data/payments_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Keep queue lookup contract and “not found in queue” recovery; no new detail endpoint; all links retain caseId. Pass U; preserve J1. |




### E050. Leads pipeline


| Field | Required detail |
|---|---|
| Route / Surface | /leads; ?action=create — [leads_screen.dart:15](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/leads/presentation/leads_screen.dart#L15); file `omc_app/lib/features/leads/presentation/leads_screen.dart` |
| Persona | canManageLeads; retain exact capability/feature predicates. |
| Purpose | Leads pipeline: complete this existing user task while preserving its scope and authority. |
| Current UI | Search/status filter, metric grid, lead cards/pager and guarded creation sheet. |
| Current UX | Queries lead pages/search/status; authorized create opens sheet (also action=create); saves via repository then refreshes. |
| Problems | Five lead metrics and many small metadata chips crowd pipeline rows. File-level style anchors: `L328` `fontSize: 13,`; `L554` `fontSize: 12.5,`; `L621` `fontSize: 13,`; `L1164` `fontSize: 12,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Leads + create → search/status → lead/contact + stage → service interest → follow-up metadata → pager. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Leads + create → search/status → lead/contact + stage → service interest → follow-up metadata → pager. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/unavailable, no leads/matches, create permission change, save success/failure. Observed state anchors: `L124`, `L127`, `L207`, `L264`, `L737` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `leadsPageProvider`, `leadsProvider`, `leadsRepositoryProvider`, `leadsResultPageProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/leads_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Create-on-load remains single open; existing status/query/paging and creation mutation preserved; no invented conversion editing. Pass U; preserve J1. |




### E051. Lead detail


| Field | Required detail |
|---|---|
| Route / Surface | /leads/:leadId — [lead_detail_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/leads/presentation/lead_detail_screen.dart#L11); file `omc_app/lib/features/leads/presentation/lead_detail_screen.dart` |
| Persona | canManageLeads; retain exact capability/feature predicates. |
| Purpose | Lead detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Shared CRM hero, contact/record, activity timeline placeholder, next-action informational rows and ID footer. |
| Current UX | Fetches lead record and presents contact/assignment/conversion information; follow-up/conversion rows do not provide mutations. |
| Problems | Placeholder activity and explanatory next actions can look interactive; technical identifiers overly repeated. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Lead/stage → contact/service interest → assignment/conversion record → truthful activity availability. Apply C1–C6. |
| Move/Remove | CONSOLIDATE duplicate Lead ID footer with record row; remove decorative placeholder framing only, retaining honest unavailable-activity message. |
| New Hierarchy | Lead/stage → contact/service interest → assignment/conversion record → truthful activity availability. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/not found, empty contact/activity. Observed state anchors: `L35`, `L40` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `leadDetailProvider`; imports `../data/leads_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P2 |
| Acceptance Criteria | Do not introduce follow-up/conversion mutations: current detail is informational; all existing record values remain. Pass U; preserve J1. |




### E052. Tasks list


| Field | Required detail |
|---|---|
| Route / Surface | /tasks — [tasks_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tasks/presentation/tasks_screen.dart#L13); file `omc_app/lib/features/tasks/presentation/tasks_screen.dart` |
| Persona | canViewTasks; retain exact capability/feature predicates. |
| Purpose | Tasks list: complete this existing user task while preserving its scope and authority. |
| Current UI | Paged read-only task list, search/status tabs, priority sheet and context metadata. |
| Current UX | Searches and filters paged read-only tasks by status/priority; selecting opens task detail. |
| Problems | Dense status/assignee/priority/due chips; people may assume task editing exists. File-level style anchors: `L215` `fontSize: 12.5,`; `L382` `fontSize: 12,`; `L795` `fontSize: 11,`; `L807` `fontSize: 11.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Tasks → search/status/priority → task title → due/priority → assignment/service context. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Tasks → search/status/priority → task title → due/priority → assignment/service context. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error, no tasks/no matches, loading more/failure, priority/status filters. Observed state anchors: `L286`, `L390` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `tasksRepositoryProvider`; imports `../data/tasks_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Read-only authority remains; no add/edit/complete controls invented; failed load-more preserves existing rows. Pass U; preserve J1. |




### E053. Task detail


| Field | Required detail |
|---|---|
| Route / Surface | /tasks/:taskId — [task_detail_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tasks/presentation/task_detail_screen.dart#L13); file `omc_app/lib/features/tasks/presentation/task_detail_screen.dart` |
| Persona | canViewTasks; linked-case access checked; retain exact capability/feature predicates. |
| Purpose | Task detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Task hero, read-only notice, detailed fields, linked service-case CTA. |
| Current UX | Fetches read-only task, retries same ID and opens linked service case only through existing access rule. |
| Problems | Read-only notice and chip duplicate; lengthy metadata needs accessible label/value stacking. File-level style anchors: `L99` `fontSize: 12.5,`; `L176` `fontSize: 11.5,`; `L235` `fontSize: 12,`; `L337` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Task/status/due → description → assignment → linked case → secondary record fields. Apply C1–C6. |
| Move/Remove | CONSOLIDATE read-only badge and notice into one concise explanation; preserve read-only semantics. |
| New Hierarchy | Task/status/due → description → assignment → linked case → secondary record fields. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/not found, missing linked case, long description. Observed state anchors: `L39`, `L40`, `L45` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `taskDetailProvider`, `tasksProvider`; imports `../../auth/application/auth_controller.dart`, `../data/tasks_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | No mutation controls; linked-case route remains authority-aware; retry invalidates same task provider. Pass U; preserve J1. |




### E054. My referrals


| Field | Required detail |
|---|---|
| Route / Surface | /my-referrals — [my_referrals_screen.dart:16](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/my_referrals_screen.dart#L16); file `omc_app/lib/features/profile/presentation/my_referrals_screen.dart` |
| Persona | canOwnReferrals; retain exact capability/feature predicates. |
| Purpose | My referrals: complete this existing user task while preserving its scope and authority. |
| Current UI | Referral code copy/share hero, total/active/services metrics, search and paged referral customer cards. |
| Current UX | Loads/searches/pages own referrals; copies/shares referral code and opens scoped customer referral detail. |
| Problems | Hero/code/three counters compete with customers; status and referral consent need separate meanings. File-level style anchors: `L181` `fontSize: 12,`; `L271` `fontSize: 12,`; `L293` `fontSize: 11,`; `L337` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Referral code + copy/share → customer search/list → concise summary. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Referral code + copy/share → customer search/list → concise summary. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Initial/error, no referrals/no matches, load more, inactive code. Observed state anchors: `L101`, `L111`, `L141`, `L143`, `L194` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `referralRepositoryProvider`; imports `../data/referral_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Copy/share use same code; pagination/search and referral status untouched; masked/limited customer data not expanded. Pass U; preserve J1. |




### E055. Referral detail


| Field | Required detail |
|---|---|
| Route / Surface | /my-referrals/:customerId?customer_name=… — [referral_detail_screen.dart:14](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/referral_detail_screen.dart#L14); file `omc_app/lib/features/profile/presentation/referral_detail_screen.dart` |
| Persona | Referral owner with scoped customer visibility; retain exact capability/feature predicates. |
| Purpose | Referral detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Customer status/consent badges, metrics, active/services/requests sections and Start service for this customer. |
| Current UX | Fetches referral customer service/request activity; eligible Start service action propagates assisted customer and consent context. |
| Problems | Consent and customer approval can be visually conflated; numerous counters precede service records. File-level style anchors: `L134` `fontSize: 12,`; `L277` `fontSize: 11,`; `L370` `fontSize: 11.5,`; `L420` `fontSize: 10.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Customer + consent/access → start assisted service if allowed → service/request activity → summary. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Customer + consent/access → start assisted service if allowed → service/request activity → summary. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error, no activity/services/requests, consent absent/granted, assisted CTA. Observed state anchors: `L78`, `L183`, `L204`, `L218`, `L408` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `referralRepositoryProvider`; imports `../data/referral_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Customer ID/name and assisted context passed exactly; consent limitation preserved; no service activity differs from missing permission. Pass U; preserve J1. |




### E056. My commissions


| Field | Required detail |
|---|---|
| Route / Surface | /my-commissions — [my_commissions_screen.dart:7](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/my_commissions_screen.dart#L7); file `omc_app/lib/features/commissions/presentation/my_commissions_screen.dart` |
| Persona | canViewOwnCommissions; retain exact capability/feature predicates. |
| Purpose | My commissions: complete this existing user task while preserving its scope and authority. |
| Current UI | Currency-separated outstanding/settled summaries, expandable filters, commission list and paging. |
| Current UX | Loads currency summaries and filtered earning pages; row opens own commission detail. |
| Problems | Mixed financial metadata and filter fields need hierarchy; currencies must never be combined. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Currency totals → filters summary → earning amount/status → customer/service → month/reference. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Currency totals → filters summary → earning amount/status → customer/service → month/reference. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading/error/empty, filter empty, paging, multiple currencies. Observed state anchors: `L123` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `commissionPageLoaderProvider`, `commissionSummaryLoaderProvider`; imports `../data/commission_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Currency grouping/status/date/customer/service queries preserved; outstanding/settled meanings unchanged. Pass U; preserve J1. |




### E057. Commission detail


| Field | Required detail |
|---|---|
| Route / Surface | /my-commissions/:earningId — [commission_detail_screen.dart:13](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/commission_detail_screen.dart#L13); file `omc_app/lib/features/commissions/presentation/commission_detail_screen.dart` |
| Persona | Own commission viewer; retain exact capability/feature predicates. |
| Purpose | Commission detail: complete this existing user task while preserving its scope and authority. |
| Current UI | Session-epoch provider and a separate Card for each amount/basis/rate/customer/service/accounting-evidence value. |
| Current UX | Session-epoch-bound fetchOne retrieves own earning and accounting/settlement provenance; values are selectable. |
| Problems | One Card per field makes the financial/audit record unnecessarily long; amount and evidence require distinct hierarchy. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Amount/currency → commission status → basis/customer/service → accounting/settlement evidence. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Amount/currency → commission status → basis/customer/service → accounting/settlement evidence. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading/error/missing or partial evidence. Observed state anchors: `L23`, `L24` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `commissionDetailProvider`, `commissionRepositoryProvider`, `sessionEpochProvider`; imports `../data/commission_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | fetchOne ownership/session invalidation unchanged; error stays recoverable without leaking details. Pass U; preserve J1. |




### E058. Commission operations


| Field | Required detail |
|---|---|
| Route / Surface | /internal-workspace/commissions — [finance_commissions_screen.dart:11](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L11); file `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart` |
| Persona | Approve and/or mark-paid capabilities; retain exact capability/feature predicates. |
| Purpose | Commission operations: complete this existing user task while preserving its scope and authority. |
| Current UI | Status/evidence filters, allocation cards, approve/reject/payable/record-paid actions; confirm/reason/settlement sheets. |
| Current UX | Filters allocations/evidence; eligible approve/reject/payable/record-paid mutations use separate confirmations and settlement input. |
| Problems | Multiple similarly styled financial mutations and dense evidence pills increase wrong-action risk. File-level style anchors: `L430` `fontSize: 12.5,`; `L502` `fontSize: 11.5,`; `L677` `fontSize: 12.5,`; `L760` `fontSize: 13,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Queue/filter → amount/recipient → status/evidence → permitted next transition → secondary record details. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Queue/filter → amount/recipient → status/evidence → permitted next transition → secondary record details. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Loading/error/empty, evidence missing, each transition busy/failure, forbidden actions. Observed state anchors: `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeCommissionRepositoryProvider`; imports `../data/finance_commission_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Approve, payable and paid remain different mutations; evidence restrictions, settlement reference/date and required rejection reason preserved. Pass U; preserve J1. |




### E059. Settlement exceptions


| Field | Required detail |
|---|---|
| Route / Surface | Navigator from internal workspace; no GoRoute — [settlement_exceptions_screen.dart:9](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart#L9); file `omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart` |
| Persona | Workspace finance access per focus.canShowSettlementExceptions; retain exact capability/feature predicates. |
| Purpose | Settlement exceptions: complete this existing user task while preserving its scope and authority. |
| Current UI | Reconciliation query/filter/pager, human-review banner, exception cards/open case/ignore/resolve and finance-note confirmation. |
| Current UX | Queries reconciliation reviews; opens case or confirms resolve/ignore with finance note; records human review only. |
| Problems | Review actions need clear impact wording; technical exception text can dominate. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Human review context → filters → case/amount if provided → exception reason → review decision → evidence metadata. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Human review context → filters → case/amount if provided → exception reason → review decision → evidence metadata. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Loading/error/empty, search/status page, resolve/ignore confirmation/failure. Observed state anchors: `L63`, `L64`, `L116`, `L224`, `L238` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeReconciliationPageProvider`, `financeReconciliationRepositoryProvider`; imports `../data/finance_reconciliation_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Resolve/ignore only records human review under existing repository contract; never claim payment repaired or settlement executed. Pass U; preserve J1. |




### E060. Administration


| Field | Required detail |
|---|---|
| Route / Surface | /admin-control — [admin_control_screen.dart:12](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_control_screen.dart#L12); file `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart` |
| Persona | Manage staff / review registrations / business settings separately; retain exact capability/feature predicates. |
| Purpose | Administration: complete this existing user task while preserving its scope and authority. |
| Current UI | Applications, existing staff grants/access profile, business settings and numeric edits; each section gated. |
| Current UX | Loads capability-scoped application/staff/settings sections; grants existing staff access, edits allowed role set and updates business values. |
| Problems | Dense settings and consequential access mutations require clearer section grouping and target identity. File-level style anchors: `L174` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L303` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L405` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L554` `style: TextStyle(fontSize: 12.5, height: 1.4),` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Authorized pending decisions → staff list/access → business configuration; contextual dialogs with target summary. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Authorized pending decisions → staff list/access → business configuration; contextual dialogs with target summary. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Overview/settings independent errors, no roles, dirty dialogs, success/failure, partial capabilities. Observed state anchors: `L87`, `L88`, `L113`, `L114`, `L144` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminBusinessSettingsProvider`, `adminControlRepositoryProvider`, `effectiveCapabilitiesProvider`, `scopedAdminOverviewProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`, `../data/admin_overview_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Never turn existing-staff grant into arbitrary user creation; role choices from backend; registration decisions/settings payload retained. Pass U; preserve J1. |




### E061. Operational controls


| Field | Required detail |
|---|---|
| Route / Surface | /admin-control/operations — [admin_operations_screen.dart:12](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart#L12); file `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart` |
| Persona | Reassign / retry sync / business settings capabilities; retain exact capability/feature predicates. |
| Purpose | Operational controls: complete this existing user task while preserving its scope and authority. |
| Current UI | Server tabs/search/pager; fetch options then reassign eligible staff, retry exhausted sync and approve/reject discount dialogs. |
| Current UX | Queries operations queue, loads case options, then confirms eligible reassignment, sync retry or discount review. |
| Problems | Many numeric/technical fields in compact dialogs; dangerous and ordinary operations compete. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Operation type/filter → case/customer/service → blocker → authorized action → full review context. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Operation type/filter → case/customer/service → blocker → authorized action → full review context. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Options loading/failure, no candidates, stale options, dirty selection, mutation success/error. Observed state anchors: `L42`, `L99`, `L105`, `L126`, `L228` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminCaseOptionsProvider`, `adminControlRepositoryProvider`, `adminOperationsProvider`, `effectiveCapabilitiesProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Eligible candidate query preserved; sync retry and discount approval remain explicit; rejection reason and busy locking retained. Pass U; preserve J1. |




### E062. Application shell and back navigation


| Field | Required detail |
|---|---|
| Route / Surface | StatefulShellRoute + ShellNavScaffold — [main_shell.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/main_shell.dart#L1); file `omc_app/lib/app/main_shell.dart` |
| Persona | All allowed personas; retain exact capability/feature predicates. |
| Purpose | Application shell and back navigation: complete this existing user task while preserving its scope and authority. |
| Current UI | IndexedStack branches and standalone detail wrappers share bottom bar, sheets, access feedback and back/dirty guard. |
| Current UX | Selects/restores shell branch, opens More/Quick Actions, enforces route/dirty guards and delegates auth redirects. |
| Problems | Different shell wrappers risk duplicate bottom bars and selected-tab inconsistency during visual migration. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Single current-page header → content → persistent navigation; request draft owns only its submit bar. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Single current-page header → content → persistent navigation; request draft owns only its submit bar. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Access-denied notice, guest/pending/rejected, More already open, logout busy/failure, deep link, dirty form. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `effectiveCapabilitiesProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `unreadNotificationsProvider`; imports `../features/app_config/data/mobile_app_config_repository.dart`, `../features/auth/application/auth_controller.dart`, `../features/auth/application/auth_state.dart`, `../features/notifications/data/notifications_repository.dart`, `../features/profile/data/profile_repository.dart`, `providers/effective_capabilities_provider.dart`, `../core/forms/dirty_form_controller.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Branch restoration/reselect, /more dismissal→/home, detail back and dirty guard remain; no nested bottom bars; no route names/parameters change. Pass U; preserve J1. |




### E063. Bottom navigation


| Field | Required detail |
|---|---|
| Route / Surface | Persistent shell bottom navigation — [omc_bottom_nav.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/navigation/omc_bottom_nav.dart#L1); file `omc_app/lib/app/navigation/omc_bottom_nav.dart` |
| Persona | Customer and internal variants; retain exact capability/feature predicates. |
| Purpose | Bottom navigation: complete this existing user task while preserving its scope and authority. |
| Current UI | Five visual positions including central action; route branches keep historical indices; 10px labels, 8.5 badge; height grows with text scale. |
| Current UX | Destination taps dispatch existing branch index; central action and More dispatch sheet callbacks; current destination/unread count drive appearance. |
| Problems | 10px meaningful navigation text is too small; height adaptation alone does not guarantee readable wrapped labels. File-level style anchors: `L302` `fontSize: 10,`; `L390` `fontSize: 10,`; `L424` `fontSize: 8.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Keep exact order/index bindings; 24px icons → navigation 12/1.2 labels; central action uses button semantics. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Keep exact order/index bindings; 24px icons → navigation 12/1.2 labels; central action uses button semantics. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Selected/unselected, unread badge, locked destinations, 1–2x text, keyboard/safe area. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | At 320px/2x all labels accessible and destinations tappable; no label scaling clamp; More opens overlay, central action never claims selected page. Pass U; preserve J1. |




### E064. More menu


| Field | Required detail |
|---|---|
| Route / Surface | /more or bottom More — [omc_more_sheet.dart:112](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/navigation/omc_more_sheet.dart#L112); file `omc_app/lib/app/navigation/omc_more_sheet.dart` |
| Persona | Capability/feature-scoped public/customer/internal; retain exact capability/feature predicates. |
| Purpose | More menu: complete this existing user task while preserving its scope and authority. |
| Current UI | 82%-height scroll sheet, identity header, limited-access note, capability groups and module-colored rows. |
| Current UX | Builds capability/config groups, pops selected callback result, then host navigates; /more dismissal with no selection returns Home. |
| Problems | 11.5 headings/13 labels/w800–900 and colored icons; long identity ellipsized. File-level style anchors: `L199` `fontSize: 11.5,`; `L281` `fontSize: 13,`; `L417` `fontSize: 12,`; `L509` `fontSize: 12.5,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Profile header → My OMC → Tax & knowledge → Tools & help → Account; internal grouping retained. Apply C1–C6. |
| Move/Remove | RELOCATE Tax and Knowledge to an immediately visible group before optional expense tools; rename Tax → Tax calculator, Knowledge → Knowledge & news. |
| New Hierarchy | Profile header → My OMC → Tax & knowledge → Tools & help → Account; internal grouping retained. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Guest/pending/rejected/internal, feature flags, long identity, unread >99, dismissal. Observed state anchors: `L571` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; imports `../../features/auth/application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Every existing allowed action remains with same callback; 16px rows/14px headings, min56 row, full labels at 2x; no new capability visibility. Pass U; preserve J1. |




### E065. Quick Actions


| Field | Required detail |
|---|---|
| Route / Surface | Central action sheet — [omc_quick_actions_sheet.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/app/navigation/omc_quick_actions_sheet.dart#L1); file `omc_app/lib/app/navigation/omc_quick_actions_sheet.dart` |
| Persona | Capability-scoped customer/internal/public; retain exact capability/feature predicates. |
| Purpose | Quick Actions: complete this existing user task while preserving its scope and authority. |
| Current UI | Three-column GridView, aspect ratio 1.05, 10.8 labels and module icons. |
| Current UX | Builds existing capability action list; selection closes sheet and invokes selected host callback. |
| Problems | Fixed three-column tiles compress action labels and large-text layout. File-level style anchors: `L110` `fontSize: 12.5,`; `L120` `crossAxisCount: 3,`; `L123` `childAspectRatio: 1.05,`; `L182` `fontSize: 10.8,` |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Sheet heading → action tiles in current capability order → scroll; 2 columns ordinary phones, 1 narrow/large text. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Sheet heading → action tiles in current capability order → scroll; 2 columns ordinary phones, 1 narrow/large text. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Action set varies by capability, long labels, scroll, no available action. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; imports `../../features/auth/application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | All callbacks unchanged; 16px labels wrap with natural height; full action name visible at 2x; no hard-coded six-action limit. Pass U; preserve J1. |




### E066. Unknown / invalid route recovery


| Field | Required detail |
|---|---|
| Route / Surface | GoRouter errorBuilder — [route_failure_screen.dart:7](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/route_failure_screen.dart#L7); file `omc_app/lib/core/widgets/route_failure_screen.dart` |
| Persona | All, recovery derived from auth/capability; retain exact capability/feature predicates. |
| Purpose | Unknown / invalid route recovery: complete this existing user task while preserving its scope and authority. |
| Current UI | Route failure icon/title/message, capability-selected primary recovery and optional back. |
| Current UX | Router errorBuilder chooses safe recovery from current auth/capabilities and optional back based on navigator state. |
| Problems | Need same state styling and safe long recovery label. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Unavailable destination → explanation → existing safe recovery → back if possible. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Unavailable destination → explanation → existing safe recovery → back if possible. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Unknown/malformed deep link, guest/checking/pending/internal, can/cannot pop. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | resolveRouteFailureRecovery remains source of destination; no blanket home/login redirect introduced. Pass U; preserve J1. |




### E067. Unsaved changes confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Global form discard dialog — [dirty_form_controller.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/forms/dirty_form_controller.dart#L1); file `omc_app/lib/core/forms/dirty_form_controller.dart` |
| Persona | Any dirty guarded form; retain exact capability/feature predicates. |
| Purpose | Unsaved changes confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Non-barrier-dismissible dialog with Stay and Discard, controller-driven PopScope and active form registration. |
| Current UX | Stay returns false; confirmed Discard permits next exit through DirtyFormController; barrier dismissal is disabled. |
| Problems | Discard uses filled primary styling; destructive intent should be unmistakable without changing default result. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Discard changes? → consequence → Stay safe action → Destructive Discard. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Discard changes? → consequence → Stay safe action → Destructive Discard. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Dirty/pristine/submitting, system back, shell navigation, confirmed/cancelled. Observed state anchors: `L97`, `L98`, `L110`, `L111`, `L114` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `NotifierProvider`, `activeDirtyFormProvider`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Stay/back/barrier never discards; successful submission allows exit; controller registration/disposal unchanged. Pass U; preserve J1. |




### E068. Signup role step


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Signup role step — [signup_steps.dart:973](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_steps.dart#L973); file `omc_app/lib/features/auth/presentation/signup_steps.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Signup role step: complete this existing user task while preserving its scope and authority. |
| Current UI | Role cards and New to OMC / Already an OMC customer entry |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L32` `fontSize: 12,`; `L41` `fontSize: 12,`; `L109` `fontSize: 13,`; `L294` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Role selection → existing-account activation alternative Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Role selection → existing-account activation alternative |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Selection never grants internal privileges; Continue uses existing role value. Pass U; preserve J1. |




### E069. Signup details step


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Signup details step — [signup_steps.dart:973](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_steps.dart#L973); file `omc_app/lib/features/auth/presentation/signup_steps.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Signup details step: complete this existing user task while preserving its scope and authority. |
| Current UI | Name/email/username availability/mobile/WhatsApp/CNIC/NTN/address and conditional professional fields |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L32` `fontSize: 12,`; `L41` `fontSize: 12,`; `L109` `fontSize: 13,`; `L294` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Identity → contact → tax identity → conditional professional details Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Identity → contact → tax identity → conditional professional details |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Fields retain format validators; matching WhatsApp checkbox keeps current value-copy rule; errors beside fields. Pass U; preserve J1. |




### E070. Signup preferences step


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Signup preferences step — [signup_steps.dart:973](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_steps.dart#L973); file `omc_app/lib/features/auth/presentation/signup_steps.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Signup preferences step: complete this existing user task while preserving its scope and authority. |
| Current UI | Referral-code verification and acquisition source/other input |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L32` `fontSize: 12,`; `L41` `fontSize: 12,`; `L109` `fontSize: 13,`; `L294` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Referral optional toggle/code → verification result → acquisition source Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Referral optional toggle/code → verification result → acquisition source |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Verification result survives navigation according to current state; invalid referral never shows verified badge. Pass U; preserve J1. |




### E071. Signup security/review step


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Signup security/review step — [signup_steps.dart:973](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_steps.dart#L973); file `omc_app/lib/features/auth/presentation/signup_steps.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Signup security/review step: complete this existing user task while preserving its scope and authority. |
| Current UI | Customer/professional review notice and consent before verification email |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L32` `fontSize: 12,`; `L41` `fontSize: 12,`; `L109` `fontSize: 13,`; `L294` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Review identity → consent → Send verification email Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Review identity → consent → Send verification email |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Do not introduce pre-verification password collection or remove existing consent. Pass U; preserve J1. |




### E072. Pending registration success


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Pending registration success — [signup_screen.dart:34](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/signup_screen.dart#L34); file `omc_app/lib/features/auth/presentation/signup_screen.dart` |
| Persona | New customer / public professional registration options allowed by source; retain exact capability/feature predicates. |
| Purpose | Pending registration success: complete this existing user task while preserving its scope and authority. |
| Current UI | Check-your-email screen, login and resend timer |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L901` `fontSize: 12.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Email-check status → resend countdown → resend → login Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Email-check status → resend countdown → resend → login |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L152`, `L168`, `L181`, `L244`, `L507` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authRepositoryProvider`, `signupSubmitProvider`, `signupUsernameAvailabilityProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/auth_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Cooldown blocks duplicate resend; route remains /signup state; no assumption account is already active. Pass U; preserve J1. |




### E073. Dynamic service form controls


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Dynamic service form controls — [service_request_draft_form_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart#L1); file `omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Dynamic service form controls: complete this existing user task while preserving its scope and authority. |
| Current UI | Backend fields rendered as check/select/text with required marker and helper; additional notes |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L197` `fontSize: 11.5,`; `L247` `fontSize: 11,`; `L274` `fontSize: 13,`; `L284` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Section title → field label → control → helper/error Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Section title → field label → control → helper/error |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L163`, `L307` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Fieldname, selected values, required validation and serialization identical; no date-picker/type conversion invented. Pass U; preserve J1. |




### E074. Internal discount form


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Internal discount form — [service_request_draft_service_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_service_sections.dart#L1); file `omc_app/lib/features/service_requests/presentation/service_request_draft_service_sections.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Internal discount form: complete this existing user task while preserving its scope and authority. |
| Current UI | Type/value/reason plus original/discount/final price preview |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L212` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Discount type/value → reason → price review Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Discount type/value → reason → price review |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L81` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Percentage/fixed validation and original-price requirement preserved; preview does not authorize discount. Pass U; preserve J1. |




### E075. Request submit bar


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Request submit bar — [service_request_draft_form_sections.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart#L1); file `omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Request submit bar: complete this existing user task while preserving its scope and authority. |
| Current UI | Completed/remaining fields and submit; attachmentCount remains zero |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L197` `fontSize: 11.5,`; `L247` `fontSize: 11,`; `L274` `fontSize: 13,`; `L284` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Completion summary → full-width Submit Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Completion summary → full-width Submit |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L163`, `L307` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Retain submitting lock and responsive stacking; keyboard/large text cannot obscure CTA. Pass U; preserve J1. |




### E076. Customer required-document upload rows


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Customer required-document upload rows — [customer_service_case_detail_evidence.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart#L1); file `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Customer required-document upload rows: complete this existing user task while preserving its scope and authority. |
| Current UI | Per-requirement upload/reupload, uploading set, statuses and View uploaded documents |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L55` `fontSize: 12.5,`; `L73` `fontSize: 12.5,`; `L258` `fontSize: 12.5,`; `L269` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Requirement name → rejection instruction → upload state/action Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Requirement name → rejection instruction → upload state/action |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L50`, `L87`, `L384`, `L390` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `customerServiceCaseDetailProvider`, `documentAttachmentControllerProvider`, `documentPageProvider`, `documentsProvider`, `documentsRepositoryProvider`, `homeDashboardSummaryProvider`, `serviceCasesProvider`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Each uploadIdentity stays independent; attachment validation and request refresh unchanged. Pass U; preserve J1. |




### E077. Receipt upload action/progress


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Receipt upload action/progress — [payment_action_card.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/widgets/payment_action_card.dart#L1); file `omc_app/lib/features/payments/presentation/widgets/payment_action_card.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Receipt upload action/progress: complete this existing user task while preserving its scope and authority. |
| Current UI | Payment action, receipt replacement, percent/indeterminate progress and Cancel |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L75` `fontSize: 12,`; `L186` `fontSize: 13,`; `L293` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Payment action → progress text → cancel → invoice/proof secondaries Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Payment action → progress text → cancel → invoice/proof secondaries |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Cancel reaches existing token; unknown byte total stays indeterminate; submitted receipt never reads Paid. Pass U; preserve J1. |




### E078. Create support ticket form


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Create support ticket form — [support_screen_legacy.dart:19](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_screen_legacy.dart#L19); file `omc_app/lib/features/support/presentation/support_screen_legacy.dart` |
| Persona | Public contacts; authorized own tickets or internal queue; retain exact capability/feature predicates. |
| Purpose | Create support ticket form: complete this existing user task while preserving its scope and authority. |
| Current UI | Inline topic selector/message and mutation CTA |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L283` `fontSize: 11,`; `L679` `fontSize: 10.5,`; `L912` `fontSize: 12,`; `L932` `fontSize: 10,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Topic → message → Create ticket Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Topic → message → Create ticket |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L52`, `L79`, `L164`, `L397`, `L599` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `activeSupportTicketProvider`, `appFaqsProvider`, `authControllerProvider`, `supportConfigProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketPageProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../content/data/app_content_repository.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Required topic/message and returned ticket handling unchanged; submitted text survives failure. Pass U; preserve J1. |




### E079. Support FAQ/topics/contact sections


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Support FAQ/topics/contact sections — [support_screen_legacy.dart:19](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_screen_legacy.dart#L19); file `omc_app/lib/features/support/presentation/support_screen_legacy.dart` |
| Persona | Public contacts; authorized own tickets or internal queue; retain exact capability/feature predicates. |
| Purpose | Support FAQ/topics/contact sections: complete this existing user task while preserving its scope and authority. |
| Current UI | FAQ expansions, WhatsApp topic links, office/hours/channel rows |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L283` `fontSize: 11,`; `L679` `fontSize: 10.5,`; `L912` `fontSize: 12,`; `L932` `fontSize: 10,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Direct channel → FAQ list → additional contact details Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Direct channel → FAQ list → additional contact details |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L52`, `L79`, `L164`, `L397`, `L599` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `activeSupportTicketProvider`, `appFaqsProvider`, `authControllerProvider`, `supportConfigProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketPageProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../content/data/app_content_repository.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | No topic silently creates a ticket; WhatsApp failure retains existing launcher feedback. Pass U; preserve J1. |




### E080. Conversation composer / attachments


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Conversation composer / attachments — [support_ticket_detail_legacy_screen.dart:21](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart#L21); file `omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart` |
| Persona | Ticket owner or support workspace; retain exact capability/feature predicates. |
| Purpose | Conversation composer / attachments: complete this existing user task while preserving its scope and authority. |
| Current UI | Picked attachment preview, message, attach/send controls and closed restriction |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L514` `fontSize: 12,`; `L542` `fontSize: 12,`; `L597` `fontSize: 12,`; `L624` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Draft message → file preview/removal → Send Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Draft message → file preview/removal → Send |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L81`, `L82`, `L85`, `L177`, `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | 10MB/empty/type checks preserved; closed state disables replies; draft and file remain after failed send. Pass U; preserve J1. |




### E081. Tax result / breakdown / comparison


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Tax result / breakdown / comparison — [tax_calculator_screen.dart:16](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart#L16); file `omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart` |
| Persona | Guest/pending/approved/staff according to capabilities/config; retain exact capability/feature predicates. |
| Purpose | Tax result / breakdown / comparison: complete this existing user task while preserving its scope and authority. |
| Current UI | Annual estimate, monthly take-home/rate, readiness insights, tax slab breakdown and next steps |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Estimated annual tax → monthly metrics → labeled collapsible breakdown/comparison → service CTA Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Estimated annual tax → monthly metrics → labeled collapsible breakdown/comparison → service CTA |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L105`, `L109`, `L307`, `L374`, `L388` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `effectiveCapabilitiesProvider`, `taxCalculationRepositoryProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../data/tax_calculation_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | All numbers/currency/tax year and disclaimer sourced from existing result; no local recalculation or implied filing guarantee. Pass U; preserve J1. |




### E082. Advanced tax inputs


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Advanced tax inputs — [tax_calculator_screen.dart:16](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart#L16); file `omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart` |
| Persona | Guest/pending/approved/staff according to capabilities/config; retain exact capability/feature predicates. |
| Purpose | Advanced tax inputs: complete this existing user task while preserving its scope and authority. |
| Current UI | Refine calculation expansion with config-driven checks/select/numeric fields |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Refine calculation → current income-type fields → inline helpers Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Refine calculation → current income-type fields → inline helpers |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L105`, `L109`, `L307`, `L374`, `L388` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `effectiveCapabilitiesProvider`, `taxCalculationRepositoryProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../data/tax_calculation_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Hidden-field reset/retention follows existing implementation; expand when its field validation fails as separately reviewed UX logic. Pass U; preserve J1. |




### E083. Home content rail


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Home content rail — [home_content_rail.dart:40](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/widgets/home_content_rail.dart#L40); file `omc_app/lib/features/home/presentation/widgets/home_content_rail.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Home content rail: complete this existing user task while preserving its scope and authority. |
| Current UI | Horizontal backend article/content cards with image fallback and click callback |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L99` `fontSize: 9.5,`; `L120` `fontSize: 9,`; `L148` `fontSize: 11.5,`; `L167` `fontSize: 10.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Section → headline cards → type/date secondary Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Section → headline cards → type/date secondary |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L19` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Preserve backend destination validation; no content omitted to cap card count; scroll and focus reveal all items. Pass U; preserve J1. |




### E084. Home featured carousel


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Home featured carousel — [home_featured_carousel.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/widgets/home_featured_carousel.dart#L1); file `omc_app/lib/features/home/presentation/widgets/home_featured_carousel.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Home featured carousel: complete this existing user task while preserving its scope and authority. |
| Current UI | PageView featured banners and page indicators |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L169` `fontSize: 10.5,`; `L196` `fontSize: 12.5,`; `L213` `fontSize: 12.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Readable headline/summary → existing CTA → page indication Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Readable headline/summary → existing CTA → page indication |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L37` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Image has fallback; reduced-motion behavior verified; no automatically advancing focus; preserve content action. Pass U; preserve J1. |




### E085. Home service-search suggestions


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Home service-search suggestions — [customer_guest_home_view.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/customer_guest_home_view.dart#L18); file `omc_app/lib/features/home/presentation/customer_guest_home_view.dart` |
| Persona | Guest, pending, rejected and remaining non-internal fallback; retain exact capability/feature predicates. |
| Purpose | Home service-search suggestions: complete this existing user task while preserving its scope and authority. |
| Current UI | Search field and matching-service suggestions |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L355` `fontSize: 12,`; `L384` `fontSize: 11.5,`; `L560` `fontSize: 10,`; `L808` `fontSize: 13.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Search → readable result title → service detail Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Search → readable result title → service detail |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L280`, `L510`, `L671`, `L690` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; imports `../../auth/application/auth_state.dart`, `../data/home_dashboard_repository.dart`, `../data/mobile_quick_actions_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keyboard navigation and tap select same service ID; search query passed safely to /services. Pass U; preserve J1. |




### E086. Cloud expense history / local pending entries


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Cloud expense history / local pending entries — [expense_tracker_screen.dart:259](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L259); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Cloud expense history / local pending entries: complete this existing user task while preserving its scope and authority. |
| Current UI | Server-paged cloud list plus unsynced local entries |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Account history → existing filter/page controls → pending local entries clearly marked Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Account history → existing filter/page controls → pending local entries clearly marked |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | FinancialSummary, KeyValueRow, StatusBadge, ActionRow, FormField, ErrorState; feature-specific calculations remain outside components. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Account switch cancels stale export/fetch influence; totals are not fabricated from only one page. Pass U; preserve J1. |




### E087. Freshness warning / retry


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Freshness warning / retry — [data_freshness_banner.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/data_freshness_banner.dart#L1); file `omc_app/lib/core/widgets/data_freshness_banner.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Freshness warning / retry: complete this existing user task while preserving its scope and authority. |
| Current UI | 12.5 title, 11.5 message, timestamp and responsive retry |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. File-level style anchors: `L55` `fontSize: 12.5,`; `L64` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Stale/current refresh title → timestamp/reason → retry Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Stale/current refresh title → timestamp/reason → retry |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L6`, `L7` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keep previous data labeled stale; retrying disables duplicate retry; screen reader hears state once, not repeated every rebuild. Pass U; preserve J1. |




### E088. Shared empty / error / access / configuration state


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Shared empty / error / access / configuration state — [app_state.dart:162](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_state.dart#L162); file `omc_app/lib/core/widgets/app_state.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Shared empty / error / access / configuration state: complete this existing user task while preserving its scope and authority. |
| Current UI | AppStateView and dedicated adapters, icon/title/body/action and live semantics |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Specific state heading → one actionable explanation → permitted recovery Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Specific state heading → one actionable explanation → permitted recovery |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Empty never substitutes for failure; classified non-retryable error never exposes retry; use 20/16 typography. Pass U; preserve J1. |




### E089. Loading skeleton


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Loading skeleton — [app_skeleton.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/widgets/app_skeleton.dart#L1); file `omc_app/lib/core/widgets/app_skeleton.dart` |
| Persona | Inherits the host screen capability and feature gates; retain exact capability/feature predicates. |
| Purpose | Loading skeleton: complete this existing user task while preserving its scope and authority. |
| Current UI | Reduced-motion-aware pulse and excluded decorative semantics |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: One loading announcement → structural placeholders Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | One loading announcement → structural placeholders |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Static placeholders under disableAnimations; no fake data values; focus not trapped. Pass U; preserve J1. |




### E090. Recommended update state


| Field | Required detail |
|---|---|
| Route / Surface | Inline / state surface: Recommended update state — [app_readiness_gate.dart:32](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/app_config/presentation/app_readiness_gate.dart#L32); file `omc_app/lib/features/app_config/presentation/app_readiness_gate.dart` |
| Persona | All; global and route-feature decisions; retain exact capability/feature predicates. |
| Purpose | Recommended update state: complete this existing user task while preserving its scope and authority. |
| Current UI | Update offer with Continue for now, retry and platform/account actions |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Local styling and constrained rows must conform to the shared design contract while retaining this independent interaction. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Update recommendation → Google Play → Continue for now Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Update recommendation → Google Play → Continue for now |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Applicable loading, validation, disabled/busy, error/retry, long text and keyboard states; host state contract also applies. Observed state anchors: `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `appGateDecisionProvider`, `appRouterProvider`, `authControllerProvider`, `installedMobileVersionProvider`, `mobileAppConfigProvider`, `mobileBackDispatcherProvider`, `optionalUpdateSuppressionProvider`, `routeInformationProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../application/app_gate_controller.dart`, `../data/mobile_app_config_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | 24-hour deferral policy unchanged; forced update never inherits this continue action. Pass U; preserve J1. |




### E091. Biometric account chooser


| Field | Required detail |
|---|---|
| Route / Surface | Biometric account chooser; call site L103 — [login_screen.dart:103](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/login_screen.dart#L103); file `omc_app/lib/features/auth/presentation/login_screen.dart` |
| Persona | Signed-out/guest entry; retain exact capability/feature predicates. |
| Purpose | Biometric account chooser: complete this existing user task while preserving its scope and authority. |
| Current UI | Existing enrolled identities, selectable account rows |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L522` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L89`, `L162`, `L193`, `L337`, `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `biometricLoginAvailableProvider`, `deviceLockServiceProvider`; imports `../application/auth_controller.dart`, `../application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Select account without exposing secret material; cancellation performs no login. Pass U; preserve J1. |




### E092. Login help sheet


| Field | Required detail |
|---|---|
| Route / Surface | Login help sheet; call site L240 — [login_screen.dart:240](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/login_screen.dart#L240); file `omc_app/lib/features/auth/presentation/login_screen.dart` |
| Persona | Signed-out/guest entry; retain exact capability/feature predicates. |
| Purpose | Login help sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Email, Phone/WhatsApp and business hours |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L522` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L89`, `L162`, `L193`, `L337`, `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `biometricLoginAvailableProvider`, `deviceLockServiceProvider`; imports `../application/auth_controller.dart`, `../application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Keep configured contact actions and external-launch failure handling. Pass U; preserve J1. |




### E093. Review support sheet


| Field | Required detail |
|---|---|
| Route / Surface | Review support sheet; call site L82 — [under_review_screen.dart:82](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/auth/presentation/under_review_screen.dart#L82); file `omc_app/lib/features/auth/presentation/under_review_screen.dart` |
| Persona | Pending approval path; retain exact capability/feature predicates. |
| Purpose | Review support sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Support email, number and hours |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L194` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`; imports `../application/auth_controller.dart`, `../application/auth_state.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Contacts selectable at 2x; return to pending state without refreshing authority locally. Pass U; preserve J1. |




### E094. Guest protected-action sheet


| Field | Required detail |
|---|---|
| Route / Surface | Guest protected-action sheet; call site L717 — [home_screen_role_aware.dart:717](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/home/presentation/home_screen_role_aware.dart#L717); file `omc_app/lib/features/home/presentation/home_screen_role_aware.dart` |
| Persona | Guest for signup/login sheet; pending/rejected receive existing locked feedback; retain exact capability/feature predicates. |
| Purpose | Guest protected-action sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Feature-specific access explanation, signup/login actions |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L780` `fontSize: 13,`; `L818` `fontSize: 12.5,`; `L935` `fontSize: 13,`; `L1013` `fontSize: 10,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L115`, `L118`, `L121`, `L532`, `L543` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `effectiveCapabilitiesProvider`, `homeContentProvider`, `homeDashboardSummaryProvider`, `mobileQuickActionsProvider`, `profileSummaryProvider`, `serviceCatalogueProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../profile/data/profile_repository.dart`, `../../service_catalogue/application/service_catalogue_controller.dart`, `../data/home_content_repository.dart`, `../data/home_dashboard_repository.dart`, `../data/mobile_quick_actions_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Guest sees account choices; pending/rejected keep their existing access feedback instead. Pass U; preserve J1. |




### E095. Catalogue category filters


| Field | Required detail |
|---|---|
| Route / Surface | Catalogue category filters; call site L268 — [service_catalogue_screen_impl.dart:268](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart#L268); file `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart` |
| Persona | Public; assisted context for eligible staff; retain exact capability/feature predicates. |
| Purpose | Catalogue category filters: complete this existing user task while preserving its scope and authority. |
| Current UI | Category selection and All option |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L216` `crossAxisCount: crossAxisCount,`; `L219` `mainAxisExtent: 114,`; `L311` `fontSize: 13,`; `L385` `fontSize: 13.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L90`, `L91`, `L181`, `L190`, `L771` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `pageProvider`, `serviceCataloguePageProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../application/service_catalogue_controller.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Same categories/query/page reset; selection visible without relying on color. Pass U; preserve J1. |




### E096. Existing / in-progress requests sheet


| Field | Required detail |
|---|---|
| Route / Surface | Existing / in-progress requests sheet; call site L276 — [service_detail_screen_impl.dart:276](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart#L276); file `omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart` |
| Persona | Public, customer, eligible assisted staff; retain exact capability/feature predicates. |
| Purpose | Existing / in-progress requests sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Existing active requests plus Start a new request where source allows |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L144` `fontSize: 13.5,`; `L425` `fontSize: 13.5,`; `L492` `fontSize: 12,`; `L716` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L57`, `L61`, `L271`, `L903`, `L1060` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `mobileAppConfigProvider`, `serviceCasesProvider`, `serviceDetailProvider`; imports `../../app_config/data/mobile_app_config_repository.dart`, `../../auth/application/auth_controller.dart`, `../../auth/application/auth_state.dart`, `../../service_requests/data/service_case_repository.dart`, `../application/service_catalogue_controller.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Open chosen case or existing new-request path; duplicate prevention remains server-side and unchanged. Pass U; preserve J1. |




### E097. Request sort sheet


| Field | Required detail |
|---|---|
| Route / Surface | Request sort sheet; call site L198 — [my_services_screen.dart:198](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/my_services_screen.dart#L198); file `omc_app/lib/features/service_requests/presentation/my_services_screen.dart` |
| Persona | canTrackRequests or /track-authorized case viewer; retain exact capability/feature predicates. |
| Purpose | Request sort sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Existing sort options with selected row |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L311` `fontSize: 12,`; `L417` `fontSize: 13.5,`; `L463` `fontSize: 13,`; `L470` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L45`, `L46`, `L47`, `L52`, `L124` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `effectiveCapabilitiesProvider`, `serviceCasesProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_state.dart`, `../data/service_case_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Result order exactly matches current comparator; close without selection leaves it unchanged. Pass U; preserve J1. |




### E098. Request filter sheet


| Field | Required detail |
|---|---|
| Route / Surface | Request filter sheet; call site L263 — [my_services_screen.dart:263](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/my_services_screen.dart#L263); file `omc_app/lib/features/service_requests/presentation/my_services_screen.dart` |
| Persona | canTrackRequests or /track-authorized case viewer; retain exact capability/feature predicates. |
| Purpose | Request filter sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Counts/status choices with labels and explanations |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L311` `fontSize: 12,`; `L417` `fontSize: 13.5,`; `L463` `fontSize: 13,`; `L470` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L45`, `L46`, `L47`, `L52`, `L124` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `effectiveCapabilitiesProvider`, `serviceCasesProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../auth/application/auth_state.dart`, `../data/service_case_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Counts and status mapping unchanged; filters remain visible after closing. Pass U; preserve J1. |




### E099. Customer cancel request confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Customer cancel request confirmation; call site L154 — [customer_service_case_detail_screen.dart:154](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart#L154); file `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart` |
| Persona | Approved non-internal, not assisted, canTrackRequests; retain exact capability/feature predicates. |
| Purpose | Customer cancel request confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Keep request and Cancel request |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L68`, `L69` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `customerServiceCaseDetailProvider`, `customerServiceCaseRepositoryProvider`, `documentAttachmentControllerProvider`, `documentPageProvider`, `documentsProvider`, `documentsRepositoryProvider`, `effectiveCapabilitiesProvider`, `homeDashboardSummaryProvider`, `serviceCasesProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../documents/application/document_attachment_controller.dart`, `../../documents/data/documents_repository.dart`, `../../home/data/home_dashboard_repository.dart`, `../data/customer_service_case_repository.dart`, `../data/service_case_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Only confirmed cancellation mutates; terminal eligibility comes from existing detail. Pass U; preserve J1. |




### E100. Legacy reassign dialog


| Field | Required detail |
|---|---|
| Route / Surface | Legacy reassign dialog; call site L216 — [service_case_detail_legacy_screen.dart:216](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L216); file `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart` |
| Persona | Assisted staff and non-canonical authorized variants; retain exact capability/feature predicates. |
| Purpose | Legacy reassign dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Enabled eligible operational staff choices |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L702` `fontSize: 12.5,`; `L713` `fontSize: 11,`; `L838` `fontSize: 12.5,`; `L853` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L79`, `L80`, `L131`, `L160`, `L212` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminControlRepositoryProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `serviceCaseDetailProvider`, `serviceCaseRepositoryProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../admin_control/data/admin_control_repository.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/service_case_repository.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | No free-text arbitrary assignee; retain full user ID and selected candidate. Pass U; preserve J1. |




### E101. Legacy discount rejection dialog


| Field | Required detail |
|---|---|
| Route / Surface | Legacy discount rejection dialog; call site L258 — [service_case_detail_legacy_screen.dart:258](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L258); file `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart` |
| Persona | Assisted staff and non-canonical authorized variants; retain exact capability/feature predicates. |
| Purpose | Legacy discount rejection dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Review remarks and Reject |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L702` `fontSize: 12.5,`; `L713` `fontSize: 11,`; `L838` `fontSize: 12.5,`; `L853` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L79`, `L80`, `L131`, `L160`, `L212` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminControlRepositoryProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `serviceCaseDetailProvider`, `serviceCaseRepositoryProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../admin_control/data/admin_control_repository.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/service_case_repository.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Required reason preserved; close cancels decision; discount authority unchanged. Pass U; preserve J1. |




### E102. Operational/assisted cancellation dialog


| Field | Required detail |
|---|---|
| Route / Surface | Operational/assisted cancellation dialog; call site L301 — [service_case_detail_legacy_screen.dart:301](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L301); file `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart` |
| Persona | Assisted staff and non-canonical authorized variants; retain exact capability/feature predicates. |
| Purpose | Operational/assisted cancellation dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Keep request and Cancel request |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L702` `fontSize: 12.5,`; `L713` `fontSize: 11,`; `L838` `fontSize: 12.5,`; `L853` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L79`, `L80`, `L131`, `L160`, `L212` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminControlRepositoryProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `serviceCaseDetailProvider`, `serviceCaseRepositoryProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../admin_control/data/admin_control_repository.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/service_case_repository.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Preserve cancellation API, busy locking and historical restrictions. Pass U; preserve J1. |




### E103. Required document upload sheet


| Field | Required detail |
|---|---|
| Route / Surface | Required document upload sheet; call site L445 — [service_case_detail_legacy_screen.dart:445](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart#L445); file `omc_app/lib/features/service_requests/presentation/service_case_detail_legacy_screen.dart` |
| Persona | Assisted staff and non-canonical authorized variants; retain exact capability/feature predicates. |
| Purpose | Required document upload sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Requirement selection, picked files, progress and upload CTA |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L702` `fontSize: 12.5,`; `L713` `fontSize: 11,`; `L838` `fontSize: 12.5,`; `L853` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L79`, `L80`, `L131`, `L160`, `L212` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminControlRepositoryProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `serviceCaseDetailProvider`, `serviceCaseRepositoryProvider`, `serviceCasesProvider`, `serviceRequestRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../../admin_control/data/admin_control_repository.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/service_case_repository.dart`, `../data/service_request_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Requirement-to-file mapping and duplicates preserved; cancellation/failure never clears successful evidence. Pass U; preserve J1. |




### E104. Reject document dialog


| Field | Required detail |
|---|---|
| Route / Surface | Reject document dialog; call site L235 — [internal_document_review_screen.dart:235](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/internal_document_review_screen.dart#L235); file `omc_app/lib/features/documents/presentation/internal_document_review_screen.dart` |
| Persona | Document queue/review capabilities; retain exact capability/feature predicates. |
| Purpose | Reject document dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Required reason/reupload instruction and dirty guard |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L668` `fontSize: 13.5,`; `L675` `fontSize: 12.5,`; `L742` `fontSize: 13,`; `L750` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L238`, `L280`, `L332`, `L338`, `L475` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `documentsRepositoryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/documents_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Reason stays required; discard/stay nesting preserves typed value; reject only selected document. Pass U; preserve J1. |




### E105. Payment approve / reject review dialog


| Field | Required detail |
|---|---|
| Route / Surface | Payment approve / reject review dialog; call site L759 — [payment_detail_screen.dart:759](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/payment_detail_screen.dart#L759); file `omc_app/lib/features/payments/presentation/payment_detail_screen.dart` |
| Persona | Payment owner, assisted staff, authorized reviewer; retain exact capability/feature predicates. |
| Purpose | Payment approve / reject review dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Status-specific remarks and confirmation |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L159` `fontSize: 13,`; `L257` `fontSize: 12,`; `L367` `fontSize: 11,`; `L461` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained.Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L65`, `L70`, `L73`, `L446`, `L787` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `assistedPaymentDetailProvider`, `authControllerProvider`, `documentAttachmentControllerProvider`, `paymentDetailProvider`, `paymentsRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../../auth/application/auth_controller.dart`, `../../documents/application/document_attachment_controller.dart`, `../data/payments_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Exact Paid/Rejected status payload unchanged; required rejection remarks remain visible and validated. Pass U; preserve J1. |




### E106. Profile support request sheet


| Field | Required detail |
|---|---|
| Route / Surface | Profile support request sheet; call site L495 — [profile_screen.dart:495](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/profile_screen.dart#L495); file `omc_app/lib/features/profile/presentation/profile_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Profile support request sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Request message and optional profile snapshot |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L271` `fontSize: 13,`; `L417` `fontSize: 13,`; `L722` `fontSize: 13,`; `L766` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L47`, `L48`, `L513`, `L789`, `L973` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `profileRepositoryProvider`, `profileSummaryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../support/data/support_repository.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keep support-ticket payload and snapshot consent/context; failed submission retains message. Pass U; preserve J1. |




### E107. Personal / contact / professional / identity edit sheets


| Field | Required detail |
|---|---|
| Route / Surface | Personal / contact / professional / identity edit sheets; call site L904 — [edit_profile_screen.dart:904](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/edit_profile_screen.dart#L904); file `omc_app/lib/features/profile/presentation/edit_profile_screen.dart` |
| Persona | Signed-in scoped profile; retain exact capability/feature predicates. |
| Purpose | Personal / contact / professional / identity edit sheets: complete this existing user task while preserving its scope and authority. |
| Current UI | Renderer used by name, mobile/WhatsApp/address, education/experience/remarks, email/CNIC/NTN/company add/update |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L205` `fontSize: 12.5,`; `L282` `fontSize: 12,`; `L329` `fontSize: 12,`; `L343` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L39`, `L40`, `L835`, `L1036` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `profileRepositoryProvider`, `profileSummaryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Retain each payloadBuilder and add/update/locked distinction; labels 15, input16, Save56; long values scroll above keyboard. Pass U; preserve J1. |




### E108. Verified identity confirmation dialog


| Field | Required detail |
|---|---|
| Route / Surface | Verified identity confirmation dialog; call site L963 — [edit_profile_screen.dart:963](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/edit_profile_screen.dart#L963); file `omc_app/lib/features/profile/presentation/edit_profile_screen.dart` |
| Persona | Signed-in scoped profile; retain exact capability/feature predicates. |
| Purpose | Verified identity confirmation dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Review and Confirm & save |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L205` `fontSize: 12.5,`; `L282` `fontSize: 12,`; `L329` `fontSize: 12,`; `L343` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L39`, `L40`, `L835`, `L1036` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `profileRepositoryProvider`, `profileSummaryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Preserve field-specific confirmation message and exact pending edit; dismiss never saves. Pass U; preserve J1. |




### E109. Locked identity explanation sheet


| Field | Required detail |
|---|---|
| Route / Surface | Locked identity explanation sheet; call site L1215 — [edit_profile_screen.dart:1215](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/edit_profile_screen.dart#L1215); file `omc_app/lib/features/profile/presentation/edit_profile_screen.dart` |
| Persona | Signed-in scoped profile; retain exact capability/feature predicates. |
| Purpose | Locked identity explanation sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Verified account details explanation and Understood |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L205` `fontSize: 12.5,`; `L282` `fontSize: 12,`; `L329` `fontSize: 12,`; `L343` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L39`, `L40`, `L835`, `L1036` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `profileRepositoryProvider`, `profileSummaryProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | No editable controls or bypass; retain support route for needed correction. Pass U; preserve J1. |




### E110. Enable biometric sign-in password dialog


| Field | Required detail |
|---|---|
| Route / Surface | Enable biometric sign-in password dialog; call site L358 — [settings_screen.dart:358](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L358); file `omc_app/lib/features/settings/presentation/settings_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Enable biometric sign-in password dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Current password with visibility and Continue |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L1034` `fontSize: 13,`; `L1041` `fontSize: 12,`; `L1048` `fontSize: 12,`; `L1054` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L142`, `L143`, `L303`, `L307`, `L448` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `appPackageInfoProvider`, `authControllerProvider`, `authRepositoryProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `settingsPreferencesProvider`, `settingsRepositoryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`, `../../app_config/data/mobile_app_config_repository.dart`, `../../profile/data/profile_repository.dart`, `../../support/data/support_repository.dart`, `../data/settings_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Do not store/reuse plaintext beyond existing flow; validation/enrollment failure must not show switch enabled. Pass U; preserve J1. |




### E111. Account deletion request sheet


| Field | Required detail |
|---|---|
| Route / Surface | Account deletion request sheet; call site L433 — [settings_screen.dart:433](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L433); file `omc_app/lib/features/settings/presentation/settings_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Account deletion request sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Reason/instructions submitted for OMC review |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L1034` `fontSize: 13,`; `L1041` `fontSize: 12,`; `L1048` `fontSize: 12,`; `L1054` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L142`, `L143`, `L303`, `L307`, `L448` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `appPackageInfoProvider`, `authControllerProvider`, `authRepositoryProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `settingsPreferencesProvider`, `settingsRepositoryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`, `../../app_config/data/mobile_app_config_repository.dart`, `../../profile/data/profile_repository.dart`, `../../support/data/support_repository.dart`, `../data/settings_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Clearly say request, not immediate deletion; retain submission guard and support repository. Pass U; preserve J1. |




### E112. Logout confirmation sheet


| Field | Required detail |
|---|---|
| Route / Surface | Logout confirmation sheet; call site L473 — [settings_screen.dart:473](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L473); file `omc_app/lib/features/settings/presentation/settings_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Logout confirmation sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Cancel and Logout |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L1034` `fontSize: 13,`; `L1041` `fontSize: 12,`; `L1048` `fontSize: 12,`; `L1054` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L142`, `L143`, `L303`, `L307`, `L448` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `appPackageInfoProvider`, `authControllerProvider`, `authRepositoryProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `settingsPreferencesProvider`, `settingsRepositoryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`, `../../app_config/data/mobile_app_config_repository.dart`, `../../profile/data/profile_repository.dart`, `../../support/data/support_repository.dart`, `../data/settings_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Successful logout follows auth redirect once; failure remains visible and retryable. Pass U; preserve J1. |




### E113. Privacy / terms fallback sheets


| Field | Required detail |
|---|---|
| Route / Surface | Privacy / terms fallback sheets; call site L549 — [settings_screen.dart:549](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/settings/presentation/settings_screen.dart#L549); file `omc_app/lib/features/settings/presentation/settings_screen.dart` |
| Persona | Signed-in customer/internal/limited account; retain exact capability/feature predicates. |
| Purpose | Privacy / terms fallback sheets: complete this existing user task while preserving its scope and authority. |
| Current UI | Configured policy text and Done when external link unavailable |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L1034` `fontSize: 13,`; `L1041` `fontSize: 12,`; `L1048` `fontSize: 12,`; `L1054` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L142`, `L143`, `L303`, `L307`, `L448` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `appPackageInfoProvider`, `authControllerProvider`, `authRepositoryProvider`, `biometricLoginAccountsProvider`, `biometricLoginAvailableProvider`, `biometricLoginEnabledForProvider`, `deviceLockEnabledProvider`, `deviceLockServiceProvider`, `deviceLockSessionUnlockedProvider`, `mobileAppConfigProvider`, `profileSummaryProvider`, `settingsPreferencesProvider`, `settingsRepositoryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../auth/data/auth_repository.dart`, `../../app_config/data/mobile_app_config_repository.dart`, `../../profile/data/profile_repository.dart`, `../../support/data/support_repository.dart`, `../data/settings_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Full policy readable/scrollable; preserve validated external URL path; do not rewrite policy substance. Pass U; preserve J1. |




### E114. Internal ticket status sheet


| Field | Required detail |
|---|---|
| Route / Surface | Internal ticket status sheet; call site L1255 — [support_ticket_detail_legacy_screen.dart:1255](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart#L1255); file `omc_app/lib/features/support/presentation/support_ticket_detail_legacy_screen.dart` |
| Persona | Ticket owner or support workspace; retain exact capability/feature predicates. |
| Purpose | Internal ticket status sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Permitted ticket status choices |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L514` `fontSize: 12,`; `L542` `fontSize: 12,`; `L597` `fontSize: 12,`; `L624` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L81`, `L82`, `L85`, `L177`, `L213` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `supportRepositoryProvider`, `supportTicketDetailProvider`, `supportTicketsProvider`, `supportUnreadCountProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/support_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Exact selected status mutation and closed reply restriction retained. Pass U; preserve J1. |




### E115. Tracker storage / data tools menu


| Field | Required detail |
|---|---|
| Route / Surface | Tracker storage / data tools menu; call site L305 — [expense_tracker_screen.dart:305](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L305); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Tracker storage / data tools menu: complete this existing user task while preserving its scope and authority. |
| Current UI | Storage mode, refresh/sync, JSON backup/import, account export and clear choices as allowed |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Do not expose account operations for guest; changing presentation does not change sync opt-in or destructive semantics. Pass U; preserve J1. |




### E116. Add / edit transaction sheet


| Field | Required detail |
|---|---|
| Route / Surface | Add / edit transaction sheet; call site L497 — [expense_tracker_screen.dart:497](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L497); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Add / edit transaction sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Expense/income, amount, category, description, advanced account/method/note/date/tax/business/recurring/reimbursable fields |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keep transaction ID/type and all flags; edit prefill and failed save retain values; advanced fields remain discoverable. Pass U; preserve J1. |




### E117. Account history export progress dialog


| Field | Required detail |
|---|---|
| Route / Surface | Account history export progress dialog; call site L535 — [expense_tracker_screen.dart:535](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L535); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Account history export progress dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Records prepared counter and Cancel in DialogRoute |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keep root navigator, epoch/cancel token and explicit non-pop behavior; cancel never writes incomplete export as successful. Pass U; preserve J1. |




### E118. Local JSON backup dialog


| Field | Required detail |
|---|---|
| Route / Surface | Local JSON backup dialog; call site L596 — [expense_tracker_screen.dart:596](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L596); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Local JSON backup dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Selectable backup JSON and Close |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Keep exact exported data; readable selectable monospace14; no unintended mutation. Pass U; preserve J1. |




### E119. Import JSON backup dialog


| Field | Required detail |
|---|---|
| Route / Surface | Import JSON backup dialog; call site L617 — [expense_tracker_screen.dart:617](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L617); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Import JSON backup dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Multiline JSON input, validation and import |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Preserve parser, duplicate handling and import errors; do not label partial/import failure success. Pass U; preserve J1. |




### E120. Archive transaction confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Archive transaction confirmation; call site L745 — [expense_tracker_screen.dart:745](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L745); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Archive transaction confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Scope-specific archive explanation and Archive |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Same transaction/sync mode; archive failure keeps row and explanation. Pass U; preserve J1. |




### E121. Clear local tracker confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Clear local tracker confirmation; call site L792 — [expense_tracker_screen.dart:792](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L792); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Clear local tracker confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Local-only deletion explanation and Clear |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Do not imply server records deleted; keep existing local-clear contract and failure feedback. Pass U; preserve J1. |




### E122. Tracker period filter menu


| Field | Required detail |
|---|---|
| Route / Surface | Tracker period filter menu; call site L1402 — [expense_tracker_screen.dart:1402](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L1402); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Tracker period filter menu: complete this existing user task while preserving its scope and authority. |
| Current UI | Existing period values |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Chosen period updates same local predicate; full selected label accessible. Pass U; preserve J1. |




### E123. Transaction action menu


| Field | Required detail |
|---|---|
| Route / Surface | Transaction action menu; call site L1654 — [expense_tracker_screen.dart:1654](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L1654); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Transaction action menu: complete this existing user task while preserving its scope and authority. |
| Current UI | Edit and Archive |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Menu belongs to the same transaction ID; archive remains confirmed. Pass U; preserve J1. |




### E124. Transaction date picker


| Field | Required detail |
|---|---|
| Route / Surface | Transaction date picker; call site L2027 — [expense_tracker_screen.dart:2027](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart#L2027); file `omc_app/lib/features/expense_tracker/presentation/expense_tracker_screen.dart` |
| Persona | Guest/local and eligible account mode; capability-controlled internal visibility; retain exact capability/feature predicates. |
| Purpose | Transaction date picker: complete this existing user task while preserving its scope and authority. |
| Current UI | Current selected date and allowed range |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L601` `child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),`; `L1155` `fontSize: 11,`; `L1226` `fontSize: 10,`; `L1237` `fontSize: 11,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L178`, `L191`, `L417`, `L418`, `L920` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `AsyncNotifierProvider`, `FutureProvider`, `effectiveCapabilitiesProvider`, `expenseCloudPageProvider`, `expenseTrackerConfigProvider`, `expenseTrackerRepositoryProvider`, `expenseTrackerStorageModeProvider`, `expenseTransactionsProvider`, `sessionEpochProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_state.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Retain current first/last/initial dates and serialization; cancel keeps date. Pass U; preserve J1. |




### E125. Budget action menu


| Field | Required detail |
|---|---|
| Route / Surface | Budget action menu; call site L142 — [expense_budget_screen.dart:142](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart#L142); file `omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart` |
| Persona | Approved or internal; local/internal note as applicable; retain exact capability/feature predicates. |
| Purpose | Budget action menu: complete this existing user task while preserving its scope and authority. |
| Current UI | Add budget and Refresh |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L202` `fontSize: 11,`; `L486` `fontSize: 10.5,`; `L532` `fontSize: 10.5,`; `L670` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L212`, `L213`, `L232`, `L233`, `L252` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `authControllerProvider`, `expenseBudgetSummaryProvider`, `expenseBudgetsProvider`, `expenseTrackerRepositoryProvider`, `localExpenseBudgetEntriesProvider`, `localExpenseBudgetsProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Both actions preserve selected month. Pass U; preserve J1. |




### E126. Add / edit budget sheet


| Field | Required detail |
|---|---|
| Route / Surface | Add / edit budget sheet; call site L313 — [expense_budget_screen.dart:313](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart#L313); file `omc_app/lib/features/expense_tracker/presentation/expense_budget_screen.dart` |
| Persona | Approved or internal; local/internal note as applicable; retain exact capability/feature predicates. |
| Purpose | Add / edit budget sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Category, budget limit, warning threshold and Save budget |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L202` `fontSize: 11,`; `L486` `fontSize: 10.5,`; `L532` `fontSize: 10.5,`; `L670` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained.Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L212`, `L213`, `L232`, `L233`, `L252` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `FutureProvider`, `authControllerProvider`, `expenseBudgetSummaryProvider`, `expenseBudgetsProvider`, `expenseTrackerRepositoryProvider`, `localExpenseBudgetEntriesProvider`, `localExpenseBudgetsProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/expense_tracker_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Same month/category payload/local persistence; zero/invalid limit and threshold errors readable. Pass U; preserve J1. |




### E127. Internal case advanced filters


| Field | Required detail |
|---|---|
| Route / Surface | Internal case advanced filters; call site L169 — [internal_service_cases_screen.dart:169](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart#L169); file `omc_app/lib/features/internal_workspace/presentation/internal_service_cases_screen.dart` |
| Persona | Scoped any-service-case viewer; retain exact capability/feature predicates. |
| Purpose | Internal case advanced filters: complete this existing user task while preserving its scope and authority. |
| Current UI | Operational status/document state and apply/clear |
| Current UX | Uses host-supplied values/callbacks; retain the specific interaction and state cases below. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L452` `fontSize: 11.5,`; `L567` `fontSize: 12,`; `L597` `fontSize: 10.5,`; `L653` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L191`, `L219`, `L221`, `L287`, `L983` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `internalServiceCasePageRepositoryProvider`; imports `../data/internal_service_case_page_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Query fields unchanged; cancelling does not apply unfinished choices. Pass U; preserve J1. |




### E128. Task priority filter sheet


| Field | Required detail |
|---|---|
| Route / Surface | Task priority filter sheet; call site L188 — [tasks_screen.dart:188](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/tasks/presentation/tasks_screen.dart#L188); file `omc_app/lib/features/tasks/presentation/tasks_screen.dart` |
| Persona | canViewTasks; retain exact capability/feature predicates. |
| Purpose | Task priority filter sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Priority selection and Apply filter |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L215` `fontSize: 12.5,`; `L382` `fontSize: 12,`; `L795` `fontSize: 11,`; `L807` `fontSize: 11.5,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L286`, `L390` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `tasksRepositoryProvider`; imports `../data/tasks_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | No task mutation; selected priority participates in existing paged query. Pass U; preserve J1. |




### E129. Create lead sheet


| Field | Required detail |
|---|---|
| Route / Surface | Create lead sheet; call site L180 — [leads_screen.dart:180](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/leads/presentation/leads_screen.dart#L180); file `omc_app/lib/features/leads/presentation/leads_screen.dart` |
| Persona | canManageLeads; retain exact capability/feature predicates. |
| Purpose | Create lead sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Opportunity, contact, optional notes and create action |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L328` `fontSize: 13,`; `L554` `fontSize: 12.5,`; `L621` `fontSize: 13,`; `L1164` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L124`, `L127`, `L207`, `L264`, `L737` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `leadsPageProvider`, `leadsProvider`, `leadsRepositoryProvider`, `leadsResultPageProvider`; imports `../../../core/forms/dirty_form_controller.dart`, `../../auth/application/auth_controller.dart`, `../data/leads_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Required title and capability recheck preserved; creation only once per intent; dirty exit remains. Pass U; preserve J1. |




### E130. Record paid settlement sheet


| Field | Required detail |
|---|---|
| Route / Surface | Record paid settlement sheet; call site L183 — [finance_commissions_screen.dart:183](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L183); file `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart` |
| Persona | Approve and/or mark-paid capabilities; retain exact capability/feature predicates. |
| Purpose | Record paid settlement sheet: complete this existing user task while preserving its scope and authority. |
| Current UI | Settlement reference, date picker and Record commission paid |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L430` `fontSize: 12.5,`; `L502` `fontSize: 11.5,`; `L677` `fontSize: 12.5,`; `L760` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeCommissionRepositoryProvider`; imports `../data/finance_commission_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Keep reference/date validation and exact record-paid mutation; never execute a payment transfer. Pass U; preserve J1. |




### E131. Approve / mark-payable commission confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Approve / mark-payable commission confirmation; call site L208 — [finance_commissions_screen.dart:208](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L208); file `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart` |
| Persona | Approve and/or mark-paid capabilities; retain exact capability/feature predicates. |
| Purpose | Approve / mark-payable commission confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Target-specific financial confirmation |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L430` `fontSize: 12.5,`; `L502` `fontSize: 11.5,`; `L677` `fontSize: 12.5,`; `L760` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained.Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeCommissionRepositoryProvider`; imports `../data/finance_commission_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Approve and payable remain distinct; accounting-evidence gating unchanged. Pass U; preserve J1. |




### E132. Reject commission dialog


| Field | Required detail |
|---|---|
| Route / Surface | Reject commission dialog; call site L230 — [finance_commissions_screen.dart:230](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L230); file `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart` |
| Persona | Approve and/or mark-paid capabilities; retain exact capability/feature predicates. |
| Purpose | Reject commission dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Required audit-trail reason |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L430` `fontSize: 12.5,`; `L502` `fontSize: 11.5,`; `L677` `fontSize: 12.5,`; `L760` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained.Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeCommissionRepositoryProvider`; imports `../data/finance_commission_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Cannot submit blank reason; same allocation targeted. Pass U; preserve J1. |




### E133. Commission settlement date picker


| Field | Required detail |
|---|---|
| Route / Surface | Commission settlement date picker; call site L696 — [finance_commissions_screen.dart:696](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart#L696); file `omc_app/lib/features/commissions/presentation/finance_commissions_screen.dart` |
| Persona | Approve and/or mark-paid capabilities; retain exact capability/feature predicates. |
| Purpose | Commission settlement date picker: complete this existing user task while preserving its scope and authority. |
| Current UI | Selected settlement date |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L430` `fontSize: 12.5,`; `L502` `fontSize: 11.5,`; `L677` `fontSize: 12.5,`; `L760` `fontSize: 13,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Financial values: amount28/secondary20, currency retained. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L367` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeCommissionRepositoryProvider`; imports `../data/finance_commission_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Date bounds and serialized value unchanged; cancellation retains prior date. Pass U; preserve J1. |




### E134. Resolve / ignore exception confirmation


| Field | Required detail |
|---|---|
| Route / Surface | Resolve / ignore exception confirmation; call site L191 — [settlement_exceptions_screen.dart:191](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart#L191); file `omc_app/lib/features/payments/presentation/settlement_exceptions_screen.dart` |
| Persona | Workspace finance access per focus.canShowSettlementExceptions; retain exact capability/feature predicates. |
| Purpose | Resolve / ignore exception confirmation: complete this existing user task while preserving its scope and authority. |
| Current UI | Finance review note and explicit decision |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L63`, `L64`, `L116`, `L224`, `L238` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `financeReconciliationPageProvider`, `financeReconciliationRepositoryProvider`; imports `../data/finance_reconciliation_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Clearly distinguish review recording from settlement repair; exact enum/payload retained. Pass U; preserve J1. |




### E135. Grant existing staff access dialog


| Field | Required detail |
|---|---|
| Route / Surface | Grant existing staff access dialog; call site L154 — [admin_control_screen.dart:154](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_control_screen.dart#L154); file `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart` |
| Persona | Manage staff / review registrations / business settings separately; retain exact capability/feature predicates. |
| Purpose | Grant existing staff access dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Existing full name/login email and backend roles |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L174` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L303` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L405` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L554` `style: TextStyle(fontSize: 12.5, height: 1.4),` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L87`, `L88`, `L113`, `L114`, `L144` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminBusinessSettingsProvider`, `adminControlRepositoryProvider`, `effectiveCapabilitiesProvider`, `scopedAdminOverviewProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`, `../data/admin_overview_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | No new unauthorized role choices; dirty exit retained; confirmation names target account. Pass U; preserve J1. |




### E136. Staff access profile dialog


| Field | Required detail |
|---|---|
| Route / Surface | Staff access profile dialog; call site L466 — [admin_control_screen.dart:466](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_control_screen.dart#L466); file `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart` |
| Persona | Manage staff / review registrations / business settings separately; retain exact capability/feature predicates. |
| Purpose | Staff access profile dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Current and available role checkboxes |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L174` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L303` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L405` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L554` `style: TextStyle(fontSize: 12.5, height: 1.4),` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L87`, `L88`, `L113`, `L114`, `L144` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminBusinessSettingsProvider`, `adminControlRepositoryProvider`, `effectiveCapabilitiesProvider`, `scopedAdminOverviewProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`, `../data/admin_overview_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Preserve roles set, required selection rules and access update semantics. Pass U; preserve J1. |




### E137. Business numeric setting dialog


| Field | Required detail |
|---|---|
| Route / Surface | Business numeric setting dialog; call site L632 — [admin_control_screen.dart:632](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_control_screen.dart#L632); file `omc_app/lib/features/admin_control/presentation/admin_control_screen.dart` |
| Persona | Manage staff / review registrations / business settings separately; retain exact capability/feature predicates. |
| Purpose | Business numeric setting dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Auto-approved discount percent or minimum service price |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. File-level style anchors: `L174` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L303` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L405` `style: TextStyle(fontSize: 12.5, height: 1.4),`; `L554` `style: TextStyle(fontSize: 12.5, height: 1.4),` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L87`, `L88`, `L113`, `L114`, `L144` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminBusinessSettingsProvider`, `adminControlRepositoryProvider`, `effectiveCapabilitiesProvider`, `scopedAdminOverviewProvider`; imports `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`, `../data/admin_overview_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Show unit/% or currency beside input; preserve validators and setting key. Pass U; preserve J1. |




### E138. Operational reassignment dialog


| Field | Required detail |
|---|---|
| Route / Surface | Operational reassignment dialog; call site L225 — [admin_operations_screen.dart:225](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart#L225); file `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart` |
| Persona | Reassign / retry sync / business settings capabilities; retain exact capability/feature predicates. |
| Purpose | Operational reassignment dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Eligible staff search/select and optional reason |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L42`, `L99`, `L105`, `L126`, `L228` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminCaseOptionsProvider`, `adminControlRepositoryProvider`, `adminOperationsProvider`, `effectiveCapabilitiesProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Preserve backend options and selected candidate; no arbitrary assignee input. Pass U; preserve J1. |




### E139. Exhausted sync retry dialog


| Field | Required detail |
|---|---|
| Route / Surface | Exhausted sync retry dialog; call site L335 — [admin_operations_screen.dart:335](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart#L335); file `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart` |
| Persona | Reassign / retry sync / business settings capabilities; retain exact capability/feature predicates. |
| Purpose | Exhausted sync retry dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Case ID and last sync error, Retry sync |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L42`, `L99`, `L105`, `L126`, `L228` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminCaseOptionsProvider`, `adminControlRepositoryProvider`, `adminOperationsProvider`, `effectiveCapabilitiesProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Retain explicit retry and target case; error is technical staff content, not customer copy. Pass U; preserve J1. |




### E140. Discount review dialog


| Field | Required detail |
|---|---|
| Route / Surface | Discount review dialog; call site L378 — [admin_operations_screen.dart:378](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart#L378); file `omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart` |
| Persona | Reassign / retry sync / business settings capabilities; retain exact capability/feature predicates. |
| Purpose | Discount review dialog: complete this existing user task while preserving its scope and authority. |
| Current UI | Customer/service/base/final amounts, reason, approve/reject selection, review remarks |
| Current UX | Opener supplies target/options and owns the result. Selection, confirmation and cancellation retain current callback semantics. |
| Problems | Independent modal/menu styling; compact controls and fixed content can obscure context or confirmation at large text. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. Apply C1–C6. |
| Move/Remove | None; all original options, callbacks and confirmation requirements retained. |
| New Hierarchy | Contextual heading → target/selection → readable content → validation → safe cancel/back and single action. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16. Sheet heading21/options16; target48/action56. |
| Components | F: BottomSheetFrame/themed Dialog/native picker, ActionRow, FormField, PrimaryCTA; host owns result. |
| States | Target scenarios: Open/selected, cancel/back/barrier behavior, long target name, 320px/2x; form variants add keyboard, validation, saving/failure. Observed state anchors: `L42`, `L99`, `L105`, `L126`, `L228` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `adminCaseOptionsProvider`, `adminControlRepositoryProvider`, `adminOperationsProvider`, `effectiveCapabilitiesProvider`; imports `../../../app/mutation_invalidation.dart`, `../../../app/providers/effective_capabilities_provider.dart`, `../../../core/forms/dirty_form_controller.dart`, `../data/admin_control_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | No default accidental approve; rejection reason/decision flag and authority preserved. Pass U; preserve J1. |




### E141. Push-open failure recovery


| Field | Required detail |
|---|---|
| Route / Surface | Global PushRuntimeHost error overlay — [push_runtime.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/push_runtime.dart#L1); file `omc_app/lib/core/push/push_runtime.dart` |
| Persona | Current authenticated push-bound identity after readiness/device-unlock checks; retain exact capability/feature predicates. |
| Purpose | Push-open failure recovery: complete this existing user task while preserving its scope and authority. |
| Current UI | Bottom safe-area material error panel with Dismiss and conditional Retry; terminal 401/403/404 consumes intent, transient failure retains retry. |
| Current UX | Looks up push intent for current owner/binding; terminal unavailable intent is consumed, transient error retains Retry, Dismiss clears pending. |
| Problems | Error overlay can compete with bottom navigation and uses a fixed Row for actions; accessibility/long text needs reflow. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Readable update-open failure → Dismiss → Retry only for retained transient intent. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Readable update-open failure → Dismiss → Retry only for retained transient intent. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Transient network failure, terminal unavailable update, retry busy, dismiss, account switch, lock/readiness hidden state. Observed state anchors: `L92` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `appGateDecisionProvider`, `appRouterProvider`, `authControllerProvider`, `biometricLoginEnabledForProvider`, `deviceLockSessionUnlockedProvider`, `effectiveCapabilitiesProvider`, `frappeClientProvider`, `pushAuthBindingProvider`, `pushNavigationAllowedProvider`, `pushRegistrationProvider`, `routeInformationProvider`; imports `../../app/providers/effective_capabilities_provider.dart`, `../../features/app_config/application/app_gate_controller.dart`, `../../features/auth/application/auth_controller.dart`, `../../features/auth/application/auth_state.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Owner/binding/cancel checks and consumeOpen semantics unchanged; Retry schedules same valid intent; terminal/unauthorized notification never opens protected destination. Pass U; preserve J1. |




### E142. Device notification permission / registration


| Field | Required detail |
|---|---|
| Route / Surface | Settings inline Android device notifications card — [push_device_settings_tile.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/push_device_settings_tile.dart#L1); file `omc_app/lib/core/push/push_device_settings_tile.dart` |
| Persona | Signed-in Settings; Android source only; retain exact capability/feature predicates. |
| Purpose | Device notification permission / registration: complete this existing user task while preserving its scope and authority. |
| Current UI | Device-specific configuration, permission, registration status and Enable/retry or Refresh registration button separate from notification preferences. |
| Current UX | Android-only action enables system notifications or opens settings, then refreshes device registration for the same account. |
| Problems | Technical Firebase/server copy overwhelms native settings; device permission, device registration and account delivery preference are different states. See B4 for inherited/shared style locations. |
| Keep | KEEP all working actions, information and data scope; revise hierarchy. |
| Change | REDESIGN: Notifications on this device → permission/registration status → Enable or Retry → concise actionable error. Apply C1–C6. |
| Move/Remove | CONSOLIDATE the visual card into Notifications settings group; retain separate device state from account-level push preferences. Move technical configuration explanation into optional detail, not remove state truth. |
| New Hierarchy | Notifications on this device → permission/registration status → Enable or Retry → concise actionable error. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Build not configured, permission not requested/blocked/granted, registered/unregistered, busy/error, account change. Observed state anchors: Inherited from host/controller; see B4. |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `pushRegistrationProvider`; imports `../../features/auth/application/auth_controller.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Non-Android remains hidden; enableNotifications and syncForAuth identity guard retained; simplify technical wording without promising delivery when only registration succeeded. Pass U; preserve J1. |




### E143. Platform notification interaction


| Field | Required detail |
|---|---|
| Route / Surface | Native Android permission/settings and foreground notification — [firebase_push_source.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/core/push/firebase_push_source.dart#L1); file `omc_app/lib/core/push/firebase_push_source.dart` |
| Persona | Android configured push source and bound identity; retain exact capability/feature predicates. |
| Purpose | Platform notification interaction: complete this existing user task while preserving its scope and authority. |
| Current UI | enableNotifications requests permission when not requested or opens Android notification settings when blocked; source renders foreground local notification. |
| Current UX | Existing source requests native permission only on enable, opens settings if blocked and resolves notification taps through bound intent. |
| Problems | Platform surfaces are not styled by Flutter; app-side explanation must describe the actual next system action. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Device status → existing Enable action → native prompt/settings → refreshed device state. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Device status → existing Enable action → native prompt/settings → refreshed device state. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | AuthEntryScaffold where public, FormSection, labeled FormField, InlineError, PrimaryCTA; preserve DirtyFormController. |
| States | Target scenarios: Not requested, denied, granted, settings return, notification tap, foreground/background, source unavailable. Observed state anchors: `L232` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | Injected callbacks/local state; no direct provider declared here; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | No new prompt-on-start behavior; preserve binding/permission and foreground notification content; test denial, settings return, tap and current-account resolution. Pass U; preserve J1. |




### E144. Document file selection and validation


| Field | Required detail |
|---|---|
| Route / Surface | Native file chooser from upload actions — [document_attachment_controller.dart:1](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/application/document_attachment_controller.dart#L1); file `omc_app/lib/features/documents/application/document_attachment_controller.dart` |
| Persona | Host authorized uploader; retain exact capability/feature predicates. |
| Purpose | Document file selection and validation: complete this existing user task while preserving its scope and authority. |
| Current UI | FilePicker selection then accepted files/rejectedMessages returned to host; bytes/path and existing file policy retained. |
| Current UX | Returns accepted files and rejection messages to initiating upload action; chooser cancellation produces no upload. |
| Problems | Accepted and rejected selections must be distinguishable before/after upload; tiny snackbar-only messages may be missed. See B4 for inherited/shared style locations. |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Pick files → accepted filenames → explicit rejected-file explanation → current upload flow. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Pick files → accepted filenames → explicit rejected-file explanation → current upload flow. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Cancel, no file, invalid/oversized/empty/multiple files, mixed accepted/rejected and platform path/bytes behavior. Observed state anchors: `L49` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `documentAttachmentControllerProvider`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Picker cancellation is not an error; keep type/size/empty/path checks and no upload on no accepted files; host-specific upload/retry semantics unchanged. Pass U; preserve J1. |




### E145. Profile photo selection / upload


| Field | Required detail |
|---|---|
| Route / Surface | Native image picker → Profile photo upload — [profile_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/profile/presentation/profile_screen.dart#L18); file `omc_app/lib/features/profile/presentation/profile_screen.dart` |
| Persona | Current profile identity; retain exact capability/feature predicates. |
| Purpose | Profile photo selection / upload: complete this existing user task while preserving its scope and authority. |
| Current UI | Gallery ImagePicker action, upload feedback, repository mutation and profile refresh. |
| Current UX | Gallery selection triggers existing avatar upload and profile refresh; cancelled selection leaves photo unchanged. |
| Problems | Transient upload text needs persistent busy state adjacent to avatar; image selection failure should not replace existing identity. File-level style anchors: `L271` `fontSize: 13,`; `L417` `fontSize: 13,`; `L722` `fontSize: 13,`; `L766` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Avatar action → gallery → selected upload state → refreshed photo or retry explanation. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Avatar action → gallery → selected upload state → refreshed photo or retry explanation. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Gallery cancel/unavailable, image load fallback, upload busy/failure/success. Observed state anchors: `L47`, `L48`, `L513`, `L789`, `L973` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `authControllerProvider`, `profileRepositoryProvider`, `profileSummaryProvider`, `supportRepositoryProvider`; imports `../../auth/application/auth_controller.dart`, `../../support/data/support_repository.dart`, `../data/profile_repository.dart`; freeze per J1. |
| Risk | Medium: preserve navigation, visibility, async state and accessible actions. |
| Priority | P1 |
| Acceptance Criteria | Same picker source/compression/repository and refresh; cancelled selection retains image; account ownership unchanged. Pass U; preserve J1. |




### E146. Customer document external opening


| Field | Required detail |
|---|---|
| Route / Surface | External app from Preview / Download actions — [document_detail_screen.dart:18](https://github.com/mshahwaiz-ali/omc_app/blob/b42ed754fdb58dcd672497ba2e2e612658e1b882/omc_app/lib/features/documents/presentation/document_detail_screen.dart#L18); file `omc_app/lib/features/documents/presentation/document_detail_screen.dart` |
| Persona | Authorized document detail including assisted provider; retain exact capability/feature predicates. |
| Purpose | Customer document external opening: complete this existing user task while preserving its scope and authority. |
| Current UI | previewUrl/downloadUrl or fileUrl validated for supported web scheme or rooted backend-relative path, then externalApplication launcher. |
| Current UX | Resolves supported absolute or backend-root-relative URL, calls external launcher and reports missing/invalid/open failure. |
| Problems | External-open failure and missing link need contextual readable feedback; this is not the internal byte-based preview screen. File-level style anchors: `L148` `fontSize: 13,`; `L251` `fontSize: 12,`; `L376` `fontSize: 11,`; `L452` `fontSize: 12,` |
| Keep | KEEP function, actions, data scope and existing hierarchy; polish presentation. |
| Change | KEEP + POLISH: Document identity → preview/download → external viewer/browser → return with current document preserved. Apply C1–C6. |
| Move/Remove | None; preserve all business actions. |
| New Hierarchy | Document identity → preview/download → external viewer/browser → return with current document preserved. |
| Typography | C1: page26, section21, title17, body16, supporting15, status14, caption13; controls label15/input16/button16.  |
| Components | F: PageHeader, SectionHeader, ListRow, StatusBadge, InfoSection, state adapters. |
| States | Target scenarios: Missing/invalid URL, launch false/exception, viewer return; upload handled separately. Observed state anchors: `L54`, `L59`, `L62`, `L437`, `L602` |
| Accessibility | U: full identity/action labels; wrap/stack at narrow/large text; verify focus and announcements. |
| Backend Dependencies | `assistedDocumentDetailProvider`, `documentAttachmentControllerProvider`, `documentDetailProvider`, `documentsRepositoryProvider`; imports `../../../app/mutation_invalidation.dart`, `../application/document_attachment_controller.dart`, `../data/documents_repository.dart`; freeze per J1. |
| Risk | High: shared layout or consequential workflow; require call/payload parity. |
| Priority | P0 |
| Acceptance Criteria | Retain URL resolution/scheme validation and launch mode; absent/invalid/unopenable URL shows existing error and no unsafe fallback. Pass U; preserve J1. |





## F. Shared component migration map

Prefer extending existing compatible primitives. Proposed names below describe responsibilities; they do not mandate a new wrapper per row. Keep feature-specific status mapping, payload creation, async loading and provider subscriptions in their current owners. Components accept data and callbacks and must not acquire new backend dependencies.

| Existing source / duplication | Target | Exact migration and boundary |
|---|---|---|
| app/theme.dart, design_tokens.dart; per-feature _TextStyles and TextStyle | Central TextTheme + semantic text tokens | C1 weights/sizes/height; migrate reachable callers incrementally. Do not change labels/enums by regex. |
| app.dart _withAccentTheme; app_brand_registry.dart | Runtime color roles | Preserve resolver/config input; use onAccent for fill and contrast-safe accentInk for text. Resolve checkbox/radio/date/focus appearance consistently. |
| AppBackHeader, PremiumListHeader, local _Header/_PageHeading | PageHeader | Title26, supporting15, back48; optional action48; stack metadata at narrow width; preserve fallbackRoute/back callback. |
| OmcSectionHeader, local _SectionHeading/_SectionTitle | SectionHeader | Section21/600, optional supporting15, min48 action; wraps without horizontal overflow. |
| OmcStatusBadge, PremiumInfoChip, local _StatusPill/_Chip/_Badge | StatusBadge | Status14 + icon, caption13 only for non-status metadata; no provider/status mapping inside primitive. |
| PremiumCard, OmcSurface, PremiumListCard, local _Card/_SurfaceCard | InfoSection / bounded card | Plain section by default; card16/padding20/border1/no shadow when useful. Preserve independent nested interactive semantics. |
| DocumentActionCard, PaymentActionCard, ProfileActionCard, settings tiles | ActionRow | Row min56, glyph24, title17, supporting15, disclosure/disabled reason; each existing callback remains separate. |
| Feature card rows across documents/payments/CRM/tasks/referrals | ListRow | Name17, supporting15/status14, caption13; adaptive trailing actions below content; no new generic repository/list controller. |
| Tax/expense/payment/commission _MetricTile/_Stat/_Summary | FinancialSummary / KeyValueRow | Amount28/20 with currency; label15; tabular figures where available; stack on narrow widths. No arithmetic/summation migration. |
| AppEmptyState/AppErrorState/AppAccessState/AppConfigurationState; local duplicates | Existing AppStateView adapters | Empty title21/body16, error classification preserved. EmptyState/PremiumEmptyState already delegate: do not count as distinct error architectures or rewrite unnecessarily. |
| DataFreshnessBanner and support wrappers | Existing freshness banner | Title17/body15/timestamp13; preserve stale source/time, independent retries and prior-content visibility. |
| AppSkeleton / local repeated shimmer blocks / LoadingView | Existing loading primitives | Match final structure; reduced-motion static; one accessible loading announcement. Avoid replacing usable cached content with skeleton. |
| _SearchField/_SearchBar in catalogue/requests/tasks/leads/customers/docs | SearchField | Min56, input16, leading24/clear48; preserve each debounce, submit, page reset and query semantics. |
| Local filter chips and sort rows | FilterChip / selectable ActionRow | Visible label14–15; min48 hit target; selected check + text; long options wrap; preserve local/server filter scope. |
| Every showModalBottomSheet builder in B/E | BottomSheetFrame | Shared C6 geometry/keyboard/safe area only; caller owns state/results/discard guard. |
| AuthEntryScaffold/auth_entry_widgets | Existing auth frame | Page26/body16/form spacing20; flexible illustration; no changes to auth navigation. |
| Repeated InputDecoration and labels, _SheetTextField/_LeadFormField/_DynamicField | FormField styling / FormSection | Shared C5 theme and errors; field type/parsing/validation remains feature-owned. |
| AppButton / FilledButton / submit bars | PrimaryCTA | Min56, width stable while loading, label16/600; semantic busy; callbacks/idempotency remain caller-owned. |
| CRM shared widgets | Existing CRM detail components | Remove decorative framing around absent timeline, retain data rows; do not imply editable CRM operations. |
| OmcIdentityHeader and Home/Profile custom identity | Shared identity styling | Avatar48; title26 or17 by context; no business identity fetching inside widget. |
| Native PDF/file/date/biometric components | Retain platform/plugin control | Theme host actions and errors; no media/security implementation replacement. |

For each migration first compare all callers, including widgets under `part of`, private components used by old fallbacks and tests. Preserve OmcWidgetKeys and semantic action identities used by tests/robots. Delete a duplicate helper only after proving no caller; cleanup is not a Phase 0 deliverable.

## G. Old → new decisions

| Existing pattern | Classification | Proposed replacement | Capability outcome |
|---|---|---|---|
| 10px bottom label | REDESIGN | navigation12, measured height and wrapping | All destinations/indices retained |
| Quick Action 3-column10.8 | REDESIGN | Two-column16; one column at narrow/large text | All permitted actions retained |
| Catalogue 3-column/fixed114 | REDESIGN | Two-column17 or readable list | Same server paging/search/category |
| w900 headings and w800 ordinary copy | KEEP + POLISH | 600/700 titles,400 body | No data/wording loss |
| Saturated per-module More icons | REDESIGN | Neutral icon, runtime accent selected | Same recognition via icon/label |
| Card inside card / per-field commission cards | CONSOLIDATE | Divided info section and financial hierarchy | All values including audit evidence retained |
| Settings Profile preferences | KEEP + POLISH | Label Profile; preserve editor target | Edit functionality retained |
| Settings section subtitles + static account-sync explanation | REMOVE FROM UI | Native grouped rows; show actual error when present | No sync behavior or preference removed |
| Logout/deletion among ordinary top account rows | RELOCATE | Final Account actions group | Logout/deletion request intact |
| Tax/Knowledge inside broad Tools & help | RELOCATE | First-level Tax & knowledge group before optional tools | Mandatory destinations easier to find; config gates intact |
| Document/payment timeline-coming-later cards | REMOVE FROM UI | Omit static placeholder; keep status/remarks/dates | No fetched timeline/data removed |
| Article Details heading + body card | REMOVE FROM UI | Continuous reading body17 | All article text/link retained |
| Repeated raw IDs/status chips in list and detail | CONSOLIDATE / RELOCATE | Primary identity/status once; technical fields in existing details | Operational IDs accessible; never remove finance provenance |
| Dashboard duplicated concepts | CONSOLIDATE | Shared presentation with Home/workspace | /dashboard retained; no route removal |
| Request stage preview competing with form | RELOCATE | What happens after submission expansion | No lifecycle reorder; draft still sends attachments[] |
| Read-only task notice plus chip | CONSOLIDATE | One readable read-only explanation | No task mutation invented |
| Contextual Home Alerts/Tax and More shortcuts | KEEP | Preserve useful contextual entry points | Mandatory discoverability retained |
| Approval/capability/access gates | KEEP | Visual polish of states only | Backend authority unchanged |

REMOVE recommendations above are UI-only and remain proposals until implementation approval. No business field, attachment, payment, tax tool, news, service stage, customer/staff capability or API is retired.

## H. Implementation phases and review gates

| Phase | Scope / concrete outputs | Exit criteria and dependency |
|---|---|---|
| 0 — Inventory & visual contracts | This document; source/route/surface/contract ledger; agree C/G/J decisions | Review design and removal/relocation proposals; no production changes. Stop for explicit approval. |
| 1 — Design system | TextTheme, color roles, spacing/radius, existing shared primitives; representative auth/list/financial/form fixtures | Token/contrast and narrow2x component tests pass; runtime accent preserved; no provider/API change. |
| 2 — App shell | Both shells, bottom navigation, More, Quick Actions, headers and global sheets | All capability/route/back/restoration tests plus full labels at320/2x; no duplicate bars; Tax/Knowledge/Alerts visible. |
| 3 — Core customer journey | Home → catalogue/detail → request draft → tracking → canonical and assisted detail | Complete submit/duplicate/retry/dirty-exit/payment-first scenarios with unchanged payload and authority; approve major hierarchy on device. |
| 4 — Customer operations | Documents/upload/preview; payment/proof/review; notifications; support/conversation | Upload cancel/retry, verified versus submitted, unread/undo, stale support and ownership parity pass. |
| 5 — Customer tools | Tax/input/result/history, Knowledge/articles, expense/local/cloud/budget | Same tax inputs/results, article actions, currency totals, storage/import/export/archival behavior. |
| 6 — Profile/settings/auth | Profile/photo/edit sheets, notification preferences/legal/deletion/logout, all auth/onboarding/review/device-lock states | Token/session/enrollment behavior unchanged; large-text keyboard forms pass; no policy wording changed unintentionally. |
| 7 — Internal/staff | Internal Home/workspace/cases/customers, review queues, referrals/commissions, leads/tasks, support workspace/admin | Full capability matrix, read-only tasks, review reasons, eligible assignees, frozen commission evidence and settlement semantics pass. |
| 8 — Accessibility & responsive QA | Full width/scale/persona/state matrix, screen readers, reduced motion, long data, manual device capture | No important clipping/overflow, no inaccessible controls, approved visual comparison; all applicable tests/analyze pass with current evidence. |

Accessibility tests start in Phase1 and accompany every screen; Phase8 closes the complete matrix. Keep each phase reviewable and do not implement a new backend-dependent interaction to fill an attractive UI. If a phase changes shared components, rerun their affected callers. Route and mutation preservation are continuous gates, not last-minute checks.

## I. Regression / QA plan

### I1. Evidence status and commands

This phase ran read-only source/Git inspections and document consistency checks only. **Flutter analyze/test and manual visual QA: NOT RUN.** No production-readiness conclusion follows from this audit. Backend behavior is frozen and its reported passing suite is not reused as UI evidence.

For later approved implementation, from `omc_app/`, using the checkout's installed/pinned Flutter toolchain:

```sh
flutter analyze
flutter test
```

Run full applicable unit/widget suite. Run integration tests separately with the project's existing configured device/accounts and target instructions; do not run destructive E2E against unspecified production records. Record exact commands, commit, device/OS/viewport, fixtures, count/results and any blockers. Do not report “all passed” for skipped integration/hardware scenarios. Baseline test files may enforce old literal typography; replace obsolete visual assertions with the new approved contract while retaining behavioral assertions—never delete a failing authority guard as a style cleanup.

### I2. Existing regression anchors to preserve and extend

| Area | Existing evidence source (tests present, not run here) | New/extended validation |
|---|---|---|
| Core tokens/semantics | test/app/accessibility_design_contract_test.dart; test/core/widgets/app_state_test.dart | C1 weights/height; actual hit targets; accentInk and focus contrast; busy width; 320px2x with labels visible |
| Shell/IA | test/app/omc_navigation_ia_test.dart; navigation_hardening_regression_test.dart; more_route_consistency_guard_test.dart | Both shells, exact route/query/indices, More close/reopen, Quick Action result routing, 5-target bar at large text |
| Route authority | route_access_policy_test.dart; route_capability_matrix_test.dart; router_policy_parity_test.dart; shell_capability_authority_test.dart | Guest/pending/rejected/approved/staff and partial grants; /track versus /my-services; unknown routes fail closed |
| Auth/link isolation | auth_route_redirect_test.dart; link_coordinator_test.dart; test/features/auth/session_isolation_test.dart; auth_repository_login_test.dart | Login/biometric chooser, stale response after account switch, queued token link; same-session canonical verification |
| Forms/mutations | test/core/forms/dirty_form_controller_test.dart; test/core/network/mutation_intent_test.dart; test/resilience/mutation_safety_regression_test.dart | Stay/discard via back/shell/sheet; double taps; payload equality; retained values on timeout |
| Lifecycle and assisted flow | test/features/home/home_dashboard_lifecycle_test.dart; test/features/service_requests/customer_service_case_detail_contract_test.dart; assisted_customer_retirement_test.dart | Canonical/legacy dispatch; preparation/payment-first; assisted attribution/consent and historical safeguards |
| Documents/payments | document_upload_contract_test.dart; test/features/payments/payment_receipt_upload_contract_test.dart; finance_reconciliation_contract_test.dart | Reject/reupload, missing request link, skipped path files, cancel/progress, external document URL vs internal bytes preview, finance review only |
| Support | test/features/support/support_resilience_contract_test.dart | Config/feed/unread/detail stale independently; failed reply retains draft; closed ticket; attachment failure; foreground timer unchanged |
| Alerts | test/features/notifications/notification_pagination_contract_test.dart; internal_notification_contract_test.dart | Read-all/dismiss/Undo, unread badge, stale page mutation, unsupported reference target |
| Expense | test/batch3/expense_state_test.dart; expense_export_test.dart; test/resilience/expense_consistency_regression_test.dart; expense_destructive_actions_test.dart | Local/account scope, cloud export cancellation/session epoch, JSON import, archive/clear distinction, over-budget readable value |
| Tax/Knowledge | test/features/tax_calculator/tax_calculation_repository_test.dart; test/features/knowledge_resilience/knowledge_failure_mapping_test.dart | Config-driven advanced fields, year/input/result parity, no valid result on config failure; long article and external link fallback |
| Settings | test/features/settings/inactive_delivery_preferences_test.dart; settings_resilience/settings_failure_mapping_test.dart | Push provider operational gating, preferences error/rollback behavior, enrollment failure, deletion request vs deletion |
| Staff/tasks/commissions | test/features/commissions/commission_accessibility_test.dart; finance_commission_contract_test.dart; test/features/tasks/task_tracking_final_contract_test.dart; test/features/admin_control/admin_operations_contract_test.dart | Currency/evidence preserved, read-only task with linked-case permission, eligible candidates, rejection required, each transition separate |

Existing accessibility tests cover selected components and a commission list at320/2x. They do not prove the entire app matrix. Add targeted widget tests around actual risky layouts, not hundreds of assertions mirroring every padding literal. Use test fixtures/provider overrides for presentation states; do not manufacture backend production evidence.

### I3. State coverage matrix

Legend: **Required** = later rendering/interaction scenario; **N/A** = not meaningful for a pure static/modal state. Each E table specifies its feature-specific variants. A missing current custom state is a gap to handle with existing classifier/provider semantics, not permission to invent backend behavior.

| Surface family | Required state scenarios and expected result |
|---|---|
| Paged lists (catalogue/docs/alerts/CRM/internal/commissions/cloud expenses) | Initial load; valid data; refresh; next/previous/load-more where present; load-more failure retains existing list; true empty; filtered empty with clear action; last page; network/backend unavailable; permission denial; long row data. Do not invent pagination for unpaged lists such as current customer Payments. |
| Details (service/case/document/payment/article/ticket/customer/task/referral/commission) | Loading; inaccessible/not found; backend failure; missing optional metadata; long text; valid terminal states. Retry must use same ID/query; no synthetic success record. |
| Mutable forms (request/auth/profile/expense/budget/lead/support/admin) | Keyboard visible; required invalid; format invalid; async validation failure; read-only/disabled field; dirty exit Stay/Discard; submitting/double-tap; success; timeout/server rejection; retry retains intent/data. |
| Upload and media | Empty/unsupported/oversized picker selection; picker cancel; bytes/path policy; upload known/unknown progress; cancellation where provided; partial/skipped file results; rejection/reupload; preview unsupported/corrupt; external open failure; missing service ownership. |
| Payment and finance | Invoice preparing, pending/overdue, receipt submitted, review, rejection, verified/paid, cancelled; missing proof/invoice/gateway; review required reason; settlement reference/date; held/missing evidence; failed transition. Never collapse these to one green status. |
| Auth/account | Guest, checking, pending, rejected, approved, internal; wrong credentials; invalid/expired/missing tokens; registration cooldown; biometric unavailable/cancel/lockout/failure; account switch; logout error. |
| Global overlays | Loading/config unavailable, maintenance, recommended/forced update, feature gate; normal back; dirty dialog; device lock; route failure; long recovery CTA; underlying focus blocked and restored. |
| Support freshness | No snapshot vs last synced snapshot, refreshing with content retained, partial feed/config/unread error, retry busy/failure/success; stale state never grants offline mutation. |
| Knowledge/tax/content | Empty/unpublished versus load error; image missing; featured absent; long article; unsupported link; calculator unconfigured/year unavailable/invalid input/calculation failure/result/history empty. |
| Local tools | Guest local storage, eligible account storage, internal visibility/local budget note, cloud pending entries, import bad JSON, export cancel, archive failure, clear local only, month/filter empty. |
| Static information/confirmation | Long content, focus/semantics, cancel/dismiss, target identity, result delivered once; data loading/mutation N/A unless host performs it. |

### I4. Persona and capability matrix

| Persona | Verify visible public/primary content | Verify protected actions |
|---|---|---|
| Guest | Home, catalogue/detail, Tax, Knowledge/detail, support contacts, local expense when enabled | No request/document/payment/ticket/account data; existing signup/login feedback |
| Pending | Public tools plus permitted Profile/Settings and account-state note | Protected services remain denied; refresh uses backend session; tax-history gate tested separately |
| Rejected | Public tools/support and accurate approval-required copy | No local visual state may enable protected flow |
| Approved customer | Full Home/services/requests/documents/payments/alerts/tax/knowledge/support/profile discoverability | Own record only, customer-specific canonical detail, existing receipt/document rights |
| Operational staff with relevant/assigned scope | Scoped queue/home/customers/docs/tasks/support as individually granted | No all-customer or review authority inferred from staff status |
| Finance/commission staff | Payment/commission/evidence/settlement-review surfaces allowed by capability | Approve, mark payable, record paid and resolve/ignore remain separately gated |
| Admin partial/full grants | Only applications/staff/settings/operations sections permitted | Reassignment uses eligible staff, retry authorized, role changes remain server-controlled |
| Referral owner / assisted creator | Own referrals/commissions; assisted selection where allowed | Consent/customer_profile/request IDs preserved; cannot infer access to unrelated customers |
| Account A→B transition | No old avatar/list/notification/support/expense data persists improperly | Session-epoch/keyed provider behavior unchanged; stale mutation result not applied to B |

### I5. Visual acceptance and review artifacts for later implementation

For every E surface family capture 390px1x normal state and its highest-risk320px2x state, plus the actual E edge cases. Record all widths/scales in a checklist; photos/snapshots are evidence, not substitutes for tap/focus tests. Check no overflow exceptions and visually inspect clipping even when Flutter emits no overflow (ellipsis can hide data silently). Screen-reader traverse and activate every control; confirm semantics boundaries on clickable cards, dialog focus return and lock overlays. Test physical Android/iOS biometrics, keyboard, OS text/display scale, file chooser, PDF/image viewer and push permission flows on applicable platforms. No hardware pass can be claimed from widget tests.

Financial amount/status/next action and service/customer names should be findable immediately in a short usability review. At normal width the current service dominates Home; More exposes all mandatory allowed customer areas in one sheet; Quick Actions and service titles do not need squinting. After each phase compare mutations/queries/route outcomes with baseline fixtures and rerun applicable full tests. Final QA closes all unresolved risks; no phase is “production complete” solely because the new theme compiles.

## J. Frozen contracts, absence findings and proposed small logic adjustments

### J1. Source-specific functional freeze

| Contract | Source and invariant |
|---|---|
| Routing/access | app/router.dart, auth_route_redirect.dart, route_access_policy.dart, providers/effective_capabilities_provider.dart; all path names/query/defaults and fail-closed rules unchanged |
| Shell lifetime/back | MainShell, ShellNavScaffold, navigation guards/coordinators; keep root/indexed navigators, restoration, modal dismissal and dirty form behavior |
| Auth/session | auth_controller.dart, auth_repository.dart, auth_state.dart; canonical identity/session, epochs, redirect and logout invalidation remain authoritative |
| Branding/config | app.dart, app_brand_registry.dart, app_gate_policy/controller and mobile_app_config; keep configured branding/features/release controls; only derive visual contrast roles |
| Request creation | service_request_draft_screen.dart:503–536, service_request_repository.dart; keep ServiceRequestPayload fields, attachments[], additionalDetails, customer mode/consent, internal discount fields, MutationIntent.keyFor(payload.toJson()), duplicate response and refresh/navigation |
| Customer lifecycle | customer_service_case_repository.dart, service_case_repository.dart, case/home lifecycle models; payment-first, activation preparation, historical/terminal restrictions and next action are not redesigned business rules |
| Documents | documents_repository.dart and document_attachment_controller.dart; preserve authenticated review download, required document upload vs generic attachment upload, file constraints/partial results and request ownership |
| Customer document opening | document_detail_screen.dart:596–606/:696 onward uses validated preview/download URL through launchUrl externalApplication. It does not use DocumentPreviewScreen here. Preserve that behavior; do not silently switch authentication/opening method. |
| Payments | payments_repository.dart; preserve reviewPaymentReceipt, uploadPaymentReceipts, invoice/proof downloads, assisted lookup, cancel/progress, gateway availability and invalidation |
| Tax | tax_calculation_repository.dart getConfig/calculate/startServiceFromCalculation/getHistory; all field/result models and year/rate calculations server-owned |
| Support | support_repository.dart plus wrappers and legacy presenters; config/feed/unread/detail cache state, foreground timer, ownership, reply/file/status and assign-to-self unchanged |
| Settings/profile | settings_repository.dart, profile_repository.dart, device_lock_service.dart; permission-aware field payloads, operational-push flag, preference errors, deletion support request, credential enrollment and logout unchanged |
| Expense/budget | expense_tracker_repository.dart, local_expense_budget_store.dart, expense_export_*; local/account modes, transaction IDs/flags, epoch and cancellation, parser/clear/archive scope unchanged |
| Finance/admin/CRM | Current feature repositories; immutable commission evidence, review-only reconciliation, staff role predicates, assignment options, discount reasons, read-only tasks and lead creation contracts unchanged |

### J2. Features not to invent from names or backend methods

The request draft has **no active document-upload step** and sends `attachments: const []`; document requirements there are guidance. Actual uploads are later surfaces. A visually guided form must not move evidence collection before payment or change lifecycle. Catalogue modern/premium files are exports, not separate designs. Knowledge type/category labels are not proof of a current interactive category filter; preserve current feed, do not invent a query/API. Tax repository has PDF/share methods, but no corresponding presentation call was found in the current Tax screen: do not list them as existing visible buttons or add them without separate scope. Tasks are read-only. Lead detail is informational; do not add conversion/follow-up mutations. SignupSuccessScreen is declared but PendingRegistrationSuccessScreen is the used success state. Non-payment legacy operations-center branches are not current routed customer/document screens.

### J3. Explicitly reviewable small frontend behavior changes

These proposals are not authorization to change implementation now. Visual-only work can proceed later without them; each logic adjustment must be deliberately included in an approved phase and tested.

| Current problem / evidence | Proposed small adjustment | Why needed | Backend/API impact | Regression risk / acceptance |
|---|---|---|---|---|
| Request form is one long ListView; required errors may be remote from submit | Focus and scroll to first invalid field; optionally make sections expandable while retaining one form/controller | User can locate correction without scanning full ERP-like form | None; validators/payload/order of mutation unchanged | Medium: focus/hidden fields. All invalid fields reachable; retained form values and dirty intent identical. A true multi-step state machine is separately scoped. |
| Tax advanced inputs can fail validation inside collapsed section | Expand the containing advanced section and focus existing invalid field | Prevent hidden correction | None; config/validation/calculation unchanged | Medium: preserve current hidden-field values and income-type change rules. |
| DeviceLockGate is a Stack retaining router; unlike readiness overlay it does not visibly wrap child in ExcludeFocus/ExcludeSemantics/IgnorePointer | Verify with screen reader; if underlying content remains accessible, apply exclusion wrappers while mustLock | Prevent access to obscured UI through assistive navigation | No auth/backend change | High: never remove navigator; lock/unlock/account switch tests and hardware check. This is a source-derived accessibility risk, not a reproduced bypass. |
| Some dynamic accent use is only fill-foreground contrast-safe | Add derived visual accentInk/focus tones while retaining configured accent | Readability on light surfaces | None; no config schema changes | Medium: preserve hue/config and check contrast across accents; no behavior/capability changes. |
| Swipe-dismiss notification action may be hard to discover/access | Expose the same existing dismiss callback in an accessible row action/menu | Non-gesture alternative | None; same ID and Undo behavior | Medium: no duplicate delete or changed Undo timing. |
| AppButton compact loading swaps content to spinner | Preserve measured content width and readable busy label | Avoid shifting primary action and improve progress communication | None | Low: same enabled/isLoading rules and haptics. |
| Details sheets contain long identity/confirmation data in small dialogs | Reflow/scroll and use shared visual container | Complete review before confirming | None; preserve result type/barrier/dirty guard | Medium: confirm/cancel result exactly once, keyboard/back tests. |

Do not broaden these into provider rewrites, repository replacement, new caching, route aliases, field migrations, backend validation or permission changes. A newly discovered functional defect gets its own problem/proposal/API-impact/risk entry before implementation.

## K. Phase 0 delivery and approval boundary

This document is the only repository deliverable. Document checks confirmed 59 GoRoute declarations, 146 complete surface tables with all 18 required fields, all 107 presentation/shared-widget files plus five external interaction owners, valid source-file/line links, and resolved internal index anchors. GitHub main was rechecked after writing and still matched the baseline. Flutter/backend tracked files remain unchanged; only root ui-ux.md is new. Implementation, including the proposed small logic adjustments and UI removal/relocation decisions, waits for explicit approval. Subsequent work should refer to E IDs and the C/U contract and update evidence against the then-current approved main snapshot rather than assuming this audit proves rendered behavior.

