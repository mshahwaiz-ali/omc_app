# OMC Role and Access Model

This document is the canonical access model for the OMC App and Frappe backend.

## 1. User types

| User type | Created from | Frappe role | Main purpose |
|---|---|---|---|
| Guest | Mobile app without login | None | Public browsing, public content, tax calculator, local-only lite expense tracker |
| OMC Customer | Mobile signup or backend-created customer account | `OMC Customer` | Normal customer/client account. Approval state controls protected access. |
| OMC Admin | Frappe Desk/backend only | `OMC Admin` | Full OMC operations administration |
| OMC Manager | Frappe Desk/backend only | `OMC Manager` | Operational admin without destructive/system-level rights |
| OMC Customer Support | Frappe Desk/backend only | `OMC Customer Support` | Support/chat focused staff access |

## 2. Public signup vs backend-created users

### Public mobile signup

A person who signs up from the mobile app is always treated as a customer applicant/profile, not an internal user.

Public signup may collect values such as `register_as`, `customer_type`, company name, CNIC, NTN, education, experience, or remarks. These values are customer profile metadata only. They must never become permission roles.

Public signup must never assign:

- `OMC Admin`
- `OMC Manager`
- `OMC Customer Support`
- Any other internal Frappe/System role

The only normal client role is:

- `OMC Customer`

The user can still remain locked in the app until their customer profile is approved.

### Backend/Frappe-created users

Internal staff are created and managed manually from Frappe Desk/backend.

Use these roles only:

- `OMC Admin`
- `OMC Manager`
- `OMC Customer Support`

Internal staff should be `System User` accounts. Customer/mobile accounts should be `Website User` accounts.

## 3. Customer approval flow

1. User signs up from the mobile app.
2. Backend creates or updates a `User` and an `OMC Customer Profile`.
3. Backend keeps/assigns `OMC Customer` only.
4. Initial profile state remains pending, normally:
   - `customer_status = Pending`
   - `approval_status = Pending Review`
5. Internal admin/manager reviews the profile in Frappe.
6. When approved, backend/profile state becomes:
   - `customer_status = Active`
   - `approval_status = Approved`
7. Flutter unlocks customer protected features from backend capability flags and `access_state = approved`.
8. If rejected, Flutter uses `access_state = rejected` and keeps protected features locked.

## 4. Role permission matrix

| Area / DocType group | OMC Customer | OMC Customer Support | OMC Manager | OMC Admin |
|---|---:|---:|---:|---:|
| Public catalogue/content | API/public only | Read if needed | Full operational | Full |
| Customer profile | Own profile through API only | Read basic profile context | Read/create/write/review/approve | Full |
| Service requests/cases | Own approved-customer API only | Read related context | Read/create/write/submit/review | Full including delete where safe |
| Service documents | Own approved-customer API only | Prefer read-only | Read/create/write/review | Full including delete where safe |
| Service payments | Own approved-customer API only | Read-only if support context needs it | Read/create/write/review/submit where applicable | Full including delete where safe |
| Support tickets/messages | Own approved-customer API only | Read/create/write/status/chat | Read/create/write/status/chat | Full |
| Expense tracker cloud data | Own approved-customer API only | No default edit | Operational read/review if backend enabled | Full |
| Mobile settings/content | No | No | Can manage configured OMC operational/mobile content | Full |
| Tax calculator settings/slabs | No | No | Can manage operational config if needed | Full |
| Delete records | No | No | No by default | Yes where DocType allows |
| System-level roles/settings | No | No | No destructive/system-level permissions | Full OMC app administration |

## 5. Flutter feature access matrix

Flutter should stay simple and backend-driven.

| Feature | Guest | Pending customer | Approved OMC Customer | Rejected customer | Internal staff |
|---|---:|---:|---:|---:|---:|
| Public catalogue/content | Yes | Yes | Yes | Yes | Yes |
| Tax calculator | Yes | Yes | Yes | Yes | Yes |
| Lite local expense tracker | Yes | Yes | Optional | Yes | No customer mode by default |
| Cloud expense sync | No | No | Yes, if backend enabled | No | No customer mode by default |
| Receipt upload | No | No | Yes, if backend enabled | No | Staff workflow only |
| Service request creation | No | Locked | Yes | Locked | Staff workflow only |
| Documents | No | Locked | Yes | Locked | Role-based internal access |
| Payments | No | Locked | Yes | Locked | Role-based internal access |
| Support tickets/chat | No or public contact only | Locked | Yes | Locked | Support/admin workspace |
| Notifications | Public only | Locked/customer state notices | Yes | Locked/customer state notices | Internal workspace notices if implemented |
| Internal workspace | No | No | No | No | Yes for `OMC Admin`, `OMC Manager`, `OMC Customer Support` |

## 6. Manager scope

`OMC Manager` is the safe operational admin role.

Can do:

- Review and approve customers.
- Manage service cases and operational workflows.
- Review/manage service documents.
- Review/manage payments where configured.
- Manage support tickets and status.
- Manage OMC mobile/content/config doctypes needed for operations.
- Read/export operational OMC records where needed.

Cannot do by default:

- Delete OMC records.
- Manage destructive/system-level settings.
- Act as a full system administrator.
- Assign arbitrary internal roles unless separate Frappe permissions allow it.

## 7. Customer Support scope

`OMC Customer Support` is support/chat focused.

Can do:

- Access internal support workspace.
- Read enough customer/profile/service context to answer support issues.
- Read/create/write support tickets and support messages.
- Update support ticket status where the app exposes it.
- View payment or document context only as read-only support context when required.

Cannot do:

- Delete records.
- Approve payments.
- Approve documents by default.
- Manage mobile/system/settings/configuration.
- Approve customers unless explicitly promoted to Manager/Admin.

## 8. Legacy role cleanup

The cleanup patches consolidate older/over-split roles into this model.

Legacy client role:

- `OMC Customer Applicant` -> replaced by `OMC Customer` plus profile approval state.

Legacy internal roles:

- `OMC Support Agent` -> replaced by `OMC Customer Support`.
- `OMC Document Reviewer` -> replaced by `OMC Manager`/`OMC Admin` operational review rights.
- `OMC Finance Reviewer` -> replaced by `OMC Manager`/`OMC Admin` operational review rights.
- `OMC Consultant`, `OMC Business Partner`, `OMC Tax Associate` -> treated as customer profile metadata or operational assignment metadata, not app permission roles.

These legacy roles should not be used for new users.

## 9. Final behavior target

- Mobile user signs up.
- Customer profile appears in Frappe.
- Admin/Manager reviews and approves/rejects.
- Backend keeps only `OMC Customer` as the customer permission role.
- Flutter unlocks customer features only when backend returns approved customer capabilities.
- Staff are created manually in Frappe and assigned one of the internal roles.
- Frappe permissions and Flutter capabilities follow the same role/access model.
