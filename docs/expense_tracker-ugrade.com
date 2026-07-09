# OMC Tax-Ready Expense Tracker — Final Feature Plan

## 1. Product Vision

The Expense Tracker should become one of the strongest USP features of the OMC App.

It should not be only a generic expense tracker. It should become a **Tax-Ready Expense Tracker** that helps users:

* Track daily expenses quickly.
* Separate personal, business, and tax-relevant spending.
* Attach receipts.
* Generate monthly reports.
* Prepare tax/business summaries.
* Share data with an OMC consultant.
* Convert naturally into OMC services such as tax filing, bookkeeping, business registration, and financial advisory.

Core positioning:

> “Track your expenses today. Prepare your tax records automatically.”

---

# 2. User Access Behavior

## 2.1 Guest User

Guest users should be allowed to use a **Lite Local Tracker**.

Reason:

* Increases app usage.
* Gives value before signup.
* Builds habit.
* Converts users to OMC accounts.

Guest gets:

* Local-only expense tracking.
* 20–30 transaction limit.
* Basic income/expense categories.
* Current month summary.
* Basic JSON export.
* CTA card for account creation.

Guest does not get:

* Backend sync.
* Cloud backup.
* Receipt upload.
* PDF reports.
* Consultant sharing.
* Budget alerts.
* Frappe Desk visibility.

Guest CTA:

> “Create an OMC account to unlock cloud sync, backup, reports, receipts and tax-ready expense summaries.”

---

## 2.2 Pending Customer

Pending customer should keep the tracker unlocked in local mode.

Pending customer gets:

* Same features as guest.
* Local-only data.
* Upgrade banner.

Pending banner:

> “Sync will activate after your profile is approved.”

Pending customer does not get:

* Backend sync.
* Receipt upload.
* Consultant sharing.
* PDF report sharing.
* Cloud backup.

---

## 2.3 Approved Customer

Approved customer gets the full tracker.

Approved customer gets:

* Cloud sync.
* Local backup.
* Monthly PDF report.
* Receipt upload.
* Budget alerts.
* Tax/business expense tagging.
* Consultant sharing.
* Data visible in Frappe Desk.
* Tax-ready summaries.
* Business expense summaries.
* Smart service recommendations.

Approved customer upgrade flow:

When approved customer opens the tracker, if local entries exist:

> “Sync your local tracker with your OMC account?”

Options:

* Sync now.
* Keep local only.
* Decide later.

---

## 2.4 Internal User

Internal users should not use the personal tracker as a customer tool by default.

Recommended behavior:

* Hide personal tracker for internal users unless they also have a customer profile.
* Later, add a separate staff-only analytics/support view.

Internal future feature:

* View customer-shared reports.
* See tax-relevant summaries.
* Attach report to service case.
* Consultant notes.
* Follow-up recommendations.

---

# 3. USP Upgrade: OMC Tax-Ready Layer

This is the main difference between OMC and a normal expense app.

## 3.1 Tax-Ready Expense Tagging

Every expense can be marked as:

* Personal
* Business related
* Tax relevant
* Reimbursable
* Recurring

The user should not feel forced to fill too many fields. These should be optional advanced fields.

Simple labels:

* “Useful for tax”
* “Business expense”
* “Attach receipt”

---

## 3.2 OMC Smart Service Suggestions

The tracker should recommend OMC services based on user behavior.

Examples:

If user marks many business expenses:

> “You are tracking business expenses. Need bookkeeping support?”

If user marks tax-relevant expenses:

> “Your tax-ready expense summary is building up. Start tax filing with OMC?”

If user uploads many receipts:

> “Want OMC to organize these into a monthly report?”

If user has recurring rent/salary/business payments:

> “Need monthly bookkeeping or financial records management?”

These should appear as soft CTA cards, not annoying popups.

---

## 3.3 Consultant Sharing

Approved customers should be able to share:

* Monthly report.
* Tax-relevant expenses.
* Business expenses.
* Receipt vault.
* Summary note.

Sharing should create or attach to:

* Service Request.
* Support Ticket.
* Consultant Review item.
* Frappe Desk record.

Button examples:

* “Share with OMC Consultant”
* “Prepare for Tax Filing”
* “Attach to Service Request”

---

## 3.4 Tax Filing Readiness Score

Add a simple score that makes the feature feel premium.

Example:

**Tax Readiness: 72%**

Based on:

