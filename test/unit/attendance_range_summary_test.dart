import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/network/api_constants.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';
import 'package:methotx_workforce/features/attendance/data/datasources/attendance_remote_data_source.dart';
import 'package:methotx_workforce/features/attendance/data/mock_attendance_repository.dart';
import 'package:methotx_workforce/features/attendance/data/models/attendance_model.dart';
import 'package:methotx_workforce/features/attendance/data/models/policy_model.dart';
import 'package:methotx_workforce/features/attendance/presentation/widgets/daily_overview_card.dart';
import 'package:methotx_workforce/shared/models/attendance_record_model.dart';

class MockAttendanceStorage implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> saveBool(String key, bool value) async => _data[key] = value;
  @override
  Future<bool?> getBool(String key) async => _data[key] as bool?;
  @override
  Future<void> saveString(String key, String value) async => _data[key] = value;
  @override
  Future<String?> getString(String key) async => _data[key] as String?;
  @override
  Future<void> saveInt(String key, int value) async => _data[key] = value;
  @override
  Future<int?> getInt(String key) async => _data[key] as int?;
  @override
  Future<void> remove(String key) async => _data.remove(key);
  @override
  Future<void> clear() async => _data.clear();
  @override
  Future<void> clearAll() async => _data.clear();
  @override
  Future<void> clearSecure() async => _data.clear();
  @override
  Future<void> saveSecure(String key, String value) async => _data[key] = value;
  @override
  Future<String?> getSecure(String key) async => _data[key] as String?;
  @override
  Future<void> deleteSecure(String key) async => _data.remove(key);
}

class MockAttendanceRemoteDataSource implements AttendanceRemoteDataSource {
  String? lastRangeFromDate;
  String? lastRangeToDate;
  String? lastDailyDate;
  String? lastHolidayYear;

  @override
  Future<Map<String, dynamic>> getRangeSummaryApi({
    required String empId,
    required String fromDate,
    required String toDate,
    required String secure,
  }) async {
    lastRangeFromDate = fromDate;
    lastRangeToDate = toDate;

    return {
      'totals': {
        'totalPresent': 22,
        'totalAbsent': 2,
        'totalLeave': 1,
        'totalHoliday': 4,
        'totalOfficeOff': 1,
      },
      'timeline': [
        {
          'date': '01-09-2026',
          'status': 'Present',
          'badge_class': 'present',
          'check_in': '09:35 AM',
          'check_out': '06:20 PM',
          'notes': '',
        },
        {
          'date': '02-09-2026',
          'status': 'Absent',
          'badge_class': 'absent',
          'check_in': null,
          'check_out': null,
          'notes': 'Unexcused',
        },
        {
          'date': '03-09-2026',
          'status': 'Leave',
          'badge_class': 'leave',
          'check_in': null,
          'check_out': null,
          'notes': 'Sick Leave',
        },
        {
          'date': '05-09-2026',
          'day': 'Saturday',
          'status': 'Present',
          'badge_class': 'present',
          'check_in': '09:30 AM',
          'check_out': '06:00 PM',
          'notes': 'Saturday Working',
        },
        {
          'date': '06-09-2026',
          'day': 'Sunday',
          'status': 'Office Off',
          'badge_class': 'office_off',
          'check_in': null,
          'check_out': null,
          'notes': 'Weekly Off',
        },
        {
          'date': '15-09-2026',
          'status': 'Holiday',
          'badge_class': 'holiday',
          'check_in': null,
          'check_out': null,
          'notes': 'Festival Holiday',
        },
      ],
    };
  }

