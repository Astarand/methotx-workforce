import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/performance_review_entity.dart';
import '../../domain/repositories/performance_review_repository.dart';
import '../datasources/performance_review_remote_data_source.dart';

class PerformanceReviewRepositoryImpl implements PerformanceReviewRepository {
  final PerformanceReviewRemoteDataSource remoteDataSource;
  final StorageService storageService;

  PerformanceReviewRepositoryImpl({
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
  Future<List<PerformanceReviewEntity>> getReviews() async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final models = await remoteDataSource.getReviewList(
      empId: empId,
      secure: secure,
    );

    // Sort by period descending (newest year & month first)
    models.sort((a, b) {
      if (a.reviewYear != b.reviewYear) {
        return b.reviewYear.compareTo(a.reviewYear);
      }
      if (a.reviewMonth != b.reviewMonth) {
        return b.reviewMonth.compareTo(a.reviewMonth);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return models.map((m) => m.toEntity()).toList();
  }
}

final performanceReviewRepositoryProvider =
    Provider<PerformanceReviewRepository>((ref) {
  final remoteDataSource = ref.watch(performanceReviewRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return PerformanceReviewRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
