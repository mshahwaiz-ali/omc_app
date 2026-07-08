# OMC Tax Calculator — Premium Lightweight Backend-Controlled Plan

## Goal

Build a **premium but fast tax calculator** inside the OMC app.

The calculator should feel simple for users, but powerful for OMC because all important rules, slabs, content, CTAs, and guidance are controlled from **Frappe backend**.

The mobile app should not hardcode tax slabs or business rules.
The app should only render the calculator based on Frappe configuration and call backend APIs for calculation.

---

# 1. Core User Experience

## Default Mode: Simple Calculator

This should be the default experience for guests and customers.

The user should only see the minimum fields needed to calculate tax.

| Field         | User Sees? | Notes                                                                                      |
| ------------- | ---------: | ------------------------------------------------------------------------------------------ |
| Tax Year      |        Yes | Auto-selected from backend. Can be read-only or dropdown if multiple published years exist |
| Income Type   |        Yes | Salary / Business / Rental                                                                 |
| Income Mode   |        Yes | Monthly / Annual                                                                           |
| Income Amount |        Yes | Main input                                                                                 |
| Filer Status  |        Yes | Active Filer / Late Filer / Non-Filer                                                      |

This gives the user a clean and fast experience.

## Result Cards

After calculation, show clean result cards:

| Card                 | Example       |
| -------------------- | ------------- |
| Annual Income        | PKR 3,000,000 |
| Estimated Annual Tax | PKR 580,000   |
| Monthly Tax          | PKR 48,333    |
| Monthly Take-home    | PKR 201,667   |
| Effective Tax Rate   | 19.33%        |

Below the result cards, show small trust text:

* Based on OMC Tax Year 2026-27
* Verified from OMC configured slabs
* Estimate only. Final filing may require document review.

---

# 2. Advanced Mode

Advanced mode should be hidden under:

**Refine calculation**

The user should only open this if they need extra accuracy.

## Advanced Optional Fields

| Field                                  | Why Useful                                        |
| -------------------------------------- | ------------------------------------------------- |
| Bonus / additional annual income       | Salary users often need this                      |
| Other income                           | Rental, freelance, profit, or side income         |
| Deductible expenses                    | Useful for business and rental cases              |
| Tax already deducted                   | Salary/WHT adjustment                             |
| Zakat / donation / approved deductions | Optional deductions                               |
| Province / city                        | Useful for future provincial/service tax handling |
| Business turnover                      | Business users                                    |
| Rental annual income                   | Rental-specific flow                              |
| Withholding tax paid                   | Common Pakistan tax scenario                      |

## Important Rule

Advanced fields must be **dynamic by income type**.

Examples:

* Salary user should see salary-related fields only.
* Business user should see business turnover, expenses, and WHT fields.
* Rental user should see rental income, deductions, and WHT fields.
* Guest should never feel overwhelmed.

---

# 3. Premium Features

## A. Tax Health Score

After calculation, show a friendly readiness score.

Example:

**Tax readiness: Medium**

Reason:
You have an estimated tax liability, but income proof or tax deduction certificate has not been uploaded yet.

## Backend-Controlled Health Factors

Frappe settings can control factors such as:

* Missing NTN
* Non-filer status
* Tax payable above threshold
* No prior return
* No documents uploaded
* Business income present
* Rental income present
* Tax already deducted but no certificate uploaded

This is useful because it helps convert calculator users into OMC service customers.

---

## B. Recommended Next Steps

Instead of only showing numbers, the result should guide the user.

Example:

**Recommended next steps:**

1. Verify your filer status.
2. Keep salary certificate or bank statement ready.
3. Start OMC Tax Filing service before the deadline.

These next steps should be maintained from Frappe, not hardcoded in the app.

---

## C. Compare Filer vs Non-Filer

This is very useful for Pakistan users.

Show a clean comparison when rules are configured in backend.

| Scenario            | Estimated Tax |
| ------------------- | ------------: |
| Active Filer        |         PKR X |
| Non-Filer           |         PKR Y |
| Possible Difference |         PKR Z |

This can become a strong conversion point:

**Become an active filer with OMC.**

---

## D. Monthly Take-home Planner

For salary users, show:

| Item                  |     Example |
| --------------------- | ----------: |
| Monthly Income        | PKR 250,000 |
| Estimated Monthly Tax |  PKR 48,333 |
| Estimated Take-home   | PKR 201,667 |

This is simple, useful, and premium-looking.

---

## E. Download / Share Estimate

For logged-in users:

* Save as PDF
* Share with OMC consultant
* Attach to tax service request

