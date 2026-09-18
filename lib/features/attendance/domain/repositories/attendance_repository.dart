import '../entities/attendance_entity.dart';
import '../../data/models/policy_model.dart';

/// Abstract repository contract for all Attendance, Geofence & Shift operations
abstract class AttendanceRepository {
  /// Fetches employee details & today's attendance working status
  Future<AttendanceEntity> fetchEmployeeDetails({
    required String empId,
    required String todayDate,
    required String secure,
  });

  /// Punch In API call
  Future<AttendanceEntity> punchInWithParams({
    required String todayDate,
    required String punchInTime,
    required String empId,
    required String secure,
    required double punchInLat,
    required double punchInLong,
    required String workLocationStatus,
  });

  /// Punch Out API call
  Future<AttendanceEntity> punchOutWithParams({
    required String empId,
    double? punchOutLat,
    double? punchOutLong,
    required String punchOutTime,
    required String secure,
    required String todayDate,
  });

  /// Lunch In API call
  Future<AttendanceEntity> lunchInWithParams({
    required String todayDate,
    required String lunchInTime,
    required String empId,
    required String secure,
  });

  /// Lunch Out API call
  Future<AttendanceEntity> lunchOutWithParams({
    required String todayDate,
    required String lunchOutTime,
    required String empId,
    required String secure,
  });

  /// Break In API call
  Future<AttendanceEntity> breakInWithParams({
    required String breakDate,
    required String breakInTime,
    required String empId,
    required String secure,
  });

  /// Break Out API call
  Future<AttendanceEntity> breakOutWithParams({
    required String breakDate,
    required String breakOutTime,
    required String empId,
    required String secure,
  });

  /// Policy Check API call
  Future<PolicyCheckResult> checkPolicies({
    required String employeeId,
    required String secure,
  });

  /// Daily Activity API call
  Future<AttendanceEntity> getDailyActivity({
    required String empId,
    required String date,
    required String secure,
  });

  // Legacy signatures
  Future<AttendanceEntity> getTodayAttendance();

  Future<AttendanceEntity> punchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceEntity> punchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceEntity> lunchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceEntity> lunchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceEntity> breakIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceEntity> breakOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  /// Drains and synchronizes queued offline punch/break actions when connectivity is active.
  /// Returns the number of successfully synced actions.
  Future<int> syncOfflineOutbox();
}

