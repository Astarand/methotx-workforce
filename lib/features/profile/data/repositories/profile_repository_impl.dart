import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final StorageService storageService;

  static const String keyFullName = 'user_full_name';
  static const String keyEmail = 'user_email';
  static const String keyPhone = 'user_phone';
  static const String keyDesignation = 'user_designation';
  static const String keyDepartment = 'user_department';
  static const String keyWorkMode = 'user_work_mode';
  static const String keyProfileImg = 'user_profile_img';
  static const String keyEmployeeCode = 'user_employee_code';
  static const String keyJoiningDate = 'user_joining_date';
  static const String keyOpeningTime = 'user_opening_time';
  static const String keyClosingTime = 'user_closing_time';
  static const String keyPan = 'user_pan_number';
  static const String keyAadhaar = 'user_aadhaar_number';

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  @override
  Future<ProfileEntity?> getCachedProfile() async {
    final empId =
        await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
        await storageService.getString(ApiConstants.storageEmpIdKey);

    final fullName = await storageService.getString(keyFullName);
    if (fullName == null || fullName.isEmpty) return null;

    final email = await storageService.getString(keyEmail) ?? '';
    final phone = await storageService.getString(keyPhone) ?? '';
    final designation =
        await storageService.getString(keyDesignation) ?? 'Employee';
    final department =
        await storageService.getString(keyDepartment) ?? 'General';
    final workMode =
        await storageService.getString(keyWorkMode) ?? 'Work From Home';
    final avatarUrl = await storageService.getString(keyProfileImg);
    final employeeCode =
        await storageService.getString(keyEmployeeCode) ?? empId ?? '';
    final joiningDateStr = await storageService.getString(keyJoiningDate);
    final openingTime = await storageService.getString(keyOpeningTime);
    final closingTime = await storageService.getString(keyClosingTime);
    final pan = await storageService.getString(keyPan);
    final aadhaar = await storageService.getString(keyAadhaar);

    DateTime? joiningDate;
    if (joiningDateStr != null && joiningDateStr.isNotEmpty) {
      try {
        joiningDate = DateTime.parse(joiningDateStr);
      } catch (_) {}
    }

    return ProfileEntity(
      id: empId ?? '0',
      empId: empId ?? '0',
      employeeCode: employeeCode.isNotEmpty ? employeeCode : (empId ?? '0'),
      fullName: fullName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      designation: designation,
      department: department,
      workMode: workMode,
      joiningDate: joiningDate,
      openingTime: openingTime,
      closingTime: closingTime,
      panNumber: pan,
      aadhaarNumber: aadhaar,
    );
  }

  @override
  Future<void> saveLocalProfile(ProfileEntity profile) async {
    await storageService.saveString(keyFullName, profile.fullName);
    await storageService.saveString(keyEmail, profile.email);
    await storageService.saveString(keyPhone, profile.phone);
    await storageService.saveString(keyDesignation, profile.designation);
    await storageService.saveString(keyDepartment, profile.department);
    await storageService.saveString(keyWorkMode, profile.workMode);
    await storageService.saveString(keyEmployeeCode, profile.employeeCode);

    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      await storageService.saveString(keyProfileImg, profile.avatarUrl!);
    }
    if (profile.joiningDate != null) {
      await storageService.saveString(
        keyJoiningDate,
        profile.joiningDate!.toIso8601String(),
      );
    }
    if (profile.openingTime != null) {
      await storageService.saveString(keyOpeningTime, profile.openingTime!);
    }
    if (profile.closingTime != null) {
      await storageService.saveString(keyClosingTime, profile.closingTime!);
    }
    if (profile.panNumber != null) {
      await storageService.saveString(keyPan, profile.panNumber!);
    }
    if (profile.aadhaarNumber != null) {
      await storageService.saveString(keyAadhaar, profile.aadhaarNumber!);
    }
  }

  @override
  Future<ProfileEntity> getProfile({
    required String empId,
    required String secure,
    bool forceRefresh = false,
  }) async {
    // Only return cached without network call if it is fully complete (has joining date & specific department)
    if (!forceRefresh) {
      final cached = await getCachedProfile();
      if (cached != null &&
          cached.joiningDate != null &&
          cached.department.isNotEmpty &&
          cached.department != 'General' &&
          cached.department != 'Engineering' &&
          cached.phone.isNotEmpty) {
        return cached;
      }
    }

    try {
      final model = await remoteDataSource.fetchEmployeeDetails(
        empId: empId,
        secure: secure,
      );
      final entity = model.toEntity();
      await saveLocalProfile(entity);
      return entity;
    } catch (e) {
      // Fallback to cache if remote failed
      final cached = await getCachedProfile();
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<ProfileEntity> updateRemoteProfile({
    required String name,
    required String email,
    required String contactNumber,
  }) async {
    final updatedModel = await remoteDataSource.updateEmployeeProfile(
      name: name,
      email: email,
      contactNumber: contactNumber,
    );

    final currentCached = await getCachedProfile();
    final updatedEntity = (currentCached ?? updatedModel.toEntity()).copyWith(
      fullName: name.trim(),
      email: email.trim(),
      phone: contactNumber.trim(),
    );

    await saveLocalProfile(updatedEntity);
    await storageService.saveString(keyFullName, name.trim());
    await storageService.saveString(keyEmail, email.trim());
    await storageService.saveString(keyPhone, contactNumber.trim());

    return updatedEntity;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);

  return ProfileRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