For guests:

**Create account to save this estimate**

---

## F. Start Service from Result

The result screen should have a strong CTA.

Example:

**Need OMC to verify and file this?**
**Start Tax Filing Service**

Behavior:

### Guest User

If guest taps CTA:

* Send to login/signup
* Or show lead form if enabled from backend

### Approved Customer

If approved customer taps CTA:

* Create service request
* Pre-fill income estimate
* Link calculation log
* Attach result summary to request

---

## G. Admin-Controlled Content Blocks

OMC staff should be able to control calculator content from Frappe.

Backend-controlled content:

* Calculator disclaimer
* Tax year note
* Filing deadline alert
* Required documents list
* CTA title and button
* Linked service
* Educational tips
* Result insight cards
* Warning messages
* Verified/unverified source badge

This keeps the app dynamic without requiring a mobile app release.

---

# 4. Frappe Backend Design

## Required DocTypes

---

## 1. OMC Tax Calculator Settings

Single DocType.

Controls the calculator globally.

| Field                       | Type               |
| --------------------------- | ------------------ |
| calculator_enabled          | Check              |
| allow_guest_calculation     | Check              |
| default_tax_year            | Link: OMC Tax Year |
| show_advanced_mode          | Check              |
| show_breakdown              | Check              |
| show_filer_comparison       | Check              |
| show_tax_health_score       | Check              |
| allow_pdf_for_guest         | Check              |
| save_logged_in_calculations | Check              |
| result_disclaimer           | Text Editor        |
| guest_cta_title             | Data               |
| guest_cta_button            | Data               |
| customer_cta_title          | Data               |
| customer_cta_service        | Link: OMC Service  |
| verified_badge_label        | Data               |
| filing_deadline_alert       | Text Editor        |

---

## 2. OMC Tax Year

Parent yearly configuration.

| Field            | Type                                 |
| ---------------- | ------------------------------------ |
| tax_year         | Data                                 |
| title            | Data                                 |
| country          | Data                                 |
| currency         | Data                                 |
| effective_from   | Date                                 |
| effective_to     | Date                                 |
| status           | Select: Draft / Published / Archived |
| is_active        | Check                                |
| source_reference | Data                                 |
| last_verified_on | Date                                 |
| public_note      | Text Editor                          |

Purpose:

* Maintain tax year separately
* Allow future tax years without app release
* Keep old years archived
* Let admin publish only verified years

---

## 3. OMC Tax Slab

Child table under OMC Tax Year.

| Field         | Type                                          |
| ------------- | --------------------------------------------- |
| income_type   | Select: Salary / Business / Rental            |
| filer_status  | Select: Active Filer / Late Filer / Non-Filer |
| taxpayer_type | Select                                        |
| from_amount   | Currency                                      |
| to_amount     | Currency                                      |
| fixed_tax     | Currency                                      |
| rate_percent  | Percent                                       |
| amount_over   | Currency                                      |
| sort_order    | Int                                           |
| label         | Data                                          |

Purpose:

* Supports Pakistan-style slabs
* Supports fixed tax + percentage over threshold
* Supports filer and non-filer variations
* Supports income-type specific rules

Formula example:

**Tax = fixed_tax + ((taxable_income - amount_over) × rate_percent)**

---

## 4. OMC Tax Input Field

This makes the calculator flexible and premium.

Instead of hardcoding advanced fields in Flutter, backend sends field schema.

| Field         | Type                                     |
| ------------- | ---------------------------------------- |
| field_key     | Data                                     |
| label         | Data                                     |
| input_type    | Select: Number / Select / Toggle / Text  |
| income_type   | Select: Salary / Business / Rental / All |
| mode          | Select: Simple / Advanced                |
| is_required   | Check                                    |
| default_value | Data                                     |
| options_json  | Code                                     |
| help_text     | Small Text                               |
| sort_order    | Int                                      |
| is_active     | Check                                    |

Example:

| Field       | Value                            |
| ----------- | -------------------------------- |
| field_key   | bonus_income                     |
| label       | Bonus / additional annual income |
| income_type | Salary                           |
| mode        | Advanced                         |
| input_type  | Number                           |

The app renders fields dynamically based on:

* selected tax year
* income type
* simple or advanced mode
* active backend fields

---

## 5. OMC Tax Adjustment Rule

Used for deductions, additions, and credits.

