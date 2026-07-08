Premium but not heavy: recommended feature set
1. Simple Calculator Mode

This should be default.

Fields
Field	User sees?	Notes
Tax Year	Yes, auto-selected	Read-only or dropdown
Income Type	Yes	Salary / Business / Rental
Income Mode	Yes	Monthly / Annual
Income Amount	Yes	Main input
Filer Status	Yes	Active Filer / Late Filer / Non-Filer

This is enough for guest.

Result

Show clean cards:

Card	Example
Annual Income	PKR 3,000,000
Estimated Annual Tax	PKR 580,000
Monthly Tax	PKR 48,333
Monthly Take-home	PKR 201,667
Effective Tax Rate	19.33%

Then below:

Based on OMC Tax Year 2026-27
Verified from OMC configured slabs
Estimate only, final filing may require document review
2. Advanced Mode

Hidden under:

Refine calculation

User taps only if needed.

Advanced optional fields
Field	Why useful
Bonus / additional annual income	Salary users often need this
Other income	Rental, freelance, profit
Deductible expenses	Business/rental cases
Tax already deducted	Salary/WHT adjustment
Zakat / donation / approved deductions	Optional
Province / city	Later useful for provincial/service taxes
Business turnover	For business users later
Rental annual income	Rental-specific flow
Withholding tax paid	Common Pakistan scenario

Important: advanced fields should be dynamic. Salary user should not see business turnover fields. Rental user should not see salary bonus fields.

Killer premium features we can add
A. “Tax Health Score”

After calculation, app gives a friendly score:

Tax readiness: Medium
Reason: You have estimated liability but have not uploaded income proof or tax deduction certificate.

This is very premium and useful.

Backend configurable factors

From Frappe Settings:

Missing NTN?
Non-filer?
Tax payable above threshold?
No prior return?
No documents uploaded?
Has business income?

This can drive OMC service conversion.

B. “What should I do next?”

Instead of only showing numbers, result should show action items.

Example:

Recommended next steps:
1. Verify your filer status.
2. Keep salary certificate / bank statement ready.
3. Start OMC Tax Filing service before deadline.

Admin can maintain these from Frappe.

C. “Compare Filer vs Non-Filer”

Very useful in Pakistan context.

Result can show:

Scenario	Estimated Tax
Active Filer	PKR X
Non-Filer	PKR Y
Possible Difference	PKR Z

But only if backend has rules configured.

This becomes a strong conversion feature:

Become active filer / file return with OMC.

D. “Monthly Take-home Planner”

For salary users:

Monthly Income: PKR 250,000
Estimated Monthly Tax: PKR 48,333
Estimated Take-home: PKR 201,667

This is simple but premium-looking.

E. “Download / Share Estimate”

For logged-in users:

Save as PDF
Share with OMC consultant
Attach to tax service request

For guest:

“Create account to save this estimate”
F. “Start Service from Result”

CTA should be powerful:

Need OMC to verify and file this?
[Start Tax Filing Service]

If guest taps:

Login/signup
Or lead form

If approved customer taps:

Create service request
Pre-fill income estimate
Link calculation log
G. “Admin-controlled content blocks”

From Frappe, OMC team can maintain:

Calculator disclaimer
Tax year note
Filing deadline alert
Required documents list
CTA service
Educational tips

This keeps app dynamic without app release.

Backend/Frappe design for this premium version
Required DocTypes
1. OMC Tax Calculator Settings

Single doctype.

Fields:

Field	Type
calculator_enabled	Check
allow_guest_calculation	Check
default_tax_year	Link
show_advanced_mode	Check
show_breakdown	Check
show_filer_comparison	Check
show_tax_health_score	Check
allow_pdf_for_guest	Check
save_logged_in_calculations	Check
result_disclaimer	Text Editor
guest_cta_title	Data
guest_cta_button	Data
customer_cta_title	Data
customer_cta_service	Link OMC Service
2. OMC Tax Year

Parent yearly config.

Fields:

Field	Type
tax_year	Data
title	Data
country	Data
currency	Data
effective_from	Date
effective_to	Date
status	Draft / Published / Archived
is_active	Check
source_reference	Data
last_verified_on	Date
public_note	Text Editor
3. OMC Tax Slab

Child table.

Fields:

Field	Type
income_type	Select
filer_status	Select
taxpayer_type	Select
from_amount	Currency
to_amount	Currency
fixed_tax	Currency
rate_percent	Percent
amount_over	Currency
sort_order	Int
label	Data

This supports Pakistan-style slabs properly.

4. OMC Tax Input Field

This is what makes it premium and configurable.

Instead of hardcoding advanced fields in app, backend sends field schema.

Fields:

Field	Type
field_key	Data
label	Data
input_type	Select: Number / Select / Toggle
income_type	Select
mode	Simple / Advanced
is_required	Check
default_value	Data
help_text	Small Text
sort_order	Int
is_active	Check

Example:

bonus_income
Label: Bonus / additional annual income
Income Type: Salary
Mode: Advanced

App renders fields dynamically.

5. OMC Tax Adjustment Rule

For deductions/additions.

Fields:

Field	Type
tax_year	Link
income_type	Select
adjustment_key	Data
label	Data
adjustment_type	Add / Deduct / Credit
calculation_type	User Input / Fixed / Percentage
max_amount	Currency
rate_percent	Percent
is_active	Check

This lets admin maintain advanced logic without code changes.

6. OMC Tax Result Insight

For premium advice cards.

Fields:

Field	Type
tax_year	Link
condition_type	Select
min_income	Currency
max_income	Currency
filer_status	Select
income_type	Select
severity	Low / Medium / High
title	Data
message	Text
action_label	Data
action_type	Service / Article / Signup
linked_service	Link
linked_article	Link
is_active	Check

Example:

Title: Filing recommended
Message: Your annual income is above the taxable threshold. OMC can help verify your return.
Action: Start Tax Filing
7. OMC Tax Calculation Log

For logged-in users only.

Fields:

Field	Type
user	Link User
customer	Link OMC Customer
tax_year	Link
income_type	Select
filer_status	Select
input_json	Code
result_json	Code
yearly_income	Currency
yearly_tax	Currency
source	Select
created_from_app	Check
Mobile UI design
Screen layout
Top
Tax Calculator
Estimate your tax using OMC configured tax rules.

Show small badge:

Tax Year 2026-27 · PKR · Verified slabs
Input card

Default simple mode:

Income Type
[Salary] [Business] [Rental]

Income
[Monthly] [Annual]

Amount
[PKR 250,000]

Filer Status
[Active Filer] [Late Filer] [Non-Filer]

[Calculate Tax]

Advanced collapsed:

+ Refine calculation
Result card
Estimated Annual Tax
PKR 580,000

Monthly Tax
PKR 48,333

Take-home / month
PKR 201,667

Effective rate
19.33%
Premium sections
Breakdown
Slab used
Fixed tax
Percentage
Amount above threshold
Comparison
Active filer vs non-filer
Tax health
Low / Medium / High readiness
Next steps
Documents needed
Filing recommendation
CTA
Important: keep it light for user
Do not show everything at once

Default should be only:

Income type
Monthly/annual
Amount
Filer status
Calculate

Everything else hidden under Refine calculation.

That gives premium depth without making it boring.

Backend API endpoints
1. Get config
omc_app.api.tax_calculator.get_tax_calculator_config

Returns:

active tax year
enabled income types
filer status options
dynamic fields
settings
disclaimer
2. Calculate
omc_app.api.tax_calculator.calculate_tax

Accepts:

{
  "tax_year": "2026-2027",
  "income_type": "salary",
  "income_mode": "monthly",
  "income_amount": 250000,
  "filer_status": "active_filer",
  "advanced_inputs": {
    "bonus_income": 100000,
    "tax_already_deducted": 50000
  }
}

Returns:

result numbers
breakdown
comparison
insights
CTA
source/verified status
Recommended v1 vs later
Build now — v1 premium

This is enough and not too heavy:

Tax Year DocType
Tax Slab child table
Tax Calculator Settings
Dynamic input fields
Backend calculation from Frappe
Simple + Advanced UI
Breakdown
CTA
No guest data save
Logged-in save optional
Later — v2
PDF estimate
Filer vs non-filer comparison
Tax health score
Required documents auto-suggest
Calculation history
Consultant review flow
WhatsApp/share estimate
Final best plan
We should build it like this
User experience

Guest opens calculator → 4 fields → result → CTA.

Admin experience

OMC staff opens Frappe → updates Tax Year/slabs/settings → app instantly follows.

Backend

No hardcoded slabs. Code only knows formula engine. Rules live in Frappe.

Premium feel

Add:

Verified tax year badge
Smart breakdown
Take-home income
Filer status comparison later
Recommended next steps
Start service from result
My recommended final feature list for OMC
Feature	Priority
Simple guest calculator	Must
Frappe-managed tax years/slabs	Must
Monthly/annual income mode	Must
Income type-specific fields	Must
Filer status	Must
Verified/unverified source badge	Must
Breakdown card	Must
CTA to tax filing service	Must
Advanced refine fields	Should
Logged-in calculation history	Later
PDF estimate	Later
Filer vs non-filer comparison	Later
Tax health score	Later