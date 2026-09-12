Boss, I completed this as an **architecture audit only** against GitHub `main` at **`d3cba074` — `fix: harden ERP service task bridge`**. I did **not** modify files, ERPNext core, schema, permissions, commits, or remote state. I also did not run runtime tests during this audit, so I am not claiming any new test passes.

I treated the supplied payment/accounting requirements and verified runtime observations as the audit baseline. 

# Executive conclusion

Your overall direction is correct, but the financial model should be made sharper:

> **OMC must move the ERP accounting demand earlier in the lifecycle, not invent a new payment lifecycle.**

The clean canonical model is:

```text
OMC Service Request
        │
        ▼
Immutable pricing snapshot
        │
        ▼
ONE canonical ERP Sales Invoice
        │
        ├── Payment Entry #1
        ├── Payment Entry #2
        └── Payment Entry #N
        │
        ▼
ERP outstanding / settlement
        │
        ▼
OMC reconciliation projection
        │
        ▼
Activation policy satisfied
        │
        ▼
ERP Service + ERP Task
        │
        ▼
Normal operational workflow
        │
        ▼
Task Completed
```

The important distinction is:

* **Sales Invoice = debt / accounting demand**
* **Payment Entry = individual settlement/payment**
* **Sales Invoice outstanding = aggregate financial truth**
* **OMC Service Payment = orchestration/evidence for a payment attempt/installment**
* **OMC Accounting Link = bridge between the request and canonical ERP accounting**
* **Task.invoiced = legacy compatibility projection only**
* **Task is no longer responsible for originating the invoice for an OMC request**

That gives you payment-first protection **without replacing ERPNext AR/GL/accounting**.

---

# 1. Current legacy ERP flow

## A. Client-specific Task layer

Current repo source confirms the client has customized ERP Task behavior in:

```text
backend_omc_app/frappe-bench/apps/erpnext/
erpnext/projects/doctype/task/task.js

backend_omc_app/frappe-bench/apps/erpnext/
erpnext/projects/doctype/task/task.py
```

The Desk logic is effectively:

```text
Task status = Completed
AND Task.invoiced = 0
        ↓
show "Generate Invoice"
```

The button calls:

```python
erpnext.projects.doctype.task.task.mk_inv
```

`mk_inv()` currently:

```text
Task
  ↓
new Sales Invoice
  customer = task.customer

  item:
    item_code = task.type
    qty       = 1
    rate      = task.rate
    amount    = task.rate
  ↓
invoice.save()
  ↓
Task.invoiced = 1
```

### Critical detail

It calls `save()`, not `submit()`.

So the Task customization itself creates a **draft Sales Invoice**. From there the normal ERP accounting lifecycle takes over after submission/payment.

`bulk_generate_invoices()` has effectively the same weakness.

## No duplicate protection exists here

I confirmed no check in those functions for:

* OMC Service Request
* OMC Accounting Link
* existing OMC Sales Invoice
* `linked_invoice`
* already-settled request
* existing Payment Entry
* equivalent existing invoice

Therefore your observed state is genuinely dangerous:

```text
OMC canonical SI already exists + is Paid
        +
Task.invoiced = 0
        ↓
Generate Invoice still visible
        ↓
another draft SI can be created
```

This is not merely a UI problem.

---

## B. What happens after the Sales Invoice

The actual financial lifecycle belongs to ERPNext rather than Task.

Conceptually:

```text
Draft Sales Invoice
       ↓ submit
Submitted Sales Invoice
       ↓
Receivable / income / tax accounting posted
       ↓
Outstanding amount established
       ↓
Payment Entry/Entries allocated
```

A partial settlement does **not** require another invoice.

The correct ERP model is:

```text
Sales Invoice = 50,000

Payment Entry A = 20,000
    outstanding → 30,000

Payment Entry B = 10,000
    outstanding → 20,000

Payment Entry C = 20,000
    outstanding → 0
```