* Tax-relevant expenses tagged.
* Receipts attached.
* Business expenses categorized.
* Monthly summary generated.
* Income entries added.

Labels:

* Low
* Improving
* Good
* Ready for review

This should be simple calculated logic, not AI-heavy.

---

# 4. Backend Frappe Design

## 4.1 DocType: OMC Expense Entry

Purpose:

Stores synced approved-customer expense/income entries.

Fields:

| Field              | Type                      | Notes                                |
| ------------------ | ------------------------- | ------------------------------------ |
| user               | Link User                 | Owner/customer user                  |
| customer           | Link OMC Customer         | Optional but useful                  |
| transaction_type   | Select                    | Income / Expense                     |
| amount             | Currency                  | Required                             |
| category           | Link OMC Expense Category | Backend configurable                 |
| account            | Data                      | Cash, Bank, Wallet, etc.             |
| payment_method     | Select                    | Cash, Card, Bank Transfer, Wallet    |
| transaction_date   | Date                      | Required                             |
| merchant           | Data                      | Optional                             |
| note               | Small Text                | Optional                             |
| tax_relevant       | Check                     | For tax filing usage                 |
| business_related   | Check                     | For business customers               |
| recurring          | Check                     | Salary, rent, subscription           |
| reimbursable       | Check                     | Optional future use                  |
| receipt_file       | Attach                    | Approved customer only               |
| source             | Select                    | Mobile / Import / Desk               |
| sync_id            | Data                      | Unique mobile sync id                |
| status             | Select                    | Active / Archived                    |
| created_from_guest | Check                     | True if synced from local guest data |

Important backend rules:

* `sync_id` must be unique per user to prevent duplicate mobile sync.
* User can only access their own records.
* Internal roles can view only if permission allows or record is shared through consultant flow.
* Delete should preferably archive instead of hard delete.

---

## 4.2 DocType: OMC Expense Category

Purpose:

Backend-configurable categories used by Flutter.

Fields:

| Field            | Type   | Notes                     |
| ---------------- | ------ | ------------------------- |
| category_name    | Data   | Display name              |
| type             | Select | Income / Expense / Both   |
| icon             | Data   | Flutter icon key          |
| color            | Data   | Hex color or token        |
| is_default       | Check  | Default seeded category   |
| is_tax_relevant  | Check  | Suggested tax category    |
| business_default | Check  | Useful for business users |
| sort_order       | Int    | Display order             |
| enabled          | Check  | Hide/show category        |

Default categories:

Expense:

* Food
* Fuel
* Bills
* Rent
* Shopping
* Transport
* Health
* Education
* Business
* Tax / Legal
* Utilities
* Other

Income:

* Salary
* Business Income
* Freelance
* Rental Income
* Investment
* Other Income

---

## 4.3 DocType: OMC Expense Budget

Purpose:

Stores monthly budget limits.

Fields:

| Field           | Type                      | Notes                    |
| --------------- | ------------------------- | ------------------------ |
| user            | Link User                 | Owner                    |
| customer        | Link OMC Customer         | Optional                 |
| category        | Link OMC Expense Category | Optional category budget |
| month           | Date                      | Month start date         |
| limit_amount    | Currency                  | Budget limit             |
| alert_threshold | Percent                   | Example: 80%             |
| active          | Check                     | Enabled/disabled         |

Budget types:

* Overall monthly budget.
* Category budget.
* Business budget.
* Personal budget.

---

## 4.4 DocType: OMC Expense Report

Purpose:

Stores generated monthly reports.

Fields:

| Field                  | Type              | Notes                      |
| ---------------------- | ----------------- | -------------------------- |
| user                   | Link User         | Owner                      |
| customer               | Link OMC Customer | Optional                   |
| month                  | Date              | Report month               |
| total_income           | Currency          | Summary                    |
| total_expense          | Currency          | Summary                    |
| net_balance            | Currency          | Income - expense           |
| tax_relevant_total     | Currency          | Tax tagged total           |
| business_expense_total | Currency          | Business tagged total      |
| report_file            | Attach            | Generated PDF              |
| shared_with_consultant | Check             | True/false                 |
| linked_service_request | Link              | Optional                   |
| status                 | Select            | Draft / Generated / Shared |

This can be Phase 4 if we want to keep Phase 2 lighter.

---

# 5. Backend APIs

Existing Flutter expects these API names:

* `get_expense_categories`
* `get_expense_entries`
* `create_expense_entry`
* `update_expense_entry`
* `delete_expense_entry`
* `get_expense_summary`

We should implement these properly and add new APIs.

## 5.1 Required APIs

| API                                  | Purpose                                            |
| ------------------------------------ | -------------------------------------------------- |
| get_expense_config                   | Categories, limits, sync availability, guest rules |
| get_expense_categories               | Get enabled backend categories                     |
| get_expense_entries                  | Paginated transaction list                         |
| create_expense_entry                 | Create one entry                                   |
| bulk_sync_expense_entries            | Upload guest/pending local entries after approval  |
| update_expense_entry                 | Edit transaction                                   |
| delete_expense_entry                 | Archive/delete transaction                         |
| get_expense_summary                  | Monthly stats, category totals, trends             |
| upload_expense_receipt               | Attach receipt                                     |
| get_expense_budgets                  | List budgets                                       |
| save_expense_budget                  | Create/update budget                               |
| generate_expense_report              | Create monthly PDF report                          |
| share_expense_report_with_consultant | Attach report to consultant/service flow           |

---

## 5.2 API Access Rules

Guest:

* No backend calls required.
* Uses local config fallback.
* Can read public/default categories from local Flutter seed.

Pending customer:

* Can use local tracker.
* Can call config API if authenticated.
* Sync disabled until approved.

Approved customer:

* Full API access.
* Can sync entries.
* Can upload receipt.
* Can generate reports.
* Can share with consultant.

Internal user:

* No personal tracker API by default.
* Later staff APIs can be separate.

---

# 6. Flutter Redesign

## 6.1 New Folder Structure

Refactor the feature into clean modules:

```text
lib/features/expense_tracker/
  data/
    expense_tracker_repository.dart
    expense_tracker_api_models.dart
    expense_local_store.dart
    expense_sync_service.dart
  domain/
    expense_transaction.dart
    expense_category.dart
    expense_budget.dart
    expense_summary.dart
    expense_report.dart
    expense_access_mode.dart
  presentation/
    expense_tracker_screen.dart
    widgets/
      expense_hero_card.dart
      quick_add_panel.dart
      budget_ring_card.dart
      insight_card.dart
      transaction_tile.dart
      add_expense_sheet.dart
      expense_summary_card.dart
      tax_ready_card.dart
      receipt_vault_card.dart
      sync_banner.dart
```

---

## 6.2 Tracker Modes

Flutter should support these modes:

* `guestLocal`
* `pendingLocal`
* `approvedSync`
* `internalHidden`
* `offlineApproved`

Mode decides:

* Route access.
* Tile subtitle.
* CTA text.
* Sync behavior.
* Receipt upload visibility.
* Report visibility.
* Budget visibility.
* Consultant sharing visibility.

---

## 6.3 More Screen Tile Behavior

Tile should not be locked for guests.

Subtitle should change by access state:

Guest:

> “Track locally on this device”

Pending:

> “Local tracker — sync after approval”

Approved:

> “Track, sync and generate reports”

Internal:

* Hide tile by default.

---

# 7. Main UX Design

## 7.1 Top Hero Card

The top dashboard should show:

* Current month spending.
* Income.
* Net balance.
* Remaining budget.
* Tax-ready total.
* Small insight pill.

Example insight pills:

* “Food +18% vs last month”
* “You spent PKR 4,200 today”
* “3 recurring payments expected this week”
* “PKR 18,000 marked tax-relevant”

Hero card should feel premium but lightweight.

---

## 7.2 Quick Add Panel

This is the most important UX upgrade.

Instead of opening a long form immediately, show quick category chips:

* Food
* Fuel
* Bills
* Rent
* Shopping
* Transport
* Salary
* Other

Flow:

1. User taps category.
2. Amount field opens.
3. User enters amount.
4. Tap save.

Default values:

* Date = today.
* Account = last used.
* Payment method = last used.
* Type = expense unless category is income.
* Category suggestions based on usage.

Goal:

> Add expense in 2 taps.

---

## 7.3 Add Transaction Modal V2

Simple mode fields:

* Amount
* Category
* Save

Advanced section collapsed by default:

* Account
* Payment method
* Date
* Merchant
* Note
* Receipt
* Tax relevant
* Business related
* Recurring

This avoids the “fields hi fields” problem.

---

## 7.4 Transaction List

Transaction tile should show:

* Category icon.
* Merchant or category name.
* Date.
* Payment method/account.
* Amount.
* Small chips:

  * Tax
  * Business
  * Receipt
  * Recurring

Swipe/actions:

* Edit.
* Duplicate.
* Archive/delete.

---

# 8. Smart Defaults

Store simple local preferences:

* Last used account.
* Last used payment method.
* Top categories.
* Category usage by time/day.
* Common amount per category.
* Recently used merchant.
* Last selected tax/business flags per category.

Examples:

If user often enters:

* Fuel PKR 5,000
* Food PKR 800
* Bills via Easypaisa

Quick suggestions become:

* Fuel PKR 5,000
* Lunch PKR 800
* Bills via Easypaisa

This gives an “app knows me” feeling without heavy AI.

---

# 9. Premium Widgets

| Widget                | Value                               |
| --------------------- | ----------------------------------- |
| Spending Health Score | Simple monthly financial status     |
| Budget Ring           | Visual monthly limit progress       |
| Category Heatmap      | Shows where money goes              |
| Recurring Tracker     | Rent, salary, subscriptions         |
| Tax Ready Card        | Tax-relevant expense total          |
| Business Expense Card | Business spending summary           |
| Smart Nudges          | “You spent more on fuel this month” |
| Receipt Vault         | Attach receipts to entries          |
| Monthly PDF           | Export/share report                 |
| Consultant Share Card | OMC-specific conversion tool        |

---

# 10. Reports

Approved customers should get premium reports.

## 10.1 Monthly Expense Report

Includes:

* Total income.
* Total expenses.
* Net balance.
* Category breakdown.
* Payment method breakdown.
* Cash vs bank spending.
* Tax-relevant total.
* Business expense total.
* Receipt-attached expenses.
* Budget health.
* Smart notes.

---

## 10.2 Tax-Ready Summary

Includes:

* Tax-relevant expenses.
* Business expenses.
* Receipts attached.
* Missing receipts.
* Monthly totals.
* Export PDF.
* Share with OMC consultant.

---

## 10.3 Business Summary

For business customers:

* Business income.
* Business expenses.
* Recurring expenses.
* Cash/bank split.
* Vendor/merchant summary.
* Receipt vault.
* Consultant notes.

---

# 11. Conversion Strategy

## 11.1 Guest Conversion

After 20–30 entries:

> “Create free OMC account to unlock cloud sync, reports and tax-ready summaries.”

Soft limits:

* User can still view old entries.
* Adding new entries requires account creation or limit extension.
* Do not delete local data.

---

## 11.2 Approved Customer Conversion

Show OMC service cards based on usage.

Examples:

Tax filing CTA:

> “Your tax-relevant expenses are ready. Start tax filing with OMC.”

Bookkeeping CTA:

> “You are tracking business expenses. Need monthly bookkeeping support?”

Receipt CTA:

> “You uploaded receipts. Let OMC organize them into a report.”

---

# 12. Final User Flow

## 12.1 Guest Flow

1. Guest opens More.
2. Taps Expense Tracker.
3. Sees “Local Lite Mode”.
4. Adds expense in 2 taps.
5. Sees simple monthly summary.
6. After limit, sees account creation CTA.
7. Local data remains safe.

---

## 12.2 Pending Customer Flow

1. Pending customer opens tracker.
2. Uses local tracker.
3. Sees banner: “Sync will activate after profile approval.”
4. After approval, app offers sync.

---

## 12.3 Approved Customer Flow

1. Approved customer opens tracker.
2. App checks local entries.
3. App asks to sync local tracker.
4. User syncs entries.
5. Full dashboard unlocks.
6. User can upload receipts.
7. User can generate reports.
8. User can share report with consultant.

---

## 12.4 Consultant Flow

1. Customer shares report.
2. Frappe creates/updates report record.
3. Consultant sees summary in Desk.
4. Consultant can attach it to service request.
5. Consultant can recommend filing/bookkeeping service.

---

# 13. Implementation Phases

## Phase 1 — Fix Current Foundation

Goal:

Make the existing tracker usable and correctly unlocked.

Tasks:

* Allow guest route access for `/expense-tracker`.
* Keep pending users unlocked in local mode.
* Hide tracker for internal users unless they have customer profile.
* Change More tile subtitle based on user state.
* Fix hardcoded `storageMode`.
* Add proper local/sync mode selection.
* Add edit transaction UI.
* Keep existing local data safe.
* Add local transaction limit for guests.
* Add CTA cards for guest/pending users.
* Add local JSON export.

