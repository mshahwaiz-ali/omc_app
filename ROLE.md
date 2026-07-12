# OMC Role and Access Model

This document is the canonical access model for the OMC App and Frappe backend.

## Canonical roles

### Active portal roles

- `OMC Customer` — normal mobile/customer account. Approval state controls protected access.
- `OMC Business Partner` — active Website User role for partner accounts.
- `OMC Tax Associate` — active Website User role for tax-associate accounts.

Portal roles do not receive broad Desk DocPerms. Their access remains API-owned.

### Active internal roles

- `OMC Admin` — full OMC operations administration.
- `OMC Manager` — operational administration without delete or share rights.

Internal staff are `System User` accounts. Portal/customer accounts are `Website User` accounts.

### Disabled legacy roles

- `OMC Customer Applicant`
- `OMC Customer Support`
- `OMC Support Agent`
- `OMC Document Reviewer`
- `OMC Finance Reviewer`
- `OMC Consultant`

These roles remain disabled for compatibility with older databases and must not be assigned to new users.

## Public signup and approval

Public mobile signup assigns only `OMC Customer`. Values such as `register_as`, customer type, company name, CNIC, NTN, education, experience, and remarks remain profile metadata and must never become permission roles.

The normal approval flow is:

1. Signup creates or updates a `User` and `OMC Customer Profile`.
2. The user remains a Website User with `OMC Customer`.
3. Initial profile state is normally `customer_status = Pending` and `approval_status = Pending Review`.
4. OMC Admin or OMC Manager reviews the profile.
5. Approved profiles use `customer_status = Active` and `approval_status = Approved`.
6. Flutter unlocks protected features from backend capability flags and `access_state`.

## Permission model

### OMC Admin

For non-child `OMC %` DocTypes, Admin receives broad operational permissions including read, write, create, delete, report, export, import, print, email, share, and select. Submit, cancel, and amend follow the DocType's submittable state.

### OMC Manager

Manager receives the same operational access except:

- delete is disabled;
- share is disabled.

### OMC Mobile Quick Action exception

The verified local permission design is intentionally narrower:

- OMC Admin: normal create/write/delete access, but report, import, and select are disabled.
- OMC Manager: read-only; all other permission flags are disabled.

### Portal roles

`OMC Customer`, `OMC Business Partner`, and `OMC Tax Associate` receive no broad Desk DocPerm rows. Access is enforced through application APIs and profile/account state.

## Persistence and installation

The canonical implementation lives in `omc_app.setup.roles`.

- `after_install` provisions roles and permissions on new sites.
- `omc_app.patches.sync_canonical_roles_20260712` corrects existing sites.
- The shared synchronizer is idempotent and does not commit internally.
- It does not modify users, `Has Role` assignments, or Administrator.
- Legacy role DocPerms are removed while legacy Role records remain disabled.

## Runtime behavior

Runtime access code imports the same canonical constants used by installation and migration code. Only `System Manager`, `OMC Admin`, and `OMC Manager` are internal roles. Business Partner and Tax Associate remain active portal roles and are not stripped during user normalization.
