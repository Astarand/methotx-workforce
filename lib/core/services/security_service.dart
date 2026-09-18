import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

abstract class SecurityService {
  Future<String> hashPin(String pin, [String? customSalt]);
  Future<bool> verifyPin(String enteredPin, String storedHash);
  String hashPinSync(String pin, [String? customSalt]);
  bool verifyPinSync(String enteredPin, String storedHash);
  Future<bool> isBiometricsAvailable();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticateWithBiometrics({String reason});
}

class AppSecurityService implements SecurityService {
  final LocalAuthentication _localAuth;
  static const int _saltLength = 16; // 128-bit cryptographic salt
  static const int _hashIterations = 10000; // 10,000 rounds

  AppSecurityService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  static String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _hashWithSaltStatic(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin'));
    for (int i = 0; i < _hashIterations; i++) {
      digest = sha256.convert(digest.bytes + utf8.encode(salt));
    }
    return digest.toString();
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  @override
  String hashPinSync(String pin, [String? customSalt]) {
    final salt = customSalt ?? _generateSalt();
    final hash = _hashWithSaltStatic(pin, salt);
    return '$salt:$hash';
  }

  @override
  Future<String> hashPin(String pin, [String? customSalt]) {
    final salt = customSalt ?? _generateSalt();
    return Isolate.run(() {
      final hash = _hashWithSaltStatic(pin, salt);
      return '$salt:$hash';
    });
  }

  @override
  bool verifyPinSync(String enteredPin, String storedHash) {
    if (storedHash.contains(':')) {
      final parts = storedHash.split(':');
      if (parts.length == 2) {
        final salt = parts[0];
        final expectedHash = parts[1];
        final computedHash = _hashWithSaltStatic(enteredPin, salt);
        return _constantTimeEquals(computedHash, expectedHash);
      }
    }

    // Backward compatibility for legacy unsalted SHA-256
    final legacyHash = sha256.convert(utf8.encode(enteredPin)).toString();
    return _constantTimeEquals(legacyHash, storedHash);
  }

  @override
  Future<bool> verifyPin(String enteredPin, String storedHash) {
    return Isolate.run(() => verifyPinSync(enteredPin, storedHash));
  }

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to unlock your MethotX workspace',
  }) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Riverpod provider for SecurityService
final securityServiceProvider = Provider<SecurityService>((ref) {
  return AppSecurityService();
});