The same invoice remains the accounting document throughout.

That is exactly the accounting model OMC should preserve.

### AR / GL separation

The Task's `mk_inv()` is not the accounting engine.

It merely creates the invoice document.

Once submitted, standard ERP accounting governs:

* receivable
* income
* tax accounts
* outstanding
* payment allocation
* Payment Entry references
* customer/account ledgers
* GL impact
* reversal/cancellation effects
* invoice status

Therefore replacing `mk_inv()` with a separate OMC bookkeeping model would be the wrong architecture.

---

## Standard vs client-specific

| Behavior                                 | Classification      |
| ---------------------------------------- | ------------------- |
| Sales Invoice                            | Standard ERPNext    |
| Sales Invoice submission/accounting      | Standard ERPNext    |
| Accounts Receivable                      | Standard ERPNext    |
| GL posting                               | Standard ERPNext    |
| Payment Entry                            | Standard ERPNext    |
| outstanding calculation                  | Standard ERPNext    |
| partial allocation                       | Standard ERPNext    |
| customer/invoice ledger                  | Standard ERPNext    |
| Task `Generate Invoice` customization    | **Client-specific** |
| `mk_inv()` using Task customer/type/rate | **Client-specific** |
| `Task.invoiced` compatibility behavior   | **Client-specific** |
| bulk Task invoice generation             | **Client-specific** |

This distinction matters a lot: **we should preserve standard accounting while adapting the client-specific Task bridge.**

---

# 2. Current OMC flow

The OMC implementation is already substantially closer to the target architecture than the legacy Task flow.

The relevant backend accounting path is centered around:

```text
omc_app/api/payment_accounting.py
```

plus reconciliation/payment/activation modules and the OMC financial DocTypes.

The architecture already resembles:

```text
Request/pricing
    ↓
Payment evidence/verification
    ↓
payment accounting preflight
    ↓
ensure canonical invoice
    ↓
submit ERP Sales Invoice
    ↓
create ERP Payment Entry
    ↓
submit ERP Payment Entry
    ↓
reconcile from ERP
    ↓
OMC Accounting Link
    ↓
Partial / Settled projection
    ↓
activation bridge
```

## Important existing strength: `_ensure_invoice()`

This is conceptually much safer than Task `mk_inv()`.

Its purpose is to reuse the invoice linked through OMC accounting state instead of blindly creating another one.

That gives the OMC side an idempotency boundary that the legacy Task implementation lacks.

---

## Verified runtime example

Your existing test request proves the financial chain already reaches real ERP accounting:

```text
OMC Service Request
OMC-SR-260911-00001

        ↓

OMC Accounting Link
sales_invoice = SINV-O-03057
accounting_status = Settled

        ↓

ERP Sales Invoice
SINV-O-03057
docstatus = 1
status = Paid
grand_total = 50,000
outstanding = 0

        ↓

ERP Payment Entry
ACC-PAY-2026-00458

        ↓

OMC Service Payment
OMC-PAY-260911-00001
status = Paid
linked_invoice = SINV-O-03057
linked_payment_entry = ACC-PAY-2026-00458
```

That is not a fake OMC-only paid state.

There is a real submitted ERP Sales Invoice and Payment Entry behind it.

That is the architecture we want to strengthen.

---

# 3. Gap matrix

