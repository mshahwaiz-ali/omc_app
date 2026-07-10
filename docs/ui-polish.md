Module color = what area it belongs to

Examples:

Tax / Calculator / NTN / GST → same blue family
Payments / Receipts → green family
Documents → indigo / sky family
Services / Cases → brand red or rose family
Track / Progress → teal family
Leads → purple family
Tasks → orange family
Notifications → slate / violet family
State color = what is happening

This is separate from module color:

Open → blue
Under review → teal
Action needed → amber
Completed → green
Pending → purple
Blocked / rejected → red



OMC Home Screen Design README

This document preserves the styling, layout, and role-based decisions used for the OMC home screen. It is the reference for keeping future screens visually consistent.

1) Core design goal

Build a clean, premium, executive-style dashboard.

The home screen should feel:

calm
structured
lightweight
trustworthy
business-focused

The visual language should never feel heavy, crowded, or too playful.

2) Role model

There are 3 user modes:

Internal

Internal users see the operational workspace.

They should get:

review-focused quick actions
internal summary cards
queue / ops language
higher-density information
lead, task, document, and payment review surfaces
Customer

Approved customers see the customer dashboard.

They should get:

service tracking
document upload/review access
payment access
notifications
tax calculator
service progress cards
recent activity feed
Guest

Guests share the same screen structure as customers, but with restrictions.

Guests should:

see the same main layout
see locked or limited actions where needed
have a limited summary state
be encouraged to sign up or complete profile

Guest and customer should not become separate visual systems. The structure stays the same; only access changes.

3) Layout hierarchy

The home screen should follow this order:

Header
Search bar
Access banner / status banner
Quick Actions
Summary cards
CTA / completion card
Services in progress
Recent activity
Bottom navigation

Keep this order stable.

4) Header rules

Header should contain:

greeting line
large user name
notifications button
avatar

Style rules:

greeting is small and muted
name is bold and dominant
avatar is circular
notification button is compact
spacing must stay airy

Do not overcrowd the top row.

5) Search bar rules

The search bar should feel like a soft card.

Use:

rounded corners
subtle shadow
light border
search icon on the left
filter/tune icon on the right
muted placeholder text

The search bar should look tappable even if it is not a full search flow yet.

6) Banner rules

Banner is role-aware.

Customer / guest

Use banner copy such as:

profile under review
guest access
limited access
Internal

Use workspace / operations wording.

Banner style:

left icon badge
concise title
short supporting text
one clear primary action
soft card layout

Do not make the banner visually louder than the summary cards.

7) Quick actions rules

Quick actions are a key visual system.

Current pattern

Use compact tiles with:

icon
label
optional lock state
Styling direction

The more premium version uses:

smaller outer card footprint
minimal spacing
icon-first emphasis
short labels
consistent tile size
controlled color families
Customer / guest quick actions

Recommended customer set:

Services
Documents
Payments
Track
Tax Calc
More

Guest sees the same structure, but some tiles can be locked or visually reduced.

Internal quick actions

Recommended internal set:

Review Docs
Review Payments
Customers
Leads
Tasks
More
8) Color system

Color should communicate function and family.

Use one family color per domain.

Suggested families
Tax / calculator / NTN: blue
Payments / receipt / invoice: green
Documents: indigo
Services / case work: rose-red
Track / progress / review: teal
Leads: purple
Tasks: orange
Notifications: slate / neutral
Color rule

The same family color should be reused consistently across the app.

Example:

payment-related items always reuse payment green
document-related items always reuse document indigo
tax-related items always reuse tax blue

Do not randomize colors per screen.

9) Status color rules

Status should be readable at a glance.

Use these rules:

Open / active: rose or primary brand tone
In progress: blue
Under review: green or calm active tone
Pending: orange
Rejected / blocked: red
Completed: green

Status pills should always stay compact.

10) Summary card rules

Summary cards are mini dashboard metrics.

They should have:

uniform size
strong number hierarchy
small colored icon badge
tiny trend accent or micro-line
soft border
gentle shadow

Each card should be easy to scan in under one second.

Customer summary cards

Examples:

Active Services
Documents
Payments
Notifications
Internal summary cards

Examples:

Open Leads
Customers
Tasks
Payments
11) CTA / completion card rules

Use a mid-screen CTA card between summary and service list.

This card should:

explain a next step
have one primary action
feel promotional but not noisy
use a rounded and soft layout

Examples:

Complete your profile
Create your account
Open internal workspace
12) Services in progress rules

Service cards should show:

service title
customer name or case owner
status pill
progress bar
percent complete
arrow / chevron for navigation
Progress bar behavior

Use a deliberate progression:

low progress: brown / amber start
mid progress: yellow / orange
high progress: green
rejected / blocked: red

This gives the bar meaning instead of a flat single color.

13) Recent activity rules

Recent activity is a feed, not a list of random items.

Each item should show:

icon badge
title
short explanation
timestamp
family color dot or marker
Activity family matching

The activity should inherit the family color of the subject it refers to.

Examples:

payment receipt submitted → payment green
document uploaded → document indigo
service review event → service / track family
tax-related event → tax blue

If the item is linked to a service, prefer the service family color.

14) Lock state rules

Locked items must still be understandable.

Locked state should:

remain visible
look muted or dimmed
show a lock indicator if needed
avoid confusing the user

Do not fully hide useful navigation unless the feature truly must not appear.

15) Backend-driven design rules

Prefer backend control for:

color family
service status
progress
visibility / lock state
action labels
review state

This keeps the UI consistent and reduces hardcoded visual logic.

Important backend fields

Use backend data where possible for:

service family
status
customer name
progress
review state
unread counts
16) Spacing and feel

General spacing rules:

use generous horizontal padding
avoid dense blocks
keep card corners rounded
use subtle shadows
keep content aligned
let sections breathe

The app should feel premium even before adding animations.

17) Typography rules

Typography should follow this pattern:

greeting: small and muted
titles: bold and dark
labels: medium weight
helper text: smaller and soft
numeric values: very bold

Avoid too many font weights in one card.

18) Do / do not
Do
keep visual family colors consistent
keep guest and customer structure aligned
use internal vs customer mode clearly
make actions and statuses easy to scan
keep cards compact and premium
Do not
use random colors per widget
mix internal admin layout into customer dashboard
overfill quick actions
make progress bars flat and lifeless
create heavy, cluttered dashboards
19) Practical implementation note

When adding a new screen, ask these questions:

Is this internal, customer, or guest?
What family color should it inherit?
Is it a primary action, summary, or feed item?
Should it be locked, hidden, or visible-but-muted?
Does it belong before or after the CTA card?

If the answer is unclear, reuse the home screen pattern first.

20) Reference intent

This README is meant to preserve the decisions behind the current home redesign so the same design language can be reused on:

services
documents
payments
tracking
tax calculator
notifications
internal workspace

Keep the system consistent. Build variations on top of this base, not beside it.
