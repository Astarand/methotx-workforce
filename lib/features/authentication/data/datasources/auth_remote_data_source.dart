import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/notification_service.dart';
import '../models/auth_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<String?> fetchDesignationName({
    required String empId,
    required String secure,
  });

  Future<Map<String, String?>?> fetchEmployeeProfile({
    required String empId,
    required String secure,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final String deviceType = !kIsWeb && Platform.isIOS ? 'ios' : 'android';
    String deviceToken = 'Fetch_Device_phone_token';
    try {
      final fcmToken = await NotificationService.instance.getToken();
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        deviceToken = fcmToken.trim();
      }
    } catch (_) {}

    final response = await dioClient.post(
      ApiEndpoints.login,
      data: {
        'email': email.trim(),
        'password': password,
        'device_token': deviceToken,
        'device_type': deviceType,
      },
    );

    final responseData = response.data;
    if (responseData is Map<String, dynamic>) {
      // Verify business success status returned under HTTP 200
      final isSuccess =
          responseData['status'] == true ||
          responseData['success'] == true ||
          responseData['status'] == 'success' ||
          responseData['status'] == 1;

      if (!isSuccess && responseData.containsKey('message')) {
        throw BadRequestException(
          message:
              responseData['message']?.toString() ??
              'Invalid login credentials.',
          statusCode: response.statusCode,
        );
      }

      final model = AuthResponseModel.fromJson(responseData);
      if (model.token.isEmpty) {
        throw const UnauthorizedException(
          message: 'Authentication token was not returned by server.',
        );
      }
      return model;
    } else {
      throw Exception('Unexpected response format from server: $responseData');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dioClient.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      // 401 TOKEN_MISMATCH or expired session: remote session is already invalid
      debugPrint(
        '[AuthRemoteDataSource] Remote logout DioException ignored: ${e.message}',
      );
    } catch (e) {
      // Catch all exceptions (ApiException, Network error, etc.) so execution never halts
      debugPrint('[AuthRemoteDataSource] Remote logout error ignored: $e');
    }
  }

  @override
  Future<String?> fetchDesignationName({
    required String empId,
    required String secure,
  }) async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await dioClient.post(
        ApiEndpoints.employeeDetails,
        data: {
          'empId': empId,
          'today_date': todayStr,
          'todayDate': todayStr,
          'date': todayStr,
          'secure': secure,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final userData = data['data'] ?? data['user'] ?? data;
        return userData['designation_name']?.toString() ??
            userData['designation']?.toString() ??
            userData['role']?.toString();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthRemoteDataSource] Error fetching designation name: $e',
        );
      }
      return null;
    }
  }

  @override
  Future<Map<String, String?>?> fetchEmployeeProfile({
    required String empId,
    required String secure,
  }) async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await dioClient.post(
        ApiEndpoints.employeeDetails,
        data: {
          'empId': empId,
          'today_date': todayStr,
          'todayDate': todayStr,
          'date': todayStr,
          'secure': secure,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final userData =
            (data['data'] is Map ? data['data'] as Map : null) ??
            (data['user'] is Map ? data['user'] as Map : null) ??
            (data['employee'] is Map ? data['employee'] as Map : null) ??
            (data['employee_details'] is Map
                ? data['employee_details'] as Map
                : null) ??
            data;

        final designation =
            userData['designation_name']?.toString() ??
            userData['designation']?.toString() ??
            userData['role']?.toString();

        final rawImg =
            userData['profile_img']?.toString() ??
            userData['profileImg']?.toString() ??
            userData['profile_image']?.toString() ??
            userData['profileImage']?.toString() ??
            userData['avatar']?.toString() ??
            userData['photo']?.toString() ??
            userData['image']?.toString();

        final cleanImg =
            (rawImg != null &&
                rawImg.trim().isNotEmpty &&
                rawImg.trim() != 'null')
            ? rawImg.trim()
            : null;

        return {'designation': designation, 'profileImg': cleanImg};
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthRemoteDataSource] Error fetching employee profile: $e',
        );
      }
      return null;
    }
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDataSourceImpl(dioClient: dioClient);
});
