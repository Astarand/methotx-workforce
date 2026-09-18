import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/attendance_record_model.dart'
    as rec
    show AttendanceStatus;
import '../../../../shared/models/attendance_record_model.dart'
    hide AttendanceStatus;
import '../../domain/entities/attendance_entity.dart';

/// Authoritative Server Duration Parser fixing "HH:mm" vs "HH:mm:ss" vs "mm:ss"
Duration parseServerDuration(dynamic raw) {
  if (raw == null) return Duration.zero;
  final str = raw.toString().trim();
  if (str.isEmpty ||
      str == '0' ||
      str == 'null' ||
      str == '00:00' ||
      str == '00:00:00') {
    return Duration.zero;
  }

  // 1. Colon-separated formats: "HH:mm:ss" or "HH:mm"
  if (str.contains(':')) {
    final parts = str
        .split(':')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();

    // Format "HH:mm:ss" (e.g. "00:06:00" = 6 mins)
    if (parts.length >= 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }

    // Format "HH:mm" (e.g. "00:06" = 0 hours, 6 minutes - NOT 6 seconds!)
    if (parts.length == 2) {
      return Duration(hours: parts[0], minutes: parts[1]);
    }
  }

  // 2. Pure integer/double (Backend sends raw minutes, e.g. "6" or 6)
  final numValue = double.tryParse(str);
  if (numValue != null) {
    return Duration(seconds: (numValue * 60).round());
  }

  // 3. Textual formats (e.g. "6 mins", "1h 15m")
  int hours = 0;
  int minutes = 0;
  int seconds = 0;

  final hMatch = RegExp(r'(\d+)\s*(?:h|hr|hrs|hour|hours)').firstMatch(str);
  final mMatch = RegExp(
    r'(\d+)\s*(?:m|min|mins|minute|minutes)',
  ).firstMatch(str);
  final sMatch = RegExp(
    r'(\d+)\s*(?:s|sec|secs|second|seconds)',
  ).firstMatch(str);

  if (hMatch != null) hours = int.tryParse(hMatch.group(1)!) ?? 0;
  if (mMatch != null) minutes = int.tryParse(mMatch.group(1)!) ?? 0;
  if (sMatch != null) seconds = int.tryParse(sMatch.group(1)!) ?? 0;

  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

/// Cumulative Calculation from Break Entries (Bulletproof Fallback)
Duration calculateTotalBreakFromEntries(dynamic breakData) {
  Duration total = Duration.zero;
  if (breakData == null) return total;

  List<dynamic> entries = [];
  if (breakData is Map && breakData['entries'] is List) {
    entries = breakData['entries'] as List<dynamic>;
  } else if (breakData is List) {
    entries = breakData;
  }

  for (final entry in entries) {
    if (entry is Map) {
      final bInStr =
          entry['breakIn']?.toString() ?? entry['break_in']?.toString();
      final bOutStr =
          entry['breakOut']?.toString() ?? entry['break_out']?.toString();
      if (bInStr != null &&
          bOutStr != null &&
          bInStr.trim().isNotEmpty &&
          bOutStr.trim().isNotEmpty) {
        try {
          final inTime = DateFormat('HH:mm:ss').parse(bInStr.trim());
          final outTime = DateFormat('HH:mm:ss').parse(bOutStr.trim());
          final diff = outTime.difference(inTime);
          if (!diff.isNegative) total += diff;
        } catch (_) {
          try {
            final inTime = DateFormat(
              'hh:mm a',
            ).parse(bInStr.trim().toUpperCase());
            final outTime = DateFormat(
              'hh:mm a',
            ).parse(bOutStr.trim().toUpperCase());
            final diff = outTime.difference(inTime);
            if (!diff.isNegative) total += diff;
          } catch (_) {}
        }
      }
    }
  }
  return total;
}

/// Formatter for Break Taken & Tiffin Taken UI Cards
String formatDurationToDisplay(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) {
    return "${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s";
  }
  return "${m}m ${s.toString().padLeft(2, '0')}s";
}

