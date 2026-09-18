import 'package:intl/intl.dart';
import '../../features/leave/domain/entities/leave_entity.dart';

enum LeaveType {
  casual,
  sick,
  paid,
  maternity,
  paternity,
  unpaid;

  static LeaveType fromString(String? value) {
    if (value == null) return LeaveType.casual;
    final clean = value.trim().toLowerCase();
    switch (clean) {
      case 'casual':
      case 'casual_leave':
      case 'casual leave':
        return LeaveType.casual;
      case 'sick':
      case 'sick_leave':
      case 'sick leave':
        return LeaveType.sick;
      case 'paid':
      case 'paid_leave':
      case 'paid leave':
        return LeaveType.paid;
      case 'maternity':
      case 'maternity_leave':
      case 'maternity leave':
        return LeaveType.maternity;
      case 'paternity':
      case 'paternity_leave':
      case 'paternity leave':
        return LeaveType.paternity;
      case 'unpaid':
      case 'unpaid_leave':
      case 'unpaid leave':
        return LeaveType.unpaid;
      default:
        return LeaveType.casual;
    }
  }

  String toApiKey() {
    switch (this) {
      case LeaveType.casual:
        return 'casual';
      case LeaveType.sick:
        return 'sick';
      case LeaveType.paid:
        return 'paid';
      case LeaveType.maternity:
        return 'maternity';
      case LeaveType.paternity:
        return 'paternity';
      case LeaveType.unpaid:
        return 'unpaid';
    }
  }

  String get displayName {
    switch (this) {
      case LeaveType.casual:
        return 'Casual Leave';
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.paid:
        return 'Paid Leave';
      case LeaveType.maternity:
        return 'Maternity Leave';
      case LeaveType.paternity:
        return 'Paternity Leave';
      case LeaveType.unpaid:
        return 'Unpaid Leave';
    }
  }
}

enum LeaveStatus {
  approved,
  pending,
  rejected,
  cancelled;

  static LeaveStatus fromString(String? value) {
    if (value == null) return LeaveStatus.pending;
    final clean = value.trim().toLowerCase();
    switch (clean) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return LeaveStatus.cancelled;
      case 'pending':
      default:
        return LeaveStatus.pending;
    }
  }
}

class LeaveSummaryModel {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const LeaveSummaryModel({
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
  });

  factory LeaveSummaryModel.fromJson(Map<String, dynamic> json) {
    return LeaveSummaryModel(
      total: _parseInt(json['total'] ?? json['totalLeaves'] ?? json['total_leaves']),
      pending: _parseInt(json['pending'] ?? json['totalPending'] ?? json['total_pending']),
      approved: _parseInt(json['approved'] ?? json['totalApproved'] ?? json['total_approved']),
      rejected: _parseInt(json['rejected'] ?? json['totalRejected'] ?? json['total_rejected']),
    );
  }

  factory LeaveSummaryModel.fromLeaves(List<LeaveApplicationEntity> leaves) {
    int total = leaves.length;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final leave in leaves) {
      switch (leave.status) {
        case LeaveStatus.approved:
          approved++;
          break;
        case LeaveStatus.rejected:
          rejected++;
          break;
        case LeaveStatus.pending:
        case LeaveStatus.cancelled:
          pending++;
          break;
      }
    }

    return LeaveSummaryModel(
      total: total,
      pending: pending,
      approved: approved,
      rejected: rejected,
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'pending': pending,
    'approved': approved,
    'rejected': rejected,
  };
}

class LeaveBalanceModel {
  final LeaveType type;
  final String title;
  final int total;
  final int used;
  final int remaining;

  const LeaveBalanceModel({
    required this.type,
    required this.title,
    required this.total,
    required this.used,
    required this.remaining,
  });

  LeaveBalanceEntity toEntity() {
    return LeaveBalanceEntity(
      type: type,
      title: title,
      total: total,
      used: used,
      remaining: remaining,
    );
  }
}

class LeaveApplicationModel {
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

