# OMC App — Backend Product & Workflow Guide

Source cross-check: **25 August 2026**, branch `main`.

This document is the backend-facing product overview for OMC House. For the canonical high-level architecture, see [`../README.md`](../README.md). For detailed workflows, see [`../docs/omc_detailed_explanation.md`](../docs/omc_detailed_explanation.md).

---

## Backend responsibility

The custom Frappe app `omc_app` is responsible for OMC-specific application state and guarded integration with ERPNext.

It provides:

- customer authentication/onboarding/activation support;
- canonical customer access mapping through `OMC Customer Account`;
- canonical internal access through `OMC Staff Access`;
- capability and break-glass enforcement;
- service catalogue and request lifecycle;
- required-document contracts and uploads;
- payment/receipt workflow and settlement gating;
- durable ERP Service/Task activation;
- assignment and task integration;
- referrals and commission lifecycle;
- support and notifications;
- customer migration/reconciliation;
- audit/reconciliation evidence;
- backend APIs consumed by Flutter.

ERPNext remains the source of truth for ERP Customer, Lead, accounting, Service, Task and other ERP-owned records.

---

## Canonical identity model

### Customer

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +--> ERP Customer
        +--> OMC Customer Profile
```

Protected customer access requires a verified/linked/approved canonical account. Customer Profile remains business/profile and legacy compatibility state.

### Staff

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +--> capability rows
        +--> access status
        +--> reconciliation status
        +--> persona evidence
```

`System Manager` is not implicit OMC business authority. Protected internal operations require canonical capabilities.

---

## Service catalogue

The production catalogue is source controlled under:

```text
frappe-bench/apps/omc_app/omc_app/setup/service_catalogue/
```

Current manifest:

```text
9 categories
31 services
17 active
14 inactive/review-required
PKR
Omc House
Full Settlement default policy
```

The catalogue maps only to exact existing ERP Task Types.

Operator commands:

```bash
cd frappe-bench

bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

Normal `bench migrate` does not publish the catalogue.

---

## Customer service lifecycle

Representative canonical request states:

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

The normal paid path is:

```text
Service Request
   -> required documents
   -> payment/receipt workflow
   -> ERP accounting settlement
   -> Ready for Activation
   -> durable bridge
   -> ERP Service + ERP Task
   -> assignment/execution
```

For `Full Settlement`, activation requires settled accounting evidence. OMC payment records do not replace ERP finance authority.

---

## Required documents

Required-document templates and submitted service documents support stable `document_key` identity.

Rules:

- keyed requirements use the key as authority;
- wrong keys do not fall back to matching title/type;
- genuine legacy/unkeyed history can use exact normalized title+type fallback;
- one upload satisfies at most one requirement;
- new requirements can be grandfathered with `effective_from`;
- backend canonicalises requirement title/type before storing keyed uploads.

---

## Durable ERP activation

`OMC Bridge Operation` protects ERP activation with deterministic operation identity, request locking, settlement re-checks, bounded retry, stale-lease recovery, rollback and audit events.

A request cannot become fully Activated unless committed ERP Service and ERP Task links exist.

---

## Customer migration

Existing ERP customer identity is resolved in this priority:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

Migration is designed to avoid bulk customer login-user creation and to preserve ambiguous identities for review.

See [`../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md) for the operator runbook.

---

## Referrals and commissions

Referral ownership, personal commission visibility and finance commission operations are separate capabilities.

The backend preserves referral attribution/provenance separately from payout lifecycle. `OMC Commission Allocation` represents commission entitlement/evidence; finance approval/payment authority is not implied by referral ownership.

---

## Main internal domains

Internal operational areas include:

- internal workspace;
- customer/lead operations;
- service-case queues and assignment;
- task visibility/management;
- document review;
- payment review;
- settlement reconciliation;
- support operations;
- staff access/reconciliation;
- referrals and commissions;
- business/configuration operations;
- bridge recovery;
- audit/reconciliation evidence.

Each protected action must use backend capability/scope checks even if Frappe Desk permissions also allow the record to be displayed.

---

## Setup lifecycle

The current setup lifecycle is deliberately conservative:

```text
before_install -> validate client ERP contract
after_install  -> explicit one-time initialization
after_migrate  -> validation only
```

Deliberate setup operations include:

```text
initialize_site
repair_permissions
sync_desk_configuration
apply_site_branding
preview_service_catalogue
validate_service_catalogue
sync_service_catalogue
```

---

## Validation

Latest directly observed implementation validation before the documentation refresh:

```text
Backend OMC suite:             932 / 932 passed
Catalogue managed objects:     195 unchanged
Catalogue conflicts/blockers:  0 / 0
```

Run validation against the exact environment being released:

```bash
cd frappe-bench
bench --site <site> run-tests --app omc_app --skip-test-records
bench --site <site> execute omc_app.setup.operations.validate_service_catalogue
```

---

## Documentation map

- [`../README.md`](../README.md) — canonical high-level architecture;
- [`../docs/ROLE.md`](../docs/ROLE.md) — roles/personas/capabilities;
- [`../docs/OMC_APP_FEATURES.md`](../docs/OMC_APP_FEATURES.md) — feature catalogue;
- [`../docs/omc_detailed_explanation.md`](../docs/omc_detailed_explanation.md) — detailed business/workflow architecture;
- [`deploy/README.md`](deploy/README.md) — deployment toolkit;
- [`frappe-bench/apps/omc_app/README.md`](frappe-bench/apps/omc_app/README.md) — Frappe app engineering guide.
