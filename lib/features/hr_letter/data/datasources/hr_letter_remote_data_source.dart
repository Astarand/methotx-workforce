import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../payslip/data/models/company_details_model.dart';
import '../models/hr_letter_model.dart';

abstract class HrLetterRemoteDataSource {
  Future<List<HrLetterModel>> getLetterList({
    required String empId,
    required String secure,
  });

  Future<CompanyDetailsModel> fetchCompanyDetails({
    required String empId,
    required String secure,
  });
}

class HrLetterRemoteDataSourceImpl implements HrLetterRemoteDataSource {
  final DioClient dioClient;

  HrLetterRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<HrLetterModel>> getLetterList({
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.hrLetterList,
      data: {
        'employee_id': empId,
        'empId': empId,
        'secure': secure,
      },
    );

    final raw = response.data;
    List<dynamic>? listData;

    if (raw is Map<String, dynamic>) {
      // Check success flag
      final success = raw['success'] == true ||
          raw['status'] == 'success' ||
          raw['status'] == 1 ||
          raw['status'] == true;

      if (!success && raw.containsKey('message') && raw['data'] == null) {
        throw ServerException(
          message: raw['message']?.toString() ?? 'Failed to fetch HR letters',
          statusCode: response.statusCode ?? 400,
        );
      }

      final data = raw['data'];
      if (data is List) {
        listData = data;
      } else if (data is Map<String, dynamic>) {
        if (data['letters'] is List) {
          listData = data['letters'] as List;
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
        .map((item) => HrLetterModel.fromJson(item))
        .toList();
  }

  @override
  Future<CompanyDetailsModel> fetchCompanyDetails({
    required String empId,
    required String secure,
  }) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.companyDetails,
        data: {
          'empId': empId,
          'employee_id': empId,
          'secure': secure,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return CompanyDetailsModel.fromJson(data);
      }
      return const CompanyDetailsModel(compName: 'MethotX Workforce');
    } catch (_) {
      return const CompanyDetailsModel(compName: 'MethotX Workforce');
    }
  }
}

final hrLetterRemoteDataSourceProvider = Provider<HrLetterRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return HrLetterRemoteDataSourceImpl(dioClient: dioClient);
});