| Field            | Type                                    |
| ---------------- | --------------------------------------- |
| tax_year         | Link: OMC Tax Year                      |
| income_type      | Select                                  |
| adjustment_key   | Data                                    |
| label            | Data                                    |
| adjustment_type  | Select: Add / Deduct / Credit           |
| calculation_type | Select: User Input / Fixed / Percentage |
| max_amount       | Currency                                |
| rate_percent     | Percent                                 |
| is_active        | Check                                   |

Purpose:

* Bonus can be added
* Expenses can be deducted
* Tax already deducted can be treated as credit
* WHT can be adjusted
* Admin can manage supported adjustments from Frappe

---

## 6. OMC Tax Result Insight

Used for premium advice cards and next steps.

| Field          | Type                                      |
| -------------- | ----------------------------------------- |
| tax_year       | Link: OMC Tax Year                        |
| condition_type | Select                                    |
| min_income     | Currency                                  |
| max_income     | Currency                                  |
| filer_status   | Select                                    |
| income_type    | Select                                    |
| severity       | Select: Low / Medium / High               |
| title          | Data                                      |
| message        | Text                                      |
| action_label   | Data                                      |
| action_type    | Select: Service / Article / Signup / None |
| linked_service | Link: OMC Service                         |
| linked_article | Link                                      |
| is_active      | Check                                     |

Example:

**Title:** Filing recommended
**Message:** Your annual income is above the taxable threshold. OMC can help verify your return.
**Action:** Start Tax Filing

---

## 7. OMC Tax Calculation Log

For logged-in users.

| Field                  | Type                                       |
| ---------------------- | ------------------------------------------ |
| user                   | Link: User                                 |
| customer               | Link: OMC Customer                         |
| tax_year               | Link: OMC Tax Year                         |
| income_type            | Select                                     |
| filer_status           | Select                                     |
| input_json             | Code                                       |
| result_json            | Code                                       |
| yearly_income          | Currency                                   |
| yearly_tax             | Currency                                   |
| monthly_tax            | Currency                                   |
| effective_tax_rate     | Percent                                    |
| source                 | Select: Guest / Customer / Service Request |
| created_from_app       | Check                                      |
| linked_service_request | Link: OMC Service Request                  |

Purpose:

* Save customer calculations
* Attach estimate to service request
* Allow OMC consultant to view estimate context
* Build calculation history later if needed

---

# 5. Mobile UI Design

## Screen Top

Title:

**Tax Calculator**

Subtitle:

**Estimate your tax using OMC configured tax rules.**

Small badge:

**Tax Year 2026-27 · PKR · Verified slabs**

---

## Input Card

Default simple mode:

### Income Type

Segmented selector:

* Salary
* Business
* Rental

### Income Mode

Segmented selector:

* Monthly
* Annual

### Amount

Input:

**PKR 250,000**

### Filer Status

Segmented selector:

* Active Filer
* Late Filer
* Non-Filer

Button:

**Calculate Tax**

---

## Advanced Section

Collapsed by default:

**+ Refine calculation**

When opened, show only fields relevant to selected income type.

Examples:

### Salary

* Bonus / additional annual income
* Tax already deducted
* Other income
* Approved deductions

### Business

* Business turnover
* Deductible expenses
* WHT paid
* Other income

### Rental

* Rental annual income
* Property-related deductions
* WHT paid
* Other income

---

# 6. Result UI

## Main Result Card

Show the strongest number first.

**Estimated Annual Tax**
**PKR 580,000**

Then smaller cards:

| Label             |         Value |
| ----------------- | ------------: |
| Annual Income     | PKR 3,000,000 |
| Monthly Tax       |    PKR 48,333 |
| Monthly Take-home |   PKR 201,667 |
| Effective Rate    |        19.33% |

---

## Breakdown Card

Show only if enabled from backend.

Example:

| Item                   |                         Value |
| ---------------------- | ----------------------------: |
| Slab Used              | PKR 2,400,000 – PKR 3,600,000 |
| Fixed Tax              |                         PKR X |
| Rate                   |                            X% |
| Amount Above Threshold |                         PKR X |
| Tax Before Credits     |                         PKR X |
| Tax Credits            |                         PKR X |
| Final Estimated Tax    |                         PKR X |

---

## Filer Comparison Card

Show only if enabled and backend has comparison rules.

| Scenario            | Estimated Tax |
| ------------------- | ------------: |
| Active Filer        |         PKR X |
| Non-Filer           |         PKR Y |
| Possible Difference |         PKR Z |

CTA:

**File your return and improve filer status with OMC**

---

## Tax Health Card

Show only if enabled.

Example:

**Tax Readiness: Medium**

Reason:

You have an estimated tax liability, but income proof or tax deduction certificate is missing.

