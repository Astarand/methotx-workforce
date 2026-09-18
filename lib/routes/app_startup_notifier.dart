import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_constants.dart';
import '../core/services/notification_service.dart';
import '../core/services/storage_service.dart';

/// State model containing the comprehensive startup and security flags
class AppStartupState {
  final bool isInitializing;
  final bool hasCompletedOnboarding;
  final bool hasGrantedPermissions;
  final bool isLoggedIn;
  final bool hasPinSetup;
  final bool isAppLocked;
  final String? pendingRedirectUri;

  const AppStartupState({
    this.isInitializing = true,
    this.hasCompletedOnboarding = false,
    this.hasGrantedPermissions = false,
    this.isLoggedIn = false,
    this.hasPinSetup = false,
    this.isAppLocked = false,
    this.pendingRedirectUri,
  });

  AppStartupState copyWith({
    bool? isInitializing,
    bool? hasCompletedOnboarding,
    bool? hasGrantedPermissions,
    bool? isLoggedIn,
    bool? hasPinSetup,
    bool? isAppLocked,
    String? pendingRedirectUri,
    bool clearPendingRedirect = false,
  }) {
    return AppStartupState(
      isInitializing: isInitializing ?? this.isInitializing,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasGrantedPermissions:
          hasGrantedPermissions ?? this.hasGrantedPermissions,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      hasPinSetup: hasPinSetup ?? this.hasPinSetup,
      isAppLocked: isAppLocked ?? this.isAppLocked,
      pendingRedirectUri: clearPendingRedirect ? null : (pendingRedirectUri ?? this.pendingRedirectUri),
    );
  }

  @override
  String toString() =>
      'AppStartupState(isInit: $isInitializing, onboarding: $hasCompletedOnboarding, permissions: $hasGrantedPermissions, loggedIn: $isLoggedIn, pinSet: $hasPinSetup, locked: $isAppLocked, redirect: $pendingRedirectUri)';
}

