import '../../data/models/company_details_model.dart';
import '../entities/payslip_entity.dart';

abstract class PayslipRepository {
  Future<PayslipEntity?> generatePayslip({
    required String month,
    required String financialYear,
    String? employeeId,
    String? secure,
    String? fallbackEmpName,
    String? fallbackDesignation,
    String? fallbackDepartment,
  });

  Future<CompanyDetailsModel?> getCompanyDetails({
    String? empId,
    String? secure,
  });

  Future<List<String>> getAvailableMonths();
  Future<List<String>> getAvailableFinancialYears();
}
