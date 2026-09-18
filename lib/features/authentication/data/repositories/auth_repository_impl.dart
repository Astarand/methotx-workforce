import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final StorageService storageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  @override
  Future<AuthEntity> login(String email, String password) async {
    // 1. Authenticate via Remote Data Source
    final responseModel = await remoteDataSource.login(
      email: email,
      password: password,
    );

    if (responseModel.token.isEmpty || responseModel.empId.isEmpty) {
      throw const UnauthorizedException(
        message: 'Invalid credentials or missing employee ID.',
      );
    }

    // 2. Persist Sensitive Credentials in Hardware-Backed Secure Storage & SharedPreferences fallback
    await storageService.saveSecure(
      ApiConstants.storageTokenKey,
      responseModel.token,
    );
    await storageService.saveString(
      ApiConstants.storageTokenKey,
      responseModel.token,
    );

    await storageService.saveSecure(
      ApiConstants.storageEmpIdKey,
      responseModel.empId,
    );
    await storageService.saveString(
      ApiConstants.storageEmpIdKey,
      responseModel.empId,
    );

    if (responseModel.secure.isNotEmpty) {
      await storageService.saveSecure(
        ApiConstants.storageSecureKey,
        responseModel.secure,
      );
      await storageService.saveString(
        ApiConstants.storageSecureKey,
        responseModel.secure,
      );
    }

    // Persist non-sensitive session flags & profile display info in SharedPreferences
    await storageService.saveString('user_email', responseModel.email);
    await storageService.saveString('user_full_name', responseModel.fullName);
    await storageService.saveString('user_designation', responseModel.designation);
    await storageService.saveString('user_department', responseModel.department);
    await storageService.saveString('user_work_mode', responseModel.workMode);
    if (responseModel.profileImg != null &&
        responseModel.profileImg!.trim().isNotEmpty &&
        responseModel.profileImg != 'null') {
      await storageService.saveString('user_profile_img', responseModel.profileImg!.trim());
    }
    final modeLower = responseModel.workMode.toLowerCase();
    final isExplicitWfo = (modeLower.contains('office') || modeLower == 'wfo' || modeLower == 'work_from_office') &&
        !modeLower.contains('home') &&
        !modeLower.contains('wfh') &&
        !modeLower.contains('remote');
    final isWfhMode = !isExplicitWfo;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await storageService.saveString('user_work_location_status', isWfhMode ? 'WFH' : 'WFO');
    await storageService.saveString('user_today_work_location', isWfhMode ? 'Work_From_Home' : 'Work_From_Office');
    await storageService.saveString('user_work_location_status_$todayStr', isWfhMode ? 'WFH' : 'WFO');
    await storageService.saveString('user_today_work_location_$todayStr', isWfhMode ? 'Work_From_Home' : 'Work_From_Office');
    await storageService.saveBool('user_logged_in', true);

    // 3. Synchronize Push Notification FCM Token with Laravel backend
    NotificationService.instance.syncFcmTokenWithBackend(
      storageService: storageService,
    );

    // 4. Return Clean Domain Entity
    return responseModel.toEntity();
  }

  @override
  Future<void> logout() async {
    try {
      // 1. Attempt graceful remote token revocation
      await remoteDataSource.logout();
    } catch (e) {
      // 2. Ignore any error (401, timeout, token mismatch). Do NOT rethrow.
      debugPrint('[AuthRepository] Remote logout failed, proceeding with local wipe: $e');
    } finally {
      // 3. Unconditionally clear hardware-backed security credentials & persistent flags
      try {
        await storageService.deleteSecure(ApiConstants.storageTokenKey);
        await storageService.deleteSecure(ApiConstants.storageEmpIdKey);
        await storageService.deleteSecure(ApiConstants.storageSecureKey);
        await storageService.remove(ApiConstants.storageTokenKey);
        await storageService.remove(ApiConstants.storageEmpIdKey);
        await storageService.remove(ApiConstants.storageSecureKey);
        await storageService.remove('user_email');
        await storageService.remove('user_full_name');
        await storageService.remove('user_designation');
        await storageService.remove('user_department');
        await storageService.remove('user_work_mode');
        await storageService.remove('user_profile_img');
        await storageService.remove('user_work_location_status');
        await storageService.remove('user_today_work_location');
        await storageService.remove('cached_pending_tasks');
        await storageService.remove('cached_completed_tasks');
        await storageService.remove('cached_today_attendance');
        await storageService.remove('pin_attempt_count');
        await storageService.saveBool('user_logged_in', false);
      } catch (storageError) {
        debugPrint('[AuthRepository] Storage cleanup error: $storageError');
      }
    }
  }

  @override
  Future<AuthEntity?> getCurrentUser() async {
    final token = await storageService.getSecure(ApiConstants.storageTokenKey) ??
        await storageService.getString(ApiConstants.storageTokenKey);
    final empId = await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
        await storageService.getString(ApiConstants.storageEmpIdKey);
    final secure = await storageService.getSecure(ApiConstants.storageSecureKey) ??
        await storageService.getString(ApiConstants.storageSecureKey);
    final isLoggedIn = await storageService.getBool('user_logged_in') ?? false;

    if (token == null || token.isEmpty || !isLoggedIn) {
      return null;
    }

    final email = await storageService.getString('user_email') ?? '';
    final fullName = await storageService.getString('user_full_name') ?? 'Employee';
    final designation = await storageService.getString('user_designation') ?? 'Software Engineer';
    final department = await storageService.getString('user_department') ?? 'Engineering';
    final workMode = await storageService.getString('user_work_mode') ?? 'Home Office';
    final profileImg = await storageService.getString('user_profile_img');

    return AuthEntity(
      empId: empId ?? '',
      token: token,
      secure: secure ?? '',
      email: email,
      fullName: fullName,
      designation: designation,
      department: department,
      workMode: workMode,
      profileImg: profileImg,
      isActive: true,
    );
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await storageService.getSecure(ApiConstants.storageTokenKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<AuthEntity?> refreshProfile() async {
    final user = await getCurrentUser();
    if (user == null) return null;

    final profile = await remoteDataSource.fetchEmployeeProfile(
      empId: user.empId,
      secure: user.secure,
    );

    if (profile != null) {
      final designation = profile['designation'];
      final profileImg = profile['profileImg'];

      if (designation != null && designation.isNotEmpty) {
        await storageService.saveString('user_designation', designation);
      }
      if (profileImg != null && profileImg.isNotEmpty) {
        await storageService.saveString('user_profile_img', profileImg);
      }

      return user.copyWith(
        designation: designation ?? user.designation,
        profileImg: profileImg ?? user.profileImg,
      );
    }

    return user;
  }
}

/// Riverpod Provider exposing the Domain AuthRepository implemented by AuthRepositoryImpl
final authRepositoryDomainProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);

  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
