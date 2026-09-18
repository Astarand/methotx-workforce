import 'package:intl/intl.dart';

/// Current working status of the employee for the active shift
enum AttendanceStatus {
  notPunchedIn,
  working,
  onBreak,
  onTiffin,
  punchedOut,
  officeOff,
  holiday,
  onLeave,
}

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.notPunchedIn:
        return 'Not Punched In';
      case AttendanceStatus.working:
        return 'Working';
      case AttendanceStatus.onBreak:
        return 'On Short Break';
      case AttendanceStatus.onTiffin:
        return 'On Tiffin Break';
      case AttendanceStatus.punchedOut:
        return 'Shift Ended';
      case AttendanceStatus.officeOff:
        return 'Office Closed';
      case AttendanceStatus.holiday:
        return 'Holiday';
      case AttendanceStatus.onLeave:
        return 'On Leave';
    }
  }

  bool get isPunchedIn =>
      this == AttendanceStatus.working ||
      this == AttendanceStatus.onBreak ||
      this == AttendanceStatus.onTiffin;
}

/// Clean Architecture Entity representing today's attendance state & state machine
class AttendanceEntity {
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final AttendanceStatus currentStatus;
  final double? punchInLat;
  final double? punchInLong;
  final double? punchOutLat;
  final double? punchOutLong;
  final DateTime? lunchInTime;
  final DateTime? lunchOutTime;
  final DateTime? breakInTime;
  final DateTime? breakOutTime;
  final String? todayDate;
  final Duration totalBreakDuration;
  final Duration totalLunchDuration;
  final Duration netWorkingDuration;
  final DateTime? serverTime;

  // Shift & Daily Activity parameters
  final String? openingTime;
  final String? closingTime;
  final bool isLate;
  final String? lateBy;
  final String? holidayName;
  final String? leaveType;
  final String? backendStatus;

  // State Machine & Geofencing fields
  final String todayWorkingStatus; // 'not_present', 'present', 'punch_out'
  final String lunchStatus;        // 'none', 'ongoing', 'complete'
  final String breakStatus;        // 'none', 'ongoing', 'complete'
  final String locationStatus;     // 'initial', 'checking', 'calculating', 'inside', 'outside', 'error'
  final String workLocationStatus; // 'WFO', 'WFH'
  final String todayWorkLocation;   // 'work_from_office', 'work_from_home'
  final double officeLat;
  final double officeLong;
  final double allowedRadiusMeters;
  final String privacyPolicyRead;   // 'read', 'unread'
  final String termsAndConditionsRead; // 'read', 'unread'
  final String? profileImg;

  const AttendanceEntity({
    this.punchInTime,
    this.punchOutTime,
    this.currentStatus = AttendanceStatus.notPunchedIn,
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
    this.isLate = false,
    this.lateBy,
    this.holidayName,
    this.leaveType,
    this.backendStatus,
    this.todayWorkingStatus = 'not_present',
    this.lunchStatus = 'none',
    this.breakStatus = 'none',
    this.locationStatus = 'initial',
    this.workLocationStatus = '',
    this.todayWorkLocation = '',
    this.officeLat = 22.572646,
    this.officeLong = 88.363895,
    this.allowedRadiusMeters = 200.0,
    this.privacyPolicyRead = 'read',
    this.termsAndConditionsRead = 'read',
    this.profileImg,
  });

  bool get isPunchedIn =>
      (punchInTime != null && punchOutTime == null) ||
      todayWorkingStatus == 'present' ||
      todayWorkingStatus == 'lunch' ||
      todayWorkingStatus == 'break';
  bool get isPunchedOut =>
      punchOutTime != null || todayWorkingStatus == 'punch_out';
  bool get isNotPresent => !isPunchedIn && !isPunchedOut;
  bool get isOnBreak => breakStatus == 'ongoing';
  bool get isOnLunch => lunchStatus == 'ongoing';
  bool get isLunchComplete =>
      lunchStatus == 'complete' || lunchStatus == 'ended';
  bool get isWFH {
    final status = workLocationStatus.toUpperCase();
    final loc = todayWorkLocation.toLowerCase();
    if (status.isEmpty && loc.isEmpty) return false;
    if (status == 'WFH' ||
        loc.contains('home') ||
        loc.contains('wfh') ||
        loc.contains('remote')) {
      return true;
    }
    if (status == 'WFO' || loc.contains('office') || loc.contains('wfo')) {
      return false;
    }
    return true;
  }

