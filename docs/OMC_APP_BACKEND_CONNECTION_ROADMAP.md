# OMC App Backend Connection Roadmap

## Purpose

This document defines the roadmap for connecting the OMC Flutter mobile app with the OMC Frappe backend and moving the system from local development to production deployment.

The main goal is to make the Flutter app the permanent customer-facing UI, while Frappe works as the backend, API layer, database system, and admin/back-office panel.

---

## Final Architecture

The final production architecture will be:

```text
Customer / User
   ↓
Flutter Mobile App
   ↓ HTTPS API Calls
Frappe Backend
   ↓
MariaDB / Frappe DocTypes / Files / Business Logic
```

### Role of Flutter

Flutter will be the permanent mobile UI for app users.

It will handle:

* Login and session handling
* Home dashboard
* Service requests
* Documents
* Payments
* Support
* Notifications
* Profile and settings
* Customer-facing workflows

### Role of Frappe

Frappe will not be the main UI for mobile users.

Frappe will handle:

* Backend APIs
* Authentication
* Database and DocTypes
* File uploads
* Business logic
* Admin/back-office operations
* Reports and internal management
* Optional ERPNext integration later, if required

---

## Important Concept

The Flutter app and the Frappe backend are two separate parts of the system.

The mobile app is installed on the user's phone through the Play Store.

The Frappe backend runs on a server/cloud/VPS.

The Play Store does not host the backend. It only distributes the Android app.

```text
Play Store
   ↓
Installs Flutter App on user phone
   ↓
Flutter App connects to production Frappe backend URL
```

Example production backend URL:

```text
https://api.omchouse.com
```

---

## Current Local Development Setup

During development, the backend is running locally on the laptop using Frappe Bench.

The Flutter app is also running locally for testing.

Current local flow:

```text
Flutter App
   ↓
Local Frappe Backend
   ↓
Local Frappe Database
```

Example local backend URL:

```text
http://127.0.0.1:8000
```

This is only for local development.

Production users will not connect to the laptop. Production users will connect to the cloud/server backend.

---

## Local Testing Plan

The first milestone is to make the app fully work with the local Frappe backend.

### Local Testing Goals

We need to confirm:

* Flutter can connect to Frappe
* Login works with real Frappe backend
* Session/auth handling works
* Dashboard APIs work
* Service request APIs work
* File upload works
* Documents module works
* Payments module works
* Support module works
* Profile/settings APIs work
* Error handling is clean when backend is unavailable

---

## Local Testing Modes

### 1. Flutter Web / Chrome Testing

Use this when testing on the same laptop.

```bash
cd ~/data_drive/app_omc/omc_app

flutter run -d chrome \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

### 2. Android Emulator Testing

Android emulator cannot use `127.0.0.1` to access the laptop backend.

For emulator, use:

```text
http://10.0.2.2:8000
```

Command:

```bash
cd ~/data_drive/app_omc/omc_app

flutter run \
  --dart-define=OMC_API_BASE_URL=http://10.0.2.2:8000
```

### 3. Physical Android Device Testing

For a real Android phone on the same Wi-Fi network, use the laptop's local network IP.

Find laptop IP:

```bash
hostname -I
```

Example:

```text
192.168.1.50
```

Then run:

```bash
cd ~/data_drive/app_omc/omc_app

flutter run \
  --dart-define=OMC_API_BASE_URL=http://192.168.1.50:8000
```

The Frappe backend must be accessible on the local network for this to work.

---

## Development Roadmap

## Phase 1 — Local Backend Connection

This is the current phase.

Goal: make Flutter work properly with local Frappe APIs.

### Tasks

* Start local Frappe backend
* Confirm Frappe site is running
* Confirm OMC backend app is installed
* Confirm required APIs are whitelisted
* Configure Flutter `OMC_API_BASE_URL`
* Test login
* Test session persistence
* Test API client
* Test service request list
* Test service request create
* Test file upload
* Test documents
* Test payments
* Test support
* Test profile/settings
* Fix local connection issues

### Success Criteria

This phase is complete when the Flutter app works with the local Frappe backend without mock data for the main flows.

---

## Phase 2 — API Contract Freeze

Before UI polish and production deployment, the API contract should be documented and stabilized.

Create a dedicated API documentation file later, for example:

```text
docs/API_ENDPOINTS.md
```

Each API should define:

* Endpoint path
* Request method
* Request body
* Response body
* Error response
* Authentication requirement
* Related Flutter screen/module
* Related Frappe method/DocType

Example:

```text
POST /api/method/omc_app.api.mobile.login

