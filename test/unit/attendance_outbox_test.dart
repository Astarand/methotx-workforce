import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';
import 'package:methotx_workforce/features/attendance/data/datasources/attendance_remote_data_source.dart';
import 'package:methotx_workforce/features/attendance/data/models/attendance_model.dart';
import 'package:methotx_workforce/features/attendance/data/models/policy_model.dart';
import 'package:methotx_workforce/features/attendance/data/repositories/attendance_repository_impl.dart';

class FakeRemoteDataSource implements AttendanceRemoteDataSource {
  final List<String> calledActions = [];

  @override
  Future<AttendanceModel> punchInApi({
    required String todayDate,
    required String punchInTime,
    required String empId,
    required String secure,
    required double punchInLat,
    required double punchInLong,
    required String workLocationStatus,
  }) async {
    calledActions.add('punchInApi:$empId:$todayDate');
    return AttendanceModel(
      punchInTime: punchInTime,
      todayDate: todayDate,
      todayWorkingStatus: 'present',
    );
  }

  @override
  Future<AttendanceModel> punchOutApi({
    required String empId,
    double? punchOutLat,
    double? punchOutLong,
    required String punchOutTime,
    required String secure,
    required String todayDate,
  }) async {
    calledActions.add('punchOutApi:$empId:$todayDate');
    return AttendanceModel(
      punchOutTime: punchOutTime,
      todayDate: todayDate,
      todayWorkingStatus: 'punch_out',
    );
  }

  @override
  Future<AttendanceModel> lunchInApi({
    required String todayDate,
    required String lunchInTime,
    required String empId,
    required String secure,
  }) async {
    calledActions.add('lunchInApi');
    return AttendanceModel();
  }

  @override
  Future<AttendanceModel> lunchOutApi({
    required String todayDate,
    required String lunchOutTime,
    required String empId,
    required String secure,
  }) async {
    calledActions.add('lunchOutApi');
    return AttendanceModel();
  }

  @override
  Future<AttendanceModel> breakInApi({
    required String breakDate,
    required String breakInTime,
    required String empId,
    required String secure,
  }) async {
    calledActions.add('breakInApi');
    return AttendanceModel();
  }

  @override
  Future<AttendanceModel> breakOutApi({
    required String breakDate,
    required String breakOutTime,
    required String empId,
    required String secure,
  }) async {
    calledActions.add('breakOutApi');
    return AttendanceModel();
  }

  @override
  Future<AttendanceModel> fetchEmployeeDetails({
    required String empId,
    required String todayDate,
    required String secure,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> getDailyActivityApi({
    required String empId,
    required String date,
    required String secure,
  }) async => AttendanceModel();

  @override
  Future<PolicyCheckResult> checkPoliciesApi({
    required String employeeId,
    required String secure,
  }) async => PolicyCheckResult.fromJson({});

  @override
  Future<List<Map<String, dynamic>>> fetchCompanyHolidaysApi({
    required String empId,
    required String year,
    required String secure,
  }) async => [];

  @override
  Future<Map<String, dynamic>> getRangeSummaryApi({
    required String empId,
    required String fromDate,
    required String toDate,
    required String secure,
  }) async => {};

  @override
  Future<AttendanceModel> getTodayAttendance() async => AttendanceModel();

  @override
  Future<AttendanceModel> punchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> punchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> lunchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> lunchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> breakIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();

  @override
  Future<AttendanceModel> breakOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async => AttendanceModel();
}

class FakeStorageService implements StorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> saveString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    return _store[key] as String?;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> clearAll() async => _store.clear();
  @override
  Future<void> clearSecure() async => _store.clear();
  @override
  Future<void> deleteSecure(String key) async => _store.remove(key);
  @override
  Future<bool?> getBool(String key) async => _store[key] as bool?;
  @override
  Future<int?> getInt(String key) async => _store[key] as int?;
  @override
  Future<String?> getSecure(String key) async => _store[key] as String?;
  @override
  Future<void> saveBool(String key, bool value) async => _store[key] = value;
  @override
  Future<void> saveInt(String key, int value) async => _store[key] = value;
  @override
  Future<void> saveSecure(String key, String value) async => _store[key] = value;
}

void main() {
  group('AttendanceRepositoryImpl Offline Outbox Sync Tests', () {
    late FakeRemoteDataSource fakeRemote;
    late FakeStorageService fakeStorage;
    late AttendanceRepositoryImpl repository;

    setUp(() {
      fakeRemote = FakeRemoteDataSource();
      fakeStorage = FakeStorageService();
      repository = AttendanceRepositoryImpl(
        remoteDataSource: fakeRemote,
        storageService: fakeStorage,
      );
    });

    test('syncOfflineOutbox returns 0 when outbox is empty', () async {
      final synced = await repository.syncOfflineOutbox();
      expect(synced, equals(0));
      expect(fakeRemote.calledActions, isEmpty);
    });

    test('syncOfflineOutbox successfully dispatches queued items and clears outbox', () async {
      final queuedItems = [
        {
          'action': 'punchIn',
          'payload': {
            'todayDate': '2026-09-04',
            'punchInTime': '09:00:00',
            'empId': 'EMP001',
            'secure': 'dummy_key',
            'punchInLat': 22.57,
            'punchInLong': 88.36,
            'workLocationStatus': 'WFO',
          },
          'timestamp': DateTime.now().toIso8601String(),
        },
        {
          'action': 'punchOut',
          'payload': {
            'todayDate': '2026-09-04',
            'punchOutTime': '18:00:00',
            'empId': 'EMP001',
            'secure': 'dummy_key',
            'punchOutLat': 22.57,
            'punchOutLong': 88.36,
          },
          'timestamp': DateTime.now().toIso8601String(),
        },
      ];

      await fakeStorage.saveString('offline_attendance_outbox', jsonEncode(queuedItems));

      final count = await repository.syncOfflineOutbox();

      expect(count, equals(2));
      expect(fakeRemote.calledActions, contains('punchInApi:EMP001:2026-09-04'));
      expect(fakeRemote.calledActions, contains('punchOutApi:EMP001:2026-09-04'));

      // Storage should be drained
      final remaining = await fakeStorage.getString('offline_attendance_outbox');
      expect(remaining, isNull);
    });
  });
}
