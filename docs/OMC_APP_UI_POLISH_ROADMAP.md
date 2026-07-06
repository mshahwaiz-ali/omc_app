# OMC App UI Redesign Roadmap

## Vision

OMC app should feel like a polished native mobile workspace, not a responsive website inside a phone.

The design should be:
- Clean
- Fast to scan
- Mobile-first
- Premium but not over-decorated
- Practical for tax/business service workflows
- Friendly for normal customers
- Structured enough for power users and internal workspace users

The target feel is closer to a modern productivity app:
- Compact launcher actions
- Floating bottom navigation
- Soft surfaces
- Meaningful color badges
- Minimal nested cards
- Clear content hierarchy
- Smooth user journey from service discovery to request tracking

Reference direction:
- Rounded but not repetitive
- Colorful badges where meaning matters
- Floating navigation like modern mobile OS/productivity apps
- Less red-heavy UI
- More breathing room
- Better icon rhythm
- More native app feel

---

## Current UI Problems

### 1. App feels like a mobile website

Many screens currently use:
- Large white rounded cards
- Repeated icon boxes
- Plain page titles
- Heavy vertical sections
- Web-style AppBars

This makes the app feel like a website opened on mobile instead of a real mobile app.

### 2. Bottom navigation is missing on important pages

Bottom nav is not visible on several main workspace pages such as:
- Documents
- My Services
- Payments
- Knowledge
- Tax Calculator

This breaks navigation continuity.

### 3. Too many cards

Almost every section is inside a big rounded card. This creates visual fatigue.

Avoid:
- Card inside card
- Same radius everywhere
- Same red icon box everywhere
- Large cards for simple rows
- Repeating the same layout on every screen

### 4. Red is overused

OMC red should remain the brand anchor, but not every badge, icon, chip, and card should be red.

Use red only for:
- Brand moments
- Primary CTA
- Important tax/FBR emphasis
- Error or urgent states

Other states should use meaningful colors.

### 5. Headers need redesign

Plain top titles like:
- Documents
- My Services
- Service Details

feel weak and web-like.

Need:
- Clean mobile headers
- Back button on every non-home/deep page
- No unnecessary AppBar title on main tab pages
- Better page introduction where useful

### 6. Quick Actions are too bulky

Current Quick Actions look like big inner cards inside a big outer card.

Need:
- Compact app launcher style
- Icon + label
- 3 columns
- Scalable for more actions
- No heavy inner cards

### 7. Service catalogue feels congested

Current Services page has:
- Header
- Search
- Stats
- Category chips
- Shortcut card
- Service cards

Too much vertical clutter before user reaches actual services.

### 8. Service detail pages are too repetitive

Service detail pages repeat:
- Hero card
- Stat cards
- Facts card
- Overview card
- Requirements card
- Documents card
- Process card

This is heavy and not very mobile-friendly.

### 9. Empty states and missing document states need logic polish

Example:
- “No missing documents” appears where it does not make sense.
- Upload/document requirements need clearer business logic.

---

## Design Principles

## 1. Mobile app first

Every screen should be designed as a native mobile screen first.

Use:
- Compact rows
- Floating nav
- Bottom sheets
- Sticky CTAs
- Segmented filters
- Horizontal chips
- Timeline/progress views
- Swipe-friendly lists

Avoid:
- Desktop/web page layouts
- Long static pages full of cards
- Too much text before action

---

## 2. Fewer cards, better hierarchy

Use cards only for grouped information.

Good card use:
- Hero summary
- Case progress summary
- Payment summary
- Important alert
- Service request action area

Avoid card use for:
- Every row
- Every icon
- Every badge
- Every tiny stat

---

## 3. Semantic color system

Use color based on meaning.

| Purpose | Color Direction |
|---|---|
| Brand / Primary action | OMC Red |
| Approved / Complete / Paid | Green |
| Pending / Review / In Progress | Amber / Yellow |
| Missing / Failed / Overdue | Red |
| Open / Draft / Neutral | Blue / Gray |
| Knowledge / Guide / Info | Indigo / Blue |
| Payment / Invoice | Purple / Teal |
| Documents | Green / Blue |
| Support | Cyan / Blue |

Required shared components:
- `StatusBadge`
- `CategoryBadge`
- `PriorityBadge`
- `AmountBadge`
- `DocumentStatusBadge`

---

## 4. Modern navigation model

### Main bottom tabs

Use 5 main tabs:

1. Home
2. Services
3. Track
4. Documents
5. More

### More page includes

- Payments
- Tax Calculator
- Knowledge
- Support
- Profile
- Settings
- Internal Workspace

### Detail pages

Detail pages should:
- Show back button
- Hide bottom nav when deep/action-focused
- Keep a clean top bar
- Use sticky primary CTA where needed

