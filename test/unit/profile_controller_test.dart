import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:methotx_workforce/core/services/security_service.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';
import 'package:methotx_workforce/features/profile/data/models/profile_model.dart';
import 'package:methotx_workforce/features/profile/domain/entities/profile_entity.dart';
import 'package:methotx_workforce/features/profile/domain/repositories/profile_repository.dart';
import 'package:methotx_workforce/features/profile/presentation/controllers/profile_controller.dart';
import 'package:methotx_workforce/features/profile/presentation/screens/profile_screen.dart';
import 'package:methotx_workforce/shared/models/employee_model.dart';

class FakeStorageService implements StorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> saveBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async {
    return _store[key] as bool?;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    return _store[key] as String?;
  }

  @override
  Future<void> saveInt(String key, int value) async {
    _store[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    return _store[key] as int?;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  @override
  Future<void> clearSecure() async {
    _store.clear();
  }

  @override
  Future<void> deleteSecure(String key) async {
    _store.remove(key);
  }

  @override
  Future<String?> getSecure(String key) async {
    return _store[key] as String?;
  }

  @override
  Future<void> saveSecure(String key, String value) async {
    _store[key] = value;
  }
}

class FakeSecurityService implements SecurityService {
  bool isAvailable = true;

  @override
  Future<bool> isBiometricsAvailable() async => isAvailable;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      isAvailable ? [BiometricType.fingerprint] : [];

  @override
  Future<bool> authenticateWithBiometrics({String reason = ''}) async =>
      isAvailable;

  @override
  Future<String> hashPin(String pin, [String? customSalt]) async => 'hash_$pin';

  @override
  String hashPinSync(String pin, [String? customSalt]) => 'hash_$pin';

  @override
  Future<bool> verifyPin(String enteredPin, String storedHash) async =>
      storedHash == 'hash_$enteredPin';

  @override
  bool verifyPinSync(String enteredPin, String storedHash) =>
      storedHash == 'hash_$enteredPin';
}

class FakeProfileRepository implements ProfileRepository {
  ProfileEntity? profileToReturn;
  ProfileEntity? cachedProfile;

  @override
  Future<ProfileEntity?> getCachedProfile() async => cachedProfile;

  @override
  Future<ProfileEntity> getProfile({
    required String empId,
    required String secure,
    bool forceRefresh = false,
  }) async {
    if (profileToReturn != null) {
      cachedProfile = profileToReturn;
      return profileToReturn!;
    }
    return ProfileEntity(
      id: empId,
      empId: empId,
      employeeCode: empId,
      fullName: 'Test Employee',
      email: 'employee@test.com',
      phone: '9999999999',
      designation: 'Developer',
      department: 'IT',
      workMode: 'Work From Home',
      joiningDate: DateTime(2025, 7, 1),
      isActive: true,
    );
  }

  @override
  Future<void> saveLocalProfile(ProfileEntity profile) async {
    cachedProfile = profile;
  }

  @override
  Future<ProfileEntity> updateRemoteProfile({
    required String name,
    required String email,
    required String contactNumber,
  }) async {
    final updated = (cachedProfile ?? profileToReturn ?? ProfileEntity(
      id: 'emp3-00001',
      empId: 'emp3-00001',
      employeeCode: 'emp3-00001',
      fullName: name,
      email: email,
      phone: contactNumber,
      designation: 'Developer',
      department: 'IT',
      workMode: 'Work From Home',
      joiningDate: DateTime(2025, 7, 1),
      isActive: true,
    )).copyWith(
      fullName: name,
      email: email,
      phone: contactNumber,
    );
    cachedProfile = updated;
    return updated;
  }
}

void main() {
  group('ProfileController Persistence Tests', () {
    late FakeStorageService fakeStorage;
    late EmployeeModel testEmployee;

    setUp(() {
      fakeStorage = FakeStorageService();
      testEmployee = EmployeeModel.defaultEmployee();
    });

    test(
      'toggleBiometrics updates state and persists in StorageService',
      () async {
        final controller = ProfileController(
          initialEmployee: testEmployee,
          storageService: fakeStorage,
        );

        await controller.toggleBiometrics(false);
        expect(controller.state.biometricAuthEnabled, isFalse);
        expect(
          await fakeStorage.getBool(ProfileController.biometricKey),
          isFalse,
        );

        await controller.toggleBiometrics(true);
        expect(controller.state.biometricAuthEnabled, isTrue);
        expect(
          await fakeStorage.getBool(ProfileController.biometricKey),
          isTrue,
        );
      },
    );

    test(
      'togglePushNotifications updates state and persists in StorageService',
      () async {
        final controller = ProfileController(
          initialEmployee: testEmployee,
          storageService: fakeStorage,
        );

        await controller.togglePushNotifications(false);
        expect(controller.state.pushNotificationsEnabled, isFalse);
        expect(
          await fakeStorage.getBool(ProfileController.pushNotificationsKey),
          isFalse,
        );

        await controller.togglePushNotifications(true);
        expect(controller.state.pushNotificationsEnabled, isTrue);
        expect(
          await fakeStorage.getBool(ProfileController.pushNotificationsKey),
          isTrue,
        );
      },
    );

    test('loads persisted settings on initialization', () async {
      await fakeStorage.saveBool(ProfileController.biometricKey, false);
      await fakeStorage.saveBool(ProfileController.pushNotificationsKey, false);

      final controller = ProfileController(
        initialEmployee: testEmployee,
        storageService: fakeStorage,
      );

      // Allow microtasks to complete _loadPersistedSettings
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state.biometricAuthEnabled, isFalse);
      expect(controller.state.pushNotificationsEnabled, isFalse);
    });

    test('updateProfile calls updateRemoteProfile and updates state successfully', () async {
      final fakeRepo = FakeProfileRepository();
      final controller = ProfileController(
        initialEmployee: testEmployee,
        storageService: fakeStorage,
        profileRepository: fakeRepo,
      );

      final success = await controller.updateProfile(
        fullName: 'Updated Name',
        email: 'updated@example.com',
        phone: '9876543211',
      );

      expect(success, isTrue);
      expect(controller.state.profile.fullName, 'Updated Name');
      expect(controller.state.profile.email, 'updated@example.com');
      expect(controller.state.profile.phone, '9876543211');
      expect(controller.state.successMessage, 'Profile information updated successfully!');
      expect(fakeRepo.cachedProfile?.fullName, 'Updated Name');
      expect(fakeRepo.cachedProfile?.email, 'updated@example.com');
      expect(fakeRepo.cachedProfile?.phone, '9876543211');
    });
  });

  group('ProfileModel & Entity Comprehensive API Parsing Tests', () {
    test('ProfileModel parses GET /api/users/employee/profile payload accurately', () {
      final json = {
        'success': true,
        'data': {
          'id': 10,
          'employee_id': 'emp3-00001',
          'name': 'Employee Name',
          'email': 'employee@example.com',
          'contact_number': '9876543210',
        },
      };

      final model = ProfileModel.fromJson(json);
      expect(model.id, '10');
      expect(model.employeeCode, 'emp3-00001');
      expect(model.fullName, 'Employee Name');
      expect(model.email, 'employee@example.com');
      expect(model.phone, '9876543210');
    });
    test('ProfileModel parses live employee details payload accurately', () {
      final json = {
        'success': true,
        'message': 'Employee details fetched',
        'data': {
          'employee_details': {
            'empId': '35',
            'name': 'Rittik Sadhukhan',
            'email': 'rittik.sk@hotmail.com',
            'phone': '9609412418',
            'employee_id': 'emp2-00011',
            'joining_date': '2025-07-01',
            'dept_name': 'IT',
            'designation_name': 'Full Stack Developer',
            'work_location': 'Work From Home',
            'profile_img': '/storage/profile/avatar.png',
            'opening_time': '10:00:00',
            'closing_time': '19:00:00',
            'pan_number': 'KYMPS6119C',
            'aadhaar_number': '704021890738',
            'is_active': 1,
          },
        },
      };

      final model = ProfileModel.fromJson(json);
      expect(model.empId, '35');
      expect(model.employeeCode, 'emp2-00011');
      expect(model.fullName, 'Rittik Sadhukhan');
      expect(model.email, 'rittik.sk@hotmail.com');
      expect(model.phone, '9609412418');
      expect(model.designation, 'Full Stack Developer');
      expect(model.department, 'IT');
      expect(model.workMode, 'Work From Home');
      expect(model.avatarUrl, '/storage/profile/avatar.png');
      expect(model.joiningDate, DateTime(2025, 7, 1));
      expect(model.panNumber, 'KYMPS6119C');
      expect(model.aadhaarNumber, '704021890738');
      expect(model.isActive, isTrue);

      final entity = model.toEntity();
      expect(entity.isWFH, isTrue);
      expect(entity.isWFO, isFalse);
      expect(entity.displayWorkMode, 'Work From Home');
      expect(entity.formattedJoiningDate, '01 Jul 2025');
      expect(entity.displayStatus, 'Active');
      expect(entity.formattedShift, contains('10:00'));
      expect(entity.resolvedAvatarUrl, contains('/storage/profile/avatar.png'));
    });

    test('ProfileModel handles office work location and shift formatting', () {
      final json = {
        'empId': '40',
        'employee_id': 'emp2-00040',
        'name': 'Jane Doe',
        'email': 'jane@company.com',
        'phone': '9876543210',
        'designation_name': 'HR Specialist',
        'dept_name': 'Human Resources',
        'work_location': 'Work_From_Office',
        'joining_date': '2024-01-15',
        'opening_time': '09:30:00',
        'closing_time': '18:30:00',
        'is_active': true,
      };

      final model = ProfileModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.isWFO, isTrue);
      expect(entity.isWFH, isFalse);
      expect(entity.displayWorkMode, 'Work From Office');
      expect(entity.formattedJoiningDate, '15 Jan 2024');
      expect(entity.formattedShift, contains('09:30'));
    });
  });

  group('ProfileController Live API & Biometric Hardware Tests', () {
    late FakeStorageService fakeStorage;
    late FakeSecurityService fakeSecurity;
    late FakeProfileRepository fakeRepo;
    late EmployeeModel testEmployee;

    setUp(() {
      fakeStorage = FakeStorageService();
      fakeSecurity = FakeSecurityService();
      fakeRepo = FakeProfileRepository();
      testEmployee = EmployeeModel.defaultEmployee();
    });

    test('fetchProfile loads live API data into state', () async {
      fakeRepo.profileToReturn = const ProfileEntity(
        id: '35',
        empId: '35',
        employeeCode: 'emp2-00011',
        fullName: 'Rittik Sadhukhan',
        email: 'rittik.sk@hotmail.com',
        phone: '9609412418',
        avatarUrl: 'https://test.methotx.in/avatar.png',
        designation: 'Lead Architect',
        department: 'Engineering',
        workMode: 'Work From Home',
        isActive: true,
      );

      final controller = ProfileController(
        initialEmployee: testEmployee,
        storageService: fakeStorage,
        profileRepository: fakeRepo,
        securityService: fakeSecurity,
        empId: '35',
        secure: 'sec_123',
      );

      await controller.fetchProfile(isRefresh: true);

      expect(controller.state.profile.fullName, 'Rittik Sadhukhan');
      expect(controller.state.profile.designation, 'Lead Architect');
      expect(controller.state.profile.phone, '9609412418');
      expect(controller.state.employee.fullName, 'Rittik Sadhukhan');
      expect(controller.state.employee.designation, 'Lead Architect');
    });

    test(
      'toggleBiometrics rejects enabling when hardware is unsupported',
      () async {
        fakeSecurity.isAvailable = false;

        final controller = ProfileController(
          initialEmployee: testEmployee,
          storageService: fakeStorage,
          profileRepository: fakeRepo,
          securityService: fakeSecurity,
          empId: '35',
          secure: 'sec_123',
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final success = await controller.toggleBiometrics(true);
        expect(success, isFalse);
        expect(controller.state.biometricAuthEnabled, isFalse);
        expect(
          controller.state.errorMessage,
          contains('Biometric hardware is not available'),
        );
      },
    );

    test('updateProfile updates state and persists locally', () async {
      final controller = ProfileController(
        initialEmployee: testEmployee,
        storageService: fakeStorage,
        profileRepository: fakeRepo,
        securityService: fakeSecurity,
        empId: '35',
        secure: 'sec_123',
      );

      await controller.updateProfile(
        fullName: 'Updated Name',
        email: 'updated@example.com',
        phone: '1234567890',
      );

      expect(controller.state.profile.fullName, 'Updated Name');
      expect(controller.state.profile.email, 'updated@example.com');
      expect(controller.state.profile.phone, '1234567890');
      expect(controller.state.successMessage, isNotNull);
      expect(fakeRepo.cachedProfile?.fullName, 'Updated Name');
    });

    test('Parses nested HR master structure from payslip visible_data', () {
      final hrJson = {
        "status": "success",
        "data": {
          "payslip": {
            "salary_details": {
              "visible_data": {
                "employee_details": {
                  "empId": "35",
                  "name": "Rittik Sadhukhan",
                  "email": "rittik.sk@hotmail.com",
                  "phone": "9609412418",
                  "employee_id": "emp2-00011",
                  "joining_date": "2025-07-01",
                  "dept_name": "IT",
                  "designation_name": "Full Stack Developer",
                },
              },
            },
          },
        },
      };

      final model = ProfileModel.fromJson(hrJson);
      final entity = model.toEntity();

      expect(entity.employeeCode, 'emp2-00011');
      expect(entity.fullName, 'Rittik Sadhukhan');
      expect(entity.department, 'IT');
      expect(entity.phone, '9609412418');
      expect(entity.formattedJoiningDate, '01 Jul 2025');
    });

    test(
      'ProfileEntity.merge overrides default Engineering with actual IT department',
      () {
        const dailyAttendance = ProfileEntity(
          id: '35',
          empId: '35',
          employeeCode: 'emp2-00011',
          fullName: 'Rittik Sadhukhan',
          email: 'rittik.sk@hotmail.com',
          phone: '',
          designation: 'Full Stack Developer',
          department: 'Engineering',
          workMode: 'Work From Home',
          joiningDate: null,
        );

        final hrMaster = ProfileEntity(
          id: '35',
          empId: '35',
          employeeCode: 'emp2-00011',
          fullName: 'Rittik Sadhukhan',
          email: 'rittik.sk@hotmail.com',
          phone: '9609412418',
          designation: 'Full Stack Developer',
          department: 'IT',
          workMode: 'Work From Home',
          joiningDate: DateTime(2025, 7, 1),
        );

        final merged = dailyAttendance.merge(hrMaster);

        expect(merged.department, 'IT');
        expect(merged.phone, '9609412418');
        expect(merged.formattedJoiningDate, '01 Jul 2025');
        expect(merged.workMode, 'Work From Home');
      },
    );

    testWidgets(
      'ProfileScreen renders Department IT, Date Joined, and deletes Shift Timing',
      (tester) async {
        final customEmployee = EmployeeModel(
          id: '35',
          employeeCode: 'emp2-00011',
          fullName: 'Rittik Sadhukhan',
          designation: 'Full Stack Developer',
          department: 'IT',
          email: 'rittik.sk@hotmail.com',
          phone: '9609412418',
          avatarUrl: 'assets/images/avatar-dummy.jpg',
          workMode: 'Work From Home',
          locationStatus: 'Detected',
          geofenceStatus: 'Ready',
          isActive: true,
          joiningDate: DateTime(2025, 7, 1),
        );

        final controller = ProfileController(
          initialEmployee: customEmployee,
          storageService: fakeStorage,
          profileRepository: fakeRepo,
          securityService: fakeSecurity,
          empId: '35',
          secure: 'sec_123',
        );

        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
          ),
        );
        await tester.pump();

        // Verify Department is IT
        expect(find.text('Department'), findsOneWidget);
        expect(find.text('IT'), findsWidgets);

        // Verify Date Joined is rendered
        expect(find.text('Date Joined'), findsOneWidget);
        expect(find.text('01 Jul 2025'), findsOneWidget);

        // Verify Shift Timing is completely deleted as requested
        expect(find.text('Shift Timing'), findsNothing);
        expect(find.textContaining('Regular Shift'), findsNothing);

        // Verify App Settings elements are rendered
        expect(find.text('App Settings'), findsOneWidget);
        expect(find.text('Biometric Quick Unlock'), findsOneWidget);
        expect(find.text('Push Notifications'), findsOneWidget);
        expect(find.text('Change Security PIN'), findsOneWidget);

        // Verify Logout button says exactly 'Log Out' (and not 'Log Out of MethotX')
        expect(find.text('Log Out'), findsOneWidget);
        expect(find.text('Log Out of MethotX'), findsNothing);
      },
    );
  });
}