Request:
{
  "usr": "user@example.com",
  "pwd": "password"
}

Response:
{
  "success": true,
  "user": {},
  "sid": "..."
}
```

### Why This Matters

Without a fixed API contract, Flutter and Frappe can easily drift apart.

A stable API contract makes the app easier to maintain, test, deploy, and scale.

---

## Phase 3 — UI Polish

After local backend connection is stable, UI polish should begin.

UI polish should not be done before the backend flow is stable, because screens may still need changes based on real data.

### UI Polish Scope

* Improve spacing
* Improve empty states
* Improve loading states
* Improve error states
* Improve form validation
* Improve service request screens
* Improve dashboard cards
* Improve profile/settings
* Improve document and payment screens
* Make UI consistent across modules
* Remove temporary development wording
* Make the app feel production-ready

### Rule

Backend-connected functionality comes first.

UI polish comes after the main flows are stable.

---

## Phase 4 — Staging Deployment

Before production, deploy a staging backend.

Example staging URL:

```text
https://staging-api.omchouse.com
```

Flutter staging command:

```bash
flutter run \
  --dart-define=OMC_ENV=staging \
  --dart-define=OMC_API_BASE_URL=https://staging-api.omchouse.com
```

### Staging Goals

* Test app on real devices
* Test HTTPS connection
* Test real server performance
* Test file upload
* Test login/session handling
* Test production-like data
* Test API errors
* Test permissions
* Test backups and logs

---

## Phase 5 — Production Backend

Production backend should run on a VPS/cloud server.

Recommended production backend stack:

* Ubuntu server
* Frappe Bench production setup
* OMC backend app installed
* MariaDB
* Redis
* Nginx
* Supervisor
* HTTPS/SSL
* Domain/subdomain
* Backups
* Monitoring/logging

Example production URL:

```text
https://api.omchouse.com
```

### Production Requirements

* HTTPS must be enabled
* Backend should not run from laptop
* Mock/test mode must be disabled
* Real user permissions must be configured
* Error logs must be monitored
* Backups must be scheduled
* File upload storage must be reliable
* API access must be secured
* Admin/back-office users should use Frappe Desk

---

## Phase 6 — Android Play Store Release

The Play Store release is only for the Flutter app.

The backend is not uploaded to the Play Store.

For Android release, build an Android App Bundle.

Example production build:

```bash
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://api.omchouse.com
```

The generated `.aab` file will be uploaded to Google Play Console.

### Play Store Requirements

* Final app name
* Final app icon
* Final package name/application ID
* Release signing key
* Version code
* Version name
* Privacy policy
* Data safety form
* App screenshots
* Internal testing release
* Closed/open testing if required
* Production rollout

---

## Recommended Execution Order

The recommended order is:

```text
1. Complete local backend connection
2. Stabilize login/session/API client
3. Test all main modules locally
4. Document and freeze API contract
5. Polish UI
6. Deploy staging backend
7. Test on real Android devices
8. Prepare production backend
9. Build release app bundle
10. Upload to Play Store internal testing
11. Final production release
```

---

## Current Focus

The current focus is only:

```text
Local Flutter app ↔ Local Frappe backend connection
```

We should not jump directly to production or Play Store until local backend integration is stable.

---

## Production-Level Working Rule

For this project, every idea should be handled using this process:

```text
1. Understand the idea
2. Improve it using production-level best practices
3. Convert it into a proper plan
4. Implement step by step
5. Test before moving forward
6. Preserve backend-connected architecture
```

Temporary mock/testing logic is acceptable only when clearly isolated.

The main app flow must stay backend-connected and production-ready.

---

## Final Target

The final target is a clean production system where:

* Flutter is the permanent customer-facing app
* Frappe is the backend/admin/API/database system
* Local testing works first
* Staging is used before production
* Production backend runs on cloud/VPS
* Play Store distributes the Flutter app
* Users connect to the live Frappe backend through HTTPS
