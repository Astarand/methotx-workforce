import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/supply_entity.dart';
import '../models/supply_model.dart';

abstract class SupplyRemoteDataSource {
  Future<List<SupplyModel>> getSupplyList({
    required String empId,
    required String secure,
  });

  Future<SupplyModel> getSupplyDetails({
    required String empId,
    required String requisitionId,
    required String secure,
  });

  Future<void> submitSupplyRequisition({
    required String empId,
    required String secure,
    required DateTime date,
    required String category,
    required String details,
    required String quantity,
    required double amount,
    required SupplyPriority priority,
    String? returnExchange,
    String? comments,
    File? attachment,
  });
}

class SupplyRemoteDataSourceImpl implements SupplyRemoteDataSource {
  final DioClient dioClient;

  SupplyRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<SupplyModel>> getSupplyList({
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.supplyList,
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
          message: raw['message']?.toString() ?? 'Failed to fetch supply requisitions',
          statusCode: response.statusCode ?? 400,
        );
      }

      final data = raw['data'];
      if (data is List) {
        listData = data;
      } else if (data is Map<String, dynamic>) {
        if (data['supplies'] is List) {
          listData = data['supplies'] as List;
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
        .map((item) => SupplyModel.fromJson(item))
        .toList();
  }

  @override
  Future<SupplyModel> getSupplyDetails({
    required String empId,
    required String requisitionId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.supplyDetails,
      data: {
        'employee_id': empId,
        'empId': empId,
        'requisition_id': requisitionId,
        'claim_id': requisitionId,
        'secure': secure,
      },
    );

    final raw = response.data;
    Map<String, dynamic>? supplyMap;

    if (raw is Map<String, dynamic>) {
      final success = raw['success'] == true ||
          raw['status'] == 'success' ||
          raw['status'] == 1 ||
          raw['status'] == true;

      if (!success && raw.containsKey('message') && raw['data'] == null) {
        throw ServerException(
          message: raw['message']?.toString() ?? 'Failed to fetch requisition details',
          statusCode: response.statusCode ?? 400,
        );
      }

      if (raw['data'] is Map<String, dynamic>) {
        supplyMap = raw['data'] as Map<String, dynamic>;
      } else {
        supplyMap = raw;
      }
    }

    if (supplyMap == null) {
      throw ServerException(
        message: 'No details found for requisition $requisitionId',
        statusCode: response.statusCode ?? 404,
      );
    }

    return SupplyModel.fromJson(supplyMap);
  }

  @override
  Future<void> submitSupplyRequisition({
    required String empId,
    required String secure,
    required DateTime date,
    required String category,
    required String details,
    required String quantity,
    required double amount,
    required SupplyPriority priority,
    String? returnExchange,
    String? comments,
    File? attachment,
  }) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final map = <String, dynamic>{
      'employee_id': empId,
      'date': formattedDate,
      'category': category,
      'details': details,
      'quantity': quantity,
      'amount': amount,
      'priority': priority.label,
      'secure': secure,
    };

    if (returnExchange != null && returnExchange.trim().isNotEmpty) {
      map['return_exchange'] = returnExchange.trim();
    }

    if (comments != null && comments.trim().isNotEmpty) {
      map['comments'] = comments.trim();
    }

    if (attachment != null) {
      final fileName = attachment.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      MediaType contentType;
      if (ext == 'pdf') {
        contentType = MediaType('application', 'pdf');
      } else if (ext == 'png') {
        contentType = MediaType('image', 'png');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      map['attachment'] = await MultipartFile.fromFile(
        attachment.path,
        filename: fileName,
        contentType: contentType,
      );
    }

    final formData = FormData.fromMap(map);

    final response = await dioClient.post(
      ApiEndpoints.submitSupply,
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
        final message = raw['message']?.toString() ?? 'Failed to submit requisition';
        throw ServerException(
          message: message,
          statusCode: response.statusCode ?? 400,
        );
      }
    }
  }
}

final supplyRemoteDataSourceProvider = Provider<SupplyRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SupplyRemoteDataSourceImpl(dioClient: dioClient);
});
