import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_toast.dart';
import '../../../authentication/presentation/controllers/auth_notifier.dart';
import '../../../payslip/data/models/company_details_model.dart';
import '../../data/repositories/hr_letter_repository_impl.dart';
import '../../domain/entities/hr_letter_entity.dart';
import '../../domain/repositories/hr_letter_repository.dart';
import '../../services/hr_letter_pdf_service.dart';

class HrLetterState {
  final List<HrLetterEntity> letters;
  final bool isLoading;
  final bool isDownloading;
  final String? errorMessage;
  final String? downloadingLetterId;
  final CompanyDetailsModel? companyDetails;

  const HrLetterState({
    this.letters = const [],
    this.isLoading = false,
    this.isDownloading = false,
    this.errorMessage,
    this.downloadingLetterId,
    this.companyDetails,
  });

  HrLetterState copyWith({
    List<HrLetterEntity>? letters,
    bool? isLoading,
    bool? isDownloading,
    String? errorMessage,
    String? downloadingLetterId,
    CompanyDetailsModel? companyDetails,
  }) {
    return HrLetterState(
      letters: letters ?? this.letters,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      errorMessage: errorMessage,
      downloadingLetterId: downloadingLetterId,
      companyDetails: companyDetails ?? this.companyDetails,
    );
  }

  int get unreadCount => letters.where((l) => !l.isRead).length;
}

class HrLetterController extends StateNotifier<HrLetterState> {
  final HrLetterRepository _repository;
  final Ref _ref;

  HrLetterController(this._repository, this._ref) : super(const HrLetterState()) {
    loadLetters();
  }

  Future<void> loadLetters() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _repository.getLetterList(),
        _repository.getCompanyDetails(),
      ]);

      final letters = results[0] as List<HrLetterEntity>;
      final company = results[1] as CompanyDetailsModel?;

      state = state.copyWith(
        letters: letters,
        companyDetails: company,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      final cleanMsg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: cleanMsg.isNotEmpty
            ? cleanMsg
            : 'Failed to load HR letters',
      );
    }
  }

  void markAsRead(String letterId) {
    _repository.markLetterAsRead(letterId);
    final updated = state.letters.map((l) {
      if (l.id == letterId) {
        return l.copyWith(isRead: true);
      }
      return l;
    }).toList();
    state = state.copyWith(letters: updated);
  }

  Future<void> downloadPdf(BuildContext context, HrLetterEntity letter) async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, downloadingLetterId: letter.id);

    try {
      var company = state.companyDetails;
      company ??= await _repository.getCompanyDetails();

      final authUser = _ref.read(authNotifierProvider).user;
      final bytes = await HrLetterPdfService.generatePdf(
        contentHtml: letter.content,
        subject: letter.subject,
        companyDetails: company,
        sentAt: letter.sentAt,
        letterId: letter.id,
        authToken: authUser?.token,
      );

      final fileName = 'HR_Letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await HrLetterPdfService.saveAndOpenPdf(
        bytes: bytes,
        fileName: fileName,
      );

      state = state.copyWith(isDownloading: false, downloadingLetterId: null);

      if (context.mounted) {
        AppToast.showSuccess(
          context,
          title: 'Download Complete',
          message: 'Letter saved to $path',
        );
      }
    } catch (e) {
      state = state.copyWith(isDownloading: false, downloadingLetterId: null);

      if (context.mounted) {
        AppToast.showError(
          context,
          title: 'Download Failed',
          message:
              'Could not generate or save letter PDF: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> sharePdf(BuildContext context, HrLetterEntity letter) async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, downloadingLetterId: letter.id);

    try {
      var company = state.companyDetails;
      company ??= await _repository.getCompanyDetails();

      final authUser = _ref.read(authNotifierProvider).user;
      final bytes = await HrLetterPdfService.generatePdf(
        contentHtml: letter.content,
        subject: letter.subject,
        companyDetails: company,
        sentAt: letter.sentAt,
        letterId: letter.id,
        authToken: authUser?.token,
      );

      final fileName = 'HR_Letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await HrLetterPdfService.sharePdf(bytes: bytes, fileName: fileName);

      state = state.copyWith(isDownloading: false, downloadingLetterId: null);
    } catch (e) {
      state = state.copyWith(isDownloading: false, downloadingLetterId: null);

      if (context.mounted) {
        AppToast.showError(
          context,
          title: 'Export Failed',
          message: 'Could not share letter PDF.',
        );
      }
    }
  }
}

final hrLetterControllerProvider =
    StateNotifierProvider<HrLetterController, HrLetterState>((ref) {
      final repository = ref.watch(hrLetterRepositoryProvider);
      return HrLetterController(repository, ref);
    });
