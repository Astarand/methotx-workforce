import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/performance_review_model.dart';

abstract class PerformanceReviewRemoteDataSource {
  Future<List<PerformanceReviewModel>> getReviewList({
    required String empId,
    required String secure,
  });
}

class PerformanceReviewRemoteDataSourceImpl
    implements PerformanceReviewRemoteDataSource {
  final DioClient dioClient;

  PerformanceReviewRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<PerformanceReviewModel>> getReviewList({
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.performanceReviewList,
      data: {
        'employee_id': empId,
        'empId': empId,
        'secure': secure,
      },
    );

    final raw = response.data;
    List<dynamic>? listData;

    if (raw is Map<String, dynamic>) {
      final success = raw['success'] == true ||
          raw['status'] == 'success' ||
          raw['status'] == 1 ||
          raw['status'] == true;

      if (!success && raw.containsKey('message') && raw['data'] == null) {
        throw ServerException(
          message: raw['message']?.toString() ?? 'Failed to fetch performance reviews',
          statusCode: response.statusCode ?? 400,
        );
      }

      final data = raw['data'];
      if (data is List) {
        listData = data;
      } else if (data is Map<String, dynamic>) {
        if (data['reviews'] is List) {
          listData = data['reviews'] as List;
        } else if (data['list'] is List) {
          listData = data['list'] as List;
        } else if (data['data'] is List) {
          listData = data['data'] as List;
        }
      }
    } else if (raw is List) {
      listData = raw;
    }

    return (listData ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => PerformanceReviewModel.fromJson(item))
        .toList();
  }
}

final performanceReviewRemoteDataSourceProvider =
    Provider<PerformanceReviewRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PerformanceReviewRemoteDataSourceImpl(dioClient: dioClient);
});