| Area                       | Legacy ERP                                       | Current OMC                                         | Assessment                     |
| -------------------------- | ------------------------------------------------ | --------------------------------------------------- | ------------------------------ |
| Sales Invoice              | Yes                                              | Yes                                                 | **Equivalent foundation**      |
| ERP accounting authority   | Yes                                              | Yes                                                 | **Good**                       |
| GL / AR                    | Via submitted SI                                 | Via submitted SI                                    | **Good**                       |
| Payment Entry              | Standard ERP lifecycle                           | Created through ERP payment APIs                    | **Good**                       |
| Outstanding                | ERP authority                                    | Reconciliation exists                               | **Good direction**             |
| Full settlement            | Standard ERP                                     | `Settled` / payment `Paid` projection               | **Good**                       |
| Partial settlement         | ERP supports it                                  | Some accounting-state support exists                | **Needs lifecycle completion** |
| Multiple installments      | Same invoice can support multiple PE allocations | OMC UX/data semantics not yet sufficiently explicit | **Gap**                        |
| Invoice idempotency        | Task flow: weak                                  | Accounting Link/_ensure_invoice: much stronger      | **OMC better**                 |
| Task invoice compatibility | `Task.invoiced` controls UI                      | Not synchronized after early invoice                | **Dangerous gap**              |
| Duplicate invoice          | Possible                                         | Canonical OMC invoice protected internally          | **Cross-system risk**          |
| Invoice cancellation       | ERP authoritative                                | Must fully re-project into OMC                      | **Audit/hardening needed**     |
| PE cancellation            | ERP authoritative                                | Reconciliation must restore outstanding             | **Hardening needed**           |
| Activation                 | Legacy happens before invoice                    | OMC happens after payment                           | **Intentional change**         |
| Flutter partial payments   | N/A                                              | Current experience centered around current payment  | **Gap**                        |
| Payment history            | ERP has accounting history                       | Needs clean Flutter/API projection                  | **Gap**                        |
| Overpayment prevention     | ERP allocation rules                             | Should reject earlier at OMC API boundary too       | **Needs explicit guard**       |
| Old non-OMC tasks          | Legacy flow                                      | Must remain untouched                               | **Hard requirement**           |

---

# 4. Recommended target architecture

I would **not** move the old `Task.mk_inv()` literally earlier.

Instead, promote OMC's existing accounting integration into the canonical invoice origin for OMC Service Requests.

## Recommended lifecycle

```text
1. Customer selects service
2. OMC captures authoritative pricing snapshot
3. Customer supplies required request information/docs
4. Request becomes financially ready
5. OMC establishes ONE canonical ERP Sales Invoice
6. Customer submits payment/installment
7. Verified money creates ERP Payment Entry against THAT invoice
8. ERP recomputes outstanding
9. OMC reconciliation reads ERP result
10. Activation policy is evaluated
11. When eligible:
       create ERP Service
       create ERP Task
       project Task.invoiced = 1
12. Staff handles normal Task workflow
13. Task completes
14. No new invoice/payment is created
```

The key architectural rule should be:

> **For an OMC-originated Service Request, the request owns the accounting lifecycle. The Task consumes its financial state; it does not originate a second financial lifecycle.**

---

## Financial authority hierarchy

I recommend explicitly enforcing this order:

### Tier 1 — authoritative

```text
ERP Sales Invoice
ERP Payment Entry
ERP accounting/payment ledger
GL
```

### Tier 2 — durable integration identity

```text
OMC Accounting Link
```

### Tier 3 — OMC projections/workflow

```text
OMC Service Payment
OMC Service Request payment/accounting state
Flutter payment state
Task.invoiced
```

If they disagree, Tier 1 wins.

That prevents OMC from becoming a parallel financial ledger.

---

# 5. Partial payment policy

This is the part where I would change the conceptual model slightly.

## One invoice, many settlements

For a normal fixed-price OMC Service Request:

> **One Service Request → one canonical Sales Invoice → zero or more Payment Entries.**

Do **not** create another Sales Invoice for every installment.

Example:

```text
Request payable = 50,000
Invoice = SINV-001, grand_total 50,000

Installment 1
Payment Entry PE-001 = 15,000
ERP outstanding = 35,000

Installment 2
Payment Entry PE-002 = 20,000
ERP outstanding = 15,000

Installment 3
Payment Entry PE-003 = 15,000
ERP outstanding = 0
```

This keeps:

