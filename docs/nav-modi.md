Premium Navigation Plan for OMC App
1. Bottom bar design
Shape

Use low-radius floating rectangle, not pill.

Border radius: 18–22 max
Height: 68–72
Horizontal margin: 14–16
Bottom margin: 8–12

No huge 32px pill radius. Current code uses BorderRadius.circular(32) in nav container, which is too much for your taste.

Visual style
Background: white / very light warm white
Border: subtle 1px
Shadow: soft, low blur
Selected item: small rectangular capsule, radius 12–14

No big bubble, no excessive glow.

Animation

Only subtle movement:

Selected icon moves up 2px
Label fades slightly
Selected background animates
Duration: 160–190ms
Curve: easeOutCubic

No bouncing, no large scaling.

2. Recommended bottom nav items
Universal bottom nav
Home    Services    +    Track    More

Why:

Home: landing dashboard.
Services: main business catalogue.
+: quick action based on user role.
Track: customer cases / internal cases.
More: compact modal menu.
Remove Docs from main bar

Docs are important, but not more important than quick actions. Docs should move into:

+ quick action for customers: Upload Document
More modal: Documents

This makes nav cleaner.

3. Role-based behavior
Guest

Bottom nav:

Home / Services / + / Track locked / More

Center + opens:

Tax Calculator
Expense Tracker
Support
Create Account

More modal:

Tax Calculator
Expense Tracker
Knowledge
Support
Login
Settings? optional

Track tap shows locked message.

Pending customer

Bottom nav:

Home / Services / + / Track locked or limited / More

Center + opens:

Tax Calculator
Expense Tracker
Support
Profile Status

More modal:

Tax Calculator
Expense Tracker
Knowledge
Support
Profile
Logout
Approved customer

Bottom nav:

Home / Services / + / Track / More

Center + opens:

New Service Request
Upload Document
Upload Payment Receipt
Support Ticket
Expense Entry

More modal:

Dashboard
Documents
Payments
Notifications
Tax Calculator
Expense Tracker
Budget
Knowledge
Support
Profile
Settings
Logout
Internal/Admin

Bottom nav:

Home / Workspace / + / Cases / More

But phase 1 mein universal bar hi rakhen. Sirf labels internally adapt kar sakte hain later.

Center + for internal:

New Task
Open Service Cases
Customers
Documents Review
Payments Review

More modal:

Internal Workspace
Service Cases
Customers
Documents Review
Payments
Leads
Tasks
Notifications
Settings
Logout
4. More behavior
Best idea: compact modal, not screen

When user taps More:

showModalBottomSheet

Sheet style:

Height: content-based, max 70% screen
Radius: top 20 only
Padding: 16
Grid: 4 columns
Small icons + labels

No big list tiles. No full screen.

Example layout:

[ Profile ] [ Docs ] [ Payments ] [ Alerts ]
[ Tax ]     [ Expense ] [ Support ] [ Settings ]
[ Logout ]

For internal:

[ Workspace ] [ Cases ] [ Customers ] [ Docs ]
[ Payments ]  [ Leads ] [ Tasks ]     [ Alerts ]
[ Settings ]  [ Logout ]
5. Center + behavior

Center button should not navigate directly. It should open Quick Actions modal.

Design:

Small raised square/circle hybrid
Size: 54x54
Radius: 18
Primary red background
White plus icon
Light shadow

Again: not giant circle, not too rounded.

Quick action modal:

Title: Quick actions
Grid/list compact
Role-based actions
6. Code architecture plan

Current main_shell.dart is too large because it contains:

Main shell
Bottom nav widget
More screen
More tiles/groups
Avatar/header
Badges

We should split it.

Recommended files:

lib/app/main_shell.dart
lib/app/navigation/omc_bottom_nav.dart
lib/app/navigation/omc_nav_item.dart
lib/app/navigation/omc_more_sheet.dart
lib/app/navigation/omc_quick_actions_sheet.dart
lib/app/navigation/omc_nav_models.dart

Keep business logic in main_shell.dart, UI components separate.

7. README section you can create

Use this as your README/design note:

# OMC App Navigation UX Plan

## Goal
Create a premium, lightweight bottom navigation system for OMC App with role-aware actions for Guest, Pending Customer, Approved Customer, and Internal/Admin users.

## Design Rules
- Use clean business-app styling, not playful/cartoon UI.
- Avoid excessive curves.
- Main surfaces should use 16–22 border radius maximum.
- Buttons and tiles should use 10–16 radius.
- Bottom nav should be floating but compact.
- Animations must be subtle and fast.
- No heavy transitions.
- More should open as a compact modal sheet, not a full screen tab.

## Bottom Navigation
Default nav:
Home / Services / Quick Action / Track / More

The center Quick Action button opens role-based shortcuts.

## More Menu
More opens a modal sheet with compact icon grid.
It should replace the current full-screen More tab over time.

## Role-Based Quick Actions

### Guest
- Tax Calculator
- Expense Tracker
- Support
- Create Account

### Pending Customer
- Tax Calculator
- Expense Tracker
- Support
- Profile Status

### Approved Customer
- New Service Request
- Upload Document
- Upload Payment Receipt
- Support Ticket
- Expense Entry

### Internal/Admin
- Workspace
- Service Cases
- Customers
- Documents Review
- Tasks

## Role-Based More Items

### Guest
- Tax Calculator
- Expense Tracker
- Knowledge
- Support
- Login

### Approved Customer
- Dashboard
- Documents
- Payments
- Notifications
- Tax Calculator
- Expense Tracker
- Budget
- Knowledge
- Support
- Profile
- Settings
- Logout

### Internal/Admin
- Internal Workspace
- Service Cases
- Customers
- Documents Review
- Payments
- Leads
- Tasks
- Notifications
- Settings
- Logout

## Implementation Phases

### Phase 1
Refactor navigation UI into separate files without changing app behavior.

### Phase 2
Replace More full-screen tab with modal sheet. Keep /more route as fallback.

### Phase 3
Add center Quick Action button and role-based actions.

### Phase 4
Polish animations, spacing, selected state, and dark mode.