  @override
  Future<AttendanceModel> getDailyActivityApi({
    required String empId,
    required String date,
    required String secure,
  }) async {
    lastDailyDate = date;
    return AttendanceModel(
      todayDate: date,
      todayWorkingStatus: 'present',
      punchInTime: '09:35 AM',
      punchOutTime: '06:20 PM',
      netWorkingDuration: const Duration(hours: 8, minutes: 15),
      isLate: true,
      lateBy: '20 minutes',
      workLocationStatus: 'Office',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCompanyHolidaysApi({
    required String empId,
    required String year,
    required String secure,
  }) async {
    lastHolidayYear = year;
    return [
      {
        'id': 1,
        'name': 'Gandhi Jayanti',
        'date': '02-10-2026',
        'type': 'National Holiday',
        'description': 'Birth of Mahatma Gandhi',
      }
    ];
  }

  // Other stubs
  @override
  Future<AttendanceModel> fetchEmployeeDetails({required String empId, required String todayDate, required String secure}) async => AttendanceModel();
  @override
  Future<AttendanceModel> punchInApi({required String todayDate, required String punchInTime, required String empId, required String secure, required double punchInLat, required double punchInLong, required String workLocationStatus}) async => AttendanceModel();
  @override
  Future<AttendanceModel> punchOutApi({required String todayDate, required String punchOutTime, required String empId, required String secure, double? punchOutLat, double? punchOutLong}) async => AttendanceModel();
  @override
  Future<AttendanceModel> lunchInApi({required String todayDate, required String lunchInTime, required String empId, required String secure}) async => AttendanceModel();
  @override
  Future<AttendanceModel> lunchOutApi({required String todayDate, required String lunchOutTime, required String empId, required String secure}) async => AttendanceModel();
  @override
  Future<AttendanceModel> breakInApi({required String breakDate, required String breakInTime, required String empId, required String secure}) async => AttendanceModel();
  @override
  Future<AttendanceModel> breakOutApi({required String breakDate, required String breakOutTime, required String empId, required String secure}) async => AttendanceModel();
  @override
  Future<PolicyCheckResult> checkPoliciesApi({required String employeeId, required String secure}) async => PolicyCheckResult.fromJson({});
  @override
  Future<AttendanceModel> getTodayAttendance() async => AttendanceModel();
  @override
  Future<AttendanceModel> punchIn({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
  @override
  Future<AttendanceModel> punchOut({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
  @override
  Future<AttendanceModel> lunchIn({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
  @override
  Future<AttendanceModel> lunchOut({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
  @override
  Future<AttendanceModel> breakIn({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
  @override
  Future<AttendanceModel> breakOut({required double latitude, required double longitude, DateTime? timestamp}) async => AttendanceModel();
}

void main() {
  group('Attendance History Range Summary & Daily Activity Tests', () {
    late MockAttendanceStorage storage;
    late MockAttendanceRemoteDataSource remoteDataSource;
    late MockAttendanceRepository repository;

    setUp(() async {
      storage = MockAttendanceStorage();
      await storage.saveSecure(ApiConstants.storageEmpIdKey, 'EMP001');
      await storage.saveSecure(ApiConstants.storageSecureKey, 'hash123');

      remoteDataSource = MockAttendanceRemoteDataSource();
      repository = MockAttendanceRepository(
        remoteDataSource: remoteDataSource,
        storageService: storage,
      );
    });

    test('1. getMonthlySummary calls range-summary and parses 5 category totals correctly', () async {
      final sept2026 = DateTime(2026, 9, 15);
      final summary = await repository.getMonthlySummary(sept2026);

      // Verify date calculation
      expect(remoteDataSource.lastRangeFromDate, equals('2026-09-01'));
      expect(remoteDataSource.lastRangeToDate, equals('2026-09-30'));

      // Verify parsed totals
      expect(summary.presentCount, equals(22));
      expect(summary.absentCount, equals(2));
      expect(summary.leaveCount, equals(1));
      expect(summary.holidayCount, equals(4));
      expect(summary.officeOffCount, equals(1));
    });

    test('2. getMonthAttendanceRecords parses timeline records and maps to AttendanceStatus', () async {
      final sept2026 = DateTime(2026, 9, 15);
      final records = await repository.getMonthAttendanceRecords(sept2026);

      // September 2026 has 30 days
      expect(records.length, equals(30));

      // Day 1: Present, check-in 09:35 AM, check-out 06:20 PM
      final day1 = records.firstWhere((r) => r.date.day == 1);
      expect(day1.status, equals(AttendanceStatus.present));
      expect(day1.checkInTime, equals('09:35 AM'));
      expect(day1.checkOutTime, equals('06:20 PM'));
      expect(day1.workingDuration.inHours, greaterThanOrEqualTo(8));

      // Day 2: Absent
      final day2 = records.firstWhere((r) => r.date.day == 2);
      expect(day2.status, equals(AttendanceStatus.absent));

      // Day 3: Leave
      final day3 = records.firstWhere((r) => r.date.day == 3);
      expect(day3.status, equals(AttendanceStatus.leave));

      // Day 5 (Saturday): Present (working day from timeline, not off!)
      final day5 = records.firstWhere((r) => r.date.day == 5);
      expect(day5.status, equals(AttendanceStatus.present));
      expect(day5.checkInTime, equals('09:30 AM'));

      // Day 6 (Sunday): Office Off (parsed dynamically from timeline)
      final day6 = records.firstWhere((r) => r.date.day == 6);
      expect(day6.status, equals(AttendanceStatus.officeOff));

      // Day 15: Holiday (parsed dynamically from timeline)
      final day15 = records.firstWhere((r) => r.date.day == 15);
      expect(day15.status, equals(AttendanceStatus.holiday));
    });

    test('3. getDayOverview calls daily-activity endpoint with selected date', () async {
      final selectedDate = DateTime(2026, 9, 4);
      final overview = await repository.getDayOverview(selectedDate);

      expect(remoteDataSource.lastDailyDate, equals('2026-09-04'));
      expect(overview.status, equals(AttendanceStatus.present));
      expect(overview.checkInTime, equals('09:35 AM'));
      expect(overview.checkOutTime, equals('06:20 PM'));
      expect(overview.isLate, isTrue);
      expect(overview.lateBy, equals('20 minutes'));
    });

    test('4. getHolidayList calls company holidays API with selected year', () async {
      final holidays = await repository.getHolidayList(2026);

      expect(remoteDataSource.lastHolidayYear, equals('2026'));
      expect(holidays.length, equals(1));
      expect(holidays.first['name'], equals('Gandhi Jayanti'));
    });

    test('5. Approved leave timeline record sets AttendanceStatus.leave, notes, and orange badge', () async {
      final sept2026 = DateTime(2026, 9, 15);
      final records = await repository.getMonthAttendanceRecords(sept2026);

      // Day 3 in mock timeline has status: 'Leave', badge_class: 'leave', notes: 'Sick Leave'
      final day3 = records.firstWhere((r) => r.date.day == 3);
      expect(day3.status, equals(AttendanceStatus.leave));
      expect(day3.leaveType, equals('Sick Leave'));
      expect(day3.notes, equals('Sick Leave'));
      expect(day3.checkInTime, equals('On Leave'));
      expect(day3.checkOutTime, equals('On Leave'));

      // Check badge styling: Orange #E37400 on #FEF7E0
      final badge = getAttendanceBadge(day3);
      expect(badge.label, equals('LEAVE'));
      expect(badge.color, equals(const Color(0xFFE37400)));
      expect(badge.bgColor, equals(const Color(0xFFFEF7E0)));
    });

    test('6. Daily activity API with leave status parses leave details into AttendanceDayRecord', () {
      final json = {
        'success': true,
        'data': {
          'date': '2026-09-10',
          'status': 'Leave',
          'leaveType': 'Casual',
          'leaveReason': 'Personal work',
          'inTime': null,
          'outTime': null,
        }
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.status, equals('Leave'));
      expect(model.leaveType, equals('Casual'));
      expect(model.leaveReason, equals('Personal work'));

      final record = model.toDayRecord(DateTime(2026, 9, 10));
      expect(record.status, equals(AttendanceStatus.leave));
      expect(record.leaveType, equals('Casual'));
      expect(record.notes, equals('Personal work'));
      expect(record.checkInTime, equals('On Leave'));
      expect(record.checkOutTime, equals('On Leave'));

      final badge = getAttendanceBadge(record);
      expect(badge.label, equals('LEAVE'));
      expect(badge.color, equals(const Color(0xFFE37400)));
    });
  });
}
