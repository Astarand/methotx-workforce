import '../../domain/entities/auth_entity.dart';

class AuthResponseModel {
  final String token;
  final String empId;
  final String secure;
  final String email;
  final String fullName;
  final String designation;
  final String department;
  final String workMode;
  final String? profileImg;
  final bool isActive;

  const AuthResponseModel({
    required this.token,
    required this.empId,
    required this.secure,
    required this.email,
    required this.fullName,
    this.designation = 'Software Engineer',
    this.department = 'IT',
    this.workMode = 'Home Office',
    this.profileImg,
    this.isActive = true,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Step 1: Unwrap 'data' if it exists
    Map<String, dynamic> userData = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      userData = json['data'] as Map<String, dynamic>;
    }

    // Step 2: Unwrap 'user' or 'employee' from inside 'data' if it exists
    Map<String, dynamic> userDetails = userData;
    if (userData.containsKey('user') &&
        userData['user'] is Map<String, dynamic>) {
      userDetails = userData['user'] as Map<String, dynamic>;
    } else if (userData.containsKey('employee') &&
        userData['employee'] is Map<String, dynamic>) {
      userDetails = userData['employee'] as Map<String, dynamic>;
    }

    // Token is usually at the top level or inside 'data', not inside 'user'
    final token =
        json['token'] ?? userData['token'] ?? userDetails['token'] ?? '';

    final secure =
        json['secure'] ?? userData['secure'] ?? userDetails['secure'] ?? '';

    String? resolveCode(Map<String, dynamic> m) {
      for (final key in [
        'employee_id',
        'employee_code',
        'emp_code',
        'empId',
        'emp_id',
        'employeeId',
      ]) {
        final v = m[key]?.toString().trim();
        if (v != null && v.isNotEmpty && v != 'null') return v;
      }
      return null;
    }

    final empId =
        resolveCode(userDetails) ??
        resolveCode(userData) ??
        resolveCode(json) ??
        userDetails['id']?.toString() ??
        userData['id']?.toString() ??
        '';

    final email = userDetails['email']?.toString() ?? '';

    // Try to construct full name from multiple possible keys
    String? fullName =
        userDetails['name'] ??
        userDetails['full_name'] ??
        userDetails['fullName'];

    if (fullName == null || fullName.isEmpty) {
      final fName = userDetails['first_name'] ?? userDetails['firstName'] ?? '';
      final lName = userDetails['last_name'] ?? userDetails['lastName'] ?? '';
      if (fName.isNotEmpty || lName.isNotEmpty) {
        fullName = '$fName $lName'.trim();
      } else {
        fullName = 'Employee';
      }
    }

    final designation =
        userDetails['designation'] ??
        userDetails['role'] ??
        userDetails['job_title'] ??
        userDetails['jobTitle'] ??
        'Software Engineer';

    final department =
        userDetails['dept_name'] ??
        userDetails['deptName'] ??
        userDetails['department_name'] ??
        userDetails['departmentName'] ??
        userDetails['department'] ??
        userDetails['dept'] ??
        userData['dept_name'] ??
        userData['department_name'] ??
        userData['department'] ??
        'IT';

    String? extractWorkLocation(Map<dynamic, dynamic>? m) {
      if (m == null) return null;
      final val =
          m['work_location'] ??
          m['workLocation'] ??
          m['today_work_location'] ??
          m['todayWorkLocation'] ??
          m['work_mode'] ??
          m['workMode'] ??
          m['working_location'] ??
          m['workingLocation'];
      if (val != null) {
        final str = val.toString().trim();
        if (str.isNotEmpty && str != 'null') return str;
      }
      return null;
    }

    final rawWorkMode =
        extractWorkLocation(userDetails) ??
        extractWorkLocation(userData) ??
        (userData['employee'] is Map
            ? extractWorkLocation(userData['employee'] as Map)
            : null) ??
        (userData['employee_details'] is Map
            ? extractWorkLocation(userData['employee_details'] as Map)
            : null) ??
        (userData['user'] is Map
            ? extractWorkLocation(userData['user'] as Map)
            : null) ??
        (json['employee'] is Map
            ? extractWorkLocation(json['employee'] as Map)
            : null) ??
        (json['employee_details'] is Map
            ? extractWorkLocation(json['employee_details'] as Map)
            : null) ??
        (json['user'] is Map
            ? extractWorkLocation(json['user'] as Map)
            : null) ??
        extractWorkLocation(json);

    final workMode = rawWorkMode ?? 'Work From Home';
    final isActive =
        userDetails['is_active'] ?? userDetails['isActive'] ?? true;

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
        extractImg(userDetails) ??
        extractImg(userData) ??
        (userData['employee'] is Map
            ? extractImg(userData['employee'] as Map)
            : null) ??
        (userData['user'] is Map
            ? extractImg(userData['user'] as Map)
            : null) ??
        (userData['employee_details'] is Map
            ? extractImg(userData['employee_details'] as Map)
            : null) ??
        (json['employee'] is Map
            ? extractImg(json['employee'] as Map)
            : null) ??
        (json['user'] is Map ? extractImg(json['user'] as Map) : null) ??
        (json['employee_details'] is Map
            ? extractImg(json['employee_details'] as Map)
            : null) ??
        extractImg(json);

    return AuthResponseModel(
      token: token.toString(),
      empId: empId.toString(),
      secure: secure.toString(),
      email: email,
      fullName: fullName.toString(),
      designation: designation.toString(),
      department: department.toString(),
      workMode: workMode.toString(),
      profileImg: rawProfileImg,
      isActive: isActive is bool ? isActive : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'empId': empId,
      'secure': secure,
      'email': email,
      'fullName': fullName,
      'designation': designation,
      'department': department,
      'workMode': workMode,
      'profileImg': profileImg,
      'isActive': isActive,
    };
  }

  AuthEntity toEntity() {
    return AuthEntity(
      empId: empId,
      token: token,
      secure: secure,
      email: email,
      fullName: fullName,
      designation: designation,
      department: department,
      workMode: workMode,
      profileImg: profileImg,
      isActive: isActive,
    );
  }
}
