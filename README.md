# MethotX Workforce 🚀

<p align="center">
  <img src="assets/icon/icon.png" alt="MethotX Logo" width="100" height="100" />
</p>

<p align="center">
  <strong>India's Next-Gen CIP Ecosystem • Enterprise Workforce Management Suite</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Architecture-Clean%20%26%20SOLID-success?style=for-the-badge" alt="Clean Architecture" />
  <img src="https://img.shields.io/badge/State-Riverpod%202.x-blueviolet?style=for-the-badge" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange?style=for-the-badge" alt="Platform" />
</p>

---

## 📖 Overview

**MethotX Workforce** is an enterprise-grade mobile application engineered for corporate workforce automation, attendance tracking, payroll transparency, and real-time operational efficiency.

Built strictly according to **Clean Architecture**, **SOLID design principles**, and **Riverpod** reactive state management, MethotX guarantees hardware-backed security, zero-leak credential protection, offline resilience, and fluid 60 FPS performance across modern Android and iOS devices.

---

## 🌟 Core Modules & Capabilities

### 🔐 1. Zero-Trust Security & Multi-Factor Authentication
- **Secure Token Authentication**: Hardware-backed session management via `flutter_secure_storage`.
- **4-Digit Cryptographic PIN**: Local salted hash storage for frictionless workspace re-entry.
- **Biometric Enclave**: Seamless Face ID (iOS) and Fingerprint (Android) unlock with hardware fallback.
- **Inactivity Guard**: Background lifecycle watcher automatically locks sensitive screens after inactivity.

### 📍 2. Smart Attendance & Geofenced Punching
- **Strict Geofencing Perimeter**: 50-meter GPS proximity verification against corporate office coordinates (`22.572646, 88.363895`).
- **Mock GPS & Anti-Spoofing Detection**: Blocks fake location apps to preserve enterprise integrity.
- **Work From Home (WFH) & Remote Modes**: Intelligent mode detection that automatically bypasses office perimeter rules for authorized remote shifts.
- **2-Hour Early Punch Window & Shift Windows**: Shift timing enforcement with grace periods.
- **Swipe-to-Punch**: Interactive haptic slider preventing accidental check-ins.
- **Break & Tiffin Timers**: Precision tracking of lunch and productivity intervals.
- **Offline Outbox Pattern**: Queues punches locally if connectivity drops, auto-syncing upon reconnection.

### 📊 3. Modern Bento Dashboard & Decoupled Clock
- **Decoupled 1-Second Ticker**: Digital clock ticker operates outside the primary widget rebuild tree, completely eliminating micro-stutters.
- **Bento Status Grid**: Instant glance at active shift status, attendance mode, pending deliverables, and calendar dates.
- **Live Activity Feed**: Real-time chronological audit trail of check-ins, lunch sessions, and check-outs.

### 💰 4. Salary & High-Fidelity PDF Payslips
- **Financial Cycle Selector**: Browse payslips by month and financial year (e.g., 2026–2027).
- **Transparent Breakdown**: Granular reporting of Basic Pay, HRA, Allowances, PF deductions, Tax, and Net Disbursal.
- **Vector PDF Generator**: Instant export, viewing, and local storage of official corporate payslips.

### 🧾 5. Expense Claims & Supply Requests
- **Digital Receipt Capture**: Attach physical invoices and receipts using camera and photo pickers.
- **Google Play Compliant**: Uses Android's system document picker without requesting dangerous broad storage permissions.
- **Approval Lifecycle**: Track status (Pending, Approved, Rejected) with supervisor feedback notes.

### 🌴 6. Leave Management Suite
- **Dynamic Balance Cards**: Real-time accounting of Casual, Sick, and Paid leave allocations.
- **Interactive Leave Application**: Request modal with date-range selection and reason categorization.
- **Historical Audit Trail**: Segmented filters between upcoming planned leaves and historical approvals.

### 📋 7. Task Management & Push Notifications
- **Task Kanban Board**: Prioritize sprint deliverables with priority badges, checklists, and deadlines.
- **FCM Push Notifications**: Deep-linked operational alerts for shift reminders, leave approvals, and payroll releases.

---

## 🏗️ Architecture & Project Structure

The project follows a **Feature-First Clean Architecture** with strict layer separation:

```text
lib/
├── core/                         # Cross-cutting foundational modules
│   ├── constants/                # API endpoints, assets, layout constants
│   ├── network/                  # Dio HTTP engine, auth headers, error interceptors
│   ├── services/                 # SecureStorage, NotificationService, PDF generation
│   ├── theme/                    # Design tokens, color palettes, Outfit & Inter typography
│   └── utils/                    # Date parsers, currency formatters, geodetic helpers
│
├── features/                     # Feature-First Modular Business Domains
│   ├── attendance/               # Geofenced punch-in/out, timers, outbox queue
│   ├── authentication/           # Enterprise login, credential validation, sessions
│   ├── claims/                   # Expense claims, reimbursement requests, receipt attachments
│   ├── dashboard/                # Decoupled clock, bento grid, timeline widgets
│   ├── leave/                    # Balance ledgers, leave application modals, history
│   ├── notifications/            # FCM listeners, category filters, deep linking
│   ├── payslip/                  # Salary calculations, payslip PDF renderer
│   ├── permissions/              # Location, notification, and camera permission handling
│   ├── profile/                  # Employee directory details, profile update API
│   ├── security/                 # PIN creation, biometric enrollment, unlock screen
│   ├── splash/                   # Cold-boot initialization, token validation
│   ├── supply/                   # Office supply requests, asset tracking
│   └── tasks/                    # Task board, progress status, deadlines
│
├── routes/                       # Navigation & State-Driven Routing
│   ├── app_router.dart           # GoRouter declarations with redirect state machine
│   ├── app_routes.dart           # Route URI constants
│   ├── app_startup_notifier.dart # Boot orchestrator & lifecycle app-lock controller
│   └── main_shell_screen.dart    # Persistent bottom navigation shell
│
└── shared/                       # Cross-feature design components
    ├── models/                   # Reusable DTOs and entities
    └── widgets/                  # Enterprise buttons, modal sheets, toast banners
```

### Layer Responsibilities
- **`domain/`**: Pure Dart layer containing business entities, use cases, and repository interfaces. Completely decoupled from Flutter UI and third-party plugins.
- **`data/`**: Implements domain repository interfaces, manages remote REST APIs (via Dio), and handles local caches.
- **`presentation/`**: Declarative Flutter UI widgets, screens, and Riverpod `StateNotifier` controllers.

---

## 🛠️ Technology Stack

| Category | Technology | Purpose |
|:---|:---|:---|
| **Framework** | [Flutter 3.x](https://flutter.dev) (Dart 3.x) | Cross-platform native compilation |
| **State Management** | [Flutter Riverpod 2.x](https://pub.dev/packages/flutter_riverpod) | Compile-time safe, reactive dependency injection |
| **Navigation** | [GoRouter 18.x](https://pub.dev/packages/go_router) | Declarative URL routing with deep-link support |
| **Networking** | [Dio 5.x](https://pub.dev/packages/dio) | REST API client with interceptors & certificate pinning |
| **Local Storage** | [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage) | Keychain / KeyStore encrypted credential vault |
| **Geofencing** | [Geolocator 14.x](https://pub.dev/packages/geolocator) | GPS proximity calculation & anti-mock detection |
| **Biometrics** | [local_auth 3.x](https://pub.dev/packages/local_auth) | Hardware Face ID & Fingerprint authentication |
| **Push Alerts** | [Firebase Messaging 16.x](https://pub.dev/packages/firebase_messaging) | Cloud messaging & notifications |
| **PDF Generation** | [pdf 3.x](https://pub.dev/packages/pdf) & [printing](https://pub.dev/packages/printing) | High-fidelity payslip document generation |

---

## 🔒 Security & Store Compliance Highlights

1. **Google Play Photo & Video Compliance**:
   - Removed broad `READ_MEDIA_IMAGES` and legacy storage permissions.
   - Enforced `tools:node="remove"` in `AndroidManifest.xml` to strip transitive permissions merged from third-party plugins.
   - Fully compliant with Android 13+ (API 33+) System Photo Picker policy.
2. **Apple App Store Export Compliance**:
   - Configured `<key>ITSAppUsesNonExemptEncryption</key><false/>` in `Info.plist` to bypass export compliance prompts.
   - Full justification provided for `NSLocationWhenInUseUsageDescription` and `NSPhotoLibraryUsageDescription`.
3. **Android R8 Full Mode Optimization**:
   - Enabled `android.enableR8.fullMode=true` and `-repackageclasses ''` in ProGuard rules for maximum bytecode shrinking and obfuscation.
4. **Credential Leak Prevention**:
   - Airtight `.gitignore` protecting `key.properties`, keystores (`*.jks`, `*.keystore`), `.env` files, and Firebase service accounts.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.12.2` (Channel `stable`)
- **Dart SDK**: `>= 3.3.0`
- **Android Studio** (Android SDK API 34+ / Target SDK 36)
- **Xcode** 15+ (for macOS / iOS builds)
- **CocoaPods** `>= 1.14`

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/methotx_workforce.git
   cd methotx_workforce
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify code health & static analysis:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch the application:**
   ```bash
   # Run on connected Android device / emulator
   flutter run -d android

   # Run on connected iOS simulator / device
   flutter run -d ios
   ```

---

## 📦 Production Release Builds

### 🤖 Android App Bundle (Google Play)
```bash
# Builds signed release bundle: build/app/outputs/bundle/release/app-release.aab
flutter build appbundle --release
```

### 🍎 iOS Archive (App Store Connect)
```bash
# 1. Generate fresh iOS configs and CocoaPods:
flutter build ios --config-only

# 2. Open Xcode, select 'Any iOS Device (arm64)', and choose:
#    Product -> Archive -> Distribute App -> App Store Connect
```

---

## 📄 License & Proprietary Notice

Copyright © 2026 **CLICKNGO TECH SERVICE PRIVATE LIMITED / MethotX Workforce Ecosystem**.  
All rights reserved. Unauthorized copying, distribution, modification, or commercial use of this source code is strictly prohibited.
