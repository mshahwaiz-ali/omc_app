# final_modi.md implementation progress

Last updated: 2026-07-08
Branch: `main`

This checklist tracks what has been implemented against `docs/final_modi.md`. It intentionally judges progress from actual project files, not README claims.

## Completed on GitHub main

- Verified `main` is the working branch target.
- Verified the invalid nested backend copies are gone from the earlier bad path pattern:
  - `backend_omc_app/apps/omc_app/omc_app/omc_app/api/...`
- Confirmed valid backend API structure still exists under:
  - `backend_omc_app/apps/omc_app/omc_app/api/mobile.py`
  - `backend_omc_app/apps/omc_app/omc_app/api/secured_mobile.py`
  - `backend_omc_app/apps/omc_app/omc_app/api/guest_session.py`
  - `backend_omc_app/apps/omc_app/omc_app/api/service_templates.py`
- Confirmed valid backend DocType structure still exists under:
  - `backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/omc_guest_session/`
  - `backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/omc_service_form_field/`
  - `backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/omc_service_stage_template/`
- Added frontend guest session tracking:
  - Stable guest device/session identifiers are persisted locally.
  - Continue as Guest calls the backend guest session API.
  - Guest tracking is non-blocking; guest mode remains usable if the backend call fails.
  - Login marks an existing guest session as converted when possible.
- Expanded the service template backend API:
  - `omc_app.api.service_templates.get_service_template` now returns `form_schema`, `stages`, and `required_documents`.
  - Shared helper `get_template_for_service(service_name)` is available for safe future reuse.
- Added Flutter service template foundation:
  - `ServiceTemplate`, `ServiceTemplateField`, and `ServiceStageTemplate` models.
  - `ServiceTemplateRepository` calling `ApiConfig.serviceTemplateMethod`.
  - `serviceTemplateProvider` Riverpod family provider.
  - `ServiceItem` now parses backend `form_schema`, `stages`, and detailed required document payloads when present.
- Connected backend templates into the service catalogue load path:
  - Catalogue services are enriched from `ApiConfig.serviceTemplateMethod`.
  - Template failures are per-service non-blocking, so the catalogue still loads.
- Added backend content frontend repository:
  - `appBannersProvider` calls `ApiConfig.appBannersMethod`.
  - `appFaqsProvider` calls `ApiConfig.faqsMethod`.
  - Added typed models for app banners and FAQs.
- Confirmed notifications repository already supports:
  - `mobile_route` / `action_url` parsing.
  - Mark-one-read API.
  - Mark-all-read API.
- Confirmed Settings screen exists and already includes major customer-safe items:
  - Profile shortcut.
  - Backend-backed notification preferences.
  - App version/build using `package_info_plus`.
  - Security/account-support request sheet.
  - Logout confirmation.
  - No customer-visible API URL/debug flags found in inspected settings file.
- Confirmed expense tracker already has a local-first base:
  - Local transaction repository/controller.
  - Local-only storage banner.
  - Monthly/current summary cards.
  - Period filters.
  - Local export/import JSON.
  - No automatic cloud upload path found in the inspected screen.

## Remaining before calling `final_modi.md` fully complete

- `omc_app/lib/features/service_requests/presentation/service_request_draft_screen.dart`
  - Dynamic rendering from `service.formSchema` still needs to be wired into the actual request form.
  - Submitted dynamic values should go under `additionalDetails` / `form_data` without removing the existing static payload.
  - The catalogue now supplies template fields, but the draft UI still needs the final renderer.
- Home/content UI:
  - App banners and FAQs now have frontend providers.
  - Home and Support screens still need UI cards wired to those providers.
- Settings polish:
  - Add Privacy policy, Terms, and Delete account request tiles if they are required for the first release.
  - Current settings screen already has version, preferences, profile, account/security request and logout.
- Expense sync consent:
  - Current tracker is local-only and safe.
  - Optional cloud sync CTA/confirmation still needs implementation only if/when backend sync is intentionally enabled.

## Validation to run after pulling main

```bash
cd ~/data_drive/app_omc
git pull origin main
```

Backend:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local execute omc_app.api.guest_session.create_guest_session --kwargs "{'device_id':'test-device','platform':'android','app_version':'1.0.0'}"
bench --site omc.local execute omc_app.api.service_templates.get_service_template --kwargs "{'service_id':'tax-filing'}"
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
bench --site omc.local execute omc_app.api.mobile.get_knowledge
bench --site omc.local execute omc_app.api.mobile.get_app_banners
bench --site omc.local execute omc_app.api.mobile.get_faqs
```

Flutter:

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
flutter test
```

## Safety notes

- No new branch was created.
- No README progress claims were used.
- Backend permission enforcement remains the source of truth.
- Flutter changes are additive and intended to preserve existing working flows.
- Local validation was not run from this GitHub-only session.
