import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:methotx_workforce/features/payslip/data/datasources/payslip_remote_data_source.dart';
import 'package:methotx_workforce/features/payslip/data/models/company_details_model.dart';
import 'package:methotx_workforce/features/payslip/data/models/payslip_model.dart';
import 'package:methotx_workforce/features/payslip/data/repositories/payslip_repository_impl.dart';
import 'package:methotx_workforce/features/payslip/domain/entities/payslip_entity.dart';
import 'package:methotx_workforce/features/payslip/domain/repositories/payslip_repository.dart';
import 'package:methotx_workforce/features/payslip/presentation/controllers/payslip_controller.dart';
import 'package:methotx_workforce/features/payslip/services/payslip_pdf_service.dart';

class _TestPayslipRepository implements PayslipRepository {
  @override
  Future<PayslipEntity?> generatePayslip({
    required String month,
    required String financialYear,
    String? employeeId,
    String? secure,
    String? fallbackEmpName,
    String? fallbackDesignation,
    String? fallbackDepartment,
  }) async {
    return PayslipEntity(
      id: 'test-pay-101',
      payslipNumber: 'PAY-TEST-001',
      month: month,
      financialYear: financialYear,
      employeeName: fallbackEmpName ?? 'Jane Doe',
      employeeCode: employeeId ?? 'EMP-001',
      designation: fallbackDesignation ?? 'Software Engineer',
      department: fallbackDepartment ?? 'Engineering',
      grossSalary: 25000.00,
      totalAdditions: 25000.00,
      totalDeductions: 1500.00,
      netSalary: 23500.00,
      workingDays: 22,
      holidays: 2,
      weekends: 8,
      presentDays: 21,
      onTimeDays: 20,
      lateDays: 1,
      earlyLogoutDays: 0,
      leaves: 1,
      overtimeHours: 4.0,
      earnings: const [
        PayslipItemEntity(title: 'Basic Salary', amount: 20000.00, isAddition: true),
        PayslipItemEntity(title: 'HRA', amount: 5000.00, isAddition: true),
      ],
      deductions: const [
        PayslipItemEntity(title: 'Provident Fund', amount: 1000.00, isAddition: false),
        PayslipItemEntity(title: 'Tax', amount: 500.00, isAddition: false),
      ],
    );
  }

  @override
  Future<CompanyDetailsModel?> getCompanyDetails({
    String? empId,
    String? secure,
  }) async {
    return const CompanyDetailsModel(
      compName: 'Acme Corporation',
      gstReg: 'Yes',
      gstNo: '99XXXXX0000X1Z5',
      compPanNo: 'ABCDE1234F',
      compEmail: 'hr@example.com',
      compPhone: '+91 99999 99999',
      addressLine1: '123 Innovation Way',
      city: 'Tech City',
      state: 'Demo State',
      pin: '500001',
    );
  }

  @override
  Future<List<String>> getAvailableMonths() async {
    return const ['January', 'August', 'December'];
  }

