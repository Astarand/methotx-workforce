import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';

class ProfileEntity {
  final String id;
  final String empId;
  final String employeeCode;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String designation;
  final String department;
  final String workMode;
  final DateTime? joiningDate;
  final bool isActive;
  final String? openingTime;
  final String? closingTime;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;

  const ProfileEntity({
    required this.id,
    required this.empId,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.designation,
    required this.department,
    required this.workMode,
    this.joiningDate,
    this.isActive = true,
    this.openingTime,
    this.closingTime,
    this.panNumber,
    this.aadhaarNumber,
    this.bankName,
    this.accountNumber,
    this.ifsc,
  });

  /// Resolves the absolute URL of the avatar using the environment configuration
  String? get resolvedAvatarUrl => ApiEndpoints.resolveImageUrl(avatarUrl);

  /// Formatted date of joining (e.g., '01 Jul 2025')
  String get formattedJoiningDate {
    if (joiningDate == null) return 'Not Available';
    return DateFormat('dd MMM yyyy').format(joiningDate!);
  }

  /// Whether the employee is designated as Work From Home
  bool get isWFH {
    final lower = workMode.toLowerCase();
    return lower.contains('home') || lower.contains('wfh') || lower.contains('remote');
  }

  /// Whether the employee is designated as Work From Office
  bool get isWFO => !isWFH;

  /// User-friendly label for work mode
  String get displayWorkMode => isWFH ? 'Work From Home' : 'Work From Office';

  /// Status badge label
  String get displayStatus => isActive ? 'Active' : 'Inactive';

  /// Formatted shift timing (e.g. '10:00 AM - 07:00 PM')
  String get formattedShift {
    if (openingTime == null || closingTime == null || openingTime!.isEmpty || closingTime!.isEmpty) {
      return 'Regular Shift (10:00 AM - 07:00 PM)';
    }

    String formatTime(String raw) {
      try {
        final clean = raw.trim();
        if (clean.contains(':')) {
          final parts = clean.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final now = DateTime.now();
          final dt = DateTime(now.year, now.month, now.day, h, m);
          return DateFormat('hh:mm a').format(dt);
        }
      } catch (_) {}
      return raw;
    }

    return '${formatTime(openingTime!)} - ${formatTime(closingTime!)}';
  }

  ProfileEntity copyWith({
    String? id,
    String? empId,
    String? employeeCode,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? designation,
    String? department,
    String? workMode,
    DateTime? joiningDate,
    bool? isActive,
    String? openingTime,
    String? closingTime,
    String? panNumber,
    String? aadhaarNumber,
    String? bankName,
    String? accountNumber,
    String? ifsc,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      empId: empId ?? this.empId,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      workMode: workMode ?? this.workMode,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
    );
  }

  /// Merges fields from another profile, prioritizing non-empty and non-default values
  ProfileEntity merge(ProfileEntity other) {
    return ProfileEntity(
      id: other.id.isNotEmpty && other.id != '0' ? other.id : id,
      empId: other.empId.isNotEmpty && other.empId != '0' ? other.empId : empId,
      employeeCode: other.employeeCode.isNotEmpty && other.employeeCode != '0' ? other.employeeCode : employeeCode,
      fullName: other.fullName.isNotEmpty && other.fullName != 'Employee' ? other.fullName : fullName,
      email: other.email.isNotEmpty ? other.email : email,
      phone: other.phone.isNotEmpty ? other.phone : phone,
      avatarUrl: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? avatarUrl
          : other.avatarUrl,
      designation: other.designation.isNotEmpty && other.designation != 'Employee' ? other.designation : designation,
      department: other.department.isNotEmpty && other.department != 'General' && other.department != 'Engineering'
          ? other.department
          : (department.isNotEmpty && department != 'General' && department != 'Engineering' ? department : other.department),
      workMode: other.workMode.isNotEmpty ? other.workMode : workMode,
      joiningDate: other.joiningDate ?? joiningDate,
      isActive: other.isActive,
      openingTime: other.openingTime ?? openingTime,
      closingTime: other.closingTime ?? closingTime,
      panNumber: other.panNumber ?? panNumber,
      aadhaarNumber: other.aadhaarNumber ?? aadhaarNumber,
      bankName: other.bankName ?? bankName,
      accountNumber: other.accountNumber ?? accountNumber,
      ifsc: other.ifsc ?? ifsc,
    );
  }
}
