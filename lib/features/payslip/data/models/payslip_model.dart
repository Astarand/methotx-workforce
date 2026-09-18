import '../../domain/entities/payslip_entity.dart';

class PayslipItemModel extends PayslipItemEntity {
  const PayslipItemModel({
    required super.title,
    required super.amount,
    super.isAddition = true,
  });

  factory PayslipItemModel.fromJson(Map<String, dynamic> json, {bool defaultIsAddition = true}) {
    final title = json['title']?.toString() ??
        json['name']?.toString() ??
        json['label']?.toString() ??
        json['description']?.toString() ??
        json['item_name']?.toString() ??
        'Item';
    final amountRaw = json['amount'] ?? json['value'] ?? json['total'] ?? 0;
    final amount = _parseDouble(amountRaw);
    final isAddition = json['isAddition'] == true ||
        json['is_addition'] == true ||
        json['type']?.toString().toLowerCase() == 'addition' ||
        json['type']?.toString().toLowerCase() == 'earning' ||
        defaultIsAddition;

    return PayslipItemModel(
      title: title,
      amount: amount,
      isAddition: isAddition,
    );
  }

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    var clean = val.toString().replaceAll(',', '').replaceAll('Rs.', '').replaceAll('Rs', '').replaceAll('₹', '').trim();
    if (clean.startsWith('(') && clean.endsWith(')')) {
      clean = '-${clean.substring(1, clean.length - 1)}';
    }
    return double.tryParse(clean) ?? fallback;
  }
}

