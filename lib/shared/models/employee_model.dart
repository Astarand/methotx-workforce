class EmployeeModel {
  final String id;
  final String employeeCode;
  final String fullName;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String avatarUrl;
  final String workMode;
  final String locationStatus;
  final String geofenceStatus;
  final bool isActive;
  final DateTime joiningDate;

  const EmployeeModel({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.workMode,
    required this.locationStatus,
    required this.geofenceStatus,
    this.isActive = true,
    required this.joiningDate,
  });

  EmployeeModel copyWith({
    String? id,
    String? employeeCode,
    String? fullName,
    String? designation,
    String? department,
    String? email,
    String? phone,
    String? avatarUrl,
    String? workMode,
    String? locationStatus,
    String? geofenceStatus,
    bool? isActive,
    DateTime? joiningDate,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      workMode: workMode ?? this.workMode,
      locationStatus: locationStatus ?? this.locationStatus,
      geofenceStatus: geofenceStatus ?? this.geofenceStatus,
      isActive: isActive ?? this.isActive,
      joiningDate: joiningDate ?? this.joiningDate,
    );
  }

  static EmployeeModel defaultEmployee() {
    return EmployeeModel(
      id: 'emp-001',
      employeeCode: 'EMP4-00001',
      fullName: 'Khokan Paul',
      designation: 'Web Developer',
      department: 'Engineering & Development',
      email: 'pkhokan25@gmail.com',
      phone: '+91 98765 43210',
      avatarUrl: 'assets/images/avatar-dummy.jpg',
      workMode: 'Home Office',
      locationStatus: 'Detected',
      geofenceStatus: 'Ready',
      isActive: true,
      joiningDate: DateTime(2023, 3, 15),
    );
  }
}
