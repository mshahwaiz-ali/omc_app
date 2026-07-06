# OMC App UI Polish Roadmap

## Goal

Redesign the OMC Flutter app into a premium, modern, useful, mobile-first business services app.

The app should feel like a high-quality fintech/business productivity app, not a basic form-based Flutter app. UI polish must improve usability, trust, clarity, and perceived product quality while preserving backend-connected architecture.

---

## Core Design Direction

### Visual Identity

Use the OMC brand color as the main identity.

Recommended palette:

- Primary Red: `#8B1020`
- Dark Red: `#650B17`
- Accent Red: `#B5162C`
- Soft Blush: `#FBE8EA`
- Warm Background: `#F8F3F0`
- Card Surface: `#FFFFFF`
- Text Primary: `#161316`
- Text Secondary: `#746B6B`

### Style

The app should use:

- Premium rounded surfaces
- Soft warm background
- OMC red gradients
- Compact cards and action tiles
- Logo/icon-driven shortcuts
- Clean typography
- Strong visual hierarchy
- Minimal but useful animations
- Floating pill bottom navigation
- Consistent back navigation on inner screens

Avoid:

- Huge empty cards
- Flat default Flutter UI
- Too much wasted space
- Overloaded grids
- Cheap-looking shadows
- Hardcoded visual elements where logo assets should be used
- Fake/local data flows in production paths

---

## Design System Structure

Create a shared UI polish layer before redesigning individual screens.

Recommended structure:

```txt
lib/core/ui/
  app_colors.dart
  app_spacing.dart
  app_radius.dart
  app_shadows.dart
  app_gradients.dart
  app_motion.dart

lib/core/ui/widgets/
  omc_app_bar.dart
  omc_back_button.dart
  omc_glass_card.dart
  omc_action_tile.dart
  omc_logo_action.dart
  omc_stat_chip.dart
  omc_section_header.dart
  omc_bottom_nav.dart
  omc_settings_tile.dart

Existing shared widgets such as PremiumCard can either be upgraded or gradually replaced with the new UI widgets.

Navigation Direction
Bottom Navigation

Use a custom floating pill navigation instead of the default Material NavigationBar.

Recommended style:

Floating rounded container
Soft blush/red selected state
Compact icons
Clear labels
Slight top shadow
Rounded active tab capsule
Bottom safe-area aware spacing

Tabs:

Home
Services
Calculator
Support
More

The nav should feel like a premium mobile app control, not a standard web-style bottom bar.

Home Page Redesign
Purpose

Home should act as the main OMC command center.

It should quickly show:

User identity
Important status
Quick service actions
Current work/progress
Documents/payment alerts
Easy path to support
Home Page Layout
1. Premium Header

Content:

OMC logo asset, not hardcoded OMC text
Welcome message
User name
Notification button
Optional small status indicator

Example:

[OMC Logo] Welcome back
           Administrator

[Notification]

Use transparent logo assets from:

assets/images/logo_symbol_transparent.png
assets/images/full_logo_transparent.png
assets/images/favicon-app-label-logo_transparent.png
2. Hero Card

Use a premium red gradient hero.

Content:

Main headline
Short useful subtitle
Primary CTA: Start Request
Secondary mini status: Active cases / backend status / support available
Optional subtle watermark using OMC logo symbol

Example copy:

Your tax and business services, organized.
Submit requests, upload documents and track every update from one place.

CTA:

Start a Request

Hero should feel premium but not too tall.

3. Smart Status Row

Replace squeezed plain cards with compact premium stat chips/cards.

Recommended items:

Active Services
Pending Documents
Payments Due
Alerts

Design:

Compact horizontal scroll or 2x2 responsive layout
Icon + value + label
Small color accent
No huge empty spacing

Example:

[Icon] 0
Active Services

[Icon] 0
Documents Needed

[Icon] 0
Payments Due

[Icon] 0
Alerts
4. Quick Actions

Do not use huge blank cards.

Use premium logo/icon-based action shortcuts.

Recommended style:

Compact rounded action tiles
OMC red/blush icon capsules
Service icon/logo prominent
Short label
Optional one-line helper text only when needed

Recommended actions:

File Tax Return
NTN Registration
GST Registration
Tax Calculator
Upload Documents
Track Request

Possible layout:

Quick Actions

[Icon] File Tax      [Icon] NTN
[Icon] GST           [Icon] Calculator
[Icon] Upload Docs   [Icon] Track

Or premium horizontal launcher:

[Tax] [NTN] [GST] [Docs] [Track] [Calc]

Preferred approach:

Use compact logo/icon launcher tiles instead of large cards.

The tile should feel like a premium app shortcut, not a web card.

5. Current Progress / Active Service

Add a useful “current work” section.

If user has an active case:

Current Service
Tax Return Filing
In progress · Documents review
[Progress bar]
View Details

If no active case:

No active service yet
Start a request and track progress here.

This makes the home screen more useful than only showing static shortcuts.

6. Documents / Payments Alerts

Add a compact attention section only when needed.

Examples:

Documents needed
2 files required for your active request

Payment pending
Invoice available for review

If there is no issue, avoid showing unnecessary empty warnings.

7. Recent Activity

Keep recent activity but make it cleaner.

Show:

Latest update
Time/status
Related service
Tap to open tracking

Avoid long empty activity blocks.

More / Settings Screen Direction

Use the polished settings style inspired by premium mobile apps.

Recommended structure:

Profile Header
Name
Email
Account status

Account
- Profile
- Notifications
- Documents
- Payments

Services
- My Requests
- Knowledge & News
- Support

General
- Settings
- Privacy Policy
- Terms & Conditions

Logout

Tile style:

White rounded group card
Soft icon capsule
Title
Optional subtitle
Chevron
Clean dividers
Logout separated and visually destructive
Inner Screens Navigation

Every inner screen should have a clear back option.

Rules:

Main tab screens do not need back button.
Pushed/detail screens must show back button.
Forms must show back/cancel clearly.
Long flows should show title + progress/context.

Examples:

Request Details
Service Form
Upload Documents
Payment Detail
Profile
Settings
Notifications
Knowledge Article

Use a shared OmcBackButton or OmcAppBar.

Page-by-Page Polish Workflow

Polish should happen one page at a time.

For each page:

Inspect existing UI and backend flow
Redesign UI using shared design system
Keep existing backend-connected logic intact
Run flutter analyze
Test page with backend
Fix UI/backend issues before moving to next page

Recommended order:

Design system base
Main shell + floating bottom nav
Home page
More / Settings page
Services catalogue
Service request details/forms
Documents
Payments
Support
Calculator
Notifications
Profile
Internal workspace pages
Backend Rule

UI polish must not break backend integration.

Production mode must remain backend-connected through Frappe APIs.

Mock/local data is allowed only when clearly isolated for testing and never as the main production path.

Animation Rule

Use light animations only.

Allowed:

Fade in
Small slide up
Press scale
Smooth tab switching
Subtle progress animation

Avoid:

Heavy Lottie usage everywhere
Slow transitions
Excessive animated backgrounds
Animations that delay work

Performance must stay smooth on normal Android devices and Flutter Web.

Home Page Final Recommendation

The Home page should be redesigned as:

SafeArea
  CustomScrollView
    PremiumHeader
    RedGradientHero
    SmartStatusScroller
    QuickActionLogoLauncher
    CurrentServiceProgressCard
    DocumentsPaymentsAlertCard
    RecentActivityCard

The current huge Quick Services grid should be replaced with compact logo/icon action tiles.

The default bottom navigation should be replaced with a custom floating pill nav.

Implementation Notes

Do not redesign the whole app in one large risky patch.

Start with:

Create shared UI polish files
Replace bottom nav
Redesign Home page only
Analyze and test
Then continue page-by-page

Each step should be small, reviewable, and easy to revert.


## Meri final recommendation

Haan, **cards ke bajaye premium logo/action launcher** better hai. Cards sirf wahan rakho jahan real content ho: active service, recent activity, payment alert, document alert.

Home ka top portion killer ban sakta hai:

```txt
Header
Hero
Stats
Quick logo actions
Current service progress
Recent activity