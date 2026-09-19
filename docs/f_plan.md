OMC Customer Identity, Service, Payment & Pay-Later — Final Implementation Plan
1. Core principles — do not violate

ERPNext remains the business/accounting authority.

ERP Customer + Contact + Address
= authoritative customer/business data

ERP Sales Invoice
= authoritative receivable/invoice

ERP Payment Entry
= authoritative payment/accounting evidence

ERP Task
= authoritative operational task

OMC
= mobile access + workflow orchestration + referral/app metadata

OMC Customer Profile must not remain an independent second customer master.

It will stay because it contains OMC-specific information such as:

referral relationship/consent
acquisition source
onboarding mode
app linkage
app-specific metadata
historical compatibility fields

But ordinary customer business information should ultimately resolve from ERP Customer/Contact/Address.

Do not modify ERPNext core for this work. Existing client customizations already present inside ERPNext — especially their Task Generate Invoice function — must be preserved. OMC wrappers/hooks should integrate around them.

2. Explicitly separate two meanings of “active”

This distinction must exist everywhere in code.

Business Customer

Customer exists in ERPNext and may receive services.

ERP Customer ✅
OMC Customer Profile ✅
User may or may not exist
App Activated Customer

Customer has activated login/password.

ERP Customer ✅
OMC Customer Profile ✅
OMC Customer Account ✅
Website User ✅

App activation must never be a prerequisite for staff to serve an existing business customer.

An ERP customer with no User/password is still a valid customer.

3. Canonical customer relationship

Target relationship:

ERP Customer
     │
     ├── Contact(s)
     ├── Address(es)
     │
     ▼
OMC Customer Profile
     │
     │ optional until app activation
     ▼
OMC Customer Account
     │
     ▼
Website User

OMC Customer Profile.linked_erpnext_customer remains the stable link.

For future OMC Service Requests:

erp_customer       = required business identity
customer_profile   = required OMC/customer projection
customer_account   = optional for staff-created/inactive customers
requested user     = optional

For self-service requests made by an activated app user, account/user will naturally exist.

4. Do not implement a fake “live duplicated profile”

The desired “live link” should be implemented as authority + projection, not two-way duplicated editable records.

App/API customer profile response should compose:

ERP Customer
+ Contact
+ Address
+ OMC Customer Profile metadata
-------------------------------
one mobile profile response

Customer/business fields edited through the app must write to their authoritative ERP source and then refresh any compatibility projection needed by OMC.

Current code updates OMC Customer Profile directly for fields such as name/phone/address. That needs refactoring.

Before changing fields, inspect actual production Customer meta/custom fields and create an explicit mapping for:

customer name
phone/mobile
email
CNIC
NTN
company/business name
address

Use existing ERP Customer custom fields where they already exist. Do not invent another duplicate store.

OMC-only referral/acquisition/app metadata remains stored in OMC Customer Profile.

5. Future ERP Desk-created customers must automatically become OMC-serviceable

This is important.

Client staff will continue using ERP normally and may create a Customer directly in ERPNext.

That customer must not require app signup before OMC can use it.

Add an OMC Customer event/reconciliation layer:

ERP Customer created by staff
        ↓
ensure OMC Customer Profile exists
        ↓
link profile.linked_erpnext_customer
        ↓
NO User created
NO password created
NO Customer Account required
        ↓
customer immediately serviceable by staff

Customer update events should refresh the OMC business-data projection where necessary.

Also retain a lazy resolver/reconciliation fallback so a customer missing its profile because of historical data can be repaired safely when encountered.

6. New app signup

Current signup creates the app identity/profile but can end with no ERP Customer and therefore an Unlinked/Pending account.

That must change.

Target:

Signup
↓
verification email
↓
email verified
↓
password set
↓
identity collision preflight
↓
ERP Customer resolution
↓
OMC Profile linked
↓
OMC Customer Account linked
↓
app access active
Genuine New Customer

If onboarding mode is New Customer and no ERP customer collision exists:

Create ERP Customer
↓
link OMC Customer Profile
↓
Customer Profile = Active / Approved
↓
Customer Account:
    Identity = Verified
    Account Link = Linked
    Service Access = Approved
↓
customer can immediately use app

No unnecessary staff approval for an ordinary clean new signup.

Collision protection

Check deterministic identifiers available in the client system, such as:

email
CNIC
NTN
mobile/phone
existing explicit links