  const LeaveApplicationModel({
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

  /// Formatted approver name. Returns real human name if available,
  /// or 'Awaiting Approval' if status is pending, or 'Management' if approved by admin ID or null.
  String get formattedApprover {
    if (status == LeaveStatus.pending) return 'Awaiting Approval';
    if (approvedBy == null) return 'Management';
    final clean = approvedBy!.trim();
    if (clean.isEmpty || clean == 'null') return 'Management';
    if (int.tryParse(clean) != null) return 'Management';
    return clean;
  }

  factory LeaveApplicationModel.fromJson(Map<String, dynamic> json) {
    // ID
    final id = json['id']?.toString() ??
        json['leave_id']?.toString() ??
        json['leaveId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Employee ID & Name
    final employeeId = json['emp_id']?.toString() ??
        json['employee_id']?.toString() ??
        json['employeeId']?.toString() ??
        json['empId']?.toString();

    final employeeName = json['emp_name']?.toString() ??
        json['employee_name']?.toString() ??
        json['employeeName']?.toString() ??
        json['name']?.toString();

    // Leave Type
    final typeStr = json['leave_type'] ??
        json['leaveType'] ??
        json['type'] ??
        json['leave_name'];
    final type = LeaveType.fromString(typeStr?.toString());

    // Dates
    final startRaw = json['from_date'] ??
        json['fromDate'] ??
        json['start_date'] ??
        json['startDate'];
    final endRaw = json['to_date'] ??
        json['toDate'] ??
        json['end_date'] ??
        json['endDate'];

    DateTime startDate = _parseDate(startRaw) ?? DateTime.now();
    DateTime endDate = _parseDate(endRaw) ?? startDate;

    if (endDate.isBefore(startDate)) {
      endDate = startDate;
    }

    // Days count
    final totalDaysRaw = json['total_days'] ??
        json['totalDays'] ??
        json['days'] ??
        json['number_of_days'] ??
        json['numberOfDays'];

    int numberOfDays;
    if (totalDaysRaw != null) {
      numberOfDays = int.tryParse(totalDaysRaw.toString()) ??
          (endDate.difference(startDate).inDays + 1);
    } else {
      numberOfDays = endDate.difference(startDate).inDays + 1;
    }
    if (numberOfDays <= 0) numberOfDays = 1;

    // Reason
    final reason = json['reason']?.toString() ??
        json['description']?.toString() ??
        json['remarks']?.toString() ??
        '';

    // Status
    final statusStr = json['status']?.toString();
    final status = LeaveStatus.fromString(statusStr);

    // Applied on / Created at
    final createdRaw = json['created_at'] ??
        json['createdAt'] ??
        json['applied_date'] ??
        json['appliedDate'] ??
        json['applied_on'] ??
        json['appliedOn'];
    final appliedOn = _parseDate(createdRaw) ?? DateTime.now();

    // Approver
    final approvedBy = _parseApprover(json);

    return LeaveApplicationModel(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      type: type,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      reason: reason,
      status: status,
      appliedOn: appliedOn,
      approvedBy: approvedBy,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateTime.parse(str);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd').parse(str);
      } catch (_) {
        try {
          return DateFormat('dd-MM-yyyy').parse(str);
        } catch (_) {
          return null;
        }
      }
    }
  }

  static String? _parseApprover(Map<String, dynamic> json) {
    // 1. Dedicated Name Keys
    final nameKeys = [
      'approver_name',
      'approverName',
      'approved_by_name',
      'approvedByName',
      'approver_emp_name',
      'approverEmpName',
      'approved_by_user_name',
      'approvedByUserName',
      'manager_name',
      'managerName',
      'admin_name',
      'adminName',
      'action_by_name',
      'actionByName',
      'approved_name',
      'approvedName',
      'verifier_name',
      'verifierName',
    ];

    for (final key in nameKeys) {
      final val = json[key]?.toString().trim();
      if (val != null &&
          val.isNotEmpty &&
          val != 'null' &&
          int.tryParse(val) == null) {
        return val;
      }
    }

    // 2. Nested objects like 'approver', 'approved_by_user', 'manager', 'admin'
    final objectKeys = [
      'approver',
      'approved_by_user',
      'approvedByUser',
      'approver_user',
      'approverUser',
      'approved_user',
      'approvedUser',
      'manager',
      'admin',
      'action_by_user',
      'actionByUser',
      'user',
    ];

    for (final key in objectKeys) {
      final obj = json[key];
      if (obj is Map) {
        if (obj['first_name'] != null) {
          final fn = obj['first_name'].toString().trim();
          final ln = obj['last_name']?.toString().trim() ?? '';
          final full = '$fn $ln'.trim();
          if (full.isNotEmpty && full != 'null' && int.tryParse(full) == null) {
            return full;
          }
        }
        final name = obj['name'] ??
            obj['emp_name'] ??
            obj['employee_name'] ??
            obj['full_name'] ??
            obj['username'] ??
            obj['display_name'];
        if (name != null) {
          final s = name.toString().trim();
          if (s.isNotEmpty && s != 'null' && int.tryParse(s) == null) {
            return s;
          }
        }
      } else if (obj is String) {
        final s = obj.trim();
        if (s.isNotEmpty && s != 'null' && int.tryParse(s) == null) {
          return s;
        }
      }
    }

    // 3. Check approved_by / approvedBy / action_by
    final rawApprovedBy = json['approved_by'] ??
        json['approvedBy'] ??
        json['action_by'] ??
        json['actionBy'];
    if (rawApprovedBy is Map) {
      if (rawApprovedBy['first_name'] != null) {
        final fn = rawApprovedBy['first_name'].toString().trim();
        final ln = rawApprovedBy['last_name']?.toString().trim() ?? '';
        final full = '$fn $ln'.trim();
        if (full.isNotEmpty && full != 'null' && int.tryParse(full) == null) {
          return full;
        }
      }
      final name = rawApprovedBy['name'] ??
          rawApprovedBy['emp_name'] ??
          rawApprovedBy['employee_name'] ??
          rawApprovedBy['full_name'] ??
          rawApprovedBy['username'];
      if (name != null) {
        final s = name.toString().trim();
        if (s.isNotEmpty && s != 'null' && int.tryParse(s) == null) {
          return s;
        }
      }
    } else if (rawApprovedBy != null) {
      final s = rawApprovedBy.toString().trim();
      if (s.isNotEmpty && s != 'null') {
        // If it is not purely digits, it is a human name
        if (int.tryParse(s) == null) {
          return s;
        }
        // If it is numeric (e.g. "2" or 2), it's the backend admin user ID
        return 'Management';
      }
    }

    // 4. If status is approved, default to Management
    final statusStr = json['status']?.toString().toLowerCase();
    if (statusStr == 'approved') {
      return 'Management';
    }

    return null;
  }

  LeaveApplicationEntity toEntity() {
    return LeaveApplicationEntity(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      type: type,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      reason: reason,
      status: status,
      appliedOn: appliedOn,
      approvedBy: approvedBy,
    );
  }

  factory LeaveApplicationModel.fromEntity(LeaveApplicationEntity entity) {
    return LeaveApplicationModel(
      id: entity.id,
      employeeId: entity.employeeId,
      employeeName: entity.employeeName,
      type: entity.type,
      startDate: entity.startDate,
      endDate: entity.endDate,
      numberOfDays: entity.numberOfDays,
      reason: entity.reason,
      status: entity.status,
      appliedOn: entity.appliedOn,
      approvedBy: entity.approvedBy,
    );
  }

  Map<String, dynamic> toJson() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return {
      'id': id,
      if (employeeId != null) 'emp_id': employeeId,
      if (employeeName != null) 'emp_name': employeeName,
      'leave_type': type.toApiKey(),
      'from_date': dateFormat.format(startDate),
      'to_date': dateFormat.format(endDate),
      'total_days': numberOfDays,
      'reason': reason,
      'status': status.name,
      'created_at': appliedOn.toIso8601String(),
      if (approvedBy != null) 'approved_by': approvedBy,
    };
  }

  LeaveApplicationModel copyWith({
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
    return LeaveApplicationModel(
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