  bool get isWFO {
    if (isWFH) return false;
    final status = workLocationStatus.toUpperCase();
    final loc = todayWorkLocation.toLowerCase();
    return (status == 'WFO' || loc.contains('office') || loc.contains('wfo')) &&
        (status.isNotEmpty || loc.isNotEmpty);
  }
  bool get arePoliciesRead =>
      privacyPolicyRead == 'read' && termsAndConditionsRead == 'read';

  AttendanceEntity copyWith({
    DateTime? punchInTime,
    DateTime? punchOutTime,
    AttendanceStatus? currentStatus,
    double? punchInLat,
    double? punchInLong,
    double? punchOutLat,
    double? punchOutLong,
    DateTime? lunchInTime,
    DateTime? lunchOutTime,
    DateTime? breakInTime,
    DateTime? breakOutTime,
    String? todayDate,
    Duration? totalBreakDuration,
    Duration? totalLunchDuration,
    Duration? netWorkingDuration,
    DateTime? serverTime,
    String? openingTime,
    String? closingTime,
    bool? isLate,
    String? lateBy,
    String? holidayName,
    String? leaveType,
    String? backendStatus,
    String? todayWorkingStatus,
    String? lunchStatus,
    String? breakStatus,
    String? locationStatus,
    String? workLocationStatus,
    String? todayWorkLocation,
    double? officeLat,
    double? officeLong,
    double? allowedRadiusMeters,
    String? privacyPolicyRead,
    String? termsAndConditionsRead,
    String? profileImg,
  }) {
    return AttendanceEntity(
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      currentStatus: currentStatus ?? this.currentStatus,
      punchInLat: punchInLat ?? this.punchInLat,
      punchInLong: punchInLong ?? this.punchInLong,
      punchOutLat: punchOutLat ?? this.punchOutLat,
      punchOutLong: punchOutLong ?? this.punchOutLong,
      lunchInTime: lunchInTime ?? this.lunchInTime,
      lunchOutTime: lunchOutTime ?? this.lunchOutTime,
      breakInTime: breakInTime ?? this.breakInTime,
      breakOutTime: breakOutTime ?? this.breakOutTime,
      todayDate: todayDate ?? this.todayDate,
      totalBreakDuration: totalBreakDuration ?? this.totalBreakDuration,
      totalLunchDuration: totalLunchDuration ?? this.totalLunchDuration,
      netWorkingDuration: netWorkingDuration ?? this.netWorkingDuration,
      serverTime: serverTime ?? this.serverTime,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      isLate: isLate ?? this.isLate,
      lateBy: lateBy ?? this.lateBy,
      holidayName: holidayName ?? this.holidayName,
      leaveType: leaveType ?? this.leaveType,
      backendStatus: backendStatus ?? this.backendStatus,
      todayWorkingStatus: todayWorkingStatus ?? this.todayWorkingStatus,
      lunchStatus: lunchStatus ?? this.lunchStatus,
      breakStatus: breakStatus ?? this.breakStatus,
      locationStatus: locationStatus ?? this.locationStatus,
      workLocationStatus: workLocationStatus ?? this.workLocationStatus,
      todayWorkLocation: todayWorkLocation ?? this.todayWorkLocation,
      officeLat: officeLat ?? this.officeLat,
      officeLong: officeLong ?? this.officeLong,
      allowedRadiusMeters: allowedRadiusMeters ?? this.allowedRadiusMeters,
      privacyPolicyRead: privacyPolicyRead ?? this.privacyPolicyRead,
      termsAndConditionsRead:
          termsAndConditionsRead ?? this.termsAndConditionsRead,
      profileImg: profileImg ?? this.profileImg,
    );
  }

