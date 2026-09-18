import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../../payslip/data/models/company_details_model.dart';
import '../../domain/entities/hr_letter_entity.dart';
import '../../domain/repositories/hr_letter_repository.dart';
import '../datasources/hr_letter_remote_data_source.dart';

class HrLetterRepositoryImpl implements HrLetterRepository {
  final HrLetterRemoteDataSource remoteDataSource;
  final StorageService storageService;

  CompanyDetailsModel? _cachedCompanyDetails;
  final Set<String> _readLetterIds = {};

  HrLetterRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  Future<String> _getEmpId() async {
    return await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
        await storageService.getString(ApiConstants.storageEmpIdKey) ??
        '';
  }

  Future<String> _getSecure() async {
    return await storageService.getSecure(ApiConstants.storageSecureKey) ??
        await storageService.getString(ApiConstants.storageSecureKey) ??
        '';
  }

  @override
  Future<List<HrLetterEntity>> getLetterList() async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    // Prefetch company details in parallel/background for instant PDF generation
    _prefetchCompanyDetails(empId, secure);

    final models = await remoteDataSource.getLetterList(
      empId: empId,
      secure: secure,
    );

    // Sort by sentAt descending (latest first)
    models.sort((a, b) => b.sentAt.compareTo(a.sentAt));

    final entities = <HrLetterEntity>[];
    for (int i = 0; i < models.length; i++) {
      final m = models[i];
      // Latest letter is unread by default unless user has tapped it
      final isRead = i == 0 ? _readLetterIds.contains(m.id) : true;
      entities.add(m.toEntity(isRead: isRead));
    }

    return entities;
  }

  @override
  Future<CompanyDetailsModel?> getCompanyDetails() async {
    if (_cachedCompanyDetails != null) {
      return _cachedCompanyDetails;
    }

    final empId = await _getEmpId();
    final secure = await _getSecure();
    if (empId.isEmpty || secure.isEmpty) {
      return const CompanyDetailsModel(compName: 'MethotX Workforce');
    }

    try {
      final details = await remoteDataSource.fetchCompanyDetails(
        empId: empId,
        secure: secure,
      );
      _cachedCompanyDetails = details;
      return details;
    } catch (_) {
      return const CompanyDetailsModel(compName: 'MethotX Workforce');
    }
  }

  @override
  void markLetterAsRead(String letterId) {
    _readLetterIds.add(letterId);
  }

  void _prefetchCompanyDetails(String empId, String secure) {
    if (_cachedCompanyDetails == null) {
      remoteDataSource
          .fetchCompanyDetails(empId: empId, secure: secure)
          .then((details) => _cachedCompanyDetails = details)
          .catchError((_) => const CompanyDetailsModel(compName: 'MethotX Workforce'));
    }
  }
}

final hrLetterRepositoryProvider = Provider<HrLetterRepository>((ref) {
  final remoteDataSource = ref.watch(hrLetterRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return HrLetterRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
