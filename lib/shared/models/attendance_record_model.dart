enum AttendanceStatus {
  present,
  absent,
  leave,
  holiday,
  officeOff,
  notRecorded,
}

enum PunchState {
  punchedOut,
  punchedIn,
}

enum BreakState {
  none,
  onBreak,
  onTiffin,
}

enum LunchStatus {
  notStarted,
  ongoing,
  completed,
}

class AttendanceDayRecord {
  final DateTime date;
  final AttendanceStatus status;
  final String? checkInTime;
  final String? checkOutTime;
  final Duration workingDuration;
  final Duration breakDuration;
  final Duration lunchDuration;
  final Duration outsideOfficeDuration;
  final bool isLate;
  final String? lateBy;
  final String? holidayName;
  final String? leaveType;
  final String? notes;

  const AttendanceDayRecord({
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.workingDuration = Duration.zero,
    this.breakDuration = Duration.zero,
    this.lunchDuration = Duration.zero,
    this.outsideOfficeDuration = Duration.zero,
    this.isLate = false,
    this.lateBy,
    this.holidayName,
    this.leaveType,
    this.notes,
  });

  bool get isRecorded => checkInTime != null;

  AttendanceDayRecord copyWith({
    DateTime? date,
    AttendanceStatus? status,
    String? checkInTime,
    String? checkOutTime,
    Duration? workingDuration,
    Duration? breakDuration,
    Duration? lunchDuration,
    Duration? outsideOfficeDuration,
    bool? isLate,
    String? lateBy,
    String? holidayName,
    String? leaveType,
    String? notes,
  }) {
    return AttendanceDayRecord(
      date: date ?? this.date,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      workingDuration: workingDuration ?? this.workingDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      lunchDuration: lunchDuration ?? this.lunchDuration,
      outsideOfficeDuration:
          outsideOfficeDuration ?? this.outsideOfficeDuration,
      isLate: isLate ?? this.isLate,
      lateBy: lateBy ?? this.lateBy,
      holidayName: holidayName ?? this.holidayName,
      leaveType: leaveType ?? this.leaveType,
      notes: notes ?? this.notes,
    );
  }
}

class MonthlyAttendanceSummary {
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int holidayCount;
  final int officeOffCount;

  const MonthlyAttendanceSummary({
    this.presentCount = 0,
    this.absentCount = 1,
    this.leaveCount = 0,
    this.holidayCount = 0,
    this.officeOffCount = 0,
  });
}
