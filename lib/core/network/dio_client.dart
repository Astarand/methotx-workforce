import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'api_constants.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';
import 'environment_config.dart';
import '../../routes/app_startup_notifier.dart';
import '../../features/authentication/presentation/controllers/auth_notifier.dart';

class DioClient {
  final Dio _dio;

  DioClient(this._dio);

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Decoupled handler provider for global session eviction (Clean Architecture)
final sessionExpiryHandlerProvider = Provider<void Function()>((ref) {
  return () {
    ref.read(appStartupProvider.notifier).logout();
    ref.read(authNotifierProvider.notifier).logout();
  };
});

/// Core Dio instance provider with BaseOptions, dynamic baseUrl, and interceptor chain
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final onSessionExpired = ref.watch(sessionExpiryHandlerProvider);

  final baseOptions = BaseOptions(
    baseUrl: EnvironmentConfig.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    sendTimeout: ApiConstants.sendTimeout,
    headers: {
      ApiConstants.headerContentType: ApiConstants.applicationJson,
      ApiConstants.headerAccept: ApiConstants.applicationJson,
      'Accept-Language': 'en,en-US;q=0.9',
      'X-Locale': 'en',
      'X-Language': 'en',
      'X-Localization': 'en',
      'Locale': 'en',
    },
    responseType: ResponseType.json,
  );

  final dio = Dio(baseOptions);

  // 1. Attach Custom Auth & Common Payload Interceptor
  dio.interceptors.add(
    AuthInterceptor(
      storageService: storageService,
      onSessionExpired: onSessionExpired,
    ),
  );


  // 2. Attach Structured Logging Interceptor in Debug Mode
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) {
          debugPrint('[DIO] $obj');
        },
      ),
    );
  }

  return dio;
});

/// Riverpod Provider exposing the configured DioClient
final Provider<DioClient> dioClientProvider = Provider<DioClient>((ref) {
  final dio = ref.watch(dioProvider);
  return DioClient(dio);
});
