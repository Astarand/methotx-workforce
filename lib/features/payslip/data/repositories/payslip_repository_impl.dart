import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/payslip_entity.dart';
import '../../domain/repositories/payslip_repository.dart';
import '../datasources/payslip_remote_data_source.dart';
import '../models/company_details_model.dart';

class PayslipRepositoryImpl implements PayslipRepository {
  final PayslipRemoteDataSource remoteDataSource;
  final StorageService storageService;

  CompanyDetailsModel? _cachedCompanyDetails;

  PayslipRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

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
    final effectiveEmpId = employeeId ??
        await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
        await storageService.getString(ApiConstants.storageEmpIdKey) ??
        '';

    final effectiveSecure = secure ??
        await storageService.getSecure(ApiConstants.storageSecureKey) ??
        await storageService.getString(ApiConstants.storageSecureKey) ??
        '';

    return await remoteDataSource.fetchPayslipDetails(
      employeeId: effectiveEmpId,
      financialYear: financialYear,
      month: month,
      secure: effectiveSecure,
      fallbackMonthName: month,
      fallbackYear: financialYear,
      fallbackEmpName: fallbackEmpName,
      fallbackDesignation: fallbackDesignation,
      fallbackDepartment: fallbackDepartment,
    );
  }

  @override
  Future<CompanyDetailsModel?> getCompanyDetails({
    String? empId,
    String? secure,
  }) async {
    if (_cachedCompanyDetails != null) {
      return _cachedCompanyDetails;
    }

    try {
      final effectiveEmpId = empId ??
          await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
          await storageService.getString(ApiConstants.storageEmpIdKey) ??
          '';

      final effectiveSecure = secure ??
          await storageService.getSecure(ApiConstants.storageSecureKey) ??
          await storageService.getString(ApiConstants.storageSecureKey) ??
          '';

      final details = await remoteDataSource.fetchCompanyDetails(
        empId: effectiveEmpId,
        secure: effectiveSecure,
      );
      _cachedCompanyDetails = details;
      return details;
    } catch (_) {
      // Fallback corporate identity if network fails
      return const CompanyDetailsModel(
        compName: 'MethotX Workforce',
        compEmail: 'contact@methotx.in',
        addressLine1: 'Corporate Headquarters',
      );
    }
  }

  @override
  Future<List<String>> getAvailableMonths() async {
    return const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
  }

  @override
  Future<List<String>> getAvailableFinancialYears() async {
    return const [
      '2026-2027',
      '2025-2026',
      '2024-2025',
    ];
  }
}

final payslipRepositoryProvider = Provider<PayslipRepository>((ref) {
  final remoteDataSource = ref.watch(payslipRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return PayslipRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
