import '../../../../shared/models/leave_model.dart';

/// Pure Domain Entity for Leave Balances
class LeaveBalanceEntity {
  final LeaveType type;
  final String title;
  final int total;
  final int used;
  final int remaining;

  const LeaveBalanceEntity({
    required this.type,
    required this.title,
    required this.total,
    required this.used,
    required this.remaining,
  });
}

/// Pure Domain Entity for Leave Applications
class LeaveApplicationEntity {
  final String id;
  final String? employeeId;
  final String? employeeName;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final String reason;
  final LeaveStatus status;
  final DateTime appliedOn;
  final String? approvedBy;

  const LeaveApplicationEntity({
    required this.id,
    this.employeeId,
    this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.reason,
    required this.status,
    required this.appliedOn,
    this.approvedBy,
  });

  bool get isMultipleDays =>
      numberOfDays > 1 || !startDate.isAtSameMomentAs(endDate);

  /// Formatted approver name. Returns real human name if available,
  /// or 'Management' if only numeric ID or null.
  String get formattedApprover {
    if (approvedBy == null) return 'Management';
    final clean = approvedBy!.trim();
    if (clean.isEmpty || clean == 'null') return 'Management';
    if (int.tryParse(clean) != null) return 'Management';
    return clean;
  }

  LeaveApplicationEntity copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    LeaveType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfDays,
    String? reason,
    LeaveStatus? status,
    DateTime? appliedOn,
    String? approvedBy,
  }) {
    return LeaveApplicationEntity(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      appliedOn: appliedOn ?? this.appliedOn,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }
}

