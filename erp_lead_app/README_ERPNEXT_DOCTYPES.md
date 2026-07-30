# ERPNext Fork DocType Inventory

This report documents the ERPNext source copied under `erp_lead_app/erpnext/`, with emphasis on the client/OMC-specific DocTypes and modified business areas.

> Scope: source files committed under `erp_lead_app/erpnext/`. This tree contains a complete ERPNext fork, not only OMC customisations. Standard ERPNext contains hundreds of DocTypes, child tables and settings records; therefore this report separates the framework modules from the OMC-relevant additions and modifications.

## Source overview

```text
erp_lead_app/erpnext/erpnext/
```

The fork declares the following ERPNext modules:

- Accounts
- CRM
- Buying
- Projects
- Selling
- Setup
- Manufacturing
- Stock
- Support
- Utilities
- Assets
- Portal
- Maintenance
- Regional
- ERPNext Integrations
- Quality Management
- Communication
- Loan Management
- Telephony
- Bulk Transaction
- E-commerce
- Subcontracting
- EDI

## OMC/client-specific CRM DocTypes

The following DocTypes are present in the CRM module and are directly relevant to the client implementation or appear to be client additions beyond the ordinary Lead/Opportunity workflow.

| DocType | Likely role | Source |
|---|---|---|
| App Notification | Server-controlled in-app/mobile notification content | `erpnext/crm/doctype/app_notification/app_notification.json` |
| Appointment | Client appointment scheduling | `erpnext/crm/doctype/appointment/appointment.json` |
| Appointment Booking Settings | Booking configuration | `erpnext/crm/doctype/appointment_booking_settings/appointment_booking_settings.json` |
| Appointment Booking Slots | Available appointment slots | `erpnext/crm/doctype/appointment_booking_slots/appointment_booking_slots.json` |
| Area | Geographic/reference master | `erpnext/crm/doctype/area/area.json` |
| Availability of Slots | Slot availability child/support record | `erpnext/crm/doctype/availability_of_slots/availability_of_slots.json` |
| Banker | Banker/reference contact master | `erpnext/crm/doctype/banker/banker.json` |
| Business Partner | Partner/referral/business relationship master | `erpnext/crm/doctype/business_partner/business_partner.json` |
| City | Geographic/reference master | `erpnext/crm/doctype/city/city.json` |
| Consultant | Consultant/staff relationship master | `erpnext/crm/doctype/consultant/consultant.json` |
| Contract Fulfilment Checklist | Contract checklist tracking | `erpnext/crm/doctype/contract_fulfilment_checklist/contract_fulfilment_checklist.json` |
| Daily Job | Daily operational work record | `erpnext/crm/doctype/daily_job/daily_job.json` |
| Daily Job Status | Daily-job status master | `erpnext/crm/doctype/daily_job_status/daily_job_status.json` |
| Document Management | Customer/internal document tracking | `erpnext/crm/doctype/document_management/document_management.json` |
| Industry Sub Category | Additional industry classification | `erpnext/crm/doctype/industry_sub_category/industry_sub_category.json` |
| Knowledge | Knowledge/help content record | `erpnext/crm/doctype/knowledge/knowledge.json` |
| Market | Market master | `erpnext/crm/doctype/market/market.json` |
| Market Segment | Market segmentation master | `erpnext/crm/doctype/market_segment/market_segment.json` |
| News | News/announcement content | `erpnext/crm/doctype/news/news.json` |
| Period | Filing/service period master | `erpnext/crm/doctype/period/period.json` |
| Sales Team Commission Structure | Commission configuration | `erpnext/crm/doctype/sales_team_commission_structure/sales_team_commission_structure.json` |
| Service | OMC service catalogue/workflow definition | `erpnext/crm/doctype/service/service.json` |
| State | Geographic/reference master | `erpnext/crm/doctype/state/state.json` |
| Tax Associates | Tax-associate master | `erpnext/crm/doctype/tax_associates/tax_associates.json` |
| Tax Calculator | Tax calculation record/tool | `erpnext/crm/doctype/tax_calculator/tax_calculator.json` |
| Tax Details | Tax-calculation/detail child record | `erpnext/crm/doctype/tax_details/tax_details.json` |
| Unit | Organisational/geographic unit master | `erpnext/crm/doctype/unit/unit.json` |

