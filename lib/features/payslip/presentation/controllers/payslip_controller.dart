import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../authentication/domain/entities/auth_entity.dart';
import '../../../authentication/presentation/controllers/auth_notifier.dart';
import '../../data/models/company_details_model.dart';
import '../../data/repositories/payslip_repository_impl.dart';
import '../../domain/entities/payslip_entity.dart';
import '../../domain/repositories/payslip_repository.dart';
import '../../services/payslip_pdf_service.dart';

class PayslipState {
  final String selectedMonth;
  final String selectedYear;
  final List<String> availableMonths;
  final List<String> availableYears;
  final PayslipEntity? payslip;
  final CompanyDetailsModel? companyDetails;
  final bool isGenerating;
  final bool isDownloading;
  final String? successMessage;
  final String? errorMessage;
  final String? lastDownloadedFilePath;
  final Uint8List? lastGeneratedPdfBytes;

  const PayslipState({
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableMonths,
    required this.availableYears,
    this.payslip,
    this.companyDetails,
    this.isGenerating = false,
    this.isDownloading = false,
    this.successMessage,
    this.errorMessage,
    this.lastDownloadedFilePath,
    this.lastGeneratedPdfBytes,
  });

  PayslipState copyWith({
    String? selectedMonth,
    String? selectedYear,
    List<String>? availableMonths,
    List<String>? availableYears,
    PayslipEntity? payslip,
    CompanyDetailsModel? companyDetails,
    bool? isGenerating,
    bool? isDownloading,
    String? successMessage,
    String? errorMessage,
    String? lastDownloadedFilePath,
    Uint8List? lastGeneratedPdfBytes,
    bool clearPayslip = false,
    bool clearError = false,
  }) {
    return PayslipState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      availableMonths: availableMonths ?? this.availableMonths,
      availableYears: availableYears ?? this.availableYears,
      payslip: clearPayslip ? null : (payslip ?? this.payslip),
      companyDetails: companyDetails ?? this.companyDetails,
      isGenerating: isGenerating ?? this.isGenerating,
      isDownloading: isDownloading ?? this.isDownloading,
      successMessage: successMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastDownloadedFilePath:
          lastDownloadedFilePath ?? this.lastDownloadedFilePath,
      lastGeneratedPdfBytes:
          lastGeneratedPdfBytes ?? this.lastGeneratedPdfBytes,
    );
  }
}

class PayslipController extends StateNotifier<PayslipState> {
  final PayslipRepository _repository;
  final Ref _ref;

