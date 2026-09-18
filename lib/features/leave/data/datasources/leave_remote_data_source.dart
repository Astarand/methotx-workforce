import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/models/leave_model.dart';

class LeaveListResult {
  final List<LeaveApplicationModel> leaves;
  final LeaveSummaryModel summary;

  const LeaveListResult({
    required this.leaves,
    required this.summary,
  });
}

abstract class LeaveRemoteDataSource {
  Future<LeaveListResult> getListOfLeave({
    required String empId,
    required String secure,
  });

  Future<LeaveApplicationModel> applyLeave({
    required String empId,
    required String secure,
    required String fromDate,
    required String toDate,
    required String reason,
    required String leaveType,
  });

  Future<LeaveApplicationModel> getLeaveDetails({
    required String empId,
    required String secure,
    required String leaveId,
  });
}

class LeaveRemoteDataSourceImpl implements LeaveRemoteDataSource {
  final DioClient dioClient;

  LeaveRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<LeaveListResult> getListOfLeave({
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.listOfLeave,
      data: {
        'empId': empId,
        'secure': secure,
      },
    );

    final dynamic raw = response.data;
    Map<String, dynamic>? dataMap;
    List<dynamic>? listData;

    if (raw is Map<String, dynamic>) {
      final d = raw['data'];
      if (d is List) {
        listData = d;
      } else if (d is Map<String, dynamic>) {
        dataMap = d;
        if (d['leaves'] is List) {
          listData = d['leaves'] as List;
        } else if (d['list'] is List) {
          listData = d['list'] as List;
        }
      }
    } else if (raw is List) {
      listData = raw;
    }

    final leaves = (listData ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => LeaveApplicationModel.fromJson(item))
        .toList();

    LeaveSummaryModel summary;
    if (dataMap != null && dataMap['summary'] is Map<String, dynamic>) {
      summary = LeaveSummaryModel.fromJson(dataMap['summary'] as Map<String, dynamic>);
    } else {
      summary = LeaveSummaryModel.fromLeaves(leaves.map((m) => m.toEntity()).toList());
    }

    return LeaveListResult(leaves: leaves, summary: summary);
  }

  @override
  Future<LeaveApplicationModel> applyLeave({
    required String empId,
    required String secure,
    required String fromDate,
    required String toDate,
    required String reason,
    required String leaveType,
  }) async {
    final payload = {
      'empId': empId,
      'fromDate': fromDate,
      'toDate': toDate,
      'reason': reason,
      'leaveType': leaveType.trim().toLowerCase(),
      'secure': secure,
    };

    try {
      final response = await dioClient.post(
        ApiEndpoints.applyLeave,
        data: payload,
      );

      if (response.data is Map<String, dynamic>) {
        final resMap = response.data as Map<String, dynamic>;
        if (resMap['success'] == false) {
          final errorCode = resMap['error_code'] ?? resMap['errorCode'];
          final msg = resMap['message']?.toString() ?? 'Failed to apply leave';
          if (errorCode == 'LEAVE_OVERLAP' || msg.toLowerCase().contains('already exists')) {
            throw const ValidationException(
              message: 'You have already applied for leave on the selected dates. Please choose different dates or cancel your previous leave request.',
              statusCode: 422,
            );
          }
          throw ValidationException(message: msg, statusCode: 422);
        }
      }

      Map<String, dynamic>? data;
      if (response.data is Map<String, dynamic>) {
        final res = response.data as Map<String, dynamic>;
        if (res['data'] is Map<String, dynamic>) {
          data = res['data'] as Map<String, dynamic>;
        }
      }

      final id = data?['id']?.toString() ??
          data?['leave_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final statusStr = data?['status']?.toString() ?? 'pending';

      final start = DateTime.tryParse(fromDate) ?? DateTime.now();
      final end = DateTime.tryParse(toDate) ?? start;
      final days = end.difference(start).inDays + 1;

      return LeaveApplicationModel(
        id: id,
        employeeId: empId,
        type: LeaveType.fromString(leaveType),
        startDate: start,
        endDate: end,
        numberOfDays: days > 0 ? days : 1,
        reason: reason,
        status: LeaveStatus.fromString(statusStr),
        appliedOn: DateTime.now(),
      );
    } on ValidationException catch (e) {
      final details = e.details;
      if (details is Map) {
        final errorCode = details['error_code'] ?? details['errorCode'];
        final msg = details['message']?.toString().toLowerCase() ?? '';
        if (errorCode == 'LEAVE_OVERLAP' || msg.contains('already exists')) {
          throw ValidationException(
            message: 'You have already applied for leave on the selected dates. Please choose different dates or cancel your previous leave request.',
            statusCode: 422,
            details: details,
          );
        }

      }
      rethrow;
    }
  }

  @override
  Future<LeaveApplicationModel> getLeaveDetails({
    required String empId,
    required String secure,
    required String leaveId,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.leaveDetails,
      data: {
        'empId': empId,
        'leaveId': leaveId,
        'secure': secure,
      },
    );

    final res = response.data;
    if (res is Map<String, dynamic>) {
      if (res['data'] is Map<String, dynamic>) {
        return LeaveApplicationModel.fromJson(res['data'] as Map<String, dynamic>);
      }
      return LeaveApplicationModel.fromJson(res);
    }
    throw const UnknownApiException(message: 'Invalid response format for leave details');
  }
}

final leaveRemoteDataSourceProvider = Provider<LeaveRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return LeaveRemoteDataSourceImpl(dioClient: dioClient);
});
