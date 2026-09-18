# MethotX Enterprise Architecture Walkthrough

## 1. Accomplishments Overview

### Phase 1: Core Network & Clean Architecture Foundation

- **Dio Client & Environment Config**: Built `DioClient` with environment switching (`test.methotx.in` and `portal.methotx.com`).
- **AuthInterceptor**: Injects `Authorization: Bearer <token>`, `empId`, and `secure` keys automatically into outgoing requests.
- **StorageService**: Encapsulated `flutter_secure_storage` for credentials and `shared_preferences` for application flags.

### Phase 2: Authentication & Onboarding

- **Clean Architecture Auth**: Implemented `AuthEntity`, `AuthRepository`, `AuthRemoteDataSource`, and `AuthRepositoryImpl`.
- **Login Screen (`LoginPage`)**: Complete corporate login form with regex email validation, visibility toggles, and "Remember Me" persistent caching.
- **Permissions Controller**: Android 13+ and iOS permission requests (Fine Location, Notifications, Photos/Media) with graceful fallbacks to `openAppSettings()`.

### Phase 3: App Security (PIN & Biometrics)

- **Core Security Service (`SecurityService`)**: Cryptographic SHA-256 hashing for 4-digit PINs and `LocalAuthentication` wrapper for Face ID/Fingerprint.
- **Security Notifier (`SecurityNotifier`)**: Manages PIN hashing/saving, failed attempt lockout counters, and biometric hardware preferences.
- **Security Screens**:
  - `CreatePinScreen`: 4-digit numeric keypad entry and confirmation.
  - `BiometricSetupScreen`: Pulse animation, hardware detection, "Enable" and "Skip" paths.
  - `PinUnlockScreen`: Gatekeeper unlock screen for returning users with auto-prompted biometrics, keypad, and HR recovery dialog.

### Phase 4: Strict Sequential Redirection Flow (`GoRouter` + Riverpod)

Resolved redirection loop and sub-route suppression bug with a 6-stage sequential evaluation cascade:

1. `!hasCompletedOnboarding ➡️ /onboarding`
2. `!hasGrantedPermissions ➡️ /permissions`
3. `!isLoggedIn ➡️ /login`
4. `isLoggedIn && !hasPinSetup ➡️ /create-pin` (allows `/biometrics` & `/security-success`)
5. `isLoggedIn && hasPinSetup && isAppLocked ➡️ /pin-unlock`
6. `Fallback / Success ➡️ /dashboard`

- Wired `refreshListenable` to `AppRouterNotifier` and watched `appStartupProvider` to ensure immediate route reactivity on state mutation.

### Phase 5: Attendance & Live Shift Module

- **Domain Layer**: `AttendanceEntity` and `AttendanceStatus` (`notPunchedIn`, `working`, `onBreak`, `onTiffin`, `punchedOut`).
- **Data Layer**: `AttendanceRemoteDataSource` calling `/users/employee/` endpoints (`punch-in`, `punch-out`, `lunch-in`, `lunch-out`, `break-in`, `break-out`) with GPS coordinates and date/time parameters.
- **Presentation Layer**: `AttendanceNotifier` with 1-second ticker timer for real-time digital clock and net working hours calculation.
- **Dashboard UI**: Interactive `SwipePunchCard` for punch-in/out, dynamic `BreakLunchControls` (Tiffin and Short Break toggles), and 2x2 Work Snapshot Bento Grid.

### Phase 9: Expenditure Claims Module

- **Domain Layer**: `ClaimEntity`, `ClaimStatus`, and `ClaimCategoryInfo`.
- **Data Layer**: `ClaimRemoteDataSource` calling `/users/expenditure-claims/claim-list`, `claim-details`, and `submit-claim`.
- **Presentation Layer**: `ClaimsListScreen` with header Apply button, filter chips, pull-to-refresh, `ClaimDetailsScreen`, and `ApplyClaimScreen` with multipart receipt uploads.

### Phase 10: Supply Requisitions Module

- **Domain Layer**: `SupplyEntity`, `SupplyStatus` (`pending`, `approved`, `rejected`), `SupplyPriority` (`top`, `normal`), and `SupplyCategoryInfo` (15 categories).
- **Data Layer**: `SupplyRemoteDataSource` calling `/users/expenditure-claims/supply-list`, `supply-details`, and `submit-Supply` (multipart with quotation attachments).
- **Presentation Layer**:
  - `SupplyListScreen`: Top-right `PrimaryButton` Apply, filter chips (All, Pending, Approved, Rejected), requisition cards with category, date, priority, quantity, and amount.
  - `ApplySupplyScreen`: Full validation for category, date, quantity, amount, priority, optional return/exchange, quotation attachment, and comments.
  - `SupplyDetailsScreen`: Status banner, financial summary, specifications, details, comments, and attachment preview/open.
- **Routing**: Connected `/requisitions` route in `AppRouter` and `AppDrawer`.

---

## 2. Verification Results

- **Analyzer Status**: `flutter analyze` ➡️ `No issues found! (0 warnings, 0 errors)`
- **Test Suite Status**: `flutter test` ➡️ **135 / 135 tests passing (100% green)**

