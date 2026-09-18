import 'package:intl/intl.dart';

import '../../domain/entities/profile_entity.dart';

class ProfileModel {
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

  const ProfileModel({
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

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // 1. Unwrap data if nested
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    Map<dynamic, dynamic>? visibleData;
    if (data['visible_data'] is Map) {
      visibleData = data['visible_data'] as Map;
    } else if (data['salary_details'] is Map &&
        (data['salary_details'] as Map)['visible_data'] is Map) {
      visibleData = (data['salary_details'] as Map)['visible_data'] as Map;
    } else if (data['payslip'] is Map) {
      final p = data['payslip'] as Map;
      if (p['salary_details'] is Map &&
          (p['salary_details'] as Map)['visible_data'] is Map) {
        visibleData = (p['salary_details'] as Map)['visible_data'] as Map;
      } else if (p['visible_data'] is Map) {
        visibleData = p['visible_data'] as Map;
      }
    }

    // 2. Candidate containers
    final containers = <Map<dynamic, dynamic>>[
      if (visibleData != null && visibleData['employee_details'] is Map)
        visibleData['employee_details'] as Map,
      ?visibleData,
      if (data['payslip'] is Map &&
          (data['payslip'] as Map)['employee_details'] is Map)
        (data['payslip'] as Map)['employee_details'] as Map,
      if (data['employee_details'] is Map) data['employee_details'] as Map,
      if (data['employee'] is Map) data['employee'] as Map,
      if (data['user'] is Map) data['user'] as Map,
      if (data['details'] is Map) data['details'] as Map,
      if (data['profile'] is Map) data['profile'] as Map,
      data,
      if (json['visible_data'] is Map &&
          (json['visible_data'] as Map)['employee_details'] is Map)
        (json['visible_data'] as Map)['employee_details'] as Map,
      if (json['employee_details'] is Map) json['employee_details'] as Map,
      if (json['employee'] is Map) json['employee'] as Map,
      if (json['user'] is Map) json['user'] as Map,
      if (json['details'] is Map) json['details'] as Map,
      if (json['profile'] is Map) json['profile'] as Map,
      json,
    ];

    String? findString(List<String> keys) {
      for (final container in containers) {
        for (final key in keys) {
          final val = container[key];
          if (val != null) {
            final str = val.toString().trim();
            if (str.isNotEmpty && str != 'null') return str;
          }
        }
      }
      return null;
    }

    final empId =
        findString(['empId', 'emp_id', 'id', 'employeeId', 'employee_id']) ??
        '0';
    final employeeCode =
        findString([
          'employee_id',
          'employee_code',
          'emp_code',
          'empId',
          'code',
        ]) ??
        empId;

    // Full name
    String? fullName = findString(['name', 'full_name', 'fullName']);
    if (fullName == null || fullName.isEmpty) {
      final fName = findString(['first_name', 'firstName']) ?? '';
      final lName = findString(['last_name', 'lastName']) ?? '';
      if (fName.isNotEmpty || lName.isNotEmpty) {
        fullName = '$fName $lName'.trim();
      } else {
        fullName = 'Employee';
      }
    }

    final email = findString(['email', 'corporate_email', 'user_email']) ?? '';
    final phone =
        findString([
          'phone',
          'mobile',
          'contact_no',
          'contact_number',
          'phone_number',
          'phoneNumber',
          'mobile_no',
          'mobileNo',
          'contact',
          'contactNo',
          'emp_phone',
          'user_phone',
        ]) ??
        '';

    final designation =
        findString([
          'designation_name',
          'designation',
          'role',
          'job_title',
          'jobTitle',
        ]) ??
        'Employee';

    final department =
        findString([
          'dept_name',
          'deptName',
          'department_name',
          'departmentName',
          'department',
          'dept',
          'user_department',
          'emp_department',
        ]) ??
        'General';

    final workMode =
        findString([
          'work_location',
          'work_mode',
          'today_work_location',
          'workLocationStatus',
          'todayWorkLocation',
          'workMode',
          'workLocation',
        ]) ??
        'Work From Home';

    final avatarUrl = findString([
      'profile_img',
      'profileImg',
      'profile_image',
      'profileImage',
      'avatar',
      'photo',
      'image',
      'emp_image',
    ]);

    // Parse Joining Date
    DateTime? joiningDate;
    final dateStr = findString([
      'joining_date',
      'date_of_joining',
      'joiningDate',
      'dateOfJoining',
      'doj',
      'created_at',
      'date_joined',
      'dateJoined',
      'join_date',
      'joinDate',
      'start_date',
      'startDate',
      'emp_joining_date',
      'employee_joining_date',
    ]);
    if (dateStr != null && dateStr.isNotEmpty) {
      final cleanDate = dateStr.trim().replaceAll(' ', 'T');
      try {
        joiningDate = DateTime.parse(cleanDate);
      } catch (_) {
        try {
          joiningDate = DateFormat(
            'yyyy-MM-dd',
          ).parse(dateStr.split(' ').first);
        } catch (_) {
          try {
            joiningDate = DateFormat(
              'dd-MM-yyyy',
            ).parse(dateStr.split(' ').first);
          } catch (_) {}
        }
      }
    }

    // Shift timings
    final opening = findString([
      'opening_time',
      'openingTime',
      'shift_start_time',
    ]);
    final closing = findString([
      'closing_time',
      'closingTime',
      'shift_end_time',
    ]);

    // Banking & Government identity
    final pan = findString(['pan_number', 'panNumber', 'pan']);
    final aadhaar = findString(['aadhaar_number', 'aadhaarNumber', 'aadhaar']);
    final bank = findString(['bank_name', 'bankName']);
    final acc = findString(['account_number', 'accountNumber']);
    final ifsc = findString(['ifsc', 'ifsc_code']);

    final activeVal = data['is_active'] ?? data['isActive'] ?? data['status'];
    final isActive =
        activeVal == null ||
        activeVal == true ||
        activeVal == 1 ||
        activeVal == '1' ||
        activeVal.toString().toLowerCase() == 'active';

    return ProfileModel(
      id: empId,
      empId: empId,
      employeeCode: employeeCode,
      fullName: fullName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      designation: designation,
      department: department,
      workMode: workMode,
      joiningDate: joiningDate,
      isActive: isActive,
      openingTime: opening,
      closingTime: closing,
      panNumber: pan,
      aadhaarNumber: aadhaar,
      bankName: bank,
      accountNumber: acc,
      ifsc: ifsc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'empId': empId,
      'employee_id': employeeCode,
      'name': fullName,
      'email': email,
      'phone': phone,
      'profile_img': avatarUrl,
      'designation_name': designation,
      'dept_name': department,
      'work_location': workMode,
      'joining_date': joiningDate?.toIso8601String(),
      'is_active': isActive,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc': ifsc,
    };
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      empId: empId,
      employeeCode: employeeCode,
      fullName: fullName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      designation: designation,
      department: department,
      workMode: workMode,
      joiningDate: joiningDate,
      isActive: isActive,
      openingTime: openingTime,
      closingTime: closingTime,
      panNumber: panNumber,
      aadhaarNumber: aadhaarNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      ifsc: ifsc,
    );
  }

  factory ProfileModel.fromEntity(ProfileEntity entity) {
    return ProfileModel(
      id: entity.id,
      empId: entity.empId,
      employeeCode: entity.employeeCode,
      fullName: entity.fullName,
      email: entity.email,
      phone: entity.phone,
      avatarUrl: entity.avatarUrl,
      designation: entity.designation,
      department: entity.department,
      workMode: entity.workMode,
      joiningDate: entity.joiningDate,
      isActive: entity.isActive,
      openingTime: entity.openingTime,
      closingTime: entity.closingTime,
      panNumber: entity.panNumber,
      aadhaarNumber: entity.aadhaarNumber,
      bankName: entity.bankName,
      accountNumber: entity.accountNumber,
      ifsc: entity.ifsc,
    );
  }
}
