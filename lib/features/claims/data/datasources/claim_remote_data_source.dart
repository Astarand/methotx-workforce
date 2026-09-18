import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/claim_model.dart';

abstract class ClaimRemoteDataSource {
  Future<List<ClaimModel>> getClaimList({
    required String empId,
    required String secure,
  });

  Future<ClaimModel> getClaimDetails({
    required String empId,
    required String claimId,
    required String secure,
  });

  Future<void> submitClaim({
    required String empId,
    required String secure,
    required DateTime date,
    required String category,
    required double claimAmount,
    required String details,
    required String paymentMethod,
    String? comments,
    File? receipt,
  });
}

class ClaimRemoteDataSourceImpl implements ClaimRemoteDataSource {
  final DioClient dioClient;

  ClaimRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<ClaimModel>> getClaimList({
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.claimList,
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
          message: raw['message']?.toString() ?? 'Failed to fetch claims list',
          statusCode: response.statusCode ?? 400,
        );
      }

      final data = raw['data'];
      if (data is List) {
        listData = data;
      } else if (data is Map<String, dynamic>) {
        if (data['claims'] is List) {
          listData = data['claims'] as List;
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
        .map((item) => ClaimModel.fromJson(item))
        .toList();
  }

  @override
  Future<ClaimModel> getClaimDetails({
    required String empId,
    required String claimId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.claimDetails,
      data: {
        'employee_id': empId,
        'empId': empId,
        'claim_id': claimId,
        'secure': secure,
      },
    );

    final raw = response.data;
    Map<String, dynamic>? claimMap;

    if (raw is Map<String, dynamic>) {
      final success = raw['success'] == true ||
          raw['status'] == 'success' ||
          raw['status'] == 1 ||
          raw['status'] == true;

      if (!success && raw.containsKey('message') && raw['data'] == null) {
        throw ServerException(
          message: raw['message']?.toString() ?? 'Failed to fetch claim details',
          statusCode: response.statusCode ?? 400,
        );
      }

      if (raw['data'] is Map<String, dynamic>) {
        claimMap = raw['data'] as Map<String, dynamic>;
      } else {
        claimMap = raw;
      }
    }

    if (claimMap == null) {
      throw ServerException(
        message: 'No details found for claim $claimId',
        statusCode: response.statusCode ?? 404,
      );
    }

    return ClaimModel.fromJson(claimMap);
  }

  @override
  Future<void> submitClaim({
    required String empId,
    required String secure,
    required DateTime date,
    required String category,
    required double claimAmount,
    required String details,
    required String paymentMethod,
    String? comments,
    File? receipt,
  }) async {
    final map = <String, dynamic>{
      'employee_id': empId,
      'empId': empId,
      'secure': secure,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'category': category,
      'claim_amount': claimAmount,
      'amount': claimAmount,
      'details': details,
      'payment_method': paymentMethod,
    };

    if (comments != null && comments.trim().isNotEmpty) {
      map['comments'] = comments.trim();
    }

    if (receipt != null) {
      final fileName = receipt.path.split(Platform.pathSeparator).last;
      final ext = fileName.split('.').last.toLowerCase();
      MediaType contentType;
      if (ext == 'pdf') {
        contentType = MediaType('application', 'pdf');
      } else if (ext == 'png') {
        contentType = MediaType('image', 'png');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      map['receipt'] = await MultipartFile.fromFile(
        receipt.path,
        filename: fileName,
        contentType: contentType,
      );
    }

    final formData = FormData.fromMap(map);

    final response = await dioClient.post(
      ApiEndpoints.submitClaim,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final success = raw['success'] == true ||
          raw['status'] == 'success' ||
          raw['status'] == 1 ||
          raw['status'] == true;

      if (!success) {
        throw ServerException(
          message: raw['message']?.toString() ?? 'Failed to submit claim',
          statusCode: response.statusCode ?? 400,
        );
      }
    }
  }
}

final claimRemoteDataSourceProvider = Provider<ClaimRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ClaimRemoteDataSourceImpl(dioClient: dioClient);
});
