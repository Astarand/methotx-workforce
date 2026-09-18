import 'dart:async';
import 'package:intl/intl.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../../shared/models/attendance_record_model.dart';
import 'attendance_data_repository.dart';
import 'datasources/attendance_remote_data_source.dart';

class MockAttendanceRepository implements AttendanceDataRepository {
  final AttendanceRemoteDataSource? remoteDataSource;
  final StorageService? storageService;

  MockAttendanceRepository({
    this.remoteDataSource,
    this.storageService,
  });

  Map<String, dynamic>? _cachedMonthlyData;
  DateTime? _cachedMonth;

  Future<Map<String, dynamic>> _fetchMonthlyData(DateTime month) async {
    if (_cachedMonthlyData != null &&
        _cachedMonth != null &&
        _cachedMonth!.year == month.year &&
        _cachedMonth!.month == month.month) {
      return _cachedMonthlyData!;
    }

    if (remoteDataSource != null && storageService != null) {
      try {
        final empId = (await storageService!.getSecure(ApiConstants.storageEmpIdKey)) ??
            (await storageService!.getString(ApiConstants.storageEmpIdKey)) ??
            '';
        final secure = (await storageService!.getSecure(ApiConstants.storageSecureKey)) ??
            (await storageService!.getString(ApiConstants.storageSecureKey)) ??
            '';

        final firstDay = DateTime(month.year, month.month, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0);

        final fromDate = DateFormat('yyyy-MM-dd').format(firstDay);
        final toDate = DateFormat('yyyy-MM-dd').format(lastDay);

        final data = await remoteDataSource!.getRangeSummaryApi(
          empId: empId,
          fromDate: fromDate,
          toDate: toDate,
          secure: secure,
        );

        if (data.isNotEmpty) {
          _cachedMonthlyData = data;
          _cachedMonth = month;
          return data;
        }
      } catch (_) {}
    }
    return {};
  }