Possible statuses:

* Low
* Medium
* High

---

## Recommended Next Steps

Backend-controlled next steps.

Example:

1. Verify your filer status.
2. Keep salary certificate or bank statement ready.
3. Start OMC Tax Filing service before the deadline.

---

## CTA Card

For guest:

**Want to save this estimate?**
**Create account**

For customer:

**Need OMC to verify and file this?**
**Start Tax Filing Service**

---

# 7. Backend API Endpoints

## 1. Get Calculator Config

Endpoint:

```text
omc_app.api.tax_calculator.get_tax_calculator_config
```

Returns:

```json
{
  "enabled": true,
  "active_tax_year": {
    "name": "2026-2027",
    "title": "Tax Year 2026-27",
    "currency": "PKR",
    "verified": true,
    "last_verified_on": "2026-07-01",
    "public_note": "Based on OMC configured slabs."
  },
  "income_types": ["salary", "business", "rental"],
  "filer_status_options": [
    "active_filer",
    "late_filer",
    "non_filer"
  ],
  "simple_fields": [],
  "advanced_fields": [
    {
      "field_key": "bonus_income",
      "label": "Bonus / additional annual income",
      "input_type": "number",
      "income_type": "salary",
      "is_required": false,
      "help_text": "Add annual bonus if applicable."
    }
  ],
  "settings": {
    "show_advanced_mode": true,
    "show_breakdown": true,
    "show_filer_comparison": true,
    "show_tax_health_score": true
  },
  "disclaimer": "Estimate only. Final filing may require document review.",
  "cta": {
    "guest_title": "Create account to save this estimate",
    "guest_button": "Create Account",
    "customer_title": "Need OMC to verify and file this?",
    "customer_button": "Start Tax Filing Service"
  }
}
```

---

## 2. Calculate Tax

Endpoint:

```text
omc_app.api.tax_calculator.calculate_tax
```

Accepts:

```json
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
```

Returns:

```json
{
  "annual_income": 3100000,
  "taxable_income": 3100000,
  "estimated_annual_tax": 580000,
  "monthly_tax": 48333,
  "monthly_take_home": 201667,
  "effective_tax_rate": 18.71,
  "breakdown": {
    "slab_label": "PKR 2,400,000 - PKR 3,600,000",
    "fixed_tax": 0,
    "rate_percent": 0,
    "amount_over": 0,
    "tax_before_credits": 630000,
    "credits": 50000,
    "final_tax": 580000
  },
  "comparison": {
    "active_filer_tax": 580000,
    "non_filer_tax": 700000,
    "possible_difference": 120000
  },
  "tax_health": {
    "score": "Medium",
    "reason": "You have estimated liability but no income proof or deduction certificate uploaded."
  },
  "insights": [
    {
      "severity": "Medium",
      "title": "Filing recommended",
      "message": "Your annual income is above the taxable threshold.",
      "action_label": "Start Tax Filing",
      "action_type": "Service"
    }
  ],
  "source": {
    "tax_year": "Tax Year 2026-27",
    "verified": true,
    "last_verified_on": "2026-07-01"
  },
  "cta": {
    "title": "Need OMC to verify and file this?",
    "button": "Start Tax Filing Service",
    "linked_service": "Tax Filing"
  }
}
```

---

## 3. Start Service from Calculation

Endpoint:

```text
omc_app.api.tax_calculator.start_service_from_calculation
```

Purpose:

* Create OMC Service Request
* Link tax calculation log
* Pre-fill estimate data
* Attach calculation summary for consultant/admin review

Accepts:

```json
{
  "calculation_log": "OMC-TAX-LOG-0001",
  "service": "Tax Filing"
}
```

Returns:

```json
{
  "service_request": "OMC-SR-0001",
  "message": "Tax filing service request created successfully."
}
```

---

# 8. Calculation Engine Rules

## Backend Formula Flow

1. Get active/published tax year.
2. Validate calculator is enabled.
3. Convert income to annual amount.
4. Apply advanced income additions.
5. Apply deductions.
6. Find matching slab by:

   * tax year
   * income type
   * filer status
   * taxable income range
7. Calculate tax:

   * fixed tax
   * plus percentage over threshold
8. Apply credits:

   * tax already deducted
   * WHT paid
9. Calculate:

   * annual tax
   * monthly tax
   * take-home
   * effective tax rate
10. Generate:

* breakdown
* comparison
* tax health score
* insights
* CTA

11. Save log only if logged-in user and setting is enabled.

---

# 9. Guest vs Customer Behavior