Never silently create a duplicate.

If New Customer signup matches an existing ERP Customer:

Existing Customer Detected
→ review / existing-customer activation path

If multiple matches exist:

Ambiguous
→ manual review

No guessing.

7. Existing ERP customers activating later

Historical/imported customer:

ERP Customer ✅
OMC Profile ✅
User ❌
Customer Account ❌

is a valid state.

Staff can continue doing services for them indefinitely.

Later:

customer receives activation
↓
sets password
↓
User created
↓
Customer Account created
↓
Account linked to same ERP Customer/Profile

Do not recreate their services.

After login, previous records should become visible through canonical ERP Customer ownership.

8. Historical ownership must not depend only on Customer Account

Current ownership/access logic relies heavily on:

customer_account
or legacy customer_profile

Extend centralized ownership resolution to support:

1. exact Customer Account match
OR
2. exact ERP Customer match
OR
3. controlled legacy profile fallback

Therefore:

Account.erp_customer == Request.erp_customer

must establish customer ownership.

Update all dependent read/permission flows consistently:

service cases
payments
documents
timeline/history
notifications
customer dashboard
task visibility
invoice/payment views

Avoid solving this independently inside every API.

Use one canonical ownership resolver.

9. Staff-created Service Request for non-activated customers

Current assisted_service.py requires:

Verified Customer Account
+ Linked
+ Approved

This is the main blocker.

Remove app-account approval as a business customer requirement.

For staff-assisted requests, require instead:

valid ERP Customer
+
valid linked OMC Customer Profile
+
staff capability

Customer Account is optional.

Target:

Staff selects ERP-backed customer
↓
OMC resolves/ensures Customer Profile
↓
Service Request created
↓
erp_customer populated
↓
customer_account blank if app not activated
↓
normal service flow continues

Do not create fake Users merely to satisfy old code.

10. Referral behavior

get_my_referrals() already has useful separation, but service-selection currently restricts referral customers through approved Customer Accounts.

Decouple these concepts:

Referral relationship
≠
App activation

A referred customer can remain visible even without a User/password.

For service creation:

My Referral

Continue requiring appropriate referral relationship and customer-assistance consent.

Do not use historical/imported referral information as fake consent.

Existing Customer

Authorized staff with all-customer access may serve the ERP Customer through the normal existing-customer route regardless of app activation.

Preserve current distinction between:

explicit app referral consent
vs
historical ERP relationship
11. Documents

Document workflow must remain independent of app activation.

Documents belong to the business customer/service, not to the existence of a login account.

Approved/reusable historical documents must continue to work for:

ERP Customer with app account
ERP Customer without app account

Audit:

customer document lookup
approved document reuse
document permissions
service request document linking

and ensure they can resolve through erp_customer.

Also preserve the current fix that payment and document upload are independent. Do not restore a documents-before-payment gate.

12. Payment branch A — normal payment received now

Preserve the current accounting architecture.

Current correct path:

Receipt uploaded
↓
human verifies receipt
↓
verified amount entered
↓
Sales Invoice ensured
↓
ERP Payment Entry created + submitted
↓
ERP reconciliation
↓
positive submitted allocation
↓
Partially Settled / Settled
↓
Service + Task activation

Important:

receipt verification itself is not accounting truth.

ERP reconciliation remains authority.

Current latest rule is also correct:

A positive clean ERP-reconciled partial payment can start the service.

So:

30,000 due
15,000 verified
↓
Payment Entry 15,000
↓
Partially Settled
↓
service starts

Full settlement follows the same pipeline.

Do not weaken this.

13. Staff receipt upload on behalf of customer

Currently receipt upload is effectively customer/app initiated.

Add a separate staff/internal action:

Upload Receipt

Available on the Desk payment record to appropriately authorized staff.

Use a separate guarded endpoint rather than weakening the customer upload endpoint.

Both routes should share the same low-level safe file/evidence pipeline:

Customer App Upload
or
Staff On-Behalf Upload
          ↓
OMC Payment Receipt evidence

Persist provenance:

Submission Source:
Customer App / Staff On Behalf

Submitted By:
actual User

Submitted At:
timestamp

Preserve existing file controls:

allowed extensions
file size limit
malware/quarantine scanning
idempotency
receipt count limits
14. AI-assisted receipt extraction

Add an OMC-specific payment receipt analysis module.