## Standard CRM DocTypes retained in the fork

These standard ERPNext CRM records are also present and form the base business workflow:

- Campaign
- Campaign Email Schedule
- Competitor
- Competitor Detail
- Contract
- Contract Template
- Contract Template Fulfilment Terms
- CRM Note
- CRM Settings
- Email Campaign
- Lead
- Lead Source
- LinkedIn Settings
- Lost Reason Detail
- Opportunity
- Opportunity Item
- Opportunity Lost Reason
- Opportunity Lost Reason Detail
- Opportunity Type
- Prospect
- Prospect Lead
- Prospect Opportunity
- Sales Stage
- Social Media Post
- Twitter Settings

## Key modified standard DocTypes

The client fork also modifies standard ERPNext business DocTypes. These should be treated as integration dependencies, not as isolated custom records.

### Lead

```text
erpnext/crm/doctype/lead/lead.json
erpnext/crm/doctype/lead/lead.py
erpnext/crm/doctype/lead/lead.js
erpnext/crm/custom/lead.json
```

Role in OMC:

- Prospect intake and identity
- Conversion toward customer/service workflows
- Client-specific custom fields and layouts

### Customer

```text
erpnext/selling/doctype/customer/customer.json
erpnext/selling/custom/customer.json
erpnext/custom_customer_method.py
```

Role in OMC:

- Canonical customer master
- Customer ownership and profile data
- Client-specific fields used by the mobile app and backend APIs

### Task

```text
erpnext/projects/doctype/task/task.json
erpnext/projects/doctype/task/task.py
erpnext/projects/doctype/task/task.js
erpnext/projects/custom/task.json
erpnext/crm/custom/task.json
```

Role in OMC:

- Internal case/work assignment
- Service fulfilment and operational status
- Customer, consultant, partner and tax-associate relationships
- Filing/document extraction fields and workflow customisations

### Service workflow logic

The Service DocType controller itself is minimal, while additional workflow logic exists here:

```text
erpnext/service.py
```

This logic links service records to Task creation and operational workflow state.

## Other standard ERPNext domains present

The copied fork includes the full standard ERPNext domain model. Important families include:

### Accounts

Examples: Account, Bank, Bank Account, Budget, Cost Center, GL Entry, Journal Entry, Payment Entry, Payment Request, Purchase Invoice, Sales Invoice, Tax Category, Tax Rule and accounting child tables.

### Buying

Examples: Buying Settings, Purchase Order, Request for Quotation, Supplier, Supplier Quotation and supplier scorecard records.

### Selling

Examples: Customer, Quotation, Sales Order, Sales Partner, Territory, Selling Settings and pricing-related records.

### Projects

Examples: Project, Task, Project Template, Activity Cost, Timesheet and project-related child tables.

### Stock

Examples: Item, Warehouse, Bin, Batch, Serial Number, Stock Entry, Delivery Note, Purchase Receipt, Shipment and inventory child tables.

### Support

Examples: Issue, Issue Type, Service Level Agreement, Support Settings and related service-level records.

### Assets

Examples: Asset, Asset Category, Asset Maintenance, Asset Movement, Asset Repair and depreciation records.

### Manufacturing

Examples: BOM, Work Order, Job Card, Production Plan and manufacturing child tables.

### Setup and Utilities

Examples: Company, Employee, Authorization Rule, naming/configuration masters, import/export tools and system utilities.

## Integration conclusions

1. `erp_lead_app/erpnext` is a complete customised ERPNext fork, not a small standalone app.
2. OMC functionality is concentrated around CRM, Customer, Task, Service, documents, appointments, notifications and tax-operation records.
3. The mobile app should continue treating Frappe/ERPNext as the authority for permissions, ownership, assignments and workflow state.
4. Direct modifications to standard ERPNext DocTypes mean upgrades must be reviewed carefully; replacing this fork with stock ERPNext could remove client fields and behaviour.
5. Payment-specific DocTypes are not in this ERPNext tree; they are defined separately in the `lead_app` report.

## Important security note

Credentials, API keys, Firebase Admin service-account files and environment-specific secrets are not DocTypes and must not be committed. Runtime secrets should be supplied through server configuration or environment variables.
