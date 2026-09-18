import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/network/api_constants.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';
import 'package:methotx_workforce/routes/app_router.dart';
import 'package:methotx_workforce/routes/app_routes.dart';
import 'package:methotx_workforce/routes/app_startup_notifier.dart';

class MockStorageService implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> saveBool(String key, bool value) async => _data[key] = value;
  @override
  Future<bool?> getBool(String key) async => _data[key] as bool?;

  @override
  Future<void> saveString(String key, String value) async => _data[key] = value;
  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<void> saveInt(String key, int value) async => _data[key] = value;
  @override
  Future<int?> getInt(String key) async => _data[key] as int?;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
  @override
  Future<void> clearAll() async => _data.clear();
  @override
  Future<void> clearSecure() async => _data.clear();

  @override
  Future<void> saveSecure(String key, String value) async => _data[key] = value;
  @override
  Future<String?> getSecure(String key) async => _data[key] as String?;
  @override
  Future<void> deleteSecure(String key) async => _data.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Lock & Lifecycle State Transition Tests', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('1. App Restart / Cold Boot / Killed: Redirects to /pin-unlock if logged in and PIN exists', () async {
      // Setup authenticated state with saved PIN in SecureStorage
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.checkStartup(keepInitializing: true);

      // On startup (cold boot/restart/killed)
      expect(notifier.state.isInitializing, isTrue);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasPinSetup, isTrue);
      expect(notifier.state.isAppLocked, isTrue);

      // Transition from Splash to destination
      await notifier.completeStartup();

      expect(notifier.state.isInitializing, isFalse);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasPinSetup, isTrue);
      expect(notifier.state.isAppLocked, isTrue);

      // Verify router redirect logic sends directly to /pin-unlock
      final redirectRoute = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.dashboard,
        state: notifier.state,
      );

      expect(redirectRoute, equals(AppRoutes.pinUnlock));
    });

    test('2. App Background > 5 minutes (300s): Transitions to locked state and /pin-unlock', () async {
      // Setup user currently active in dashboard
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.completeStartup();
      await notifier.unlockApp(); // User unlocked app

      expect(notifier.state.isAppLocked, isFalse);

      // Simulate app backgrounding
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Simulate 310 seconds elapsed in background (greater than 5 minutes / 300 seconds threshold)
      final fiveMinutesTenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 310));
      await storage.saveInt('app_paused_time', fiveMinutesTenSecondsAgo.millisecondsSinceEpoch);

      // Simulate app resuming and wait for resume handling
      await notifier.handleAppResume();

      // Must be locked!
      expect(notifier.state.isAppLocked, isTrue);

      // Evaluates redirect to /pin-unlock
      final redirectRoute = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.dashboard,
        state: notifier.state,
      );

      expect(redirectRoute, equals(AppRoutes.pinUnlock));
    });

    test('3. App Background <= 5 minutes: Stays unlocked and user remains on Dashboard', () async {
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.completeStartup();
      await notifier.unlockApp();

      expect(notifier.state.isAppLocked, isFalse);

      // Simulate app backgrounding
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Simulate only 45 seconds elapsed (well within 5-minute threshold)
      final fortyFiveSecondsAgo = DateTime.now().subtract(const Duration(seconds: 45));
      await storage.saveInt('app_paused_time', fortyFiveSecondsAgo.millisecondsSinceEpoch);

      // Simulate app resuming
      await notifier.handleAppResume();

      // Should still be unlocked!
      expect(notifier.state.isAppLocked, isFalse);

      // Evaluates redirect - remains null (stays on current screen)
      final redirectRoute = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.dashboard,
        state: notifier.state,
      );

      expect(redirectRoute, isNull);
    });

    test('4. Successful PIN Unlock: Clears locked state and navigates to Dashboard', () async {
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.completeStartup();

      expect(notifier.state.isAppLocked, isTrue);

      // User enters PIN successfully
      await notifier.unlockApp();

      expect(notifier.state.isAppLocked, isFalse);

      final redirectRoute = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.dashboard,
        state: notifier.state,
      );

      expect(redirectRoute, isNull); // Allowed on dashboard
    });

    test('5. Change Security PIN navigation: Allowed for authenticated unlocked user without dashboard redirect', () async {
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.completeStartup();
      await notifier.unlockApp();

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasPinSetup, isTrue);
      expect(notifier.state.isAppLocked, isFalse);

      final redirect = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.changePin,
        state: notifier.state,
      );

      // Must be allowed (null means proceed to /change-pin, NOT redirected to /dashboard)
      expect(redirect, isNull);
    });

    test('6. Logout preserves configured PIN: Re-login routes directly to Dashboard without repeating PIN setup', () async {
      await storage.saveSecure(ApiConstants.storageTokenKey, 'mock_token_abc');
      await storage.saveSecure(ApiConstants.storagePasscodeHashKey, 'mock_salted_hash');
      await storage.saveBool('onboarding_completed', true);
      await storage.saveBool('permissions_granted', true);
      await storage.saveBool('user_logged_in', true);

      final notifier = AppStartupNotifier(storageService: storage);
      await notifier.completeStartup();
      await notifier.unlockApp();

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasPinSetup, isTrue);

      // User logs out
      await notifier.logout();

      expect(notifier.state.isLoggedIn, isFalse);
      // Device PIN hash remains securely preserved in device storage
      final storedHash = await storage.getSecure(ApiConstants.storagePasscodeHashKey);
      expect(storedHash, equals('mock_salted_hash'));

      // User logs back in with credentials
      await storage.saveSecure(ApiConstants.storageTokenKey, 'new_mock_token_xyz');
      await notifier.checkStartup();

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.hasPinSetup, isTrue); // Already configured!

      // Router redirect from /login must route directly to /dashboard (skipping /create-pin)
      final redirect = AppRouterNotifier.staticEvaluateRedirect(
        location: AppRoutes.login,
        state: notifier.state,
      );
      expect(redirect, equals(AppRoutes.dashboard));
    });

    test('7. Deep Link Preservation: Setting pending redirect URI remembers target route across lock', () async {
      final notifier = AppStartupNotifier(storageService: storage);
      notifier.lockApp();
      expect(notifier.state.isAppLocked, isTrue);

      notifier.setPendingRedirectUri(AppRoutes.payslip);
      expect(notifier.state.pendingRedirectUri, equals(AppRoutes.payslip));

      await notifier.unlockApp();
      expect(notifier.state.isAppLocked, isFalse);
      expect(notifier.state.pendingRedirectUri, equals(AppRoutes.payslip));

      notifier.clearPendingRedirectUri();
      expect(notifier.state.pendingRedirectUri, isNull);
    });
  });
}