## Guest User

Guest can:

* Open calculator
* Enter basic values
* Use advanced fields if enabled
* View estimate
* View CTA
* Create account or login

Guest should not:

* Save calculation by default
* Create service request directly unless login/signup is completed
* Access calculation history

## Approved Customer

Customer can:

* Calculate tax
* Save estimate if enabled
* Start tax filing service
* Attach calculation to service request
* Share estimate with OMC consultant
* View previous estimates if calculation history is enabled

---

# 10. Admin Experience in Frappe

OMC admin should be able to:

* Enable/disable calculator
* Select default tax year
* Publish/archive tax years
* Add or update tax slabs
* Control simple/advanced fields
* Control filer status options
* Control disclaimers
* Control CTA text
* Link CTA to OMC service
* Add result insights
* Control next steps
* Update filing deadline alert
* Enable/disable comparison
* Enable/disable tax health score
* Review logged-in calculation logs

No mobile app update should be required for normal tax rule/content changes.

---

# 11. Best Final Feature Set

| Feature                             | Priority |
| ----------------------------------- | -------- |
| Simple guest calculator             | Must     |
| Frappe-managed tax years/slabs      | Must     |
| Monthly/annual income mode          | Must     |
| Income type-specific fields         | Must     |
| Filer status                        | Must     |
| Verified tax year badge             | Must     |
| Backend calculation engine          | Must     |
| Breakdown card                      | Must     |
| CTA to tax filing service           | Must     |
| Admin-controlled disclaimer/content | Must     |
| Dynamic advanced fields             | Must     |
| Recommended next steps              | Must     |
| Start service from result           | Must     |
| Logged-in calculation log           | Must     |
| Filer vs non-filer comparison       | Should   |
| Tax health score                    | Should   |
| Download/share estimate             | Should   |
| Required documents suggestion       | Should   |
| Calculation history                 | Should   |

---

# 12. Final Recommended Build

## Build It Like This

### User Side

Guest opens calculator:

1. Select income type
2. Select monthly or annual
3. Enter amount
4. Select filer status
5. Tap calculate
6. See clean result
7. See CTA to start OMC service

### Admin Side

OMC staff opens Frappe:

1. Configure tax year
2. Add slabs
3. Configure fields
4. Configure disclaimer
5. Configure CTA
6. Configure result insights
7. App follows instantly

### Backend Side

* No hardcoded slabs in Flutter
* No hardcoded tax rules in Flutter
* Backend owns formula engine
* Frappe owns data, rules, content, CTAs, and visibility settings

### Premium Feel

Add:

* Verified tax year badge
* Clean result cards
* Smart breakdown
* Monthly take-home
* Filer comparison
* Tax health score
* Recommended next steps
* Start service from result
* Dynamic backend content

---

# 13. Implementation Order

## Phase 1 — Backend Foundation

1. Create Frappe DocTypes:

   * OMC Tax Calculator Settings
   * OMC Tax Year
   * OMC Tax Slab
   * OMC Tax Input Field
   * OMC Tax Adjustment Rule
   * OMC Tax Result Insight
   * OMC Tax Calculation Log

2. Add calculation API:

   * get_tax_calculator_config
   * calculate_tax
   * start_service_from_calculation

3. Add backend formula engine:

   * annualization
   * slab matching
   * deductions/additions
   * credits
   * result breakdown
   * insights
   * CTA
   * optional calculation log

---

## Phase 2 — Mobile Calculator UI

1. Add Tax Calculator screen.
2. Fetch backend config.
3. Render simple fields.
4. Render advanced fields dynamically.
5. Call calculate API.
6. Show result cards.
7. Show breakdown.
8. Show disclaimer.
9. Show CTA.

---

## Phase 3 — Service Conversion

1. If guest taps CTA:

   * login/signup flow

2. If approved customer taps CTA:

   * create service request
   * pre-fill estimate
   * link calculation log

3. Show success state:

   * “Tax Filing service request created successfully.”

---

# 14. Final Product Direction

The OMC Tax Calculator should not be just a number tool.

It should be a **conversion feature**.

It gives the user:

* Quick estimate
* Clear tax picture
* Take-home understanding
* Filer/non-filer awareness
* Next steps
* Direct OMC service path

It gives OMC:

* Backend-controlled tax rules
* No app release needed for slab updates
* Service lead generation
* Customer calculation logs
* Consultant-ready estimate context
* Premium app experience without heavy UI complexity

Final approach:

**Simple for user. Powerful from backend. Fully controlled from Frappe. Fast to use. Easy to maintain.**