class PayslipModel extends PayslipEntity {
  const PayslipModel({
    required super.id,
    required super.payslipNumber,
    required super.month,
    required super.financialYear,
    required super.employeeName,
    required super.employeeCode,
    required super.designation,
    required super.department,
    required super.grossSalary,
    required super.totalAdditions,
    required super.totalDeductions,
    required super.netSalary,
    required super.workingDays,
    required super.holidays,
    required super.weekends,
    required super.presentDays,
    required super.onTimeDays,
    required super.lateDays,
    required super.earlyLogoutDays,
    required super.leaves,
    required super.overtimeHours,
    required super.earnings,
    required super.deductions,
    super.pdfUrl,
    super.bankName,
    super.accountNo,
    super.ifscCode,
    super.panNo,
    super.companyName,
    super.companyAddress,
    super.companyEmail,
    super.companyLogo,
    super.inWords,
    super.visibleData,
    super.companyInfo,
  });

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    var clean = val.toString().replaceAll(',', '').replaceAll('Rs.', '').replaceAll('Rs', '').replaceAll('₹', '').trim();
    if (clean.startsWith('(') && clean.endsWith(')')) {
      clean = '-${clean.substring(1, clean.length - 1)}';
    }
    return double.tryParse(clean) ?? fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    final clean = val.toString().replaceAll(',', '').trim();
    return int.tryParse(clean) ?? fallback;
  }

  static String _formatMonthName(String rawMonth, [String? fallbackMonth]) {
    final clean = rawMonth.trim();
    if (clean.isEmpty) return fallbackMonth ?? 'Current Month';

    final lower = clean.toLowerCase();
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    for (final m in months) {
      if (lower.contains(m)) {
        return '${m[0].toUpperCase()}${m.substring(1)}';
      }
    }

    final firstToken = clean.split(' ').first.replaceAll(RegExp(r'[^0-9]'), '');
    final numVal = int.tryParse(firstToken);
    if (numVal != null && numVal >= 1 && numVal <= 12) {
      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return monthNames[numVal - 1];
    }
    return fallbackMonth ?? clean;
  }

  static String _formatKeyToTitle(String key) {
    switch (key.toLowerCase()) {
      case 'basic_salary':
      case 'basic':
        return 'Basic Salary';
      case 'hra':
      case 'house_rent_allowance':
        return 'House Rent Allowance (HRA)';
      case 'allowances':
      case 'allowance':
      case 'other_allowances':
        return 'Allowances';
      case 'conveyance':
      case 'conveyance_allowance':
        return 'Conveyance Allowance';
      case 'medical':
      case 'medical_allowance':
        return 'Medical Allowance';
      case 'special_allowance':
      case 'special':
        return 'Special Allowance';
      case 'performance_bonus':
      case 'bonus':
        return 'Performance Bonus';
      case 'overtime':
      case 'overtime_payment':
      case 'overtime_pay':
        return 'Overtime Payment';
      case 'other_earnings':
      case 'other_income':
        return 'Other Earnings';
      case 'epf':
      case 'pf':
      case 'employee_provident_fund':
        return 'Employee Provident Fund (EPF)';
      case 'esi':
      case 'employee_state_insurance':
        return 'Employee State Insurance (ESI)';
      case 'pt':
      case 'professional_tax':
        return 'Professional Tax (PT)';
      case 'tax':
      case 'income_tax':
      case 'tds':
      case 'tax_deducted_at_source':
        return 'Income Tax (TDS)';
      case 'loan':
      case 'loan_deduction':
        return 'Loan Deduction';
      case 'lop':
      case 'loss_of_pay':
        return 'Loss of Pay (LOP)';
      case 'other_deductions':
      case 'other_deduction':
        return 'Other Deductions';
      case 'advance':
        return 'Advance';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  factory PayslipModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackMonth,
    String? fallbackYear,
    String? fallbackEmpId,
    String? fallbackEmpName,
    String? fallbackDesignation,
    String? fallbackDepartment,
  }) {
    // 1. Deep unwrap root response
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    // 2. Extract company_info if present in response
    final companyInfoMap = (data['company_info'] is Map<String, dynamic>)
        ? data['company_info'] as Map<String, dynamic>
        : (json['company_info'] is Map<String, dynamic>)
            ? json['company_info'] as Map<String, dynamic>
            : (data['payslip'] is Map && data['payslip']['company_info'] is Map<String, dynamic>)
                ? data['payslip']['company_info'] as Map<String, dynamic>
                : null;

    final companyName = companyInfoMap?['name']?.toString() ?? companyInfoMap?['comp_name']?.toString();
    final companyAddress = companyInfoMap?['address']?.toString() ?? companyInfoMap?['comp_address']?.toString();
    final companyEmail = companyInfoMap?['email']?.toString() ?? companyInfoMap?['comp_email']?.toString();

    final rawCompLogo = companyInfoMap?['comp_logo'] ??
        companyInfoMap?['logo'] ??
        companyInfoMap?['company_logo'] ??
        data['comp_logo'] ??
        data['logo'] ??
        data['company_logo'];

    final companyLogo = () {
      if (rawCompLogo == null) return null;
      final str = rawCompLogo.toString().trim();
      return (str.isEmpty || str == 'null') ? null : str;
    }();

    final safeCompanyInfo = companyInfoMap != null ? Map<String, dynamic>.from(companyInfoMap) : <String, dynamic>{};
    if (companyLogo != null) {
      safeCompanyInfo['comp_logo'] ??= companyLogo;
      safeCompanyInfo['logo'] ??= companyLogo;
    }

    // 3. Merge nested sub-objects in proper hierarchy
    // Order of precedence: data -> payslip -> salary_details -> visible_data
    final Map<String, dynamic> merged = Map<String, dynamic>.from(data);

    void mergeMap(dynamic source) {
      if (source is Map<String, dynamic>) {
        merged.addAll(source);
      }
    }

    mergeMap(data['details']);
    mergeMap(data['employee']);
    mergeMap(data['salary']);
    mergeMap(data['salary_details']);

    if (data['payslip'] is Map<String, dynamic>) {
      final p = data['payslip'] as Map<String, dynamic>;
      merged.addAll(p);
      mergeMap(p['details']);
      mergeMap(p['employee']);
      mergeMap(p['salary']);
      mergeMap(p['salary_details']);

      if (p['salary_details'] is Map<String, dynamic>) {
        final sd = p['salary_details'] as Map<String, dynamic>;
        merged.addAll(sd);
        mergeMap(sd['visible_data']);
      }
    }

    if (data['salary_details'] is Map<String, dynamic>) {
      final sd = data['salary_details'] as Map<String, dynamic>;
      merged.addAll(sd);
      mergeMap(sd['visible_data']);
    }

    // Direct extraction of visible_data per documentation (data.payslip.salary_details.visible_data)
    Map<String, dynamic>? visibleData;
    if (data['payslip'] is Map<String, dynamic>) {
      final p = data['payslip'] as Map<String, dynamic>;
      if (p['salary_details'] is Map<String, dynamic>) {
        final sd = p['salary_details'] as Map<String, dynamic>;
        if (sd['visible_data'] is Map<String, dynamic>) {
          visibleData = sd['visible_data'] as Map<String, dynamic>;
        }
      }
      if (visibleData == null && p['visible_data'] is Map<String, dynamic>) {
        visibleData = p['visible_data'] as Map<String, dynamic>;
      }
    }
    if (visibleData == null && data['salary_details'] is Map<String, dynamic>) {
      final sd = data['salary_details'] as Map<String, dynamic>;
      if (sd['visible_data'] is Map<String, dynamic>) {
        visibleData = sd['visible_data'] as Map<String, dynamic>;
      }
    }
    if (visibleData == null && data['visible_data'] is Map<String, dynamic>) {
      visibleData = data['visible_data'] as Map<String, dynamic>;
    }
    if (visibleData == null && merged['visible_data'] is Map<String, dynamic>) {
      visibleData = merged['visible_data'] as Map<String, dynamic>;
    }

    if (visibleData != null) {
      merged.addAll(visibleData);
      mergeMap(visibleData['employee_details']);
      mergeMap(visibleData['bank_details']);
      mergeMap(visibleData['month_details']);
      mergeMap(visibleData['attendance_details']);
      mergeMap(visibleData['salary_details']);
      mergeMap(visibleData['final_salary_calculation']);
    }

    // Sub-objects inside visible_data
    final empDetails = (visibleData != null && visibleData['employee_details'] is Map<String, dynamic>)
        ? visibleData['employee_details'] as Map<String, dynamic>
        : (data['payslip'] is Map<String, dynamic> &&
                data['payslip']['salary_details'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response']['employee'] is Map<String, dynamic>)
            ? data['payslip']['salary_details']['raw_api_response']['employee'] as Map<String, dynamic>
            : null;

    final bankDetails = (visibleData != null && visibleData['bank_details'] is Map<String, dynamic>)
        ? visibleData['bank_details'] as Map<String, dynamic>
        : null;

    final monthDetails = (visibleData != null && visibleData['month_details'] is Map<String, dynamic>)
        ? visibleData['month_details'] as Map<String, dynamic>
        : (data['payslip'] is Map<String, dynamic> &&
                data['payslip']['salary_details'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response']['monthDetails'] is Map<String, dynamic>)
            ? data['payslip']['salary_details']['raw_api_response']['monthDetails'] as Map<String, dynamic>
            : null;

    final attDetails = (visibleData != null && visibleData['attendance_details'] is Map<String, dynamic>)
        ? visibleData['attendance_details'] as Map<String, dynamic>
        : (data['payslip'] is Map<String, dynamic> &&
                data['payslip']['salary_details'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response']['attendanceDetails'] is Map<String, dynamic>)
            ? data['payslip']['salary_details']['raw_api_response']['attendanceDetails'] as Map<String, dynamic>
            : null;

    final finalCalc = (visibleData != null && visibleData['final_salary_calculation'] is Map<String, dynamic>)
        ? visibleData['final_salary_calculation'] as Map<String, dynamic>
        : null;

    final salDetails = (visibleData != null && visibleData['salary_details'] is Map<String, dynamic>)
        ? visibleData['salary_details'] as Map<String, dynamic>
        : (data['payslip'] is Map<String, dynamic> &&
                data['payslip']['salary_details'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response'] is Map<String, dynamic> &&
                data['payslip']['salary_details']['raw_api_response']['salaryDetails'] is Map<String, dynamic>)
            ? data['payslip']['salary_details']['raw_api_response']['salaryDetails'] as Map<String, dynamic>
            : null;

    final id = merged['id']?.toString() ??
        merged['payslip_id']?.toString() ??
        merged['payslipId']?.toString() ??
        'pay-${merged['month'] ?? '01'}';

    final payslipNumber = merged['payslip_no']?.toString() ??
        merged['payslip_number']?.toString() ??
        merged['payslipNumber']?.toString() ??
        merged['slip_no']?.toString() ??
        merged['voucher_no']?.toString() ??
        data['payslip_number']?.toString() ??
        data['payslipNumber']?.toString() ??
        'PAY-MX-${DateTime.now().year}-${id.hashCode.abs().toString().padLeft(4, '0')}';

    final rawMonth = visibleData?['month']?.toString() ??
        merged['month_name']?.toString() ??
        merged['salary_month']?.toString() ??
        merged['payslip_month']?.toString() ??
        merged['month']?.toString() ??
        fallbackMonth ??
        '';
    final month = _formatMonthName(rawMonth, fallbackMonth);

    final financialYear = merged['financial_year']?.toString() ??
        merged['financialYear']?.toString() ??
        merged['year']?.toString() ??
        fallbackYear ??
        '';

    final employeeName = empDetails?['name']?.toString() ??
        visibleData?['employee_name']?.toString() ??
        merged['employee_name']?.toString() ??
        merged['employeeName']?.toString() ??
        merged['name']?.toString() ??
        fallbackEmpName ??
        'Employee';

    final employeeCode = empDetails?['employee_id']?.toString() ??
        visibleData?['employee_id']?.toString() ??
        merged['employee_id']?.toString() ??
        merged['employee_code']?.toString() ??
        merged['employeeCode']?.toString() ??
        merged['emp_id']?.toString() ??
        fallbackEmpId ??
        '';

    final designation = empDetails?['designation_name']?.toString() ??
        visibleData?['designation']?.toString() ??
        merged['designation_name']?.toString() ??
        merged['designation']?.toString() ??
        merged['designationName']?.toString() ??
        fallbackDesignation ??
        'Staff';

    final department = empDetails?['dept_name']?.toString() ??
        visibleData?['department']?.toString() ??
        merged['dept_name']?.toString() ??
        merged['department_name']?.toString() ??
        merged['department']?.toString() ??
        merged['departmentName']?.toString() ??
        fallbackDepartment ??
        'General';

    // Bank & Government ID metadata
    final bankName = bankDetails?['bank_name']?.toString() ??
        empDetails?['bank_name']?.toString() ??
        merged['bank_name']?.toString() ??
        merged['bank']?.toString();

    final accountNo = bankDetails?['account_number']?.toString() ??
        empDetails?['account_number']?.toString() ??
        merged['account_number']?.toString() ??
        merged['account_no']?.toString() ??
        merged['accountNumber']?.toString();

    final ifscCode = bankDetails?['ifsc']?.toString() ??
        empDetails?['ifsc']?.toString() ??
        merged['ifsc']?.toString() ??
        merged['ifsc_code']?.toString();

    final panNo = empDetails?['pan_number']?.toString() ??
        merged['pan_number']?.toString() ??
        merged['pan_no']?.toString() ??
        merged['pan']?.toString();

    // Attendance stats
    final workingDays = _parseInt(
      monthDetails?['total_working_days'] ??
          monthDetails?['total_days'] ??
          merged['total_working_days'] ??
          merged['working_days'] ??
          22,
    );

    final holidays = _parseInt(
      monthDetails?['total_holidays'] ??
          attDetails?['total_holiday'] ??
          merged['total_holidays'] ??
          merged['holidays'] ??
          0,
    );

    final weekends = _parseInt(
      monthDetails?['total_weekends'] ??
          attDetails?['total_office_weekend'] ??
          merged['total_weekends'] ??
          merged['weekends'] ??
          8,
    );

    final presentDays = _parseInt(
      attDetails?['total_present'] ??
          merged['total_present'] ??
          merged['present_days'] ??
          0,
    );

    final onTimeDays = _parseInt(
      attDetails?['total_present_on_time'] ??
          merged['total_present_on_time'] ??
          merged['on_time_days'] ??
          0,
    );

    final lateDays = _parseInt(
      attDetails?['total_present_late'] ??
          merged['total_present_late'] ??
          merged['late_days'] ??
          0,
    );

    final earlyLogoutDays = _parseInt(
      attDetails?['total_early_logout'] ??
          merged['total_early_logout'] ??
          merged['early_logout_days'] ??
          0,
    );

    final rawLeaveApproved = _parseInt(attDetails?['total_leave_approved'] ?? merged['total_leave_approved'] ?? merged['leaves']);
    final leaves = rawLeaveApproved > 0
        ? rawLeaveApproved
        : _parseInt(attDetails?['total_absent'] ?? merged['total_absent'] ?? 0);

    final overtimeHours = _parseDouble(
      attDetails?['total_overtime_hours'] ??
          merged['total_overtime_hours'] ??
          merged['overtime_hours'] ??
          0.0,
    );

    // PDF URL / Path from server if generated in Laravel
    final pdfUrl = merged['pdf_url']?.toString() ??
        merged['file_url']?.toString() ??
        merged['pdf_path']?.toString() ??
        merged['file_path']?.toString() ??
        merged['download_url']?.toString() ??
        merged['path']?.toString() ??
        data['pdf_url']?.toString() ??
        data['file_url']?.toString() ??
        data['pdf_path']?.toString() ??
        data['file_path']?.toString();

    // 4. Parse Earnings
    List<PayslipItemEntity> parsedEarnings = [];

    if (finalCalc != null) {
      final items = [
        MapEntry('Basic Salary', finalCalc['basic_salary']),
        MapEntry('House Rent Allowance (HRA)', finalCalc['hra']),
        MapEntry('Conveyance Allowance', finalCalc['conveyance']),
        MapEntry('Medical Allowance', finalCalc['medical_allowance']),
        MapEntry('Special Allowance', finalCalc['special_allowance']),
        MapEntry('Performance Bonus', finalCalc['performance_bonus']),
        MapEntry('Overtime Payment', finalCalc['overtime_payment']),
      ];

      for (final item in items) {
        final amount = _parseDouble(item.value);
        if (amount > 0) {
          parsedEarnings.add(PayslipItemEntity(
            title: item.key,
            amount: amount,
            isAddition: true,
          ));
        }
      }
    }

    if (parsedEarnings.isEmpty && salDetails != null) {
      final items = [
        MapEntry('Base Salary', salDetails['base_salary']),
        MapEntry('House Rent Allowance (HRA)', salDetails['hra']),
        MapEntry('Conveyance Allowance', salDetails['conveyance']),
        MapEntry('Medical Allowance', salDetails['medical_allowance']),
        MapEntry('Special Bonus', salDetails['special_bonus']),
      ];

      for (final item in items) {
        final amount = _parseDouble(item.value);
        if (amount > 0) {
          parsedEarnings.add(PayslipItemEntity(
            title: item.key,
            amount: amount,
            isAddition: true,
          ));
        }
      }
    }

    if (parsedEarnings.isEmpty) {
      final rawEarnings = merged['earnings'] ?? merged['allowance_list'] ?? merged['additions'] ?? data['earnings'];
      if (rawEarnings is List) {
        parsedEarnings = rawEarnings
            .whereType<Map<String, dynamic>>()
            .map((e) => PayslipItemModel.fromJson(e, defaultIsAddition: true))
            .where((e) => e.amount > 0)
            .toList();
      } else if (rawEarnings is Map<String, dynamic>) {
        rawEarnings.forEach((key, val) {
          final amount = _parseDouble(val);
          if (amount > 0) {
            parsedEarnings.add(PayslipItemEntity(
              title: _formatKeyToTitle(key),
              amount: amount,
              isAddition: true,
            ));
          }
        });
      }
    }

    if (parsedEarnings.isEmpty) {
      final possibleEarnings = [
        MapEntry('Basic Salary', merged['basic_salary'] ?? merged['basicSalary'] ?? merged['basic']),
        MapEntry('House Rent Allowance (HRA)', merged['hra'] ?? merged['house_rent_allowance'] ?? merged['houseRentAllowance']),
        MapEntry('Conveyance Allowance', merged['conveyance'] ?? merged['conveyance_allowance'] ?? merged['conveyanceAllowance']),
        MapEntry('Medical Allowance', merged['medical_allowance'] ?? merged['medical'] ?? merged['medicalAllowance']),
        MapEntry('Allowances', merged['allowances'] ?? merged['allowance'] ?? merged['other_allowances']),
        MapEntry('Special Allowance', merged['special_allowance'] ?? merged['specialAllowance'] ?? merged['special']),
        MapEntry('Performance Bonus', merged['performance_bonus'] ?? merged['bonus'] ?? merged['performanceBonus']),
        MapEntry('Overtime Payment', merged['overtime_payment'] ?? merged['overtime_amount'] ?? merged['overtime_pay'] ?? merged['overtime']),
        MapEntry('Other Earnings', merged['other_earnings'] ?? merged['otherEarnings'] ?? merged['other_income']),
      ];

      for (final entry in possibleEarnings) {
        if (entry.value != null) {
          final amount = _parseDouble(entry.value);
          if (amount > 0) {
            parsedEarnings.add(PayslipItemEntity(
              title: entry.key,
              amount: amount,
              isAddition: true,
            ));
          }
        }
      }
    }

    // 5. Parse Deductions
    List<PayslipItemEntity> parsedDeductions = [];

    if (finalCalc != null) {
      final items = [
        MapEntry('Loss of Pay (LOP)', finalCalc['lop'] ?? finalCalc['loss_of_pay']),
        MapEntry('Employee Provident Fund (EPF)', finalCalc['provident_fund'] ?? finalCalc['epf'] ?? finalCalc['pf']),
        MapEntry('Employee State Insurance (ESI)', finalCalc['esi']),
        MapEntry('Professional Tax (PT)', finalCalc['ptax'] ?? finalCalc['pt']),
        MapEntry('Income Tax (TDS)', finalCalc['tds'] ?? finalCalc['tax']),
        MapEntry('Loan Deduction', finalCalc['loan']),
        MapEntry('Labor Welfare Fund (LWF)', finalCalc['lwf_deduct']),
      ];

      for (final item in items) {
        final amount = _parseDouble(item.value);
        if (amount > 0) {
          parsedDeductions.add(PayslipItemEntity(
            title: item.key,
            amount: amount,
            isAddition: false,
          ));
        }
      }
    }

    if (parsedDeductions.isEmpty && salDetails != null) {
      final items = [
        MapEntry('Employee Provident Fund (EPF)', salDetails['provident_fund']),
        MapEntry('Employee State Insurance (ESI)', salDetails['esi']),
        MapEntry('Professional Tax (PT)', salDetails['ptax']),
        MapEntry('Income Tax (TDS)', salDetails['tds']),
        MapEntry('Loan Deduction', salDetails['loan']),
        MapEntry('Advance', salDetails['advance_amount']),
      ];

      for (final item in items) {
        final amount = _parseDouble(item.value);
        if (amount > 0) {
          parsedDeductions.add(PayslipItemEntity(
            title: item.key,
            amount: amount,
            isAddition: false,
          ));
        }
      }
    }

    if (parsedDeductions.isEmpty) {
      final rawDeductions = merged['deductions'] ?? merged['cuts'] ?? data['deductions'];
      if (rawDeductions is List) {
        parsedDeductions = rawDeductions
            .whereType<Map<String, dynamic>>()
            .map((d) => PayslipItemModel.fromJson(d, defaultIsAddition: false))
            .where((d) => d.amount > 0)
            .toList();
      } else if (rawDeductions is Map<String, dynamic>) {
        rawDeductions.forEach((key, val) {
          final amount = _parseDouble(val);
          if (amount > 0) {
            parsedDeductions.add(PayslipItemEntity(
              title: _formatKeyToTitle(key),
              amount: amount,
              isAddition: false,
            ));
          }
        });
      }
    }

    if (parsedDeductions.isEmpty) {
      final possibleDeductions = [
        MapEntry('Loss of Pay (LOP)', merged['lop'] ?? merged['loss_of_pay'] ?? merged['lossOfPay']),
        MapEntry('Employee Provident Fund (EPF)', merged['provident_fund'] ?? merged['pf'] ?? merged['epf'] ?? merged['employee_provident_fund']),
        MapEntry('Employee State Insurance (ESI)', merged['esi'] ?? merged['employee_state_insurance'] ?? merged['insurance']),
        MapEntry('Professional Tax (PT)', merged['ptax'] ?? merged['pt'] ?? merged['professional_tax']),
        MapEntry('Income Tax (TDS)', merged['tds'] ?? merged['tax'] ?? merged['income_tax'] ?? merged['tax_deducted']),
        MapEntry('Loan Deduction', merged['loan'] ?? merged['loan_deduction']),
        MapEntry('Advance', merged['advance_amount'] ?? merged['advance']),
        MapEntry('Other Deductions', merged['other_deductions'] ?? merged['other_deduction'] ?? merged['otherDeductions']),
      ];

      for (final entry in possibleDeductions) {
        if (entry.value != null) {
          final amount = _parseDouble(entry.value);
          if (amount > 0) {
            parsedDeductions.add(PayslipItemEntity(
              title: entry.key,
              amount: amount,
              isAddition: false,
            ));
          }
        }
      }
    }

    // 6. Compute Totals
    double totalAdditions = _parseDouble(
      finalCalc?['total_earnings'] ??
          salDetails?['total_addition'] ??
          merged['total_earnings'] ??
          merged['totalEarnings'] ??
          merged['total_additions'] ??
          merged['totalAdditions'],
    );
    if (totalAdditions == 0.0 && parsedEarnings.isNotEmpty) {
      totalAdditions = parsedEarnings.fold(0.0, (sum, e) => sum + e.amount);
    }

    double grossSalary = _parseDouble(
      salDetails?['gross_salary'] ??
          finalCalc?['total_earnings'] ??
          merged['gross_salary'] ??
          merged['grossSalary'],
    );
    if (grossSalary == 0.0) {
      grossSalary = totalAdditions > 0 ? totalAdditions : 0.0;
    }

    double totalDeductions = _parseDouble(
      finalCalc?['total_deductions'] ??
          merged['total_deductions'] ??
          merged['totalDeductions'],
    );
    if (totalDeductions == 0.0 && parsedDeductions.isNotEmpty) {
      totalDeductions = parsedDeductions.fold(0.0, (sum, d) => sum + d.amount);
    }

    double netSalary = _parseDouble(
      finalCalc?['net_salary'] ??
          merged['net_salary'] ??
          merged['netSalary'] ??
          merged['net_pay'] ??
          merged['netPay'],
    );
    if (netSalary == 0.0) {
      netSalary = totalAdditions > 0 ? totalAdditions : (grossSalary - totalDeductions).clamp(0.0, double.infinity);
    }

    return PayslipModel(
      id: id,
      payslipNumber: payslipNumber,
      month: month,
      financialYear: financialYear,
      employeeName: employeeName,
      employeeCode: employeeCode,
      designation: designation,
      department: department,
      grossSalary: grossSalary,
      totalAdditions: totalAdditions,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
      workingDays: workingDays,
      holidays: holidays,
      weekends: weekends,
      presentDays: presentDays,
      onTimeDays: onTimeDays,
      lateDays: lateDays,
      earlyLogoutDays: earlyLogoutDays,
      leaves: leaves,
      overtimeHours: overtimeHours,
      earnings: parsedEarnings,
      deductions: parsedDeductions,
      pdfUrl: pdfUrl,
      bankName: bankName,
      accountNo: accountNo,
      ifscCode: ifscCode,
      panNo: panNo,
      companyName: companyName,
      companyAddress: companyAddress,
      companyEmail: companyEmail,
      companyLogo: companyLogo,
      inWords: finalCalc?['in_words']?.toString() ??
          visibleData?['in_words']?.toString() ??
          merged['in_words']?.toString() ??
          merged['inWords']?.toString(),
      visibleData: visibleData,
      companyInfo: safeCompanyInfo.isNotEmpty ? safeCompanyInfo : null,
    );
  }
}
