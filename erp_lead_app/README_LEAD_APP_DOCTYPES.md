# Lead App DocType Inventory

This report documents the DocTypes defined inside the client `lead_app` source tree.

> Scope: source files under `erp_lead_app/lead_app/`. This is a source-code inventory, not a database/site export.

## Summary

| Item | Value |
|---|---:|
| Frappe module | `lead_app` |
| DocTypes | 2 |
| Single DocTypes | 1 |
| Transaction DocTypes | 1 |
| Child-table DocTypes | 0 |

## 1. EPG Settings

**Type:** Single DocType  
**Purpose:** Stores the configuration required to connect the ERP backend to the EPG payment gateway.

**Source**

```text
erp_lead_app/lead_app/lead_app/lead_app/doctype/epg_settings/epg_settings.json
```

### Main configuration groups

- Gateway endpoint and sandbox mode
- Merchant/customer identity
- Channel, store and terminal identifiers
- Username and password credentials
- Currency and transaction hint
- Payment return/callback URL
- Payment Entry account and automatic Payment Entry creation

### Important fields

| Field | Type | Required | Notes |
|---|---|---:|---|
| `api_url` | Data | Yes | EPG API endpoint |
| `customer` | Data | Yes | Merchant/customer name |
| `is_sandbox` | Check | No | Enables sandbox operation |
| `channel` | Data | Yes | Payment channel |
| `username` | Data | Yes | Gateway username |
| `password` | Password | Yes | Gateway password; must remain server-side |
| `store` | Data | Yes | Store identifier |
| `terminal` | Data | Yes | Terminal identifier |
| `currency` | Data | Yes | Defaults to PKR |
| `transaction_hint` | Data | Yes | Gateway transaction flags |
| `return_path` | Data | Yes | EPG callback/return URL |
| `payment_account` | Link → Account | No | Bank/cash account for receipts |
| `auto_create_payment_entry` | Check | No | Creates and submits Payment Entry on success |

### Access

The source grants management access to `System Manager` and `Administrator` roles. The DocType tracks changes.

## 2. EPG Payment Transaction

**Type:** Regular transaction DocType  
**Naming:** `EPG-.#####`  
**Purpose:** Records the lifecycle and responses of an EPG payment attempt.

**Source**

```text
erp_lead_app/lead_app/lead_app/lead_app/doctype/epg_payment_transaction/epg_payment_transaction.json
```

### Main data groups

- Order and transaction identity
- Amount, currency and payment status
- Gateway response and approval details
- Masked card information
- Payment portal URL
- Dynamic reference to the originating document
- Linked Payment Entry
- Initiated/completed timestamps
- Raw registration and finalisation responses
- Error details

### Important fields

| Field | Type | Required | Notes |
|---|---|---:|---|
| `order_id` | Data | Yes | EPG order identifier |
| `order_name` | Data | No | Human-readable order reference |
| `transaction_id` | Data | No | Read-only gateway transaction ID |
| `amount` | Currency | Yes | Payment amount |
| `currency` | Data | No | Defaults to PKR |
| `status` | Select | No | Initiated, Redirected, Pending, Success, Failed or Error |
| `user` | Link → User | No | User who initiated the payment |
| `response_code` | Data | No | Gateway response code |
| `response_description` | Small Text | No | Gateway response description |
| `approval_code` | Data | No | Gateway approval code |
| `card_number` | Data | No | Masked card number only |
| `card_brand` | Data | No | Card scheme/brand |
| `payment_portal_url` | Long Text | No | Redirect URL |
| `reference_doctype` | Link → DocType | No | Type of originating document |
| `reference_name` | Dynamic Link | No | Originating document name |
| `payment_entry` | Link → Payment Entry | No | Accounting record created after payment |
| `initiated_at` | Datetime | No | Start timestamp |
| `completed_at` | Datetime | No | Completion timestamp |
| `registration_response` | Code (JSON) | No | Registration API response |
| `finalization_response` | Code (JSON) | No | Finalisation API response |
| `error_message` | Small Text | No | Failure detail |

## Integration observations

- The app is a focused payment-integration app rather than a broad business-domain app.
- It relies on ERPNext/Frappe standard DocTypes including `Account`, `Payment Entry`, `User` and dynamic document references.
- Gateway credentials must remain outside mobile clients and public repositories.
- The transaction DocType provides traceability for payment registration, redirect, callback, accounting and failure handling.
