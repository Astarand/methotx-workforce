class AuthEntity {
  final String empId;
  final String token;
  final String secure;
  final String email;
  final String fullName;
  final String designation;
  final String department;
  final String workMode;
  final String? profileImg;
  final bool isActive;

  const AuthEntity({
    required this.empId,
    required this.token,
    required this.secure,
    required this.email,
    required this.fullName,
    this.designation = 'Employee',
    this.department = 'General',
    this.workMode = 'Office',
    this.profileImg,
    this.isActive = true,
  });

  AuthEntity copyWith({
    String? empId,
    String? token,
    String? secure,
    String? email,
    String? fullName,
    String? designation,
    String? department,
    String? workMode,
    String? profileImg,
    bool? isActive,
  }) {
    return AuthEntity(
      empId: empId ?? this.empId,
      token: token ?? this.token,
      secure: secure ?? this.secure,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      workMode: workMode ?? this.workMode,
      profileImg: profileImg ?? this.profileImg,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthEntity &&
          runtimeType == other.runtimeType &&
          empId == other.empId &&
          token == other.token &&
          email == other.email;

  @override
  int get hashCode => empId.hashCode ^ token.hashCode ^ email.hashCode;

  @override
  String toString() =>
      'AuthEntity(empId: $empId, email: $email, fullName: $fullName, designation: $designation, profileImg: $profileImg)';
}