/// Data Transfer Object for Attendance & Employee Details API responses
class AttendanceModel {
  final String? punchInTime;
  final String? punchOutTime;
  final String? status;
  final double? punchInLat;
  final double? punchInLong;
  final double? punchOutLat;
  final double? punchOutLong;
  final String? lunchInTime;
  final String? lunchOutTime;
  final String? breakInTime;
  final String? breakOutTime;
  final String? todayDate;
  final Duration totalBreakDuration;
  final Duration totalLunchDuration;
  final Duration netWorkingDuration;
  final String? serverTime;

  // Shift & Daily Activity Parameters
  final String? openingTime;
  final String? closingTime;
  final bool? isLate;
  final String? lateBy;
  final String? holidayName;
  final String? leaveType;
  final String? leaveReason;

  // State machine fields from API
  final String? todayWorkingStatus; // 'not_present', 'present', 'punch_out'
  final String? lunchStatus; // 'none', 'ongoing', 'complete'
  final String? breakStatus; // 'none', 'ongoing', 'complete'
  final String? todayWorkLocation; // 'work_from_office', 'work_from_home'
  final String? workLocationStatus; // 'WFO', 'WFH'
  final double? officeLat;
  final double? officeLong;
  final double? allowedRadiusMeters;
  final String? privacyPolicyRead;
  final String? termsAndConditionsRead;
  final String? profileImg;