Do not call the generic ERP Task acknowledgement parser directly.

The existing Task OpenAI integration can be used as a design reference only.

AI should extract structured fields such as:

amount
currency
transaction/reference ID
date
time if visible
bank/wallet
beneficiary/account if visible
transaction status

Also calculate validation warnings:

amount vs expected payment
currency mismatch
beneficiary/account mismatch
duplicate transaction reference
duplicate file hash
status not Successful/Completed
partial payment indication

Store AI result on OMC Payment Receipt, preferably as dedicated fields plus structured JSON/audit metadata.

AI credentials remain server-side.

Do not log raw receipt image/base64 data.

15. AI is assistant, not payment authority

The final flow:

Receipt uploaded
↓
AI extraction
↓
review context prepared
↓
human reviewer sees original image + extracted data
↓
human clicks Verify
↓
ERP accounting starts

AI must never automatically mark payment paid.

Example verification dialog:

Expected Amount:       PKR 30,000
Detected Amount:       PKR 15,000
Verified Amount:       PKR 15,000

Reference:             ABC123
Bank:                  Meezan
Date:                  18-Sep-2026
Status:                Successful

✓ Currency matches
✓ account appears valid
✓ no duplicate reference
⚠ partial payment

When AI extraction is confident, use detected amount as the verified amount default.

If reviewer changes an AI-detected amount, require an explicit override reason and audit it.

If AI fails or cannot confidently read the receipt:

Manual Review Required

Do not automatically reject a genuine payment merely because the AI service failed.

Authorized staff may manually verify after reviewing the actual evidence, with an exception reason.

The existing backend rules must still enforce:

verified amount > 0
verified amount <= installment amount
verified amount <= ERP remaining amount
16. Payment branch B — Pay Later

This is not manual payment verification.

It is an explicit deferred-payment decision.

Desk payment record gets:

Approve Pay Later

Only authorized finance/staff users may use it.

Require at minimum:

Reason *

Record:

approved_by
approved_at
reason

Existing post_paid_approved_by / post_paid_approved_at can be reused for compatibility; add the missing reason/audit context rather than creating unnecessary duplicate approval mechanisms.

17. Request-level payment execution mode

Do not overwrite the frozen service payment policy merely because this particular request was allowed Pay Later.

Add a request-level execution mode, conceptually:

Payment Execution Mode:
Prepaid
Pay Later

Default:

Prepaid

Service catalogue payment_policy_snapshot remains historical/configuration evidence.

Pay Later is a request-specific authorized override.

This gives clean auditability:

Service normally requires payment
but
this request was explicitly deferred by X at Y for reason Z
18. Pay Later must be mutually exclusive with real payment evidence

Initial implementation should stay simple.

Allow Pay Later only before positive accounting evidence exists.

Do not allow switching a request to Pay Later after it already has:

positive submitted Payment Entry allocation
Partially Settled state
Settled state

If a receipt has merely been uploaded but not accepted, staff must resolve/reject that evidence first before selecting Pay Later.

This avoids mixed ambiguous states.

19. What happens when Pay Later is approved

Do not:

create fake receipt
create Payment Entry
mark customer paid
create Sales Invoice immediately

Instead:

Pending Payment
↓
Approve Pay Later
↓
payment marked Deferred
↓
request becomes activation eligible
↓
ERP Service created
↓
ERP Task created
↓
Task starts normally

Clear/neutralize the normal pending-payment expiry for this request so an active deferred service cannot later be expired by the 72-hour payment scheduler.

Suppress normal “payment pending before service” reminders for deferred requests.

20. Add Deferred payment state

The OMC payment record should explicitly communicate what happened instead of pretending it was Cancelled/Paid.

Add:

Deferred

to appropriate payment state/projection.

Example:

Receipt Status: Not Submitted
Payment Status: Deferred
Accounting Status: Unmatched
Execution Mode: Pay Later

Customer-facing app, if that customer is active, should show something like:

Pay Later approved. Invoice will be generated after the service task is completed.

Do not show the normal “upload receipt to start service” action for that deferred request.

21. Pay Later invoice flow — preserve client's existing Task behavior

This is a critical repository dependency.

Client's ERP Task currently has:

Task status = Completed
Task.invoiced = 0
↓
Generate Invoice button appears
↓
erpnext.projects.doctype.task.task.mk_inv()

Keep this behavior.

