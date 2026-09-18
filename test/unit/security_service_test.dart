import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/services/security_service.dart';

void main() {
  group('AppSecurityService Cryptographic Tests', () {
    late AppSecurityService securityService;

    setUp(() {
      securityService = AppSecurityService();
    });

    test('hashPin generates unique salted hash for identical PINs asynchronously via isolate', () async {
      const pin = '1234';
      final hash1 = await securityService.hashPin(pin);
      final hash2 = await securityService.hashPin(pin);

      expect(hash1, isNot(equals(hash2)));
      expect(hash1.contains(':'), isTrue);
      expect(hash2.contains(':'), isTrue);

      final parts1 = hash1.split(':');
      expect(parts1.length, equals(2));
      expect(parts1[0].length, equals(32)); // 16 bytes hex = 32 chars
    });

    test('hashPinSync generates valid salted hash synchronously', () {
      const pin = '1234';
      final hash = securityService.hashPinSync(pin);
      expect(hash.contains(':'), isTrue);
      expect(securityService.verifyPinSync('1234', hash), isTrue);
      expect(securityService.verifyPinSync('9999', hash), isFalse);
    });

    test('verifyPin correctly validates correct PIN with salted hash via isolate', () async {
      const pin = '7890';
      final hash = await securityService.hashPin(pin);

      expect(await securityService.verifyPin('7890', hash), isTrue);
      expect(await securityService.verifyPin('7891', hash), isFalse);
      expect(await securityService.verifyPin('0000', hash), isFalse);
    });

    test('verifyPin supports backward-compatible legacy unsalted SHA-256 hash', () async {
      const legacyPin = '4321';
      final legacyHash = sha256.convert(utf8.encode(legacyPin)).toString();

      // Ensure legacy hash has no salt prefix
      expect(legacyHash.contains(':'), isFalse);

      expect(await securityService.verifyPin('4321', legacyHash), isTrue);
      expect(await securityService.verifyPin('1234', legacyHash), isFalse);
    });
  });
}
