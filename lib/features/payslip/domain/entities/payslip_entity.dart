class PayslipItemEntity {
  final String title;
  final double amount;
  final bool isAddition;

  const PayslipItemEntity({
    required this.title,
    required this.amount,
    this.isAddition = true,
  });
}

/// Pure Domain Entity for Payslips
class PayslipEntity {
  final String id;
  final String payslipNumber;
  final String month;
  final String financialYear;
  final String employeeName;
  final String employeeCode;
  final String designation;
  final String department;
  final double grossSalary;
  final double totalAdditions;
  final double totalDeductions;
  final double netSalary;

  // Attendance stats
  final int workingDays;
  final int holidays;
  final int weekends;
  final int presentDays;
  final int onTimeDays;
  final int lateDays;
  final int earlyLogoutDays;
  final int leaves;
  final double overtimeHours;

  // Earnings & Deductions items
  final List<PayslipItemEntity> earnings;
  final List<PayslipItemEntity> deductions;

  // Additional metadata from Laravel
  final String? pdfUrl;
  final String? bankName;
  final String? accountNo;
  final String? ifscCode;
  final String? panNo;
  final String? companyName;
  final String? companyAddress;
  final String? companyEmail;
  final String? companyLogo;
  final String? inWords;
  final Map<String, dynamic>? visibleData;
  final Map<String, dynamic>? companyInfo;

  const PayslipEntity({
    required this.id,
    required this.payslipNumber,
    required this.month,
    required this.financialYear,
    required this.employeeName,
    required this.employeeCode,
    required this.designation,
    required this.department,
    required this.grossSalary,
    required this.totalAdditions,
    required this.totalDeductions,
    required this.netSalary,
    required this.workingDays,
    required this.holidays,
    required this.weekends,
    required this.presentDays,
    required this.onTimeDays,
    required this.lateDays,
    required this.earlyLogoutDays,
    required this.leaves,
    required this.overtimeHours,
    required this.earnings,
    required this.deductions,
    this.pdfUrl,
    this.bankName,
    this.accountNo,
    this.ifscCode,
    this.panNo,
    this.companyName,
    this.companyAddress,
    this.companyEmail,
    this.companyLogo,
    this.inWords,
    this.visibleData,
    this.companyInfo,
  });
}
