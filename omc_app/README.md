# OMC House Mobile App

Premium Flutter mobile app for OMC House customers and internal workspace users.
The app connects with a Frappe/ERP backend and provides customer services, tax tools, document handling, payments, support, notifications, knowledge content, and internal CRM workspace modules.

## Overview

The app is built as a clean, feature-first Flutter project with backend-ready architecture.

Main purpose:

* Let customers browse OMC services
* Start service requests
* Upload required documents
* Track submitted service cases
* View invoices, receipts, and payments
* Receive notifications and tax updates
* Use tax calculator and expense tracker
* Access support and knowledge/news content
* Provide internal workspace access for leads, customers, tasks, and payments

## Tech Stack

* Flutter
* Dart
* Riverpod
* GoRouter
* Dio
* Flutter Secure Storage
* File Picker / Image Picker
* URL Launcher
* Cached Network Image
* FL Chart

## App Modules

Current app modules include:

* Authentication
* Home dashboard
* Service catalogue
* Service request form
* My Services / case tracking
* Documents
* Payments
* Tax calculator
* Expense tracker
* Support
* Notifications
* Knowledge and news
* Profile
* Settings
* Internal workspace
* Leads
* Customers
* Tasks

## App Usage Flow

Typical customer flow:

1. User logs in with OMC/Frappe credentials.
2. User lands on the Home screen.
3. User selects a service from Quick Services or Service Catalogue.
4. User fills the service request form.
5. User attaches required documents.
6. App submits the request to the backend.
7. Backend creates a service request/case.
8. App uploads attached files against that created request.
9. User can track the request from My Services.
10. User can view payment status, documents, notifications, and service updates.

Internal workspace flow:

1. Authorized user opens Internal Workspace.
2. User can access leads, customers, tasks, dashboard, and payment-related views.
3. Data is expected to come from the Frappe backend APIs.

## Backend Working

The app is designed to connect with a Frappe backend.

Backend base URL is configured through:

```bash
--dart-define=OMC_API_BASE_URL=https://your-frappe-site.com
```

Default backend URL is currently configured in `ApiConfig`.

The app communicates with Frappe using:

* `/api/method/...` for custom backend methods
* `/api/resource/...` for resource APIs
* `/api/method/upload_file` for file uploads

Authentication uses secure session storage. Session cookies or API token credentials are attached to API requests through the Dio client.

## Required Backend APIs

The backend should provide mobile API methods for:

* Login
* Google login
* Signup
* Create service request
* Dashboard summary
* Service catalogue
* Service case list
* Service case detail
* Documents list/detail
* Payments list/detail
* Profile get/update
* Knowledge/news list/detail
* Notifications list/detail
* Mark notification as read
* Settings preferences get/update
* Support ticket creation
* Internal workspace summary
* Leads list/detail
* Customers list/detail
* Tasks list/detail
* Tax calculation

These methods are centralized in:

```text
lib/core/config/api_config.dart
```

## File Upload Working

Service request attachments are submitted in two steps:

1. App creates the service request through the backend API.
2. If the backend returns a request ID/docname, the app uploads files using Frappe `upload_file`.

Uploaded files are linked to the configured doctype and docname.

Current upload-related config includes:

```text
Service Request
OMC Document
Sales Invoice
```

These doctypes should be confirmed with the final Frappe backend.

## Environment Flags

The app supports local testing flags.

### Mock Auth

For local UI testing only:

```bash
flutter run --dart-define=OMC_USE_MOCK_AUTH=true
```

Production builds force mock auth off.

### Service Preview Data

For local service tracking preview only:

```bash
flutter run --dart-define=OMC_USE_SERVICE_PREVIEW=true
```

Production builds force preview data off.

### Backend Service Catalogue

Optional backend catalogue mode:

```bash
flutter run --dart-define=OMC_USE_BACKEND_SERVICE_CATALOGUE=true
```

Keep disabled until the backend catalogue API contract is confirmed.

## Setup

Install dependencies:

```bash
flutter pub get
```

Run analyzer:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run app:

```bash
flutter run
```

Run with backend URL:

```bash
flutter run --dart-define=OMC_API_BASE_URL=https://your-frappe-site.com
```

Run local mock/testing mode:

```bash
flutter run \
  --dart-define=OMC_USE_MOCK_AUTH=true \
  --dart-define=OMC_USE_SERVICE_PREVIEW=true
```

## Build APK

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://your-frappe-site.com
```

APK output path:

```text
build/app/outputs/flutter-apk/
```

## Project Structure

```text
lib/
  app/
    router, shell, theme, providers

  core/
    config
    network
    storage
    widgets

  features/
    auth
    home
    service_catalogue
    service_requests
    documents
    payments
    dashboard
    leads
    customers
    tasks
    tax_calculator
    expense_tracker
    support
    notifications
    knowledge
    profile
    settings
    internal_workspace
```

## Current Status

The Flutter app is backend-ready and structured for production connection.

Current state:

* Main UI modules are implemented.
* App routing is configured.
* Backend API method names are centralized.
* Secure session handling is prepared.
* File upload flow is implemented and aligned with the Frappe mobile backend contracts.
* Local testing flags are isolated from production.
* Final backend API contracts and Frappe doctypes still need confirmation before live production use.

## Notes for Backend/Frappe Team

Before production release, confirm:

* Final mobile API method names
* Doctype names for service requests, documents, invoices, receipts, and tickets
* Response format for each API
* Required authentication method
* File upload permissions
* User roles and mobile access permissions
* HTTPS production endpoint
* Error response format

## Repository

This repository contains the Flutter mobile app for OMC House.

The app should be tested with:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Platform Release Notes

### Android

Android is the current primary release target.

Production Android release requires:

* `android/key.properties` configured from `android/key.properties.example`
* A valid release keystore
* Production backend flags:

```bash
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://your-frappe-site.com
### iOS

The same Flutter codebase supports iOS, but iOS release requires a Mac with Xcode.

Before TestFlight/App Store release, clean up iOS identity in Xcode:

Display name: OMC House
Bundle identifier: com.omchouse.app
Signing team / provisioning profile
App icons and launch assets

Current iOS Runner project naming is standard Flutter structure and can remain until the Mac/Xcode release phase.