  @override
  Future<List<String>> getAvailableFinancialYears() async {
    return const ['2026-2027', '2025-2026'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payslip Remote Data Source - Month Mapping Tests', () {
    test('Correctly maps month names to numeric strings 1..12', () {
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('January'), '1');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('February'), '2');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('March'), '3');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('April'), '4');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('May'), '5');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('June'), '6');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('July'), '7');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('August'), '8');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('September'), '9');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('October'), '10');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('November'), '11');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('December'), '12');
    });

    test('Passes through already numeric month strings', () {
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('8'), '8');
      expect(PayslipRemoteDataSourceImpl.monthNameToNumber('12'), '12');
    });
  });

  group('Company Details Model Tests', () {
    test('Parses generic backend JSON structure accurately without hardcoded data', () {
      final json = {
        "success": true,
        "message": "Company details fetched successfully",
        "data": {
          "comp_logo": null,
          "gst_reg": "Yes",
          "gst_no": "99XXXXX0000X1Z5",
          "comp_name": "Acme Corporation",
          "comp_email": "hr@example.com",
          "comp_phone": "+91 99999 99999",
          "comp_pan_no": "ABCDE1234F",
          "comp_bill_addone": "123 Innovation Way",
          "comp_bill_city": "Tech City",
          "comp_bill_state": "Demo State",
          "comp_bill_pin": "500001"
        }
      };

      final model = CompanyDetailsModel.fromJson(json);

      expect(model.compName, 'Acme Corporation');
      expect(model.gstNo, '99XXXXX0000X1Z5');
      expect(model.compPanNo, 'ABCDE1234F');
      expect(model.compEmail, 'hr@example.com');
      expect(model.compPhone, '+91 99999 99999');
      expect(model.addressLine1, '123 Innovation Way');
      expect(model.city, 'Tech City');
      expect(model.state, 'Demo State');
      expect(model.pin, '500001');
      expect(model.fullAddress, contains('Tech City'));
      expect(model.fullAddress, contains('500001'));
    });

    test('Parses company logo accurately across diverse keys and rejects null/empty strings', () {
      final jsonWithCompLogo = {
        "data": {
          "comp_logo": "https://test.methotx.in/storage/logos/company.png",
          "comp_name": "360 BUSINESS & SERVICES"
        }
      };
      final m1 = CompanyDetailsModel.fromJson(jsonWithCompLogo);
      expect(m1.compLogo, 'https://test.methotx.in/storage/logos/company.png');
      expect(m1.toJson()['comp_logo'], 'https://test.methotx.in/storage/logos/company.png');
      expect(m1.toJson()['logo'], 'https://test.methotx.in/storage/logos/company.png');

      final jsonWithNullString = {
        "data": {
          "comp_logo": "null",
          "comp_name": "Acme"
        }
      };
      final m2 = CompanyDetailsModel.fromJson(jsonWithNullString);
      expect(m2.compLogo, isNull);

      final jsonWithEmptyLogo = {
        "data": {
          "comp_logo": "",
          "comp_name": "Acme"
        }
      };
      final m3 = CompanyDetailsModel.fromJson(jsonWithEmptyLogo);
      expect(m3.compLogo, isNull);

      final jsonWithLogoKey = {
        "data": {
          "logo": "https://portal.methotx.com/logo.png",
          "comp_name": "Acme"
        }
      };
      final m4 = CompanyDetailsModel.fromJson(jsonWithLogoKey);
      expect(m4.compLogo, 'https://portal.methotx.com/logo.png');

      final jsonWithList = {
        "data": [
          {
            "comp_logo": "https://portal.methotx.com/company_list_logo.png",
            "comp_name": "Acme List"
          }
        ]
      };
      final m5 = CompanyDetailsModel.fromJson(jsonWithList);
      expect(m5.compLogo, 'https://portal.methotx.com/company_list_logo.png');
      expect(m5.compName, 'Acme List');
    });
  });

  group('Payslip Model JSON Parsing Tests', () {
    test('Parses nested JSON and handles string amount conversion', () {
      final json = {
        "status": "success",
        "data": {
          "id": "pay-101",
          "payslip_number": "PAY-2026-0801",
          "month": "August",
          "financial_year": "2026-2027",
          "employee_name": "Jane Doe",
          "employee_code": "emp-00001",
          "designation": "Software Developer",
          "department": "Engineering",
          "gross_salary": "25000.00",
          "total_additions": "27000.00",
          "total_deductions": "1500.00",
          "net_salary": "25500.00",
          "working_days": "22",
          "present_days": "21",
          "on_time_days": "20",
          "late_days": "1",
          "leaves": "1",
          "overtime_hours": "5.5",
          "earnings": [
            {"title": "Basic Salary", "amount": "20000.00"},
            {"title": "HRA", "amount": "5000.00"},
            {"title": "Bonus", "amount": "2000.00"}
          ],
          "deductions": [
            {"title": "PF", "amount": "1000.00"},
            {"title": "PT", "amount": "500.00"}
          ]
        }
      };

      final model = PayslipModel.fromJson(json);

      expect(model.id, 'pay-101');
      expect(model.payslipNumber, 'PAY-2026-0801');
      expect(model.month, 'August');
      expect(model.financialYear, '2026-2027');
      expect(model.employeeName, 'Jane Doe');
      expect(model.employeeCode, 'emp-00001');
      expect(model.grossSalary, 25000.00);
      expect(model.netSalary, 25500.00);
      expect(model.workingDays, 22);
      expect(model.presentDays, 21);
      expect(model.overtimeHours, 5.5);
      expect(model.earnings.length, 3);
      expect(model.deductions.length, 2);
      expect(model.earnings[0].amount, 20000.00);
      expect(model.deductions[0].amount, 1000.00);
    });

    test('Parses Laravel associative Map earnings/deductions and bank metadata', () {
      final laravelJson = {
        "status": "success",
        "data": {
          "id": 11,
          "payslip_number": "PS/emp2-00011/01082026",
          "month": "August",
          "financial_year": "2026-2027",
          "employee_name": "Rittik Sadhukhan",
          "employee_code": "emp2-00011",
          "designation": "Developer",
          "department": "IT",
          "bank_name": "State bank of India",
          "account_no": "39889106687",
          "ifsc_code": "SBIN0004636",
          "pan_no": "KYMPS6119C",
          "earnings": {
            "basic_salary": 2000,
            "hra": 1000,
            "conveyance_allowance": 1600,
            "medical_allowance": 1250
          },
          "deductions": {
            "loss_of_pay": 26000
          },
          "gross_salary": 5850.0,
          "total_earnings": 5850.0,
          "total_deductions": 26000.0,
          "net_salary": 5850.0,
          "pdf_url": "https://test.methotx.in/storage/payslips/PS_emp2-00011.pdf"
        }
      };

      final model = PayslipModel.fromJson(laravelJson);

      expect(model.employeeName, 'Rittik Sadhukhan');
      expect(model.employeeCode, 'emp2-00011');
      expect(model.payslipNumber, 'PS/emp2-00011/01082026');
      expect(model.bankName, 'State bank of India');
      expect(model.accountNo, '39889106687');
      expect(model.ifscCode, 'SBIN0004636');
      expect(model.panNo, 'KYMPS6119C');
      expect(model.pdfUrl, 'https://test.methotx.in/storage/payslips/PS_emp2-00011.pdf');

      // Earnings parsed from Map
      expect(model.earnings.length, 4);
      expect(model.earnings.any((e) => e.title == 'Basic Salary' && e.amount == 2000), isTrue);
      expect(model.earnings.any((e) => e.title.contains('HRA') && e.amount == 1000), isTrue);
      expect(model.earnings.any((e) => e.title == 'Conveyance Allowance' && e.amount == 1600), isTrue);
      expect(model.earnings.any((e) => e.title == 'Medical Allowance' && e.amount == 1250), isTrue);

      // Deductions parsed from Map
      expect(model.deductions.length, 1);
      expect(model.deductions[0].title, 'Loss of Pay (LOP)');
      expect(model.deductions[0].amount, 26000);

      // Totals
      expect(model.totalAdditions, 5850.0);
      expect(model.netSalary, 5850.0);
    });

    test('Parses official nested structure data.payslip.salary_details.visible_data and company_info', () {
      final officialJson = {
        "success": true,
        "message": "Payslip generated successfully",
        "data": {
          "payslip": {
            "salary_details": {
              "visible_data": {
                "employee_name": "John Doe",
                "employee_id": "EMP001",
                "designation": "Software Engineer",
                "month": "August 2026",
                "basic_salary": 30000,
                "hra": 10000,
                "allowances": 5000,
                "gross_salary": 45000,
                "pf": 3600,
                "tax": 1000,
                "other_deductions": 500,
                "total_deductions": 5100,
                "net_salary": 39900
              }
            }
          },
          "company_info": {
            "name": "MethotX",
            "address": "Company Address",
            "logo": "https://example.com/logo.png",
            "email": "hr@example.com"
          }
        }
      };

      final model = PayslipModel.fromJson(officialJson);

      expect(model.employeeName, 'John Doe');
      expect(model.employeeCode, 'EMP001');
      expect(model.designation, 'Software Engineer');
      expect(model.month, 'August');
      expect(model.grossSalary, 45000.0);
      expect(model.totalAdditions, 45000.0);
      expect(model.totalDeductions, 5100.0);
      expect(model.netSalary, 39900.0);

      // Company info
      expect(model.companyName, 'MethotX');
      expect(model.companyAddress, 'Company Address');
      expect(model.companyEmail, 'hr@example.com');
      expect(model.companyLogo, 'https://example.com/logo.png');

      // Earnings items
      expect(model.earnings.length, 3);
      expect(model.earnings.any((e) => e.title == 'Basic Salary' && e.amount == 30000), isTrue);
      expect(model.earnings.any((e) => e.title.contains('HRA') && e.amount == 10000), isTrue);
      expect(model.earnings.any((e) => e.title == 'Allowances' && e.amount == 5000), isTrue);

      // Deductions items
      expect(model.deductions.length, 3);
      expect(model.deductions.any((d) => d.title.contains('EPF') && d.amount == 3600), isTrue);
      expect(model.deductions.any((d) => d.title.contains('Income Tax') && d.amount == 1000), isTrue);
      expect(model.deductions.any((d) => d.title == 'Other Deductions' && d.amount == 500), isTrue);
    });

    test('Parses exact live backend payload for August 2026 with final_salary_calculation and employee_details', () {
      final liveAugustJson = {
        "status": "success",
        "data": {
          "payslip": {
            "id": 24,
            "user_emp_id": 35,
            "financial_year": "2026-2027",
            "month": "8",
            "payslip_no": "PS/emp2-00011/01082026",
            "payslip_text": "",
            "payslip_path": null,
            "date": "2026-09-04",
            "salary_details": {
              "payslip_no": "PS/emp2-00011/01082026",
              "employee_id": "35",
              "financial_year": "2026-2027",
              "month": "8",
              "generate_date": "2026-09-04",
              "notes": null,
              "visible_data": {
                "payslip_no": "PS/emp2-00011/01082026",
                "financial_year": "2026-2027",
                "month": "8",
                "generate_date": "2026-09-04",
                "notes": "",
                "employee_details": {
                  "empId": "35",
                  "name": "Rittik Sadhukhan",
                  "email": "rittik.sk@hotmail.com",
                  "phone": "9609412418",
                  "employee_id": "emp2-00011",
                  "joining_date": "2025-07-01",
                  "dept_name": "IT",
                  "designation_name": "Full Stack Developer",
                  "epf_no": null,
                  "bank_name": "State bank of India",
                  "bank_branch": "Machlandapur",
                  "ifsc": "SBIN0004636",
                  "account_holder_name": "Rittik Sadhukhan",
                  "account_number": "39889106687",
                  "pan_number": "KYMPS6119C",
                  "aadhaar_number": "704021890738"
                },
                "bank_details": {
                  "bank_name": "State bank of India",
                  "branch": "Machlandapur",
                  "ifsc": "SBIN0004636",
                  "account_holder_name": "Rittik Sadhukhan",
                  "account_number": "39889106687"
                },
                "month_details": {
                  "total_days": 31,
                  "total_working_days": 26,
                  "total_holidays": 0,
                  "total_weekends": 5
                },
                "attendance_details": {
                  "total_present": 0,
                  "total_present_on_time": 0,
                  "total_present_late": 0,
                  "total_early_logout": 0,
                  "total_absent": 26,
                  "total_leave_approved": 0,
                  "total_holiday": 0,
                  "total_office_weekend": 5,
                  "total_overtime_hours": "00:00:00",
                  "totalEarlyLogoutDeductionDays": 0
                },
                "salary_details": {
                  "gross_salary": 30000,
                  "base_salary": 15000,
                  "hra": 7500,
                  "conveyance": 1600,
                  "medical_allowance": "1250.00",
                  "special_bonus": 4650,
                  "total_addition": 30000,
                  "provident_fund": 0,
                  "esi": 0,
                  "ptax": 0,
                  "tds": 0,
                  "lwf_applicable": 0,
                  "lwf_deduct": 0,
                  "lwf_company_contribution": 0,
                  "loan": 0,
                  "total_absent_days_for_salary": 26,
                  "lateDeductionDays": 0,
                  "per_day_salary": 1000,
                  "advance_amount": 0
                },
                "final_salary_calculation": {
                  "basic_salary": 2000,
                  "hra": 1000,
                  "conveyance": 1600,
                  "medical_allowance": 1250,
                  "special_allowance": 0,
                  "performance_bonus": 0,
                  "overtime_payment": 0,
                  "total_earnings": 5850,
                  "provident_fund": 0,
                  "esi": 0,
                  "ptax": 0,
                  "tds": 0,
                  "loan": 0,
                  "lop": 26000,
                  "lwf_applicable": 0,
                  "lwf_deduct": 0,
                  "lwf_company_contribution": 0,
                  "total_deductions": 26000,
                  "net_salary": 5850,
                  "in_words": "Five Thousand Eight Hundred and FiftyOnly",
                  "generated_at": "2026-09-04T08:22:31.064Z"
                }
              }
            }
          },
          "company_info": {
            "comp_name": "360 BUSINESS & SERVICES",
            "comp_email": "contact@360bizservice.com",
            "comp_pan_no": "BDIPS9501C",
            "comp_bill_gst_no": "19BDIPS9501C1ZF",
            "comp_bill_addone": "GP-G2-1102 Srijan Corporate Park",
            "comp_bill_addtwo": "11TH FLOOR, TOWER NO-1, Bidhan Nagar",
            "comp_bill_country": "India",
            "comp_bill_state": "West Bengal",
            "comp_bill_city": "Kolkata"
          }
        }
      };

      final model = PayslipModel.fromJson(liveAugustJson);

      expect(model.employeeName, 'Rittik Sadhukhan');
      expect(model.employeeCode, 'emp2-00011');
      expect(model.designation, 'Full Stack Developer');
      expect(model.department, 'IT');
      expect(model.payslipNumber, 'PS/emp2-00011/01082026');
      expect(model.month, 'August');
      expect(model.financialYear, '2026-2027');

      // Bank & PAN
      expect(model.bankName, 'State bank of India');
      expect(model.accountNo, '39889106687');
      expect(model.ifscCode, 'SBIN0004636');
      expect(model.panNo, 'KYMPS6119C');

      // Company info
      expect(model.companyName, '360 BUSINESS & SERVICES');
      expect(model.companyEmail, 'contact@360bizservice.com');

      // Salary figures
      expect(model.grossSalary, 30000.0);
      expect(model.totalAdditions, 5850.0);
      expect(model.totalDeductions, 26000.0);
      expect(model.netSalary, 5850.0);

      // Earnings items
      expect(model.earnings.length, 4);
      expect(model.earnings.any((e) => e.title == 'Basic Salary' && e.amount == 2000.0), isTrue);
      expect(model.earnings.any((e) => e.title.contains('HRA') && e.amount == 1000.0), isTrue);
      expect(model.earnings.any((e) => e.title.contains('Conveyance') && e.amount == 1600.0), isTrue);
      expect(model.earnings.any((e) => e.title.contains('Medical') && e.amount == 1250.0), isTrue);

      // Deductions items
      expect(model.deductions.length, 1);
      expect(model.deductions[0].title, 'Loss of Pay (LOP)');
      expect(model.deductions[0].amount, 26000.0);

      // Attendance
      expect(model.workingDays, 26);
      expect(model.weekends, 5);
      expect(model.presentDays, 0);
      expect(model.leaves, 26); // total absent
    });
  });

  group('Payslip PDF Generation Service Tests', () {
    test('Generates non-empty valid PDF byte array with synthetic company data', () async {
      final mockRepo = _TestPayslipRepository();
      final payslip = await mockRepo.generatePayslip(month: 'August', financialYear: '2026-2027');
      final company = await mockRepo.getCompanyDetails();

      expect(payslip, isNotNull);

      final pdfBytes = await PayslipPdfService.generatePayslipPdf(
        payslip: payslip!,
        company: company,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, '%PDF-');
    });

    test('Generates exact A4 PDF from raw visible_data and company_info matching Laravel Portal design', () async {
      final visible = {
        'payslip_no': 'PS/emp2-00011/01082026',
        'month_name': 'August',
        'year': '2026',
        'employee_details': {
          'name': 'Rittik Sadhukhan',
          'employee_id': 'emp2-00011',
          'dept_name': 'IT',
          'designation_name': 'Full Stack Developer',
          'bank_name': 'State bank of India',
          'account_number': '39889106687',
          'ifsc': 'SBIN0004636',
          'pan_number': 'KYMPS6119C',
        },
        'final_salary_calculation': {
          'basic_salary': 2000.00,
          'hra': 1000.00,
          'conveyance': 1600.00,
          'medical_allowance': 1250.00,
          'special_allowance': 0.00,
          'performance_bonus': 0.00,
          'overtime_payment': 0.00,
          'provident_fund': 0.00,
          'esi': 0.00,
          'ptax': 0.00,
          'tds': 0.00,
          'loan': 0.00,
          'lop': 26000.00,
          'advance': 0.00,
          'total_earnings': 5850.00,
          'total_deductions': 26000.00,
          'net_salary': 5850.00,
          'in_words': 'Five Thousand Eight Hundred and FiftyOnly',
        },
      };

      final companyInfo = {
        'comp_name': '360 BUSINESS & SERVICES',
        'comp_bill_addone': 'GP-G2-1102 Srijan Corporate Park',
        'comp_bill_addtwo': '11TH FLOOR, TOWER NO-1',
        'comp_bill_city': 'Bidhan Nagar',
        'comp_phone': '9830747981',
        'comp_email': 'contact@360bizservice.com',
        'comp_bill_gst_no': '19BDIPS9501C1ZF',
        'comp_pan_no': 'BDIPS9501C',
      };

      final pdfBytes = await PayslipPdfService.generate(
        visible: visible,
        companyInfo: companyInfo,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, '%PDF-');
    });
  });

  group('Payslip Controller State Management Tests', () {
    test('Changing month or year clears current payslip for fresh generation', () async {
      final container = ProviderContainer(
        overrides: [
          payslipRepositoryProvider.overrideWithValue(_TestPayslipRepository()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(payslipControllerProvider.notifier);

      await controller.generatePayslip();
      expect(container.read(payslipControllerProvider).payslip, isNotNull);

      controller.setMonth('September');
      final state = container.read(payslipControllerProvider);
      expect(state.selectedMonth, 'September');
      expect(state.payslip, isNull);
    });

    test('Successful generation populates payslip and company details', () async {
      final container = ProviderContainer(
        overrides: [
          payslipRepositoryProvider.overrideWithValue(_TestPayslipRepository()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(payslipControllerProvider.notifier);

      final success = await controller.generatePayslip();
      final state = container.read(payslipControllerProvider);

      expect(success, isTrue);
      expect(state.payslip, isNotNull);
      expect(state.companyDetails, isNotNull);
      expect(state.companyDetails?.compName, 'Acme Corporation');
      expect(state.successMessage, contains('generated successfully'));
    });
  });
}