For now the agreed model is:

one OMC Service Request → one ERP Task

Do not design a multi-task billing engine in this phase.

22. Current OMC Task invoice guard must become mode-aware

Current task_invoice_compat.py intentionally prevents OMC Tasks from generating another Sales Invoice because prepaid OMC requests already created their canonical invoice.

That is correct for prepaid.

Target behavior:

Prepaid request
Task completed
↓
Generate Invoice called
↓
existing canonical OMC invoice returned/reused
↓
NO second invoice
Pay Later request
Task completed
↓
Generate Invoice button
↓
OMC wrapper verifies Pay Later approval
↓
no existing canonical invoice?
↓
delegate to client's existing ERP Task mk_inv()
↓
client's normal Sales Invoice generated
↓
link that invoice to OMC request/accounting

Thus one wrapper safely supports both models.

23. Protect Pay Later invoice generation

Before delegating the existing Task invoice function verify:

Task belongs uniquely to this OMC request
Task status = Completed
Request execution mode = Pay Later
Pay Later was authorized
No canonical invoice already exists
Task customer matches request ERP Customer
Task rate matches frozen OMC payable amount

If an invoice already exists, return/reuse it.

Never create a second invoice.

This endpoint must also protect direct API calls — not only rely on the button being visible.

24. Adopt the Task-generated invoice into OMC accounting

Client's Task function currently creates a draft Sales Invoice.

Immediately after it returns:

validate invoice/customer/request relationship
↓
create canonical OMC Accounting Link
↓
invoice_docstatus = draft
↓
accounting status = Unmatched

Do not submit it automatically.

Client staff continues their normal ERP flow.

When they submit the Sales Invoice:

Sales Invoice submitted
↓
existing OMC invoice hook runs
↓
accounting reconciliation refreshes

The invoice is then an ordinary ERP receivable.

25. Pay Later completion safety

Task completion and payment settlement are separate things.

For Pay Later:

Task Completed
≠
Payment Received

Do not require payment before operational work can finish.

However, prevent the OMC request from disappearing as fully finished while billing was completely forgotten.

Recommended completion condition for Pay Later:

ERP Task Completed
+
Sales Invoice generated/linked

Payment itself may remain outstanding.

The actual invoice can then be submitted/collected through the client's normal ERP workflow.

No automatic invoice creation — staff still clicks the existing Generate Invoice action.

26. Payment after Pay Later invoice

Once the generated invoice exists:

Sales Invoice
Outstanding = amount due

Later staff/customer pays through the client's normal ERP process:

ERP Payment Entry
↓
allocated to Sales Invoice
↓
OMC Payment Entry hook
↓
reconciliation
↓
Partially Settled / Settled

No fake OMC settlement logic.

ERPNext remains authority.

27. Credit limits / Payment Terms

Do not build new credit-limit/monthly billing logic merely because Pay Later exists.

ERPNext Customer already supports:

Payment Terms Template
Credit Limit

but use them only if the client actually uses those features.

For this phase:

Pay Later
→ skip initial payment
→ start service/task
→ Task Completed
→ staff clicks Generate Invoice
→ existing ERP invoice workflow

That's enough.

No monthly consolidated-invoice engine.

No artificial subscription/month-end logic.

28. Existing customer migration

Before production migration:

backup
↓
dry-run customer reconciliation
↓
inspect collisions
↓
execute idempotent migration
↓
verify counts/results

For every legitimate existing ERP Customer:

ensure OMC Customer Profile
link ERP Customer
preserve referral/history metadata
DO NOT create User
DO NOT create fake password

Then run/review the existing configuration/reconciliation workflow for historical OMC service/task mappings.

Do not invent a new destructive migration if the existing setup command already owns this work.

Inspect the actual configuration command before execution.

29. Future reconciliation safety

Migration alone isn't enough.

Add ongoing reconciliation so future data cannot drift:

ERP Customer event
+
lazy resolver
+
scheduled/idempotent reconciliation where appropriate

These must detect rather than silently merge:

duplicate ERP Customers
duplicate OMC profiles
one ERP Customer linked to multiple customer accounts
mismatched request ERP Customer
ambiguous identity claims

Fail closed and send ambiguous cases to review.

30. Security requirements

All new mutations must preserve current security architecture.

Require:

POST-only mutations
capability checks
request/customer scope checks
rate limits
row locking where accounting/approval state changes
idempotency
audit events
immutable accounting evidence
file validation/scanning
duplicate receipt detection
no arbitrary generic AI parser accepting arbitrary DocTypes
OpenAI credentials server-side only

Staff receipt upload and Pay Later approval must not become public/customer-authorized endpoints.

AI result is advisory evidence only.

31. Existing safety behavior that must survive

Do not break:

partial-payment continuation
payment installment behavior
Payment Entry cancellation reconciliation
Sales Invoice cancellation/reversal handling
Financial Hold behavior
exactly-once ERP activation bridge
service assignment recovery
referral attribution snapshots
commission projection
accounting-link immutability
cancellation safeguards
document/payment independence
bank details coming from OMC Payment Account
existing customer receipt upload
customer ownership isolation
32. Metadata cleanup

Current Service activation-policy description still says Full Settlement is required even though current business rule allows a positive verified/reconciled partial payment to start work.

Update stale descriptions/UI text/tests so staff are not shown contradictory rules.

Do not change accounting settlement semantics: partial still means partially paid.

33. Required acceptance tests

Before commit/push, prove all of these locally on omc-prod.local:

Genuine new app signup creates/links ERP Customer and immediately produces a valid app Customer Account.
New signup matching an existing ERP customer does not create a duplicate.
Ambiguous customer identity fails closed.
Staff-created ERP Customer automatically becomes OMC-serviceable without a User.
Existing ERP customer with no app User appears in Desk customer selection.
Staff can create Service Request for that non-activated customer.
ERP Service and Task can eventually be created for that customer without requiring app activation.
Customer activates months later and previous service requests/documents/payments/tasks become visible.
Referral remains visible without app activation.
Referral-assisted request does not bypass referral consent.
Existing-customer staff route works without app activation.
App customer can upload payment receipt exactly as today.
Staff can upload receipt on customer's behalf.
AI extracts payment data and displays it beside the original evidence.
AI mismatch generates warnings and cannot silently start accounting.
AI failure falls back to explicit audited manual review instead of automatically accepting payment.
Verified partial payment creates the correct ERP Payment Entry and activates service.
Full payment creates correct settlement and activates service.
Verified amount can never exceed installment/ERP remaining amount.
Duplicate transaction/file evidence is detected.
Pay Later can be selected while no positive payment evidence exists.
Pay Later requires authorized staff + reason.
Pay Later creates no fake Payment Entry.
Pay Later creates no Sales Invoice at approval time.
Pay Later activates ERP Service + Task.
Deferred request does not expire through pending-payment expiry.
Deferred request does not continue sending false pre-service payment reminders.
Completed Pay Later Task exposes the client's existing Generate Invoice action.
Generate Invoice creates exactly one draft Sales Invoice through the client's existing Task workflow.
Generated invoice is linked to the correct OMC request/accounting record.
Calling Generate Invoice again cannot create a duplicate.
Prepaid Task can never create a second invoice; it reuses the canonical prepaid invoice.
Submitted Pay Later invoice retains its real outstanding amount.
Later partial ERP Payment Entry produces Partially Settled state.
Later full ERP settlement produces Settled state.
Payment Entry cancellation/reversal restores correct ERP outstanding/accounting state.
Request cancellation never deletes or fabricates ERP accounting records.
Historical/imported customers remain usable without creating fake Users.
Customer/profile/account/service/request mapping reconciliation is idempotent.
Existing regression test suite remains green.

### 33.1 Acceptance evidence matrix — closure bookkeeping

This matrix is a bookkeeping index over evidence already executed before release.
It does not replace the underlying tests or create new accounting state.