  AttendanceModel({
    this.punchInTime,
    this.punchOutTime,
    this.status,
    this.punchInLat,
    this.punchInLong,
    this.punchOutLat,
    this.punchOutLong,
    this.lunchInTime,
    this.lunchOutTime,
    this.breakInTime,
    this.breakOutTime,
    this.todayDate,
    this.totalBreakDuration = Duration.zero,
    this.totalLunchDuration = Duration.zero,
    this.netWorkingDuration = Duration.zero,
    this.serverTime,
    this.openingTime,
    this.closingTime,
    this.isLate,
    this.lateBy,
    this.holidayName,
    this.leaveType,
    this.leaveReason,
    this.todayWorkingStatus,

    this.lunchStatus,
    this.breakStatus,
    this.todayWorkLocation,
    this.workLocationStatus,
    this.officeLat,
    this.officeLong,
    this.allowedRadiusMeters,
    this.privacyPolicyRead,
    this.termsAndConditionsRead,
    this.profileImg,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['employee'] is Map<String, dynamic>) {
      data = json['employee'] as Map<String, dynamic>;
    }

    String? findString(List<String> candidateKeys) {
      final containers = [
        data,
        json,
        if (data['employee'] is Map) data['employee'] as Map,
        if (data['employee_details'] is Map) data['employee_details'] as Map,
        if (data['user'] is Map) data['user'] as Map,
        if (data['data'] is Map) data['data'] as Map,
        if (json['data'] is Map) json['data'] as Map,
        if (json['employee'] is Map) json['employee'] as Map,
        if (json['employee_details'] is Map) json['employee_details'] as Map,
        if (json['user'] is Map) json['user'] as Map,
      ];

      for (final container in containers) {
        for (final key in candidateKeys) {
          final val = container[key];
          if (val != null) {
            final str = val.toString().trim();
            if (str.isNotEmpty && str != 'null') return str;
          }
        }
      }
      return null;
    }

    double? findDouble(List<String> candidateKeys) {
      final containers = [
        data,
        json,
        if (data['employee'] is Map) data['employee'] as Map,
        if (data['employee_details'] is Map) data['employee_details'] as Map,
        if (data['office'] is Map) data['office'] as Map,
        if (data['office_location'] is Map) data['office_location'] as Map,
        if (data['branch'] is Map) data['branch'] as Map,
        if (data['company'] is Map) data['company'] as Map,
        if (data['user'] is Map) data['user'] as Map,
        if (data['data'] is Map) data['data'] as Map,
        if (json['data'] is Map) json['data'] as Map,
        if (json['employee'] is Map) json['employee'] as Map,
        if (json['employee_details'] is Map) json['employee_details'] as Map,
        if (json['office'] is Map) json['office'] as Map,
        if (json['office_location'] is Map) json['office_location'] as Map,
        if (json['branch'] is Map) json['branch'] as Map,
        if (json['company'] is Map) json['company'] as Map,
        if (json['user'] is Map) json['user'] as Map,
      ];

      for (final container in containers) {
        for (final key in candidateKeys) {
          final val = container[key];
          final parsed = _parseDouble(val);
          if (parsed != null && parsed != 0.0) return parsed;
        }
      }
      return null;
    }

    final rawWorkingStatus =
        data['todayWorkingStatus']?.toString() ??
        data['today_working_status']?.toString() ??
        data['attendance_status']?.toString() ??
        data['working_status']?.toString() ??
        data['status']?.toString();

    final parsedWorkingStatus = _parseWorkingStatus(rawWorkingStatus);

    final rawLunchStatus =
        data['lunchStatus']?.toString() ??
        data['lunch_status']?.toString() ??
        data['tiffin_status']?.toString();
    final parsedLunchStatus = _parseLunchStatus(rawLunchStatus);

    final rawBreakStatus =
        data['breakStatus']?.toString() ?? data['break_status']?.toString();
    final parsedBreakStatus = _parseBreakStatus(rawBreakStatus);

    final rawWorkLocation = findString([
      'today_work_location',
      'todayWorkLocation',
      'work_location',
      'workLocation',
      'work_mode',
      'workMode',
      'working_location',
      'workingLocation',
      'work_type',
      'workType',
      'assigned_work',
      'assigned_work_location',
    ]);

    final rawWorkLocationStatus = findString([
      'work_location_status',
      'workLocationStatus',
      'work_from_home',
      'is_wfh',
      'isWfh',
    ]);

    final parsedWorkLocationStatus = _parseWorkLocationStatus(
      rawWorkLocationStatus ?? rawWorkLocation,
    );

    Duration breakDur = Duration.zero;
    if (data['breaks'] is Map) {
      final bMap = data['breaks'] as Map;
      breakDur = parseServerDuration(
        bMap['totalBreakTime'] ??
            bMap['total_break_time'] ??
            bMap['total_break_mins'],
      );
      if (breakDur == Duration.zero) {
        breakDur = calculateTotalBreakFromEntries(bMap);
      }
    }
    if (breakDur == Duration.zero) {
      breakDur = parseServerDuration(
        data['totalBreakMinutes'] ??
            data['total_break_mins'] ??
            data['total_break_minutes'] ??
            data['totalBreakTime'] ??
            data['total_break_time'],
      );
    }

    final lunchDur = parseServerDuration(
      data['totalLunchMinutes'] ??
          data['total_lunch_mins'] ??
          data['total_lunch_minutes'] ??
          data['totalLunchTime'] ??
          data['total_lunch_time'] ??
          data['totalLunchDuration'],
    );

    final netWorkDur = parseServerDuration(
      data['netWorkingMinutes'] ??
          data['net_working_mins'] ??
          data['net_working_minutes'] ??
          data['workingHours'] ??
          data['net_working_time'],
    );

    final rawPunchIn =
        data['punchInTime']?.toString() ??
        data['punch_in_time']?.toString() ??
        data['punch_in']?.toString() ??
        data['inTime']?.toString() ??
        data['in_time']?.toString() ??
        data['check_in_time']?.toString();

    final rawPunchOut =
        data['punchOutTime']?.toString() ??
        data['punch_out_time']?.toString() ??
        data['punch_out']?.toString() ??
        data['outTime']?.toString() ??
        data['out_time']?.toString() ??
        data['check_out_time']?.toString();

    final rawOpening =
        data['openingTime']?.toString() ??
        data['opening_time']?.toString() ??
        data['shift_start_time']?.toString();

    final rawClosing =
        data['closingTime']?.toString() ??
        data['closing_time']?.toString() ??
        data['shift_end_time']?.toString();

    final parsedIsLate =
        data['isLate'] == true ||
        data['is_late'] == true ||
        data['late'] == true ||
        (data['lateBy'] != null &&
            data['lateBy'].toString().trim().isNotEmpty) ||
        (data['late_by'] != null &&
            data['late_by'].toString().trim().isNotEmpty);

    final rawLateBy =
        data['lateBy']?.toString() ??
        data['late_by']?.toString() ??
        data['late_duration']?.toString();

    final rawHoliday =
        data['holidayName']?.toString() ??
        data['holiday_name']?.toString() ??
        data['holiday']?.toString();

    final rawLeave =
        data['leaveType']?.toString() ??
        data['leave_type']?.toString() ??
        data['leave']?.toString();

    final rawLeaveReason =
        data['leaveReason']?.toString() ??
        data['leave_reason']?.toString() ??
        data['reason']?.toString() ??
        data['notes']?.toString();

    String? extractImg(Map<dynamic, dynamic>? m) {
      if (m == null) return null;
      final val =
          m['profile_img'] ??
          m['profileImg'] ??
          m['profile_image'] ??
          m['profileImage'] ??
          m['avatar'] ??
          m['photo'] ??
          m['image'] ??
          m['emp_image'] ??
          m['user_image'];
      if (val != null) {
        final str = val.toString().trim();
        if (str.isNotEmpty && str != 'null') return str;
      }
      return null;
    }

    final rawProfileImg =
        extractImg(data) ??
        (data['employee'] is Map
            ? extractImg(data['employee'] as Map)
            : null) ??
        (data['user'] is Map ? extractImg(data['user'] as Map) : null) ??
        (data['employee_details'] is Map
            ? extractImg(data['employee_details'] as Map)
            : null) ??
        (json['employee'] is Map
            ? extractImg(json['employee'] as Map)
            : null) ??
        (json['user'] is Map ? extractImg(json['user'] as Map) : null) ??
        (json['employee_details'] is Map
            ? extractImg(json['employee_details'] as Map)
            : null) ??
        extractImg(json);

    final hasPunchIn =
        rawPunchIn != null &&
        rawPunchIn.trim().isNotEmpty &&
        rawPunchIn != 'null';
    final hasPunchOut =
        rawPunchOut != null &&
        rawPunchOut.trim().isNotEmpty &&
        rawPunchOut != 'null';

    var effectiveWorkingStatus = parsedWorkingStatus;
    if (effectiveWorkingStatus == 'not_present' && hasPunchIn && !hasPunchOut) {
      effectiveWorkingStatus = 'present';
    } else if (hasPunchOut) {
      effectiveWorkingStatus = 'punch_out';
    }

    return AttendanceModel(
      punchInTime: rawPunchIn,
      punchOutTime: rawPunchOut,
      status:
          (data['status']?.toString() == 'Active' ||
              data['status']?.toString() == 'Inactive')
          ? (data['attendance_status']?.toString() ??
                data['todayWorkingStatus']?.toString() ??
                data['current_status']?.toString())
          : (data['status']?.toString() ?? data['current_status']?.toString()),
      punchInLat: _parseDouble(
        data['punchInLat'] ??
            data['latitude'] ??
            data['lat'] ??
            data['punch_in_lat'],
      ),
      punchInLong: _parseDouble(
        data['punchInLong'] ??
            data['longitude'] ??
            data['long'] ??
            data['lng'] ??
            data['punch_in_long'],
      ),
      punchOutLat: _parseDouble(data['punchOutLat'] ?? data['punch_out_lat']),
      punchOutLong: _parseDouble(
        data['punchOutLong'] ?? data['punch_out_long'],
      ),
      lunchInTime:
          data['lunchInTime']?.toString() ??
          data['lunch_in_time']?.toString() ??
          data['lunch_in']?.toString(),
      lunchOutTime:
          data['lunchOutTime']?.toString() ??
          data['lunch_out_time']?.toString() ??
          data['lunch_out']?.toString(),
      breakInTime:
          data['breakInTime']?.toString() ??
          data['break_in_time']?.toString() ??
          data['break_in']?.toString(),
      breakOutTime:
          data['breakOutTime']?.toString() ??
          data['break_out_time']?.toString() ??
          data['break_out']?.toString(),
      todayDate:
          data['todayDate']?.toString() ??
          data['today_date']?.toString() ??
          data['date']?.toString(),
      totalBreakDuration: breakDur,
      totalLunchDuration: lunchDur,
      netWorkingDuration: netWorkDur,
      serverTime:
          data['server_time']?.toString() ??
          data['serverTime']?.toString() ??
          json['server_time']?.toString(),
      openingTime: rawOpening,
      closingTime: rawClosing,
      isLate: parsedIsLate,
      lateBy: rawLateBy,
      holidayName: rawHoliday,
      leaveType: rawLeave,
      leaveReason: rawLeaveReason,
      todayWorkingStatus: effectiveWorkingStatus,

      lunchStatus: parsedLunchStatus,
      breakStatus: parsedBreakStatus,
      todayWorkLocation:
          rawWorkLocation ??
          (parsedWorkLocationStatus == 'WFO'
              ? 'work_from_office'
              : (parsedWorkLocationStatus == 'WFH' ? 'work_from_home' : '')),
      workLocationStatus: parsedWorkLocationStatus,
      officeLat: findDouble([
        'office_lat',
        'office_latitude',
        'officeLat',
        'officelat',
        'latitude',
        'lat',
        'branch_lat',
        'company_lat',
      ]),
      officeLong: findDouble([
        'office_long',
        'office_longitude',
        'officeLong',
        'officelong',
        'longitude',
        'long',
        'lng',
        'branch_long',
        'company_long',
      ]),
      allowedRadiusMeters: findDouble([
        'office_radius',
        'allowed_radius',
        'allowedRadiusMeters',
        'radius',
        'geofence_radius',
        'perimeter',
        'allowed_distance',
      ]),
      privacyPolicyRead: _parseReadStatus(
        data['privacy_policy_read'] ?? data['privacyPolicyRead'],
      ),
      termsAndConditionsRead: _parseReadStatus(
        data['terms_and_conditions'] ??
            data['termsAndConditionsRead'] ??
            data['terms_and_conditions_read'],
      ),
      profileImg: rawProfileImg,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _parseWorkingStatus(String? raw) {
    if (raw == null) return 'not_present';
    final s = raw
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (s == 'notpresent' ||
        s == 'absent' ||
        s == 'notpunchedin' ||
        s == 'none') {
      return 'not_present';
    }
    if (s == 'punchout' ||
        s == 'punchedout' ||
        s == 'shiftended' ||
        s == 'complete') {
      return 'punch_out';
    }
    if (s == 'present' ||
        s == 'working' ||
        s == 'punchedin' ||
        s == 'onbreak' ||
        s == 'ontiffin' ||
        s == 'ongoing' ||
        s == 'late' ||
        s == 'lunch' ||
        s == 'break' ||
        s == 'tiffin') {
      return 'present';
    }
    return 'not_present';
  }

  static String _parseLunchStatus(String? raw) {
    if (raw == null) return 'none';
    final s = raw
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (s == 'ongoing' ||
        s == 'active' ||
        s == 'onlunch' ||
        s == 'ontiffin' ||
        s == 'started') {
      return 'ongoing';
    }
    if (s == 'complete' ||
        s == 'completed' ||
        s == 'done' ||
        s == 'taken' ||
        s == 'ended' ||
        s == 'end' ||
        s == 'finish' ||
        s == 'finished') {
      return 'complete';
    }
    return 'none';
  }

  static String _parseBreakStatus(String? raw) {
    if (raw == null) return 'none';
    final s = raw
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (s == 'ongoing' || s == 'active' || s == 'onbreak' || s == 'started') {
      return 'ongoing';
    }
    if (s == 'complete' ||
        s == 'completed' ||
        s == 'done' ||
        s == 'ended' ||
        s == 'end' ||
        s == 'finish' ||
        s == 'finished') {
      return 'complete';
    }
    return 'none';
  }

  static String _parseWorkLocationStatus(dynamic raw) {
    if (raw == null) return 'WFH';
    if (raw is bool) return raw ? 'WFH' : 'WFO';
    final s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return 'WFH';

    final clean = s.replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');

    final hasOffice =
        clean.contains('office') || clean == 'wfo' || clean == 'workfromoffice';
    final hasHome =
        clean.contains('home') ||
        clean.contains('wfh') ||
        clean.contains('remote');

    if (hasOffice && !hasHome) {
      return 'WFO';
    }

    return 'WFH';
  }

  static String _parseReadStatus(dynamic value) {
    if (value == null) return 'read'; // Default optimistic
    if (value is bool) return value ? 'read' : 'unread';
    final s = value.toString().toLowerCase();
    if (s == 'read' ||
        s == 'true' ||
        s == '1' ||
        s == 'yes' ||
        s == 'accepted') {
      return 'read';
    }
    return 'unread';
  }

  AttendanceEntity toEntity() {
    final workStat = todayWorkingStatus ?? 'not_present';
    final lStat = lunchStatus ?? 'none';
    final bStat = breakStatus ?? 'none';

    AttendanceStatus statusEnum;
    if (workStat == 'punch_out') {
      statusEnum = AttendanceStatus.punchedOut;
    } else if (workStat == 'present') {
      if (bStat == 'ongoing') {
        statusEnum = AttendanceStatus.onBreak;
      } else if (lStat == 'ongoing') {
        statusEnum = AttendanceStatus.onTiffin;
      } else {
        statusEnum = AttendanceStatus.working;
      }
    } else {
      statusEnum = AttendanceStatus.notPunchedIn;
    }

    final parsedLocStatus = _parseWorkLocationStatus(
      workLocationStatus ?? todayWorkLocation,
    );

    return AttendanceEntity(
      punchInTime: _parseDateTime(punchInTime),
      punchOutTime: _parseDateTime(punchOutTime),
      currentStatus: statusEnum,
      punchInLat: punchInLat,
      punchInLong: punchInLong,
      punchOutLat: punchOutLat,
      punchOutLong: punchOutLong,
      lunchInTime: _parseDateTime(lunchInTime),
      lunchOutTime: _parseDateTime(lunchOutTime),
      breakInTime: _parseDateTime(breakInTime),
      breakOutTime: _parseDateTime(breakOutTime),
      todayDate: todayDate,
      totalBreakDuration: totalBreakDuration,
      totalLunchDuration: totalLunchDuration,
      netWorkingDuration: netWorkingDuration,
      serverTime: _parseDateTime(serverTime),
      openingTime: openingTime,
      closingTime: closingTime,
      isLate: isLate ?? false,
      lateBy: lateBy,
      holidayName: holidayName,
      leaveType: leaveType,
      backendStatus: status,
      todayWorkingStatus: workStat,
      lunchStatus: lStat,
      breakStatus: bStat,
      todayWorkLocation:
          todayWorkLocation ??
          (parsedLocStatus == 'WFH' ? 'work_from_home' : 'work_from_office'),
      workLocationStatus: parsedLocStatus,
      officeLat: officeLat ?? 0.0,
      officeLong: officeLong ?? 0.0,
      allowedRadiusMeters: allowedRadiusMeters ?? 200.0,
      privacyPolicyRead: privacyPolicyRead ?? 'read',
      termsAndConditionsRead: termsAndConditionsRead ?? 'read',
      profileImg: profileImg,
    );
  }

  AttendanceDayRecord toDayRecord(DateTime date) {
    rec.AttendanceStatus statusEnum;
    final wStat = (todayWorkingStatus ?? '').toLowerCase();
    final bStatus = (status ?? '').toLowerCase();

    final hasCheckIn =
        punchInTime != null &&
        punchInTime!.trim().isNotEmpty &&
        punchInTime!.trim() != 'Not recorded' &&
        punchInTime!.trim() != '--:-- --' &&
        punchInTime!.trim() != 'Not checked in';

    final isLeave =
        bStatus == 'leave' ||
        bStatus == 'approved_leave' ||
        bStatus == 'approved leave' ||
        bStatus.contains('leave') ||
        (leaveType != null && leaveType!.isNotEmpty);

    if (hasCheckIn ||
        wStat == 'present' ||
        wStat == 'punch_out' ||
        bStatus == 'present' ||
        bStatus == 'working') {
      statusEnum = rec.AttendanceStatus.present;
    } else if (bStatus == 'holiday' ||
        (holidayName != null && holidayName!.isNotEmpty)) {
      statusEnum = rec.AttendanceStatus.holiday;
    } else if (isLeave) {
      statusEnum = rec.AttendanceStatus.leave;
    } else if (bStatus.contains('off') ||
        bStatus.contains('weekend') ||
        bStatus == 'office_off' ||
        wStat.contains('off')) {
      statusEnum = rec.AttendanceStatus.officeOff;
    } else {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final dateStart = DateTime(date.year, date.month, date.day);

      if (dateStart.isAfter(todayStart) ||
          dateStart.isAtSameMomentAs(todayStart)) {
        statusEnum = rec.AttendanceStatus.notRecorded;
      } else {
        statusEnum = rec.AttendanceStatus.absent;
      }
    }

    final formattedCheckIn = hasCheckIn
        ? AppFormatters.formatTime12Hour(punchInTime)
        : null;
    final formattedCheckOut =
        (punchOutTime != null &&
            punchOutTime!.trim().isNotEmpty &&
            punchOutTime!.trim() != 'Not recorded' &&
            punchOutTime!.trim() != '--:-- --' &&
            punchOutTime!.trim() != 'Not checked out')
        ? AppFormatters.formatTime12Hour(punchOutTime)
        : null;
    final formattedLate = AppFormatters.formatLateDuration(lateBy);

    return AttendanceDayRecord(
      date: date,
      status: statusEnum,
      checkInTime:
          formattedCheckIn ??
          (statusEnum == rec.AttendanceStatus.leave ? 'On Leave' : null),
      checkOutTime:
          formattedCheckOut ??
          (statusEnum == rec.AttendanceStatus.leave ? 'On Leave' : null),
      workingDuration: netWorkingDuration,
      breakDuration: totalBreakDuration,
      lunchDuration: totalLunchDuration,
      isLate: isLate ?? false,
      lateBy: formattedLate.isNotEmpty ? formattedLate : lateBy,
      holidayName: holidayName,
      leaveType:
          leaveType ??
          (statusEnum == rec.AttendanceStatus.leave ? 'Approved Leave' : null),
      notes:
          leaveReason ??
          (statusEnum == rec.AttendanceStatus.leave ? 'Approved Leave' : null),
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim() == 'Not checked in' ||
        value.trim() == 'Not checked out') {
      return null;
    }
    final cleanVal = value.trim();

    // Try standard DateTime.tryParse (ISO 8601)
    try {
      final parsed = DateTime.tryParse(cleanVal);
      if (parsed != null) return parsed;
    } catch (_) {}

    final now = DateTime.now();

    // Try 12-hour formats like "09:30 AM" or "9:30:00 AM" or "9:30 AM"
    if (cleanVal.toUpperCase().contains('AM') ||
        cleanVal.toUpperCase().contains('PM')) {
      try {
        final parsed = DateFormat('h:mm:ss a').parse(cleanVal.toUpperCase());
        return DateTime(
          now.year,
          now.month,
          now.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
      } catch (_) {
        try {
          final parsed = DateFormat('h:mm a').parse(cleanVal.toUpperCase());
          return DateTime(
            now.year,
            now.month,
            now.day,
            parsed.hour,
            parsed.minute,
          );
        } catch (_) {}
      }
    }

    // Try 24-hour formats like "09:30:00" or "09:30"
    try {
      final parsed = DateFormat('HH:mm:ss').parse(cleanVal);
      return DateTime(
        now.year,
        now.month,
        now.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
    } catch (_) {
      try {
        final parsed = DateFormat('HH:mm').parse(cleanVal);
        return DateTime(
          now.year,
          now.month,
          now.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {}
    }

    return null;
  }
}