Deliverable:

* Guest/pending local tracker works.
* Approved customer sees full-mode placeholder.
* No backend sync yet.
* Existing local data not broken.

---

## Phase 2 — Backend Frappe Module

Goal:

Add real backend support.

Backend files:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/expense.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/omc_app/doctype/omc_expense_entry/
backend_omc_app/frappe-bench/apps/omc_app/omc_app/omc_app/doctype/omc_expense_category/
backend_omc_app/frappe-bench/apps/omc_app/omc_app/omc_app/doctype/omc_expense_budget/
```

Tasks:

* Add OMC Expense Entry DocType.
* Add OMC Expense Category DocType.
* Add OMC Expense Budget DocType.
* Add permissions.
* Add default category seed.
* Implement APIs:

  * `get_expense_config`
  * `get_expense_categories`
  * `get_expense_entries`
  * `create_expense_entry`
  * `update_expense_entry`
  * `delete_expense_entry`
  * `bulk_sync_expense_entries`
  * `get_expense_summary`
  * `get_expense_budgets`
  * `save_expense_budget`
* Test APIs using `bench execute`.

Deliverable:

* Approved customer data syncs to Frappe.
* Data visible in Desk.
* Duplicate sync protection works.

---

## Phase 3 — Smart Flutter Redesign

Goal:

Make the tracker premium and fast.

Tasks:

* Refactor feature into clean module structure.
* Add tracker mode handling.
* Add premium hero card.
* Add quick add panel.
* Add add transaction sheet v2.
* Add transaction edit sheet.
* Add smart defaults.
* Add category chips.
* Add summary cards.
* Add budget ring UI.
* Add tax-ready card.
* Add sync banner.
* Add local-to-cloud sync flow.

Deliverable:

* Expense tracker feels premium.
* Expense entry is fast.
* Approved customer sync works from app.
* Guest/pending experience remains smooth.

---

## Phase 4 — Premium Reports

Goal:

Make this feature paid-worthy and OMC-specific.

Tasks:

* Add monthly PDF report.
* Add receipt upload.
* Add receipt vault.
* Add tax-ready summary.
* Add business expense summary.
* Add budget alerts.
* Add consultant sharing.
* Add service recommendation cards.
* Add OMC Expense Report DocType if needed.

Deliverable:

* Customer can generate and share report.
* Consultant can review report from Frappe.
* App can convert tracker usage into OMC services.

---

# 14. Recommended Build Order

Build in this exact order:

1. Route/access fix.
2. Local mode cleanup.
3. Guest/pending/approved tracker mode.
4. Edit transaction UI.
5. Backend DocTypes.
6. Backend APIs.
7. Sync service.
8. Quick add redesign.
9. Budget and summary UI.
10. Receipt upload.
11. PDF report.
12. Consultant sharing.
13. Service recommendation cards.

Reason:

This keeps the app stable and avoids breaking existing local data.

---

# 15. Definition of Done

The feature is complete when:

* Guest can use local tracker without login.
* Pending customer can use local tracker.
* Approved customer can sync with backend.
* Internal user does not see customer tracker by default.
* Local data remains safe during upgrade.
* Categories come from backend for approved users.
* Expense entries appear in Frappe Desk.
* User can edit/delete/archive entries.
* User can upload receipts.
* User can generate monthly report.
* User can share report with consultant.
* App shows OMC service CTAs based on tracker usage.
* Flutter analyze passes.
* Backend bench API tests pass.
* No fake/local bypass is used for approved customer sync.

---

# 16. Final Feature Name Options

Recommended name:

## Tax-Ready Expense Tracker

Alternative names:

* OMC Expense Tracker
* OMC Smart Expense Tracker
* Tax & Expense Tracker
* Business Expense Tracker
* OMC Money Tracker

Best final label inside app:

> Tax-Ready Expense Tracker

Best subtitle:

> Track expenses, receipts and tax-ready summaries.

---

# 17. Final Recommendation

This should be built as a serious OMC USP feature, not a side utility.

The strongest version is:

* Free local tracker for guests.
* Full cloud tracker for approved customers.
* Tax/business tagging.
* Receipt vault.
* Monthly PDF report.
* Consultant sharing.
* OMC service recommendations.

This makes the feature useful for users and valuable for OMC business conversion.