| # | Required acceptance condition | Closure evidence |
|---|---|---|
| 1 | Genuine new app signup creates/links ERP Customer and valid Customer Account | Proven by `test_signup_activation_phase2.py` and signup/account-authority coverage in the final full suite. |
| 2 | Signup matching an existing ERP customer does not create a duplicate | Proven by existing-customer activation/reuse tests in `test_signup_activation_phase2.py` and resolver reuse tests in `test_customer_profile_resolver.py`. |
| 3 | Ambiguous customer identity fails closed | Proven by ambiguous-identity tests in `test_signup_activation_phase2.py`, `test_customer_profile_resolver.py`, and reconciliation review tests. |
| 4 | Staff-created ERP Customer becomes OMC-serviceable without a User | Proven by business-only profile tests in `test_customer_profile_resolver.py` and accountless serviceability coverage. |
| 5 | Existing ERP customer without app User appears in Desk customer selection | Proven by `test_assisted_service_picker_parity.py`. |
| 6 | Staff can create a Service Request for a non-activated customer | Proven by assisted-service policy/picker coverage in `test_assisted_service.py` and `test_assisted_service_picker_parity.py`. |
| 7 | ERP Service and Task can be created without app activation | Proven by accountless ownership/activation coverage plus the retained real-DB ERP Service/Task chain. |
| 8 | Later app activation preserves access to historical requests/documents/payments/tasks | Proven by `test_customer_activation.py`, canonical ERP-customer ownership tests in `test_phase3_service_ownership.py`, and related read-scope coverage in the full suite. |
| 9 | Referral remains visible without app activation | Proven by referral migration/history coverage in `test_customer_migration.py`, `test_referrals.py`, and referral-system tests. |
| 10 | Referral-assisted request cannot bypass referral consent | Proven by `test_assisted_service.py` and `test_referrals.py`. |
| 11 | Existing-customer staff route works without app activation | Proven by `test_assisted_service_picker_parity.py` and assisted-service authorization tests. |
| 12 | App customer can upload payment receipt through the existing guarded path | Proven by receipt submission/integrity and payment mutation coverage, including `test_receipt_submission_integrity.py`. |
| 13 | Staff can upload receipt on customer's behalf | Proven by `test_phase5_staff_receipt_upload.py`. |
| 14 | AI extracts payment data and exposes it as advisory evidence | Proven by `test_phase6_payment_receipt_analysis.py` and `test_phase6b_payment_review_ai.py`. |
| 15 | AI mismatch warns and cannot silently start accounting | Proven by warning-engine and “AI never invokes accounting” tests in Phase 6/6B modules. |
| 16 | AI failure falls back to audited manual review | Proven by provider-failure/manual-review tests in `test_phase6_payment_receipt_analysis.py` and `test_phase6b_payment_review_ai.py`. |
| 17 | Verified partial payment creates ERP payment evidence and activates service | Proven by the retained real-DB partial-payment activation proof plus `test_verified_payment_activation.py`. |
| 18 | Full payment settles correctly and activates service | Covered by settled-positive activation/reconciliation tests and the full accounting regression suite. |
| 19 | Verified amount cannot exceed installment or ERP remaining amount | Proven by explicit upper-bound rejection tests in `test_phase6b_payment_review_ai.py`. |
| 20 | Duplicate transaction/file evidence is detected | Proven by duplicate receipt submission tests in `test_receipt_submission_integrity.py` and duplicate-reference warning coverage in Phase 6. |
| 21 | Pay Later is selectable only before positive accounting evidence exists | Proven by `test_phase7_pay_later.py`. |
| 22 | Pay Later requires authorized staff and reason | Proven by guarded approval/reason tests in `test_phase7_pay_later.py` and staff capability coverage. |
| 23 | Pay Later creates no fake Payment Entry | Proven by `test_phase7_pay_later.py::test_approval_defers_payment_without_creating_erp_accounting`. |
| 24 | Pay Later creates no Sales Invoice at approval time | Proven by the same deferred-approval accounting test and Phase 8 invoice-generation boundary tests. |
| 25 | Pay Later activates ERP Service + Task | Proven by Phase 7 bridge eligibility tests and operational bridge/ERP activation coverage. |
| 26 | Deferred request does not expire through pending-payment expiry | Proven by `test_phase7_pay_later.py::test_pay_later_request_never_expires_as_pending_payment`. |
| 27 | Deferred request does not send false pre-service payment reminders | Proven by `test_phase7_pay_later.py::test_daily_payment_pending_reminder_is_suppressed_for_pay_later`. |
| 28 | Completed Pay Later Task exposes/uses the existing Generate Invoice route | Proven by mode-aware Task invoice compatibility tests in `test_phase8_task_invoice_compat.py`. |
| 29 | Generate Invoice creates one draft Sales Invoice via the existing Task workflow | Proven by `test_phase8_task_invoice_compat.py::test_pay_later_delegates_existing_task_function_then_adopts_draft`. |
| 30 | Generated invoice is linked to the correct OMC request/accounting record | Proven by Phase 8 adoption/link tests, including unmatched canonical Accounting Link creation. |
| 31 | Repeated Generate Invoice cannot create a duplicate | Proven by `test_phase8_task_invoice_compat.py::test_repeated_pay_later_generation_reuses_existing_invoice`. |
| 32 | Prepaid Task never creates a second invoice | Covered by mode-aware Task invoice compatibility and canonical prepaid invoice reuse guards in the full suite. |
| 33 | Submitted Pay Later invoice retains ERPNext-authoritative outstanding amount | Covered by the native ERP invoice/adoption/reconciliation contract; OMC does not fabricate outstanding state. |
| 34 | Later partial ERP Payment Entry produces Partially Settled | Proven by accounting reconciliation/partial-payment coverage and retained real ERP partial-settlement evidence. |
| 35 | Later full ERP settlement produces Settled | Covered by settled accounting/activation tests and the final accounting regression suite. |
| 36 | Payment Entry cancellation/reversal restores ERP-authoritative state | Proven by payment hook de-dup/reversal and cancellation safety coverage, including `test_payment_accounting_hook_dedup.py`. |
| 37 | Request cancellation never deletes or fabricates ERP accounting records | Proven by `test_cancellation_payment_safety.py`. |
| 38 | Historical/imported customers remain usable without fake Users | Proven by `test_customer_migration.py`, business-only profile tests, and Phase 10 User-count invariance. |
| 39 | Customer/profile/account/service/request reconciliation is idempotent | Proven by migration/reconciliation tests, durable checkpoint tests, advisory-lock tests, and the production-style configuration rehearsal. |
| 40 | Existing regression suite remains green | Final gate: **1,330/1,330 tests passed**, with exact identity/reconciliation state invariance and no test-fixture leakage. |