  PayslipController(this._repository, this._ref)
    : super(
        const PayslipState(
          selectedMonth: 'August',
          selectedYear: '2026-2027',
          availableMonths: [],
          availableYears: [],
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    final months = await _repository.getAvailableMonths();
    final years = await _repository.getAvailableFinancialYears();
    state = state.copyWith(availableMonths: months, availableYears: years);
  }

  void setMonth(String month) {
    state = state.copyWith(
      selectedMonth: month,
      clearPayslip: true,
      clearError: true,
    );
  }

  void setYear(String year) {
    state = state.copyWith(
      selectedYear: year,
      clearPayslip: true,
      clearError: true,
    );
  }

  /// Complete Payslip Generation: loads employee credentials, calls API, and fetches company details
  Future<bool> generatePayslip() async {
    state = state.copyWith(
      isGenerating: true,
      clearError: true,
      successMessage: null,
    );

    try {
      AuthEntity? user;
      try {
        final authState = _ref.read(authNotifierProvider);
        user = authState.user;
      } catch (_) {
        // Fallback for tests or uninitialized session
      }

      // 1. Concurrently fetch Payslip and Company details
      final results = await Future.wait([
        _repository.generatePayslip(
          month: state.selectedMonth,
          financialYear: state.selectedYear,
          employeeId: user?.empId,
          secure: user?.secure,
          fallbackEmpName: user?.fullName,
          fallbackDesignation: user?.designation,
          fallbackDepartment: user?.department,
        ),
        _repository.getCompanyDetails(empId: user?.empId, secure: user?.secure),
      ]);

      final payslip = results[0] as PayslipEntity?;
      var company = results[1] as CompanyDetailsModel?;

      if (payslip != null &&
          ((payslip.companyName != null && payslip.companyName!.isNotEmpty) ||
              (payslip.companyLogo != null &&
                  payslip.companyLogo!.isNotEmpty))) {
        final compName =
            (payslip.companyName != null &&
                payslip.companyName!.trim().isNotEmpty)
            ? payslip.companyName!.trim()
            : (company?.compName ?? 'MethotX Workforce');

        final compLogo =
            (payslip.companyLogo != null &&
                payslip.companyLogo!.trim().isNotEmpty &&
                payslip.companyLogo!.trim() != 'null')
            ? payslip.companyLogo!.trim()
            : company?.compLogo;

        company = CompanyDetailsModel(
          id: company?.id,
          compName: compName,
          addressLine1: payslip.companyAddress ?? company?.addressLine1,
          compLogo: compLogo,
          gstNo: company?.gstNo,
          compPanNo: company?.compPanNo,
          compPhone: company?.compPhone,
          gstReg: company?.gstReg,
          city: company?.city,
          state: company?.state,
          pin: company?.pin,
        );
      }

      state = state.copyWith(
        payslip: payslip,
        companyDetails: company,
        isGenerating: false,
        successMessage:
            'Payslip for ${state.selectedMonth} generated successfully!',
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.message,
        successMessage: null,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to generate payslip: $e',
        successMessage: null,
      );
      return false;
    }
  }

  /// Generates the enterprise PDF and writes it to device storage
  Future<String?> downloadAndSavePdf() async {
    final payslip = state.payslip;
    if (payslip == null) return null;

    state = state.copyWith(isDownloading: true, clearError: true);

    try {
      // 1. Fetch Company Details (POST /users/company/details) to ensure fresh comp_logo URL
      var company = state.companyDetails;
      try {
        final user = _ref.read(authNotifierProvider).user;
        final fetched = await _repository.getCompanyDetails(
          empId: user?.empId,
          secure: user?.secure,
        );
        if (fetched != null) {
          company = CompanyDetailsModel(
            id: fetched.id ?? company?.id,
            compName: (fetched.compName.isNotEmpty && fetched.compName != 'MethotX Workforce')
                ? fetched.compName
                : (company?.compName ?? fetched.compName),
            addressLine1: fetched.addressLine1 ?? company?.addressLine1,
            compLogo: fetched.compLogo ?? company?.compLogo,
            gstNo: fetched.gstNo ?? company?.gstNo,
            compPanNo: fetched.compPanNo ?? company?.compPanNo,
            compPhone: fetched.compPhone ?? company?.compPhone,
            gstReg: fetched.gstReg ?? company?.gstReg,
            city: fetched.city ?? company?.city,
            state: fetched.state ?? company?.state,
            pin: fetched.pin ?? company?.pin,
          );
          state = state.copyWith(companyDetails: company);
        }
      } catch (_) {}

      // 1. Generate PDF bytes
      final user = _ref.read(authNotifierProvider).user;
      final pdfBytes = await PayslipPdfService.generatePayslipPdf(
        payslip: payslip,
        company: company,
        authToken: user?.token,
      );

      // 2. Save locally
      final filePath = await PayslipPdfService.savePdfToFile(
        bytes: pdfBytes,
        employeeId: payslip.employeeCode,
        month: payslip.month,
        financialYear: payslip.financialYear,
      );

      state = state.copyWith(
        isDownloading: false,
        lastDownloadedFilePath: filePath,
        lastGeneratedPdfBytes: pdfBytes,
        successMessage: 'Payslip PDF saved to device.',
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        errorMessage: 'Failed to download PDF: $e',
      );
      return null;
    }
  }
}

final payslipControllerProvider =
    StateNotifierProvider<PayslipController, PayslipState>((ref) {
      final repository = ref.watch(payslipRepositoryProvider);
      return PayslipController(repository, ref);
    });
