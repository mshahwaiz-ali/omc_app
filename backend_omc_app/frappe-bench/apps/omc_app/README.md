# OMC App — Frappe Backend Engineering Guide

Source cross-check: **25 August 2026**, branch `main`.

This directory contains the custom Frappe application `omc_app` used by the OMC House Flutter/customer platform.

The current client deployment target is **Frappe/ERPNext v14**. The package declares Python `>=3.10`; the checked-in deployment toolkit currently provisions Python 3.10 for the v14 runtime.

> OMC business logic belongs in this custom app. Do not patch ERPNext source files to implement OMC features.

---

## Backend responsibilities

The app provides:

- customer onboarding/login/activation support;
- canonical customer mapping through `OMC Customer Account`;
- canonical internal authority through `OMC Staff Access`;
- backend capability and break-glass checks;
- service catalogue and service templates;
- service request lifecycle;
- stable required-document identity and uploads;
- payment/receipt workflow;
- accounting settlement reconciliation;
- durable ERP Service/Task activation;
- assignment and workflow automation;
- referrals and commission lifecycle;
- support, notifications and customer settings;
- tax/expense tools;
- customer/staff migration and reconciliation;
- audit/security evidence;
- APIs consumed by Flutter.

---

## Canonical authority

### Customer

```text
Frappe Website User
        -> OMC Customer Account
              -> ERP Customer
              -> OMC Customer Profile compatibility link
```

### Staff

```text
Frappe System User
        -> OMC Staff Access
              -> explicit capabilities
              -> approval/reconciliation state
              -> optional scoped break-glass grants
```

`System Manager` is not implicit OMC business authority.

---

## Main package map

```text
omc_app/
├── api/                         # guarded API/workflow modules
├── omc_app/doctype/             # OMC DocTypes
├── patches/                     # controlled data/schema patches
├── setup/                       # roles, lifecycle, catalogue, reconciliation
├── fixtures/
├── public/
├── hooks.py
└── README.md
```

Important setup area:

```text
omc_app/setup/service_catalogue/
```

which contains the source-controlled production service catalogue manifest, requirements and provisioner.

---

## Production service catalogue

Current manifest:

```text
9 categories
31 services
17 active
14 inactive/review-required
PKR
Omc House
Full Settlement default activation policy
```

Operator entrypoints:

```bash
cd ../../..

bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

`preview` and `validate` are read-only. `sync` is an explicit reconciliation.

Normal `bench migrate` does not publish the catalogue.

---

## Setup lifecycle

Current lifecycle behavior:

```text
before_install -> validate_site
after_install  -> initialize_site(commit=False)
after_migrate  -> validate_site only
```

Normal migration deliberately does not rewrite roles, branding, Desk/workspace metadata or catalogue content.

Deliberate operator operations include:

```text
initialize_site
repair_permissions
sync_desk_configuration
apply_site_branding
seed_tax_calculator_defaults
seed_business_rental_tax_slabs
sync_service_task_type_mappings
preview_service_catalogue
validate_service_catalogue
sync_service_catalogue
```

Use only the operations required by the deployment plan.

---

## Service request lifecycle

Canonical request-state examples:

```text
Draft
Pending Payment
Payment Not Required
Ready for Activation
Activating
Activated
Activation Failed
Financial Hold
Expired
Cancelled
```

Customer-facing operational status is a compatibility projection over the canonical lifecycle.

Full-settlement activation requires accounting settlement evidence before the durable ERP bridge may create/confirm operational links.

---

## Required-document identity

`OMC Service Required Document` and `OMC Service Document` support stable `document_key` identity.

Rules:

- keyed requirement + keyed upload -> key is authoritative;
- wrong key never falls back to title/type;
- legacy/unkeyed history can use exact normalized title+type compatibility;
- one upload satisfies at most one requirement;
- new requirements can be request-grandfathered by `effective_from`;
- the backend canonicalises requirement identity on upload.

---

## Durable ERP bridge

`OMC Bridge Operation` protects ERP activation with:

- deterministic operation keys;
- request locking;
- eligibility/settlement re-checks;
- bounded retries/backoff;
- stale-processing lease recovery;
- savepoint rollback;
- explicit terminal states;
- capability-gated recovery;
- audit events.

A request cannot complete activation without committed ERP `Service` and `Task` links.

---

## Referrals and commissions

Referral ownership, personal commission visibility, and finance commission operations are separate capability domains.

`OMC Commission Allocation` is evidence/entitlement state; it does not turn a referral owner into a finance reviewer.

Historical attribution and commission evidence should preserve provenance instead of guessing it.

---

## Local Bench workflow

From the repository root:

```bash
cd backend_omc_app/frappe-bench
bench list-sites
bench --site <site> list-apps
bench start
```

For an existing site after code/schema changes:

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

Do not recreate an existing client site/Bench for ordinary development or application updates.

---

## App package installation

If the app source is already in `apps/omc_app`:

```bash
cd backend_omc_app/frappe-bench
./env/bin/pip install -e apps/omc_app
./env/bin/python -c "import omc_app; print('OMC App import: OK')"
```

First site installation:

```bash
bench --site <site> install-app omc_app
bench --site <site> migrate
```

---

## Validation

Run the backend suite against the exact environment being released:

```bash
cd backend_omc_app/frappe-bench

bench --site <site> run-tests \
  --app omc_app \
  --skip-test-records
```

Latest directly observed suite before this documentation refresh:

```text
Ran 932 tests
OK
```

Catalogue validation:

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Latest observed production catalogue state was 195 managed objects unchanged with zero conflicts/blockers.

---

## Security rules

- backend checks are authoritative;
- unknown access fails closed;
- customers are ownership-scoped;
- staff operations require canonical capability/scope;
- System Manager does not silently gain OMC authority;
- explicit break-glass grants are temporary/scoped;
- sensitive mutations use guarded APIs;
- customer identity ambiguity is reviewed rather than guessed;
- payment/accounting eligibility is re-checked before ERP activation;
- stable document keys cannot be bypassed by matching labels;
- ERPNext source remains untouched.

---

## Related documentation

- [`../../../../../README.md`](../../../../../README.md) — repository architecture;
- [`../../../../../docs/ROLE.md`](../../../../../docs/ROLE.md) — access/capabilities;
- [`../../../../../docs/OMC_APP_FEATURES.md`](../../../../../docs/OMC_APP_FEATURES.md) — features;
- [`../../../../../docs/omc_detailed_explanation.md`](../../../../../docs/omc_detailed_explanation.md) — business workflow;
- [`../../../deploy/README.md`](../../../deploy/README.md) — deployment toolkit.