  int _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    if (val is double) return val.toInt();
    return 0;
  }

  DateTime? _parseTimelineDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;
    try {
      return DateFormat('dd-MM-yyyy').parse(clean);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd').parse(clean);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parse(clean);
    } catch (_) {}
    return null;
  }

  AttendanceStatus _parseTimelineStatus(String? statusStr, {String? badgeClass}) {
    final s = (statusStr ?? '').trim().toLowerCase();
    final b = (badgeClass ?? '').trim().toLowerCase();
    if (s.contains('present') || b.contains('present')) return AttendanceStatus.present;
    if (s.contains('absent') || b.contains('absent')) return AttendanceStatus.absent;
    if (s.contains('leave') || b.contains('leave') || s == 'approved_leave' || s == 'approved leave') {
      return AttendanceStatus.leave;
    }
    if (s.contains('holiday') || b.contains('holiday')) return AttendanceStatus.holiday;
    if (s.contains('off') || s.contains('weekend') || b.contains('off')) return AttendanceStatus.officeOff;
    return AttendanceStatus.notRecorded;
  }


  Map<String, dynamic>? _getHolidayForDate(
      DateTime date, List<Map<String, dynamic>> holidays) {
    for (final h in holidays) {
      final rawDate = h['date']?.toString() ??
          h['holiday_date']?.toString() ??
          h['holidayDate']?.toString();
      final parsed = _parseTimelineDate(rawDate);
      if (parsed != null &&
          parsed.year == date.year &&
          parsed.month == date.month &&
          parsed.day == date.day) {
        return h;
      }
    }
    return null;
  }

  Duration _calculateWorkHours(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null || checkIn.isEmpty || checkOut.isEmpty) {
      return Duration.zero;
    }
    try {
      DateTime parseTime(String t) {
        final now = DateTime.now();
        try {
          final d = DateFormat('hh:mm a').parse(t.trim());
          return DateTime(now.year, now.month, now.day, d.hour, d.minute);
        } catch (_) {}
        try {
          final d = DateFormat('HH:mm:ss').parse(t.trim());
          return DateTime(now.year, now.month, now.day, d.hour, d.minute, d.second);
        } catch (_) {}
        try {
          final d = DateFormat('HH:mm').parse(t.trim());
          return DateTime(now.year, now.month, now.day, d.hour, d.minute);
        } catch (_) {}
        return now;
      }
      final start = parseTime(checkIn);
      final end = parseTime(checkOut);
      final diff = end.difference(start);
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Future<MonthlyAttendanceSummary> getMonthlySummary(DateTime month) async {
    final data = await _fetchMonthlyData(month);
    final totals = (data['totals'] is Map)
        ? (data['totals'] as Map)
        : ((data['data'] is Map && (data['data'] as Map)['totals'] is Map)
            ? (data['data'] as Map)['totals'] as Map
            : {});

    if (totals.isNotEmpty) {
      return MonthlyAttendanceSummary(
        presentCount: _parseInt(totals['totalPresent'] ?? totals['total_present'] ?? totals['present']),
        absentCount: _parseInt(totals['totalAbsent'] ?? totals['total_absent'] ?? totals['absent']),
        leaveCount: _parseInt(totals['totalLeave'] ?? totals['total_leave'] ?? totals['leave']),
        holidayCount: _parseInt(totals['totalHoliday'] ?? totals['total_holiday'] ?? totals['holiday']),
        officeOffCount: _parseInt(totals['totalOfficeOff'] ?? totals['total_office_off'] ?? totals['officeOff'] ?? totals['office_off']),
      );
    }

    return const MonthlyAttendanceSummary(
      presentCount: 0,
      absentCount: 0,
      leaveCount: 0,
      holidayCount: 0,
      officeOffCount: 0,
    );
  }

  @override
  Future<List<AttendanceDayRecord>> getMonthAttendanceRecords(DateTime month) async {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final records = <AttendanceDayRecord>[];

    final data = await _fetchMonthlyData(month);
    final timelineRaw = data['timeline'] ?? (data['data'] is Map ? (data['data'] as Map)['timeline'] : null);
    final timelineByDay = <int, Map<String, dynamic>>{};

    if (timelineRaw is List) {
      for (final item in timelineRaw) {
        if (item is Map<String, dynamic>) {
          final rawDate = item['date']?.toString();
          final parsedDate = _parseTimelineDate(rawDate);
          if (parsedDate != null &&
              parsedDate.year == month.year &&
              parsedDate.month == month.month) {
            timelineByDay[parsedDate.day] = item;
          }
        }
      }
    }

    final holidays = await getHolidayList(month.year);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final dateStart = DateTime(date.year, date.month, date.day);
      final holiday = _getHolidayForDate(date, holidays);

      // 1. Check timeline from range-summary API
      if (timelineByDay.containsKey(day)) {
        final item = timelineByDay[day]!;
        final rawStatus = item['status']?.toString();
        final badgeClass = item['badge_class']?.toString() ?? item['badgeClass']?.toString();
        var status = _parseTimelineStatus(rawStatus, badgeClass: badgeClass);

        if (status == AttendanceStatus.notRecorded && holiday != null) {
          status = AttendanceStatus.holiday;
        }

        final checkIn = item['check_in']?.toString();
        final checkOut = item['check_out']?.toString();
        final notes = item['notes']?.toString() ?? item['reason']?.toString() ?? item['leaveReason']?.toString();
        final leaveType = item['leave_type']?.toString() ?? item['leaveType']?.toString() ?? (status == AttendanceStatus.leave ? (notes ?? 'Leave') : null);
        final workDur = _calculateWorkHours(checkIn, checkOut);

        final hName = holiday?['name']?.toString();
        final hType = holiday?['type']?.toString();

        final formattedCheckIn = (checkIn != null && checkIn.isNotEmpty && checkIn != '-')
            ? checkIn
            : (status == AttendanceStatus.leave ? 'On Leave' : null);
        final formattedCheckOut = (checkOut != null && checkOut.isNotEmpty && checkOut != '-')
            ? checkOut
            : (status == AttendanceStatus.leave ? 'On Leave' : null);

        records.add(AttendanceDayRecord(
          date: date,
          status: status,
          checkInTime: formattedCheckIn,
          checkOutTime: formattedCheckOut,
          workingDuration: workDur,
          notes: notes,
          leaveType: leaveType,
          holidayName: hName != null ? (hType != null ? '$hName • $hType' : hName) : null,
        ));

      } else if (holiday != null) {
        // 2. Company holiday declared
        final hName = holiday['name']?.toString() ?? 'Company Holiday';
        final hType = holiday['type']?.toString() ?? 'Holiday';
        records.add(AttendanceDayRecord(
          date: date,
          status: AttendanceStatus.holiday,
          holidayName: '$hName • $hType',
          checkInTime: 'Office Holiday',
          checkOutTime: 'Office Holiday',
        ));
      } else {
        // 3. Normal workday without timeline entry
        if (dateStart.isAfter(todayStart)) {
          records.add(AttendanceDayRecord(
            date: date,
            status: AttendanceStatus.notRecorded,
          ));
        } else if (dateStart.isAtSameMomentAs(todayStart)) {
          records.add(AttendanceDayRecord(
            date: date,
            status: AttendanceStatus.notRecorded,
            checkInTime: null,
            checkOutTime: null,
          ));
        } else {
          records.add(AttendanceDayRecord(
            date: date,
            status: AttendanceStatus.absent,
          ));
        }
      }
    }

    return records;
  }

  @override
  Future<AttendanceDayRecord> getDayOverview(DateTime date) async {
    if (remoteDataSource != null && storageService != null) {
      try {
        final empId = (await storageService!.getSecure(ApiConstants.storageEmpIdKey)) ??
            (await storageService!.getString(ApiConstants.storageEmpIdKey)) ??
            '';
        final secure = (await storageService!.getSecure(ApiConstants.storageSecureKey)) ??
            (await storageService!.getString(ApiConstants.storageSecureKey)) ??
            '';
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final model = await remoteDataSource!.getDailyActivityApi(
          empId: empId,
          date: dateStr,
          secure: secure,
        );
        return model.toDayRecord(date);
      } catch (_) {}
    }


    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dateStart = DateTime(date.year, date.month, date.day);

    final fallbackStatus = dateStart.isAfter(todayStart)
        ? AttendanceStatus.notRecorded
        : AttendanceStatus.absent;

    return AttendanceDayRecord(
      date: date,
      status: fallbackStatus,
      checkInTime: null,
      checkOutTime: null,
      workingDuration: Duration.zero,
      breakDuration: Duration.zero,
      lunchDuration: Duration.zero,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getHolidayList(int year) async {
    if (remoteDataSource != null && storageService != null) {
      try {
        final empId = (await storageService!.getSecure(ApiConstants.storageEmpIdKey)) ??
            (await storageService!.getString(ApiConstants.storageEmpIdKey)) ??
            '';
        final secure = (await storageService!.getSecure(ApiConstants.storageSecureKey)) ??
            (await storageService!.getString(ApiConstants.storageSecureKey)) ??
            '';
        final holidays = await remoteDataSource!.fetchCompanyHolidaysApi(
          empId: empId,
          year: year.toString(),
          secure: secure,
        );
        return holidays;
      } catch (_) {}
    }
    return [];
  }
}