  /// Parses the shift opening/start time for a given reference date
  DateTime? getShiftStartDateTime([DateTime? referenceDate]) {
    if (openingTime == null || openingTime!.trim().isEmpty) return null;
    final clean = openingTime!.trim().toUpperCase();
    final ref = referenceDate ?? DateTime.now();
    try {
      if (clean.contains('AM') || clean.contains('PM')) {
        final parsed = DateFormat('h:mm a').parse(clean);
        return DateTime(ref.year, ref.month, ref.day, parsed.hour, parsed.minute);
      } else if (clean.contains(':')) {
        final parts = clean.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(ref.year, ref.month, ref.day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  /// Parses the shift closing/end time for a given reference date
  DateTime? getShiftEndDateTime([DateTime? referenceDate]) {
    if (closingTime == null || closingTime!.trim().isEmpty) return null;
    final clean = closingTime!.trim().toUpperCase();
    final ref = referenceDate ?? DateTime.now();
    try {
      if (clean.contains('AM') || clean.contains('PM')) {
        final parsed = DateFormat('h:mm a').parse(clean);
        return DateTime(ref.year, ref.month, ref.day, parsed.hour, parsed.minute);
      } else if (clean.contains(':')) {
        final parts = clean.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(ref.year, ref.month, ref.day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  /// Checks whether today is a scheduled weekly off (Sunday or backend reported weekend)
  bool isWeekend([DateTime? referenceDate]) {
    final b = backendStatus?.toLowerCase() ?? '';
    if (b.contains('weekend')) return true;
    final date = referenceDate ?? DateTime.now();
    if (date.weekday == DateTime.sunday && b != 'present' && b != 'working') {
      return true;
    }
    return false;
  }

  /// Checks whether the office is closed today (backend status office_off or weekend)
  bool isOfficeOff([DateTime? referenceDate]) {
    final b = backendStatus?.toLowerCase() ?? '';
    return b == 'office_off' ||
        b == 'office off' ||
        b == 'officeoff' ||
        b.contains('off') ||
        b == 'closed' ||
        b.contains('closed') ||
        isWeekend(referenceDate);
  }

  /// Checks whether today is a public / company holiday
  bool get isHoliday =>
      (holidayName != null && holidayName!.trim().isNotEmpty) ||
      (backendStatus?.toLowerCase() == 'holiday');

  /// Checks whether employee is on approved leave today
  bool get isOnLeave =>
      (backendStatus?.toLowerCase() == 'leave') ||
      (leaveType != null && leaveType!.trim().isNotEmpty);

  /// Checks whether today is a non-working day (Weekend, Holiday, Office Off, or Approved Leave)
  /// If the employee has already punched in/out, active work takes priority.
  bool isNonWorkingDay([DateTime? referenceDate]) =>
      !isPunchedIn &&
      !isPunchedOut &&
      (isWeekend(referenceDate) || isHoliday || isOfficeOff(referenceDate) || isOnLeave);

  /// Calculates the earliest allowed punch-in time (2 hours before shift start)
  DateTime? getEarliestPunchInTime([DateTime? referenceDate]) {
    if (isNonWorkingDay(referenceDate)) return null;
    final start = getShiftStartDateTime(referenceDate);
    if (start == null) return null;
    return start.subtract(const Duration(hours: 2));
  }

  /// Calculates the grace time deadline (5 minutes buffer after shift start)
  DateTime? getGraceTime([DateTime? referenceDate]) {
    final start = getShiftStartDateTime(referenceDate);
    if (start == null) return null;
    return start.add(const Duration(minutes: 5));
  }

  /// Checks whether the punch-in window is currently open (enabled starting 2 hours before shift)
  bool isPunchInWindowOpen([DateTime? referenceDate]) {
    if (isNonWorkingDay(referenceDate)) return false;
    final earliest = getEarliestPunchInTime(referenceDate);
    if (earliest == null) {
      // If opening time not configured, default to allowing punch in
      return true;
    }
    final now = referenceDate ?? DateTime.now();
    return now.isAfter(earliest) || now.isAtSameMomentAs(earliest);
  }

  /// Checks whether login occurred after scheduled shift start time (e.g. 09:33 > 09:30 => Late)
  bool isPunchInLate(DateTime punchInTime) {
    final start = getShiftStartDateTime(punchInTime);
    if (start == null) return false;
    return punchInTime.isAfter(start);
  }

  /// Checks whether login is within the 5-minute grace period buffer for payroll deduction protection
  bool isWithinGraceBuffer(DateTime punchInTime) {
    final grace = getGraceTime(punchInTime);
    if (grace == null) return true;
    return punchInTime.isBefore(grace) || punchInTime.isAtSameMomentAs(grace);
  }

  /// Checks if a punch-in was strictly on or before shift opening time
  bool isPunchInOnTime(DateTime punchInTime) {
    final start = getShiftStartDateTime(punchInTime);
    if (start == null) return true;
    return !punchInTime.isAfter(start);
  }
}