Release bookkeeping status after the evidence matrix:

- implementation phases 1–10: complete;
- final local validation: complete;
- release commit `ff60fc41af68f5efa5032d0b46b5e5d1418644e8`: pushed to `main`;
- bookkeeping closure commit `a68ae0c31106f5185cebae8bca3384a4002b7810`: pushed to `main`;
- no additional accounting transaction was fabricated solely to populate this matrix.

34. Implementation order

Implement as coherent batches, not random patches:

PHASE 1
Customer authority + ERP Customer/Profile resolver

PHASE 2
New signup ERP Customer creation/linking
+ existing-customer activation

PHASE 3
Inactive-customer staff service creation
+ referral selection
+ canonical ownership/history

PHASE 4
Customer profile ERP-backed read/write behavior
+ documents/customer projection audit

PHASE 5
Staff receipt upload
+ receipt provenance/evidence lifecycle

PHASE 6
AI payment receipt extraction/review assistance

PHASE 7
Request-level Pay Later approval
+ Deferred payment state
+ bridge/expiry/reminder logic

PHASE 8
Task invoice compatibility:
Prepaid = reuse invoice
Pay Later = delegate existing Task Generate Invoice
+ canonical accounting link

PHASE 9
Flutter/Desk presentation changes
+ bank/payment/status messaging

PHASE 10
Migration/reconciliation
+ full local regression/integration testing

Phase 10 migration/reconciliation/configuration hardening status:

- implemented and locally proven on `omc-prod.local`;
- `configuration.sh` is now `v1.4.0`;
- customer identity reconciliation is durable and checkpoint-aware;
- production reconciliation runs in bounded batches with a maximum batch size of `500`;
- blank initial checkpoint requires one complete cycle; interrupted/non-blank checkpoint requires completion of that cycle plus one fresh complete cycle;
- MariaDB advisory locking prevents concurrent reconciliation ownership; competing work returns `SkippedLocked` / `reconciliation_already_running` with zero reconciliation work;
- convergence fails closed on non-blank final cursor, User-count drift, open Identity quarantines, open `legacy_user_missing`, or unexpected review reasons;
- expected manual-review reasons remain limited to `erp_customer_missing`, `erp_customer_ambiguous`, and `canonical_account_conflict`;
- `OMC Mobile Settings` remains client/site-managed; app-default synchronization does not overwrite it and validates only current release controls (`minimum_app_version`, `force_update`, `maintenance_mode`);
- full production-style `configuration.sh v1.4.0` rehearsal passed, including backup, migrate, ERP contract, initialization, migration, reconciliation, catalogue/default validation, scheduler enablement, asset build, cache clear and final verification;
- final targeted Phase 10 regression passed: `110 tests` across reconciliation, queues, customer migration, historical service migration, scheduler jobs and Mobile Settings;
- identity state remained stable after regression: Customer Profiles `3241 -> 3241`, Users `321 -> 321`, Customer Accounts `7 -> 7`, open reviews `7 -> 7` (`erp_customer_missing=7`), Identity quarantines `0 -> 0`;
- scheduler was restored and verified enabled after the targeted regression;
- no identity fixture leakage was detected;
- observed production-like historical service data changed from `74 -> 75` services and `5 -> 6` conflicts during rehearsal; migration still explicitly reported `STATUS: SAFE TO CONTINUE`, so this is retained as observed data rather than hidden or treated as an implementation failure.