* AR correct
* ledger continuous
* tax invoice singular
* outstanding authoritative
* payment history native to ERP
* reconciliation straightforward

---

## OMC Service Payment semantics

I recommend treating **OMC Service Payment as an installment/payment attempt**, not as the lifetime financial state of the Service Request.

Thus potentially:

```text
Request
 ├── Payment #1 → PE #1
 ├── Payment #2 → PE #2
 └── Payment #3 → PE #3
```

And separately:

```text
Accounting Link
  canonical invoice
  invoice total
  ERP outstanding
  accounting status
```

This distinction becomes essential once partial payment exists.

### Do not overload `Payment.status`

For example:

```text
Payment installment #1 = successfully accounted
```

does not mean:

```text
Request fully Paid
```

Those are two separate facts.

The aggregate state should come from ERP invoice outstanding.

---

## Activation threshold

For the default product behavior, I recommend:

> **Require full ERP settlement before Service/Task activation.**

Why?

Because the explicit business reason for moving payment earlier is to prevent bogus/unfunded work.

If a 1-rupee or arbitrary partial payment activates a 50,000-rupee task, the protection becomes mostly ineffective.

Recommended default:

```text
outstanding > 0
    → Awaiting Payment
    → do not create Service/Task

outstanding == 0
    AND canonical invoice valid/submitted
    AND reconciliation successful
    → Settled
    → activation allowed
```

If the client later wants deposits — e.g. **50% deposit starts work** — make that an explicit, configurable **activation policy**, not an accidental consequence of accepting partial payments.

For now I would keep:

```text
Payment installments: allowed
Operational activation: full settlement
```

That cleanly separates convenience from risk policy.

---

## Overpayment

OMC should reject:

```text
payment_amount > current authoritative outstanding
```

before accounting processing.

Do not intentionally use unallocated Payment Entry balances for this workflow unless the business later explicitly requires customer credits.

Flutter should therefore receive the latest outstanding immediately before accepting another installment.

---

# 6. Generate Invoice compatibility

This is the highest-priority compatibility defect.

There are **three layers** to fix eventually.

## Layer 1 — Task projection

When OMC creates a Task after a canonical Sales Invoice already exists:

```text
Task.invoiced = 1
```

should be projected during Task creation.

This does **not** mean Task created the invoice.

It simply means:

> "The financial demand associated with this Task is already invoiced."

That removes the normal button condition.

For your current runtime example:

```text
TASK-2026-02835.invoiced
```

should conceptually be `1`, because:

```text
SINV-O-03057
```

already exists and is the canonical invoice.

---

## Layer 2 — backfill/synchronization

If the invoice is established before Task creation:

```text
Accounting succeeds
    ↓
later Service/Task created
    ↓
bridge finds canonical submitted SI
    ↓
sets Task.invoiced = 1
```

If Task somehow already exists when accounting gets linked:

```text
canonical invoice established
    ↓
OMC synchronizes Task.invoiced
```

This projection should be idempotent.

---

## Layer 3 — backend duplicate guard

**Do not rely only on hiding the button.**

Someone could still:

* invoke RPC directly
* use bulk invoice generation
* encounter stale browser state
* restore an old Task value
* use another client integration

Therefore OMC needs a server-side compatibility guard.

The principle:

```text
If Task belongs to an OMC Service Request
AND that request already has a valid canonical invoice
    ↓
legacy Generate Invoice must not create another SI
```

It should instead either:

* return/open the canonical invoice, or
* reject clearly with "This OMC request has already been invoiced."

I slightly prefer **return/reuse canonical invoice** where technically safe because it makes old UI behavior graceful.

### Important scope rule

The guard must be narrowly scoped to:

```text
Task demonstrably linked to an OMC-originated request
```

Then:

```text
ordinary old ERP Task
    → unchanged legacy mk_inv behavior
```

This is essential.

---

## No ERPNext core edit

The eventual implementation should be through OMC's Frappe integration/hook layer, not changes under:

```text
apps/erpnext/...
```

Before implementation I would validate the exact Frappe v14 interception mechanism for the dotted whitelisted Task method.

UI suppression alone is insufficient.

---

# 7. Data model changes

The good news: this does **not** require rebuilding the accounting model.

Most of the necessary concepts already exist.

## Keep

### OMC Accounting Link

Use this as the **request-to-canonical-accounting identity record**.

Its essential invariant should become:

```text
one OMC Service Request
        ↔
one active canonical Sales Invoice
```

It should describe accounting state, not duplicate ERP ledger calculations.

---

### OMC Service Payment

Keep it for:

* payment submission
* receipt/evidence
* review
* accounting attempt
* linked Payment Entry
* installment amount
* audit trail

But explicitly support **multiple records per request** if current uniqueness assumptions prevent that.

---

## Likely additive requirements

I would prefer additive fields rather than restructuring existing DocTypes.

Potentially useful projections are:

### Accounting/request level

```text
invoice_total
paid_amount
outstanding_amount
currency
accounting_status
canonical_invoice
```

But calculate/reconcile them from ERP.

Do not let operators manually maintain them.

### Payment/installment level

Each OMC payment should retain:

```text
requested/submitted amount
accounted amount
linked Sales Invoice
linked Payment Entry
receipt evidence
review status
accounting processing status
```

The exact fields should reuse what's already present wherever possible.

---

## Strong invariants

The backend should enforce:

```text
Accounting Link request identity unique
canonical active invoice unique per request
Payment Entry unique per successfully-accounted payment
receipt/idempotency key cannot create duplicate settlement
sum of new allocation cannot exceed current outstanding
```

If an amended ERP invoice legitimately replaces a cancelled one, the link should preserve audit history rather than pretend the old document never existed.

---

# 8. Flutter changes

Flutter should not independently decide financial truth.

It should render one backend accounting view.

## Payment page should become an accounting summary

Something like:

```text
Service fee / Invoice total       Rs 50,000
Paid                              Rs 20,000
Remaining                         Rs 30,000
Status                            Partially Paid

Payment history
────────────────────────────────────────────
Rs 20,000   Verified / Posted    Sep 12
```

And then:

```text
Make another payment
Amount: [ 30,000 ]
Payment account: [...]
Upload receipt: [...]
```

---

## Amount behavior

For a partially outstanding invoice:

```text
minimum > 0
maximum = authoritative outstanding
```

The customer may enter less than remaining if installments are allowed.

Example:

```text
Outstanding: 30,000

allowed:
  5,000
  10,000
  30,000

not allowed:
  30,001
```

The backend must repeat this validation because Flutter validation is only UX.

---

## Required API model

Flutter should ideally receive a single normalized object similar to:

```json
{
  "invoice": "...",
  "currency": "PKR",
  "invoice_total": 50000,
  "paid_amount": 20000,
  "outstanding_amount": 30000,
  "accounting_status": "Partially Settled",
  "activation_status": "Awaiting Full Settlement",
  "can_make_payment": true,
  "maximum_payment_amount": 30000,
  "payments": [...]
}
```

Not necessarily those exact names; the point is to keep calculation server-side.

---

## Payment history

Flutter should show all installments associated with the request.

Each one can expose user-relevant state such as:

```text
Submitted
Under Review
Rejected
Processing Accounting
Posted
```

But aggregate financial language such as:

```text
Paid
Partially Paid
Outstanding
```

should come from the invoice/accounting summary.

---

## Receipt flow

Keep receipt upload/review separate from settlement.

A receipt being approved means:

> the evidence is acceptable to process.

It should **not itself mean the Service Request is financially paid**.

Only ERP posting + reconciliation should establish that.

That preserves your non-negotiable `Paid` rule.

---

# 9. Migration / existing data

Do not bulk-create replacement invoices.

Migration should be **reconciliation-first**.