Examples:
- Service Detail
- Service Request Draft
- Document Detail
- Payment Detail
- Knowledge Detail
- Support Ticket Detail
- Service Case Detail

---

## 5. UI should follow backend content

Do not design generic screens first.

For each module:
1. Check backend response/data model
2. Identify the user’s actual job
3. Design the simplest mobile flow around that data
4. Keep API/controller behavior unchanged
5. Improve presentation only unless backend change is required

Backend-connected modules already available:
- Auth/session
- Dashboard summary
- Service catalogue
- Service cases
- Documents
- Document upload/status
- Payments
- Payment receipt upload
- Profile
- Knowledge
- Notifications
- Settings preferences
- Support tickets
- Internal workspace
- Leads
- Customers
- Tasks

---

# Target UI Direction

## Home

### Goal

Home should feel like a dashboard/workspace, not a landing page.

### Redesign

- Rename `OMC Premium Workspace` to `OMC Workspace`
- Keep hero card but make it cleaner and less oversized
- Add compact action launcher
- Use colorful icon categories
- Show active work summary
- Show recent activity in compact timeline/list format
- Reduce large repeated cards

### Quick Actions style

Use compact launcher grid:

- Icon button
- Label below
- Optional tiny subtitle only if needed
- No large inner cards
- No heavy red background everywhere

Suggested actions:
- Tax Return
- NTN
- GST
- Documents
- Track
- Calculator

---

## Services

### Goal

Make service discovery simple and fast.

### Redesign structure

1. Clean header
2. Search bar
3. Horizontal category chips
4. Popular/featured services if backend supports it later
5. Service list

### Remove or reduce

- Big stats row at top
- Heavy shortcut card
- Repetitive service cards
- Too many visible requirements on catalogue list

### Service cards should show

- Service title
- Category badge
- Fee label
- Completion time
- Document count only if useful
- One clear CTA or chevron

Use compact native list/card hybrid.

---

## Service Detail

### Goal

Help user understand the service and start request quickly.

### Redesign structure

1. Compact hero/header
2. Key facts as chips
3. Overview
4. Requirements checklist
5. Required documents
6. Process timeline
7. Sticky CTA: Start request
8. Secondary CTA: Ask support

### Avoid

- Too many separate cards
- Duplicate fee/time sections
- Empty sections with confusing copy
- Large icon boxes everywhere

### Requirements/Documents logic

- If requirements exist, show checklist.
- If required documents exist, show upload-ready list.
- If missing documents do not exist yet, do not show “No missing documents” on service detail.
- Missing document logic belongs mainly to active service case tracking.

---

## My Services / Track

### Goal

This should feel like a work tracker.

### Redesign structure

1. Compact tracking summary
2. Segmented filters:
   - Active
   - Need Docs
   - Done
3. Service case list
4. Each case row shows:
   - Service title
   - Reference
   - Status badge
   - Progress
   - Last updated
   - Missing docs count if any

### Case card style

Use less bulky cards:
- Compact row
- Progress bar
- Status badge
- CTA row only when needed

### Service Case Detail

Use timeline style:
- Request submitted
- Under review
- Documents required
- Payment pending
- In progress
- Completed

Also show:
- Documents
- Payments
- Support/chat
- Notes/updates if backend provides them

---

## Documents

### Goal

Documents should feel like a vault and upload workflow.

### Redesign structure

1. Header: Documents
2. Compact stats row or segmented status tabs
3. Filters:
   - All
   - Missing
   - Review
   - Approved
4. Document list rows

### Document row

Show:
- Document name
- Related service/case
- Status badge
- Upload/review/approved state
- Action if missing or rejected

### Better states

- Missing: red/orange, show upload CTA
- Review: amber, show “Under review”
- Approved: green, show verified
- Rejected: red, show re-upload CTA

---

## Payments

### Goal

Payments should feel like invoice/payment tracking.

### Redesign

Use:
- Payment summary at top
- Filters:
  - All
  - Due
  - Paid
  - Review
- Payment rows with:
  - Amount
  - Status badge
  - Due date/service
  - Receipt upload status

Colors:
- Paid = green
- Due = amber/red depending urgency
- Review = purple/blue
- Draft/open = gray/blue

---

## Knowledge

### Goal

Knowledge should feel like a clean guide/news reader.

### Redesign

Use:
- Search
- Category chips
- Article cards with type badge:
  - Guide
  - Tax
  - News
  - Alert
- Compact reading detail page
- Avoid red everywhere

Colors:
- Guide = blue/indigo
- Tax = OMC red
- News = teal
- Alert = amber/red

---

## Tax Calculator

### Goal

Calculator should feel like a focused tool.