This records the locally proven Phase 10 migration/reconciliation/configuration hardening work. It does not remove the remaining plan-wide final release gates below.

Only after all relevant flows pass locally:

review complete diff
↓
run focused tests
↓
run full OMC test suite
↓
manual end-to-end ERP test
↓
then commit
↓
then push main
Final target flow
                         ERP CUSTOMER
                              │
                   ┌──────────┴──────────┐
                   │                     │
              OMC Profile          ERP business data
                   │
              User optional
                   │
                   ▼
             SERVICE REQUEST
                   │
            PAYMENT DECISION
                   │
      ┌────────────┴─────────────┐
      │                          │
   PAY NOW                   PAY LATER
      │                          │
Receipt upload             Staff approval
Customer/Staff             + reason/audit
      │                          │
AI extraction                   │
      │                          │
Human verification              │
      │                          │
ERP Invoice + PE                │
Reconciliation                  │
      │                          │
Partial/Full                    │
      └────────────┬─────────────┘
                   │
              SERVICE START
                   │
               ERP TASK
                   │
             TASK COMPLETED
                   │
          ┌────────┴─────────┐
          │                  │
       PREPAID            PAY LATER
          │                  │
existing invoice       Generate Invoice
reused only            existing ERP Task flow
          │                  │
          └────────┬─────────┘
                   │
                ERPNext
             remains authority

<!-- PHASE 10 FINAL VALIDATION CLOSURE - 2026-09-19 -->
### Phase 10 final validation closure — 2026-09-19

Final local release validation is complete.

- Full OMC regression: **1,330 tests passed** (`OK`) in 135.475s.
- Scheduler was disabled for the suite and restored successfully afterward.
- Identity state was exactly invariant across the final full-suite run:
  - OMC Customer Profiles: **3,248 -> 3,248**
  - Users: **319 -> 319**
  - OMC Customer Accounts: **7 -> 7**
  - `@qa.omc.test` Users/Profiles: **0 -> 0**
  - fixed self-service test Users/Profiles: **0 -> 0**
  - open identity reviews: **7 -> 7**, all `erp_customer_missing`
  - unexpected review reasons: **0**
  - open identity quarantines: **0**
  - `legacy_user_missing`: **0**
  - reconciliation checkpoint stayed unchanged during the isolated suite:
    cursor `OMC-CUST-260823-00200`, cycle `15`, last run
    `79d382e398ab4a239a62638b30d34b54`.
- Focused regression for the stale/leaky test corrections: **58 tests passed**.
  Those corrections were test-only; no activation/payment production logic was
  weakened to make the suite pass.
- Existing real-DB ERP acceptance evidence is retained instead of creating new
  accounting records only for release testing:
  - partial-payment activation proof on `OMC-SR-260917-00001` used real local
    database state with rollback protection; exactly one durable activation
    bridge operation and one queue submission were observed while the ERP
    Payment Entry remained unchanged;
  - the persisted ERP chain for `OMC-SR-260911-00001` already proved native
    Sales Invoice / Payment Entry / GL accounting followed by ERP Service
    `SERV0093`, Task `TASK-2026-02835`, and automatic assignment.
- The later Phase 10 production changes are customer reconciliation,
  configuration/reporting, and Mobile Settings ownership hardening; the final
  full-suite correction batch changed tests only.

**Release sequence completed:** final complete-diff sanity review, focused/full regression, ERP acceptance evidence review, commit, and push to `main` are complete.

- Final release commit: `ff60fc41af68f5efa5032d0b46b5e5d1418644e8`
- Commit message: `Phase 10 harden reconciliation and deployment validation`
- GitHub `main` was verified at the same commit after push.