## Recommended migration classes

### Case A — OMC Accounting Link + valid SI exist

Example: your current request.

```text
Request
→ Accounting Link
→ submitted SI
→ PE(s)
```

Actions:

* reuse SI
* recompute outstanding from ERP
* reconstruct OMC aggregate state
* synchronize Task.invoiced if Task exists
* create nothing financial

---

### Case B — OMC payment has linked SI but Accounting Link incomplete

Recover/link existing documents after validating:

* customer
* request association
* company
* currency
* expected amount
* docstatus

Do not make another SI just because the OMC link is incomplete.

---

### Case C — canonical SI settled but Task.invoiced = 0

Your present example.

Migration:

```text
validate canonical invoice
→ set compatibility projection Task.invoiced = 1
```

No accounting document creation.

---

### Case D — legitimate partial SI

```text
SI total 50k
outstanding 20k
```

Reconcile as:

```text
Partially Settled
paid = 30k
remaining = 20k
```

No new invoice.

Allow another payment toward the same SI.

---

### Case E — duplicate invoices already exist

Do **not** automatically cancel documents.

Queue for financial review.

Need identify:

* submitted vs draft
* which invoice has Payment Entries
* GL impact
* tax consequences
* references
* whether one is clearly orphaned

Automatic "pick newest" or "cancel duplicate" logic is unsafe.

---

### Case F — old non-OMC Tasks

Do nothing.

They remain:

```text
Task complete
→ Generate Invoice
→ client's existing workflow
```

This backward compatibility is mandatory.

---

# 10. Test plan

I would require tests at four layers.

## A. Accounting integration

1. **Full payment**

   * one canonical SI
   * one PE
   * outstanding zero
   * accounting Settled
   * payment Paid only after reconciliation

2. **Partial payment**

   * canonical SI remains same
   * first PE submitted
   * outstanding remains
   * Partially Settled
   * no activation under full-payment policy

3. **Multiple installments**

   * PE1 + PE2 + PE3
   * same SI every time
   * outstanding decreases correctly
   * final reconciliation → Settled

4. **Overpayment**

   * attempt > current outstanding
   * rejected before PE submission
   * no additional accounting document

5. **Duplicate receipt/retry**

   * same event retried
   * does not produce duplicate PE

6. **Concurrent payment processing**

   * two installments attempt against same remaining balance
   * transaction/idempotency control prevents over-allocation

---

## B. Invoice identity

7. Reprocess accounting after canonical SI exists

   * `_ensure_invoice()` returns existing SI

8. Task created after SI

   * `Task.invoiced = 1`

9. Canonical invoice + legacy Generate Invoice invocation

   * no second invoice

10. Bulk Generate Invoice includes OMC Task

* OMC Task cannot create duplicate
* ordinary legacy Tasks retain behavior

11. OMC request without canonical SI

* compatibility guard must not invent arbitrary behavior

---

## C. Reversal/reconciliation

12. Cancel Payment Entry

* ERP outstanding increases
* OMC state leaves Settled as appropriate
* no manual status hack

13. Cancel canonical Sales Invoice

* Accounting Link reflects invalid/cancelled financial state
* request cannot remain falsely Settled

14. Amended invoice

* explicit lineage/reconciliation
* no silent duplicate

15. Retry after transient accounting failure

* safe idempotency

16. Scheduler reconciliation

* heals stale projections from ERP truth

17. Flutter/API state after an external ERP accounting change

* latest state follows ERP

---

## D. Operational lifecycle

18. Full settlement → activation exactly once

19. Partial settlement → no Task under proposed default policy

20. Retry activation

* no duplicate Service
* no duplicate Task

21. Task completes

* no new OMC payment
* no new SI
* no new PE

22. Completed OMC Task

* legacy Generate Invoice unavailable/guarded

23. Existing non-OMC ERP Task

* completes
* Generate Invoice still works as before

---

## E. Flutter

