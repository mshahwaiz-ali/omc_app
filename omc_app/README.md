# OMC App Python Package

This directory is the Python package for the custom OMC House Frappe application.

For the full backend engineering guide, see [`../README.md`](../README.md).

## Key areas

```text
api/                    guarded mobile/internal APIs and workflow services
omc_app/doctype/        OMC-owned DocTypes
setup/                  setup lifecycle, roles, reconciliation, catalogue
patches/                controlled migration/repair patches
public/                 app-owned static assets
hooks.py                Frappe hooks
```

## Architecture rules

- ERPNext remains the source of truth for ERP-owned business records.
- OMC customer access is canonicalised through `OMC Customer Account`.
- OMC internal access is canonicalised through `OMC Staff Access` + capabilities.
- `System Manager` is not implicit OMC business authority.
- Service catalogue identity is source controlled and maps to exact ERP Task Types.
- Required service documents use stable `document_key` identity where available.
- ERP Service/Task activation is gated through the OMC request/payment/accounting lifecycle and durable bridge.
- ERPNext source code must not be patched to implement OMC features.

## Validation

From the Bench directory:

```bash
bench --site <site> run-tests --app omc_app --skip-test-records
bench --site <site> execute omc_app.setup.operations.validate_service_catalogue
```

Latest directly observed backend suite before the documentation refresh: **932 / 932 passed**.

## License

See the app-level `license.txt` and repository licensing/ownership terms.
