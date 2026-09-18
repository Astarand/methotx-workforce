import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/storage_service.dart';

class SecurityState {
  final bool isPinSet;
  final bool isBiometricEnabled;
  final bool isBiometricAvailable;
  final int failedAttempts;
  final bool isLockedOut;

  const SecurityState({
    this.isPinSet = false,
    this.isBiometricEnabled = false,
    this.isBiometricAvailable = false,
    this.failedAttempts = 0,
    this.isLockedOut = false,
  });

  SecurityState copyWith({
    bool? isPinSet,
    bool? isBiometricEnabled,
    bool? isBiometricAvailable,
    int? failedAttempts,
    bool? isLockedOut,
  }) {
    return SecurityState(
      isPinSet: isPinSet ?? this.isPinSet,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isLockedOut: isLockedOut ?? this.isLockedOut,
    );
  }
}

/// Dedicated SecurityNotifier managing PIN creation, salted verification,
/// lockout counting, and native biometric hardware interactions.
///
/// NOTE: App lifecycle tracking and background timeouts are handled exclusively
/// by AppStartupNotifier as the single source of truth.
class SecurityNotifier extends StateNotifier<SecurityState> {
  final SecurityService securityService;
  final StorageService storageService;
  static const int maxPinAttempts = 5;

  SecurityNotifier({
    required this.securityService,
    required this.storageService,
  }) : super(const SecurityState()) {
    _init();
  }

  static const String failedAttemptsKey = 'security_failed_attempts';

  Future<void> _init() async {
    var hash = await storageService.getSecure(ApiConstants.storagePasscodeHashKey);
    if (hash == null || hash.trim().isEmpty) {
      final legacyHash = await storageService.getString(ApiConstants.storagePasscodeHashKey);
      if (legacyHash != null && legacyHash.trim().isNotEmpty) {
        hash = legacyHash;
        await storageService.saveSecure(ApiConstants.storagePasscodeHashKey, legacyHash);
      }
    } else {
      await storageService.saveString(ApiConstants.storagePasscodeHashKey, hash);
    }

    final biometricEnabled =
        await storageService.getBool('biometric_enabled') ?? false;
    final biometricHardwareAvailable =
        await securityService.isBiometricsAvailable();

    final savedAttemptsStr =
        await storageService.getSecure(failedAttemptsKey) ??
        (await storageService.getInt('pin_attempt_count'))?.toString();
    final savedAttempts = int.tryParse(savedAttemptsStr ?? '') ?? 0;
    final isLocked = savedAttempts >= maxPinAttempts;

    if (!mounted) return;

    state = state.copyWith(
      isPinSet: hash != null && hash.trim().isNotEmpty,
      isBiometricEnabled: biometricEnabled,
      isBiometricAvailable: biometricHardwareAvailable,
      failedAttempts: savedAttempts,
      isLockedOut: isLocked,
    );
  }

  /// Resets failed PIN attempts and removes lockout status
  Future<void> resetAttempts() async {
    await storageService.deleteSecure(failedAttemptsKey);
    await storageService.remove('pin_attempt_count');
    if (mounted) {
      state = state.copyWith(
        failedAttempts: 0,
        isLockedOut: false,
      );
    }
  }

  // Alias for backward compatibility with existing callers
  Future<void> clearPinRequired() => resetAttempts();

  /// 1. Create and hash new PIN through Core SecurityService, then persist to SecureStorage
  Future<bool> createAndSavePin(String rawPin) async {
    final hashedPin = await securityService.hashPin(rawPin);

    // Save strictly to encrypted secure storage (Keystore/Keychain)
    await storageService.saveSecure(
        ApiConstants.storagePasscodeHashKey, hashedPin);
    // Purge legacy plaintext hash if previously saved in SharedPreferences
    await storageService.remove(ApiConstants.storagePasscodeHashKey);
    await storageService.saveBool('pin_setup_complete', true);
    await storageService.saveBool('security_setup_complete', true);

    await resetAttempts();
    state = state.copyWith(
      isPinSet: true,
      failedAttempts: 0,
      isLockedOut: false,
    );
    return true;
  }

  // Alias for backward compatibility
  Future<bool> createAndHashPin(String rawPin) => createAndSavePin(rawPin);

  /// 2. Verify entered PIN against stored hash through Core SecurityService
  Future<bool> verifyPin(String enteredPin) async {
    var savedHash =
        await storageService.getSecure(ApiConstants.storagePasscodeHashKey);
    if (savedHash == null) {
      final legacyHash =
          await storageService.getString(ApiConstants.storagePasscodeHashKey);
      if (legacyHash != null && legacyHash.trim().isNotEmpty) {
        savedHash = legacyHash;
        await storageService.saveSecure(
            ApiConstants.storagePasscodeHashKey, legacyHash);
        await storageService.remove(ApiConstants.storagePasscodeHashKey);
      }
    }

    if (savedHash == null || savedHash.trim().isEmpty) {
      return false;
    }


    final isValid = await securityService.verifyPin(enteredPin, savedHash);

    if (isValid) {
      await resetAttempts();
      return true;
    } else {
      final newAttempts = state.failedAttempts + 1;
      final locked = newAttempts >= maxPinAttempts;
      await storageService.saveSecure(failedAttemptsKey, newAttempts.toString());
      await storageService.saveInt('pin_attempt_count', newAttempts);
      state = state.copyWith(
        failedAttempts: newAttempts,
        isLockedOut: locked,
      );
      return false;
    }
  }

  /// 3. Toggle Biometric preference and persist to StorageService
  Future<void> toggleBiometric(bool enabled) async {
    await storageService.saveBool('biometric_enabled', enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  // Alias for backward compatibility
  Future<void> enableBiometric(bool enabled) => toggleBiometric(enabled);

  /// Authenticate using native biometric dialog (Face ID / Fingerprint)
  Future<bool> authenticateBiometric({
    String reason = 'Authenticate to unlock your MethotX workspace',
  }) async {
    if (!state.isBiometricEnabled) return false;

    final success = await securityService.authenticateWithBiometrics(
      reason: reason,
    );

    if (success) {
      resetAttempts();
      return true;
    }
    return false;
  }
}

/// Riverpod Provider for SecurityNotifier
final securityNotifierProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final securityService = ref.watch(securityServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return SecurityNotifier(
    securityService: securityService,
    storageService: storageService,
  );
});
