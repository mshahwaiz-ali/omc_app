# OMC App Role and Access Guide

This document is the canonical functional guide for how roles must work across the OMC Flutter app and Frappe backend.

The implementation source of truth is the application code, especially:

- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/roles.py`
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/permissions.py`
- backend capability and mobile API modules
- Flutter authentication, routing, shell navigation, and capability checks

If this guide and the implementation differ, the mismatch is a defect.

---

## 1. Core access rules

1. **Default deny** — authenticated users do not gain access merely because a route or endpoint exists.
2. **Backend enforcement** — hiding UI is never sufficient; APIs must enforce the same rule.
3. **Capabilities drive Flutter** — routes, navigation, home actions, and buttons use canonical capabilities.
4. **Ownership and assignment matter** — customers access only their own data; specialists access assigned or relevant records.
5. **Least privilege** — every role