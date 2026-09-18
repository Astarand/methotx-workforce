import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/company_details_model.dart';
import '../models/payslip_model.dart';

abstract class PayslipRemoteDataSource {
  Future<PayslipModel> fetchPayslipDetails({
    required String employeeId,
    required String financialYear,
    required String month,
    required String secure,
    String? fallbackMonthName,
    String? fallbackYear,
    String? fallbackEmpName,
    String? fallbackDesignation,
    String? fallbackDepartment,
  });

  Future<CompanyDetailsModel> fetchCompanyDetails({
    required String empId,
    required String secure,
  });
}

class PayslipRemoteDataSourceImpl implements PayslipRemoteDataSource {
  final DioClient dioClient;

  PayslipRemoteDataSourceImpl({required this.dioClient});

  static String monthNameToNumber(String month) {
    final clean = month.trim();
    final asInt = int.tryParse(clean);
    if (asInt != null && asInt >= 1 && asInt <= 12) {
      return asInt.toString();
    }

    switch (clean.toLowerCase()) {
      case 'january':
      case 'jan':
        return '1';
      case 'february':
      case 'feb':
        return '2';
      case 'march':
      case 'mar':
        return '3';
      case 'april':
      case 'apr':
        return '4';
      case 'may':
        return '5';
      case 'june':
      case 'jun':
        return '6';
      case 'july':
      case 'jul':
        return '7';
      case 'august':
      case 'aug':
        return '8';
      case 'september':
      case 'sep':
      case 'sept':
        return '9';
      case 'october':
      case 'oct':
        return '10';
      case 'november':
      case 'nov':
        return '11';
      case 'december':
      case 'dec':
        return '12';
      default:
        return clean;
    }
  }

  @override
  Future<PayslipModel> fetchPayslipDetails({
    required String employeeId,
    required String financialYear,
    required String month,
    required String secure,
    String? fallbackMonthName,
    String? fallbackYear,
    String? fallbackEmpName,
    String? fallbackDesignation,
    String? fallbackDepartment,
  }) async {
    final monthNumber = monthNameToNumber(month);
    final monthVal = int.tryParse(monthNumber) ?? monthNumber;

    final payload = {
      'employee_id': employeeId,
      'empId': employeeId,
      'financial_year': financialYear,
      'financialYear': financialYear,
      'month': monthVal,
      'secure': secure,
    };

    final response = await dioClient.post(
      ApiEndpoints.payslipDetails,
      data: payload,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'error' || data['success'] == false) {
        final errorMsg = data['message']?.toString() ?? 'Payslip not found for the selected period.';
        throw BadRequestException(message: errorMsg);
      }

      return PayslipModel.fromJson(
        data,
        fallbackMonth: fallbackMonthName ?? month,
        fallbackYear: fallbackYear ?? financialYear,
        fallbackEmpId: employeeId,
        fallbackEmpName: fallbackEmpName,
        fallbackDesignation: fallbackDesignation,
        fallbackDepartment: fallbackDepartment,
      );
    }

    throw const BadRequestException(message: 'Unexpected payslip response received from server.');
  }

  @override
  Future<CompanyDetailsModel> fetchCompanyDetails({
    required String empId,
    required String secure,
  }) async {
    final payload = {
      'empId': empId,
      'employee_id': empId,
      'secure': secure,
    };

    final response = await dioClient.post(
      ApiEndpoints.companyDetails,
      data: payload,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CompanyDetailsModel.fromJson(data);
    }

    return const CompanyDetailsModel(
      compName: 'MethotX Workforce',
    );
  }
}

final payslipRemoteDataSourceProvider = Provider<PayslipRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PayslipRemoteDataSourceImpl(dioClient: dioClient);
});