/// StateNotifier responsible for managing app initialization, authentication presence,
/// PIN setup flags, and automatic background-lock lifecycles.
class AppStartupNotifier extends StateNotifier<AppStartupState>
    with WidgetsBindingObserver {
  final StorageService storageService;
  final int backgroundTimeoutMs;
  DateTime? _lastBackgroundedTimestamp;
  static const int defaultBackgroundTimeoutMs = 300000; // 5 minutes (300,000 ms)

  AppStartupNotifier({
    required this.storageService,
    int? timeoutMs,
  })  : backgroundTimeoutMs = timeoutMs ?? defaultBackgroundTimeoutMs,
        super(const AppStartupState()) {
    checkStartup(keepInitializing: true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final now = DateTime.now();
      _lastBackgroundedTimestamp = now;
      storageService.saveBool('app_was_backgrounded', true);
      storageService.saveInt('app_paused_time', now.millisecondsSinceEpoch);
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  Future<void> handleAppResume() => _handleAppResume();

  Future<void> _handleAppResume() async {
    final now = DateTime.now();
    final pausedEpoch = await storageService.getInt('app_paused_time');
    final backgroundedTime = (pausedEpoch != null
            ? DateTime.fromMillisecondsSinceEpoch(pausedEpoch)
            : null) ??
        _lastBackgroundedTimestamp;

    if (backgroundedTime != null &&
        state.isLoggedIn &&
        state.hasPinSetup) {
      final elapsed = now.difference(backgroundedTime).inMilliseconds;
      if (elapsed > backgroundTimeoutMs) {
        lockApp();
      }
    }
    _lastBackgroundedTimestamp = null;
  }

  /// Verifies all boolean flags from StorageService
  Future<void> checkStartup({bool keepInitializing = false}) async {
    // 1. Check Onboarding flag from SharedPreferences
    final onboardingDone =
        await storageService.getBool('onboarding_completed') ?? false;

    // 2. Check Permissions flag from SharedPreferences
    final permissionsDone =
        await storageService.getBool('permissions_granted') ?? false;

    // 3. Check auth_token from SecureStorage with automatic migration and dual-sync
    var token = await storageService.getSecure(ApiConstants.storageTokenKey);
    if (token == null || token.trim().isEmpty) {
      final legacyToken = await storageService.getString(ApiConstants.storageTokenKey);
      if (legacyToken != null && legacyToken.trim().isNotEmpty) {
        token = legacyToken;
        await storageService.saveSecure(ApiConstants.storageTokenKey, legacyToken);
      }
    } else {
      await storageService.saveString(ApiConstants.storageTokenKey, token);
    }
    final hasToken = token != null && token.trim().isNotEmpty;

    // 4. Check app_passcode_hash from SecureStorage with automatic migration and dual-sync
    var pinHash = await storageService.getSecure(ApiConstants.storagePasscodeHashKey);
    if (pinHash == null || pinHash.trim().isEmpty) {
      final legacyHash = await storageService.getString(ApiConstants.storagePasscodeHashKey);
      if (legacyHash != null && legacyHash.trim().isNotEmpty) {
        pinHash = legacyHash;
        await storageService.saveSecure(ApiConstants.storagePasscodeHashKey, legacyHash);
      }
    } else {
      await storageService.saveString(ApiConstants.storagePasscodeHashKey, pinHash);
    }
    final hasPin = pinHash != null && pinHash.trim().isNotEmpty;


    // 5. Determine initial locked state: lock on fresh boot if user is logged in & PIN exists
    final shouldLock = state.isInitializing
        ? (hasToken && hasPin)
        : (state.isAppLocked || (hasToken && hasPin && state.isAppLocked));

    state = state.copyWith(
      isInitializing: keepInitializing ? true : false,
      hasCompletedOnboarding: onboardingDone,
      hasGrantedPermissions: permissionsDone,
      isLoggedIn: hasToken,
      hasPinSetup: hasPin,
      isAppLocked: shouldLock,
    );
  }

  /// Called by SplashScreen when its animation completes to transition to the app
  Future<void> completeStartup() async {
    await checkStartup(keepInitializing: false);
    if (state.isLoggedIn) {
      NotificationService.instance.syncFcmTokenWithBackend(
        storageService: storageService,
      );
    }
  }

  /// Saves onboarding flag and immediately updates reactive state
  Future<void> completeOnboarding() async {
    await storageService.saveBool('onboarding_completed', true);
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  /// Saves permissions granted flag and immediately updates reactive state
  Future<void> grantPermissions() async {
    await storageService.saveBool('permissions_granted', true);
    state = state.copyWith(hasGrantedPermissions: true);
  }

  /// Called after successful API login
  Future<void> setLoggedIn({required String token, required String empId}) async {
    await storageService.saveSecure(ApiConstants.storageTokenKey, token);
    await storageService.saveString(ApiConstants.storageEmpIdKey, empId);
    await storageService.saveBool('user_logged_in', true);
    state = state.copyWith(isLoggedIn: true);
    NotificationService.instance.syncFcmTokenWithBackend(
      storageService: storageService,
    );
    await checkStartup();
  }

  /// Called after 4-digit PIN is created and saved
  Future<void> setPinSetupCompleted() async {
    await storageService.saveBool('pin_setup_complete', true);
    await storageService.saveBool('security_setup_complete', true);
    state = state.copyWith(hasPinSetup: true, isAppLocked: false);
  }

  /// Locks the app (e.g. after backgrounding >30s)
  void lockApp() {
    state = state.copyWith(isAppLocked: true);
  }

  /// Unlocks the app (after successful PIN or Biometric verification)
  Future<void> unlockApp() async {
    await storageService.remove('pin_attempt_count');
    await storageService.remove('app_was_backgrounded');
    await storageService.remove('app_paused_time');
    state = state.copyWith(isAppLocked: false);
  }

  /// Sets the pending deep link or notification target route to be restored after PIN unlock
  void setPendingRedirectUri(String? uri) {
    if (uri != null && uri.trim().isNotEmpty) {
      state = state.copyWith(pendingRedirectUri: uri.trim());
    }
  }

  /// Clears the pending redirect destination once handled
  void clearPendingRedirectUri() {
    state = state.copyWith(clearPendingRedirect: true);
  }

  /// Called on user logout - purges user session and auth tokens while
  /// preserving configured device PIN and biometric setup for seamless re-login.
  Future<void> logout() async {
    await storageService.deleteSecure(ApiConstants.storageTokenKey);
    await storageService.deleteSecure(ApiConstants.storageEmpIdKey);
    await storageService.deleteSecure(ApiConstants.storageSecureKey);
    await storageService.remove(ApiConstants.storageTokenKey);
    await storageService.remove(ApiConstants.storageEmpIdKey);
    await storageService.remove(ApiConstants.storageSecureKey);
    await storageService.remove('pin_attempt_count');
    await storageService.remove('app_was_backgrounded');
    await storageService.remove('app_paused_time');
    await storageService.saveBool('user_logged_in', false);

    state = state.copyWith(
      isLoggedIn: false,
      isAppLocked: false,
    );
  }
}

final appStartupProvider =
    StateNotifierProvider<AppStartupNotifier, AppStartupState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return AppStartupNotifier(storageService: storageService);
});
