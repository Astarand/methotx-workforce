import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/employee_model.dart';
import '../../../../shared/widgets/secure_network_image.dart';
import '../../../authentication/domain/entities/auth_entity.dart';
import '../../../authentication/presentation/controllers/auth_notifier.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState {
  final ProfileEntity profile;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final bool biometricAuthEnabled;
  final bool pushNotificationsEnabled;
  final bool isHardwareBiometricsSupported;

  /// Backward-compatible bridge for legacy widgets/tests
  EmployeeModel get employee => EmployeeModel(
    id: profile.id,
    employeeCode: profile.employeeCode,
    fullName: profile.fullName,
    designation: profile.designation,
    department: profile.department,
    email: profile.email,
    phone: profile.phone,
    avatarUrl: profile.avatarUrl ?? 'assets/images/avatar-dummy.jpg',
    workMode: profile.workMode,
    locationStatus: 'Detected',
    geofenceStatus: 'Ready',
    isActive: profile.isActive,
    joiningDate: profile.joiningDate ?? DateTime(2023, 3, 15),
  );

  final int imageVersion;

  const ProfileState({
    required this.profile,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.biometricAuthEnabled = true,
    this.pushNotificationsEnabled = true,
    this.isHardwareBiometricsSupported = true,
    this.imageVersion = 0,
  });

  ProfileState copyWith({
    ProfileEntity? profile,
    EmployeeModel? employee, // for backward compatibility
    bool? isLoading,
    bool? isRefreshing,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool? biometricAuthEnabled,
    bool? pushNotificationsEnabled,
    bool? isHardwareBiometricsSupported,
    int? imageVersion,
  }) {
    ProfileEntity effectiveProfile = profile ?? this.profile;
    if (employee != null) {
      effectiveProfile = effectiveProfile.copyWith(
        id: employee.id,
        employeeCode: employee.employeeCode,
        fullName: employee.fullName,
        designation: employee.designation,
        department: employee.department,
        email: employee.email,
        phone: employee.phone,
        avatarUrl: employee.avatarUrl,
        workMode: employee.workMode,
        joiningDate: employee.joiningDate,
        isActive: employee.isActive,
      );
    }

    return ProfileState(
      profile: effectiveProfile,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      successMessage: successMessage,
      biometricAuthEnabled: biometricAuthEnabled ?? this.biometricAuthEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      isHardwareBiometricsSupported:
          isHardwareBiometricsSupported ?? this.isHardwareBiometricsSupported,
      imageVersion: imageVersion ?? this.imageVersion,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  final StorageService storageService;
  final ProfileRepository? profileRepository;
  final SecurityService? securityService;
  final String? empId;
  final String? secure;

  static const String biometricKey = 'biometric_enabled';
  static const String pushNotificationsKey = 'push_notifications_enabled';

  ProfileController({
    required EmployeeModel initialEmployee,
    required this.storageService,
    this.profileRepository,
    this.securityService,
    this.empId,
    this.secure,
  }) : super(ProfileState(profile: _mapEmployeeToEntity(initialEmployee))) {
    _loadPersistedSettings();
    _initProfile();
  }

  Future<void> _initProfile() async {
    if (profileRepository != null) {
      final cached = await profileRepository!.getCachedProfile();
      if (cached != null && mounted) {
        state = state.copyWith(profile: cached);
      }
    }
    await fetchProfile(isRefresh: false);
  }

  Future<String> _resolveEmpId() async {
    // 1. Prioritize valid string employee code (e.g. 'emp12-00002' or 'emp4-00001')
    final currentCode = state.profile.employeeCode.trim();
    if (currentCode.isNotEmpty &&
        currentCode != '0' &&
        int.tryParse(currentCode) == null) {
      return currentCode;
    }
    // 2. Check injected empId if string code
    if (empId != null &&
        empId!.trim().isNotEmpty &&
        empId!.trim() != '0' &&
        int.tryParse(empId!.trim()) == null) {
      return empId!.trim();
    }
    // 3. Check secure storage
    final s1 = await storageService.getSecure(ApiConstants.storageEmpIdKey);
    if (s1 != null &&
        s1.trim().isNotEmpty &&
        s1.trim() != '0' &&
        int.tryParse(s1.trim()) == null) {
      return s1.trim();
    }
    final s2 = await storageService.getString(ApiConstants.storageEmpIdKey);
    if (s2 != null &&
        s2.trim().isNotEmpty &&
        s2.trim() != '0' &&
        int.tryParse(s2.trim()) == null) {
      return s2.trim();
    }
    // 4. Fallback to any non-empty code
    if (currentCode.isNotEmpty && currentCode != '0') return currentCode;
    if (empId != null && empId!.trim().isNotEmpty) return empId!.trim();
    return s1?.trim() ?? s2?.trim() ?? '';
  }

  Future<String> _resolveSecure() async {
    if (secure != null && secure!.trim().isNotEmpty) return secure!.trim();
    final s1 = await storageService.getSecure(ApiConstants.storageSecureKey);
    if (s1 != null && s1.trim().isNotEmpty) return s1.trim();
    final s2 = await storageService.getString(ApiConstants.storageSecureKey);
    return s2?.trim() ?? '';
  }

  static ProfileEntity _mapEmployeeToEntity(EmployeeModel emp) {
    return ProfileEntity(
      id: emp.id,
      empId: emp.id,
      employeeCode: emp.employeeCode,
      fullName: emp.fullName,
      email: emp.email,
      phone: emp.phone,
      avatarUrl: emp.avatarUrl.contains('assets/') ? null : emp.avatarUrl,
      designation: emp.designation,
      department: emp.department,
      workMode: emp.workMode,
      joiningDate: emp.joiningDate,
      isActive: emp.isActive,
    );
  }

  Future<void> _loadPersistedSettings() async {
    final bio = await storageService.getBool(biometricKey);
    final push = await storageService.getBool(pushNotificationsKey);

    bool hardwareBio = true;
    if (securityService != null) {
      hardwareBio = await securityService!.isBiometricsAvailable();
    }

    if (mounted) {
      state = state.copyWith(
        biometricAuthEnabled: bio ?? (hardwareBio ? true : false),
        pushNotificationsEnabled: push ?? true,
        isHardwareBiometricsSupported: hardwareBio,
      );
    }
  }

  /// Fetches the profile dynamically from the backend API
  Future<void> fetchProfile({bool isRefresh = false}) async {
    if (profileRepository == null) return;

    final effectiveEmpId = await _resolveEmpId();
    final effectiveSecure = await _resolveSecure();
    if (effectiveEmpId.isEmpty || effectiveSecure.isEmpty) return;

    if (isRefresh) {
      state = state.copyWith(isRefreshing: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final fetchedProfile = await profileRepository!.getProfile(
        empId: effectiveEmpId,
        secure: effectiveSecure,
        forceRefresh: true,
      );

      // Evict all possible profile image cache entries for this employee on load/refresh
      try {
        await SecureNetworkImage.evictImage(
          ApiEndpoints.employeeProfileImage(effectiveEmpId),
        );
        if (fetchedProfile.avatarUrl != null &&
            fetchedProfile.avatarUrl!.isNotEmpty) {
          await SecureNetworkImage.evictImage(fetchedProfile.avatarUrl);
          await SecureNetworkImage.evictImage(
            ApiEndpoints.resolveImageUrl(fetchedProfile.avatarUrl),
          );
        }
      } catch (_) {}

      if (mounted) {
        state = state.copyWith(
          profile: fetchedProfile,
          imageVersion: DateTime.now().millisecondsSinceEpoch,
          isLoading: false,
          isRefreshing: false,
          errorMessage: null,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: 'Failed to load profile details: $e',
        );
      }
    }
  }

  /// Updates personal details remotely via PUT/PATCH API and syncs with local storage
  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? designation,
    String? department,
  }) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: null,
      successMessage: null,
    );

    final newName = fullName?.trim() ?? state.profile.fullName;
    final newEmail = email?.trim() ?? state.profile.email;
    final newPhone = phone?.trim() ?? state.profile.phone;

    try {
      ProfileEntity updatedEntity;
      if (profileRepository != null) {
        updatedEntity = await profileRepository!.updateRemoteProfile(
          name: newName,
          email: newEmail,
          contactNumber: newPhone,
        );
      } else {
        updatedEntity = state.profile.copyWith(
          fullName: newName,
          email: newEmail,
          phone: newPhone,
          designation: designation ?? state.profile.designation,
          department: department ?? state.profile.department,
        );
      }

      if (mounted) {
        state = state.copyWith(
          profile: updatedEntity,
          isSaving: false,
          successMessage: 'Profile information updated successfully!',
          errorMessage: null,
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to update profile: $e',
          successMessage: null,
        );
      }
      return false;
    }
  }

  /// Toggles biometric quick unlock with hardware capability validation and authentication check
  Future<bool> toggleBiometrics(bool value) async {
    if (value && securityService != null) {
      final canUseBio = await securityService!.isBiometricsAvailable();
      if (!canUseBio) {
        state = state.copyWith(
          biometricAuthEnabled: false,
          errorMessage:
              'Biometric hardware is not available or enrolled on this device.',
        );
        await storageService.saveBool(biometricKey, false);
        return false;
      }

      final authenticated = await securityService!.authenticateWithBiometrics(
        reason:
            'Authenticate with Fingerprint or Face ID to enable Biometric Quick Unlock',
      );
      if (!authenticated) {
        state = state.copyWith(
          biometricAuthEnabled: false,
          errorMessage:
              'Biometric authentication was cancelled or could not be verified.',
        );
        await storageService.saveBool(biometricKey, false);
        return false;
      }
    }

    state = state.copyWith(biometricAuthEnabled: value, errorMessage: null);
    await storageService.saveBool(biometricKey, value);
    return true;
  }

  /// Toggles push notification preferences and persists to storage
  Future<bool> togglePushNotifications(bool value) async {
    if (value) {
      try {
        final status = await Permission.notification.status;
        if (status.isDenied) {
          final requestStatus = await Permission.notification.request();
          if (!requestStatus.isGranted && !requestStatus.isProvisional) {
            state = state.copyWith(
              pushNotificationsEnabled: false,
              errorMessage:
                  'Notification permission is required to receive alerts.',
            );
            await storageService.saveBool(pushNotificationsKey, false);
            return false;
          }
        } else if (status.isPermanentlyDenied) {
          state = state.copyWith(
            pushNotificationsEnabled: false,
            errorMessage: 'Please enable notifications in device settings.',
          );
          await storageService.saveBool(pushNotificationsKey, false);
          return false;
        }
      } catch (_) {}
    }

    state = state.copyWith(pushNotificationsEnabled: value, errorMessage: null);
    await storageService.saveBool(pushNotificationsKey, value);
    return true;
  }
}

EmployeeModel _mapEntityToEmployee(AuthEntity user) {
  return EmployeeModel(
    id: user.empId,
    employeeCode: user.empId,
    fullName: user.fullName,
    designation: user.designation,
    department: user.department,
    email: user.email,
    phone: '',
    avatarUrl: user.profileImg ?? 'assets/images/avatar-dummy.jpg',
    workMode: user.workMode,
    locationStatus: 'Detected',
    geofenceStatus: 'Ready',
    isActive: user.isActive,
    joiningDate: DateTime(2025, 7, 1),
  );
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final authState = ref.watch(authNotifierProvider);
      final storageService = ref.watch(storageServiceProvider);
      final profileRepository = ref.watch(profileRepositoryProvider);
      final securityService = ref.watch(securityServiceProvider);

      final user = authState.user;
      final employee = user != null
          ? _mapEntityToEmployee(user)
          : EmployeeModel.defaultEmployee();

      return ProfileController(
        initialEmployee: employee,
        storageService: storageService,
        profileRepository: profileRepository,
        securityService: securityService,
        empId: user?.empId,
        secure: user?.secure,
      );
    });
