import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import 'api_constants.dart';

class AuthInterceptor extends QueuedInterceptor {
  final StorageService storageService;
  final void Function()? onSessionExpired;
  bool _isHandlingSessionExpiry = false;

  // Reusable cryptosecure random instance to avoid repeated OS entropy pool allocations
  static final Random _secureRandom = Random.secure();

  AuthInterceptor({
    required this.storageService,
    this.onSessionExpired,
  });

  /// Generates a compliant RFC 4122 UUIDv4 string with zero-heap buffer optimization
  static String generateUuidV4() {
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // 1. Fetch credentials with self-healing dual-persistence (Keystore + SharedPreferences)
      var token = await storageService.getSecure(ApiConstants.storageTokenKey);
      if (token == null || token.trim().isEmpty) {
        token = await storageService.getString(ApiConstants.storageTokenKey);
        if (token != null && token.trim().isNotEmpty) {
          await storageService.saveSecure(ApiConstants.storageTokenKey, token.trim());
        }
      } else {
        await storageService.saveString(ApiConstants.storageTokenKey, token.trim());
      }

      var empId = await storageService.getSecure(ApiConstants.storageEmpIdKey);
      if (empId == null || empId.trim().isEmpty) {
        empId = await storageService.getString(ApiConstants.storageEmpIdKey);
        if (empId != null && empId.trim().isNotEmpty) {
          await storageService.saveSecure(ApiConstants.storageEmpIdKey, empId.trim());
        }
      } else {
        await storageService.saveString(ApiConstants.storageEmpIdKey, empId.trim());
      }

      var secure = await storageService.getSecure(ApiConstants.storageSecureKey);
      if (secure == null || secure.trim().isEmpty) {
        secure = await storageService.getString(ApiConstants.storageSecureKey);
        if (secure != null && secure.trim().isNotEmpty) {
          await storageService.saveSecure(ApiConstants.storageSecureKey, secure.trim());
        }
      } else {
        await storageService.saveString(ApiConstants.storageSecureKey, secure.trim());
      }

      // 2. Inject Authentication Header with Bearer sanitization
      if (token != null && token.trim().isNotEmpty) {
        final cleanToken = token.trim();
        final rawToken = cleanToken.startsWith('Bearer ')
            ? cleanToken.substring(7).trim()
            : cleanToken;
        if (rawToken.isNotEmpty) {
          options.headers[ApiConstants.headerAuthorization] =
              '${ApiConstants.bearerPrefix}$rawToken';
        }
      }


      options.headers.putIfAbsent(
        ApiConstants.headerContentType,
        () => ApiConstants.applicationJson,
      );
      options.headers.putIfAbsent(
        ApiConstants.headerAccept,
        () => ApiConstants.applicationJson,
      );
      options.headers['Accept-Language'] = 'en,en-US;q=0.9';
      options.headers['X-Locale'] = 'en';
      options.headers['X-Language'] = 'en';
      options.headers['X-Localization'] = 'en';
      options.headers['Locale'] = 'en';

      // 3. Inject Idempotency-Key Header for Mutating Requests (POST, PUT, PATCH)
      final method = options.method.toUpperCase();
      final isMutating = method == 'POST' || method == 'PUT' || method == 'PATCH';

      if (isMutating) {
        options.headers.putIfAbsent(
          'Idempotency-Key',
          () => generateUuidV4(),
        );

        _injectCommonPayload(options, empId: empId, secure: secure);
      }

      return handler.next(options);
    } catch (e, stackTrace) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'AuthInterceptor failed to prepare request: $e',
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  /// Injects empId and secure safely without overwriting explicit request overrides
  void _injectCommonPayload(
    RequestOptions options, {
    String? empId,
    String? secure,
  }) {
    if (empId == null && secure == null) {
      return;
    }

    if (options.data == null) {
      final payload = <String, dynamic>{};
      if (empId != null) payload[ApiConstants.keyEmpId] = empId;
      if (secure != null) payload[ApiConstants.keySecure] = secure;
      options.data = payload;
      return;
    }

    // JSON Body Map
    if (options.data is Map) {
      final Map<String, dynamic> mutableMap =
          Map<String, dynamic>.from(options.data as Map);

      mutableMap.putIfAbsent('locale', () => 'en');
      mutableMap.putIfAbsent('lang', () => 'en');
      mutableMap.putIfAbsent('language', () => 'en');

      if (empId != null && !mutableMap.containsKey(ApiConstants.keyEmpId)) {
        mutableMap[ApiConstants.keyEmpId] = empId;
      }
      if (secure != null && !mutableMap.containsKey(ApiConstants.keySecure)) {
        mutableMap[ApiConstants.keySecure] = secure;
      }
      options.data = mutableMap;
      return;
    }

    // Multipart Form Data
    if (options.data is FormData) {
      final formData = options.data as FormData;
      final existingKeys = formData.fields.map((entry) => entry.key).toSet();

      if (empId != null && !existingKeys.contains(ApiConstants.keyEmpId)) {
        formData.fields.add(MapEntry(ApiConstants.keyEmpId, empId));
      }
      if (secure != null && !existingKeys.contains(ApiConstants.keySecure)) {
        formData.fields.add(MapEntry(ApiConstants.keySecure, secure));
      }
      options.data = formData;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // 1. Guard against infinite 401 loops on the logout endpoint
      final isLogoutEndpoint = err.requestOptions.path.contains('/logout') ||
          err.requestOptions.path.contains('/auth/logout');

      // 2. Wipe invalid/expired auth tokens from secure hardware & shared prefs
      await storageService.deleteSecure(ApiConstants.storageTokenKey);
      await storageService.remove(ApiConstants.storageTokenKey);

      // 3. Trigger global session eviction if not a logout request and not in-flight
      if (!isLogoutEndpoint && !_isHandlingSessionExpiry) {
        _isHandlingSessionExpiry = true;
        try {
          onSessionExpired?.call();
        } finally {
          _isHandlingSessionExpiry = false;
        }
      }
    }
    return handler.next(err);
  }
}