24. full amount payment

25. custom partial amount

26. zero/negative amount rejected

27. amount > outstanding rejected

28. stale outstanding is rejected by backend even if UI displayed old value

29. multiple payment history rendered

30. rejected receipt does not increase paid amount

31. approved evidence awaiting accounting does not show request as financially settled

32. final PE reconciliation moves screen to Paid/Settled

---

# 11. Safe implementation phases

I would do this in **five phases**, each independently testable.

| Phase                            | Scope                                                                                                                       | Likely code areas                                                                                     |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **1. Financial invariants**      | Formalize canonical one-invoice-per-request behavior, authoritative outstanding, installment rules, overpayment/idempotency | `payment_accounting.py`, `accounting_reconciliation.py`, payment APIs, Accounting Link/Payment models |
| **2. Partial settlement**        | Multiple OMC payments/installments → multiple PE allocations to same SI; aggregate state                                    | payment APIs, Service Payment/Receipt schemas if needed, reconciliation                               |
| **3. Activation policy**         | Require authoritative settlement before Service/Task; exactly-once activation                                               | activation/bridge modules, Service Request lifecycle, Bridge Operation                                |
| **4. Legacy Task compatibility** | project `Task.invoiced`, protect Generate Invoice server-side for OMC Tasks while leaving others untouched                  | OMC hooks/integration wrapper, task bridge; **no ERPNext edit**                                       |
| **5. Flutter + migration**       | accounting summary, installment entry/history, remaining amount, reconciliation/backfill tools                              | Flutter payment model/repository/screens + additive reconciliation command/scripts                    |

I would **not** begin with Flutter.

The order should be:

```text
financial invariant
→ reconciliation
→ partial settlement
→ activation semantics
→ legacy compatibility
→ Flutter
→ migration/backfill
```

Otherwise the UI gets built on unstable semantics.

---

# The 35,000 vs 50,000 discrepancy

This remains a **stop condition before financial implementation**.

Observed:

```text
Task.rate = 35,000

canonical Sales Invoice grand_total = 50,000
```

These values are not automatically contradictory because `grand_total` can differ from a base item rate due to taxes/charges, but we should **not assume that explains this case**.

Before changing anything financial, inspect the actual canonical SI:

```text
items[].item_code
items[].rate
items[].amount
net_total
tax rows
total_taxes_and_charges
discounts
grand_total
```

and compare it with the immutable OMC pricing snapshot that fed `_ensure_invoice()`.

There are only two acceptable outcomes:

### Expected difference

For example:

```text
OMC authoritative base amount + tax/charges = 50,000
Task.rate is merely a legacy operational/base field
```

Then Task.rate should **not** drive OMC invoicing.

### Real defect

For example:

```text
request pricing snapshot = 50,000
but Task receives stale service rate = 35,000
```

Then the Task bridge has a projection bug.

Either way, we should settle this before modifying partial-payment architecture because otherwise we could faithfully split payments against the **wrong receivable**.

---

# Final architecture decision

I recommend this as the governing contract:

> **Every OMC Service Request has at most one active canonical ERP Sales Invoice. All legitimate customer installments settle that invoice through ERP Payment Entries. ERP outstanding determines aggregate payment state. Full settlement is the default activation requirement. Service and Task are operational projections created afterward. When the Task appears, `Task.invoiced` reflects that the request was already invoiced, and an OMC-side server guard prevents the client's legacy Generate Invoice mechanism from creating a duplicate. Existing non-OMC Tasks retain their current behavior unchanged.**

That preserves all four things simultaneously:

* **payment-first protection**
* **existing ERP accounting authority**
* **partial-payment support**
* **legacy client ERP compatibility**

And importantly, it does **not** require replacing ERP accounting or editing ERPNext core.

**Audit status:** GitHub `main` inspected at `d3cba074`; no files modified, no schema changes, no commits/pushes, and no new runtime-test claims.
