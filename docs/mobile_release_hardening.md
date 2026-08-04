# OMC mobile release hardening

This checklist is the release evidence record for `com.omchouse.app`. Never
replace an unchecked operational gate with an assumption.

## Required build inputs

- `OMC_ENV=production`
- `OMC_API_BASE_URL=https://erp.omchouse.com`
- `OMC_LINK_BASE_URL=https://erp.omchouse.com`
- `OMC_SENTRY_DSN` supplied by the release environment, never committed
- unique, monotonically increasing Flutter build number

Release startup rejects a missing diagnostics DSN, a non-production profile,
HTTP, a port override, or an API/link host other than `erp.omchouse.com`.

## Domain association deployment

1. Replace the placeholders in `docs/association_files` using the production
   Android signing certificate SHA-256 and Apple Team ID.
2. Deploy the files without redirects or authentication as:
   - `https://erp.omchouse.com/.well-known/assetlinks.json`
   - `https://erp.omchouse.com/.well-known/apple-app-site-association`
3. Confirm correct JSON content type, HTTPS certificate validity, and exact
   production identifiers.
4. Record `curl` output, Android `adb pm get-app-links com.omchouse.app`, and a
   real iOS Universal Link tap. The templates are not deployment evidence.

## Privacy and diagnostics

- Sentry is crash-only: no PII, request/response bodies, screenshots, view
  hierarchy, replay, tracing, profiling, interaction breadcrumbs, or analytics.
- Trigger a controlled production-symbol crash containing synthetic token,
  email, CNIC, phone, payment, and filename values.
- Confirm the received event is symbolicated and contains none of those values.
- Confirm Android Data Safety, Apple App Privacy, the privacy policy, and
  `PrivacyInfo.xcprivacy` all describe the same crash-data collection.

## Artifact verification

```bash
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com \
  --dart-define=OMC_LINK_BASE_URL=https://erp.omchouse.com \
  --dart-define=OMC_SENTRY_DSN="$OMC_RELEASE_SENTRY_DSN"
rg -a -n "100\\.51\\.143\\.221|http://|OMC_USE_MOCK_AUTH" build/app/outputs
sha256sum build/app/outputs/bundle/release/app-release.aab
```

Record the AAB hash, signer identity, clean-install smoke, upgrade smoke, link
verification, biometric/lifecycle tests, and controlled crash event ID. On
macOS, also record the Xcode archive/export hash, signing team, entitlements,
privacy report, Universal Link tap, and dSYM symbolication.

## Rollback

- Disable the Sentry DSN at release configuration if privacy validation fails.
- Keep browser authentication endpoints and the `omchouse://auth` test scheme
  available while HTTPS association is repaired.
- Roll back a rejected store artifact by its recorded hash/build number. Never
  weaken production HTTPS or reintroduce a cleartext exception.