### Redesign

Use:
- Clean header with back button if opened from More
- Input section
- Calculation result card
- Clear CTA:
  - Calculate
  - Reset
- Sticky result after calculation
- Avoid huge cards for every input

Fields should look native and compact.

---

## More

### Goal

More page should be clean settings/workspace launcher.

### Redesign

Sections:
- Account
  - Profile
  - Notifications
  - Settings
- Tools
  - Tax Calculator
  - Knowledge
  - Payments
  - Support
- Workspace
  - Internal Workspace
  - Leads
  - Customers
  - Tasks

Use list rows, not bulky cards.

---

## Internal Workspace

### Goal

Internal workspace should feel like an admin/business dashboard.

### Redesign

Use:
- Summary metrics
- Compact module launcher
- Color-coded modules:
  - Leads
  - Customers
  - Tasks
  - Payments
- Native list/detail layouts

Do not mix customer-facing and internal UI too heavily.

---

# Shared Components To Build

## App Shell

Files:
- `lib/app/router.dart`
- `lib/app/main_shell.dart`

Tasks:
- Move main pages into shared shell
- Keep bottom nav on main tabs
- Keep detail pages separate with back button

---

## Shared UI Components

Create in:
- `lib/core/widgets/`

Components:
- `app_page.dart`
- `app_page_header.dart`
- `app_back_button.dart`
- `app_bottom_nav.dart`
- `status_badge.dart`
- `compact_action_grid.dart`
- `app_list_row.dart`
- `metric_chip.dart`
- `progress_timeline.dart`
- `empty_state_v2.dart`

---

## Theme Updates

File:
- `lib/app/theme.dart`

Add:
- Semantic colors
- Badge colors
- Softer background colors
- Consistent radius scale
- Spacing scale
- Shadow rules

Suggested radius scale:
- Small: 10
- Medium: 14
- Large: 20
- Hero: 26
- Pill: 999

Suggested spacing:
- Page horizontal: 20
- Section gap: 20
- Row gap: 12
- Compact gap: 8

---

# Implementation Phases

## Phase 1 — Navigation foundation

Fix bottom navigation first.

Tasks:
- Refactor router/app shell
- Main tabs:
  - Home
  - Services
  - Track
  - Documents
  - More
- Ensure bottom nav appears on main pages
- Ensure back button appears on all detail/action pages

Acceptance:
- Documents shows bottom nav
- My Services shows bottom nav
- Services shows bottom nav
- Home has no back button
- Detail pages have back button

---

## Phase 2 — Shared design system

Tasks:
- Add shared headers
- Add semantic badges
- Add compact action grid
- Add reusable row/card patterns
- Update theme semantic colors

Acceptance:
- No more hardcoded red badges everywhere
- New screens use reusable components
- UI becomes consistent

---

## Phase 3 — Home redesign

Tasks:
- Rename `OMC Premium Workspace` to `OMC Workspace`
- Replace bulky Quick Actions
- Improve hero
- Improve current progress/recent activity layout

Acceptance:
- Home feels like a native dashboard
- Quick Actions are compact and clean
- Less card nesting

---

## Phase 4 — Track/My Services redesign

Tasks:
- Redesign tracking header
- Add filters
- Redesign case rows
- Improve detail timeline

Acceptance:
- User can quickly understand active work
- Missing docs and progress are obvious

---

## Phase 5 — Documents redesign

Tasks:
- Add filters
- Redesign stats/status header
- Redesign document rows
- Improve upload/review/approved states

Acceptance:
- Document vault feels clean
- Upload path is obvious
- Status colors are meaningful

---

## Phase 6 — Services redesign

Tasks:
- Simplify catalogue
- Improve category chips
- Redesign service list
- Redesign service detail page
- Fix confusing empty sections

Acceptance:
- Services page feels less congested
- Detail pages are easier to act on

---

## Phase 7 — Payments, Knowledge, Calculator polish

Tasks:
- Apply new shell/header/badge/list patterns
- Redesign module layouts
- Fix back button behavior
- Reduce card-heavy sections

Acceptance:
- All modules feel part of one native app

---

## Phase 8 — Final polish pass

Tasks:
- Check all screens on mobile width
- Check scroll behavior
- Check bottom nav spacing
- Check empty/loading/error states
- Run `flutter analyze`
- Manual browser/mobile test

Acceptance:
- No analyzer issues
- No missing nav on main pages
- No ugly default AppBars
- App feels modern, mobile-first, and polished

---

# First Work Batch

Start with:

1. Router/MainShell restructure
2. Bottom nav on main pages
3. Back button pattern
4. Home Quick Actions redesign
5. Semantic badge component

Do not redesign every screen at once.

Small stable batches only.