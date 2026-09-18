import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/attendance_model.dart';
import '../models/policy_model.dart';

abstract class AttendanceRemoteDataSource {
  Future<AttendanceModel> fetchEmployeeDetails({
    required String empId,
    required String todayDate,
    required String secure,
  });

  Future<AttendanceModel> punchInApi({
    required String todayDate,
    required String punchInTime,
    required String empId,
    required String secure,
    required double punchInLat,
    required double punchInLong,
    required String workLocationStatus,
  });

  Future<AttendanceModel> punchOutApi({
    required String todayDate,
    required String punchOutTime,
    required String empId,
    required String secure,
    double? punchOutLat,
    double? punchOutLong,
  });

  Future<AttendanceModel> lunchInApi({
    required String todayDate,
    required String lunchInTime,
    required String empId,
    required String secure,
  });

  Future<AttendanceModel> lunchOutApi({
    required String todayDate,
    required String lunchOutTime,
    required String empId,
    required String secure,
  });

  Future<AttendanceModel> breakInApi({
    required String breakDate,
    required String breakInTime,
    required String empId,
    required String secure,
  });

  Future<AttendanceModel> breakOutApi({
    required String breakDate,
    required String breakOutTime,
    required String empId,
    required String secure,
  });

  Future<PolicyCheckResult> checkPoliciesApi({
    required String employeeId,
    required String secure,
  });

  Future<AttendanceModel> getDailyActivityApi({
    required String empId,
    required String date,
    required String secure,
  });

  Future<Map<String, dynamic>> getRangeSummaryApi({
    required String empId,
    required String fromDate,
    required String toDate,
    required String secure,
  });

  Future<List<Map<String, dynamic>>> fetchCompanyHolidaysApi({
    required String empId,
    required String year,
    required String secure,
  });

  // Legacy signatures for backward compatibility
  Future<AttendanceModel> getTodayAttendance();

  Future<AttendanceModel> punchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceModel> punchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceModel> lunchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceModel> lunchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceModel> breakIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });

  Future<AttendanceModel> breakOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final DioClient dioClient;

  AttendanceRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<AttendanceModel> fetchEmployeeDetails({
    required String empId,
    required String todayDate,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.employeeDetails,
      data: {
        'empId': empId,
        'today_date': todayDate,
        'todayDate': todayDate,
        'date': todayDate,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel();
  }

  @override
  Future<AttendanceModel> punchInApi({
    required String todayDate,
    required String punchInTime,
    required String empId,
    required String secure,
    required double punchInLat,
    required double punchInLong,
    required String workLocationStatus,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.punchIn,
      data: {
        'todayDate': todayDate,
        'today_date': todayDate,
        'date': todayDate,
        'punchInTime': punchInTime,
        'punch_in_time': punchInTime,
        'punch_in': punchInTime,
        'inTime': punchInTime,
        'in_time': punchInTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
        'punchInLat': punchInLat,
        'punch_in_lat': punchInLat,
        'latitude': punchInLat,
        'lat': punchInLat,
        'punchInLong': punchInLong,
        'punch_in_long': punchInLong,
        'longitude': punchInLong,
        'long': punchInLong,
        'work_location_status': workLocationStatus,
        'workLocationStatus': workLocationStatus,
        'locale': 'en',
        'lang': 'en',
        'language': 'en',
      },
    );

    _checkBusinessResponse(response.data, response.statusCode);

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: todayDate,
      punchInTime: punchInTime,
      punchInLat: punchInLat,
      punchInLong: punchInLong,
      todayWorkingStatus: 'present',
      workLocationStatus: workLocationStatus,
    );
  }

  @override
  Future<AttendanceModel> punchOutApi({
    required String todayDate,
    required String punchOutTime,
    required String empId,
    required String secure,
    double? punchOutLat,
    double? punchOutLong,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.punchOut,
      data: {
        'todayDate': todayDate,
        'today_date': todayDate,
        'date': todayDate,
        'punchOutTime': punchOutTime,
        'punch_out_time': punchOutTime,
        'punch_out': punchOutTime,
        'outTime': punchOutTime,
        'out_time': punchOutTime,
        'time': punchOutTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
        if (punchOutLat != null) ...{
          'punchOutLat': punchOutLat,
          'punch_out_lat': punchOutLat,
          'latitude': punchOutLat,
          'lat': punchOutLat,
        },
        if (punchOutLong != null) ...{
          'punchOutLong': punchOutLong,
          'punch_out_long': punchOutLong,
          'longitude': punchOutLong,
          'long': punchOutLong,
        },
        'locale': 'en',
        'lang': 'en',
        'language': 'en',
      },
    );

    _checkBusinessResponse(response.data, response.statusCode);

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: todayDate,
      punchOutTime: punchOutTime,
      todayWorkingStatus: 'punch_out',
    );
  }

  @override
  Future<AttendanceModel> lunchInApi({
    required String todayDate,
    required String lunchInTime,
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.lunchIn,
      data: {
        'todayDate': todayDate,
        'today_date': todayDate,
        'date': todayDate,
        'lunchInTime': lunchInTime,
        'lunch_in_time': lunchInTime,
        'lunch_in': lunchInTime,
        'inTime': lunchInTime,
        'in_time': lunchInTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
      },
    );

    _checkBusinessResponse(response.data, response.statusCode);

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: todayDate,
      lunchInTime: lunchInTime,
      lunchStatus: 'ongoing',
      todayWorkingStatus: 'present',
    );
  }

  void _checkBusinessResponse(dynamic data, int? statusCode) {
    if (data is Map<String, dynamic>) {
      final status = data['status'];
      final success = data['success'];
      final isFailed = status == false ||
          success == false ||
          status == 'error' ||
          status == 'failed' ||
          status == 0;

      if (isFailed && data.containsKey('message') && data['data'] == null) {
        final msg = data['message']?.toString() ?? 'Attendance action failed on server.';
        throw BadRequestException(message: msg, statusCode: statusCode);
      }
    }
  }

  @override
  Future<AttendanceModel> lunchOutApi({
    required String todayDate,
    required String lunchOutTime,
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.lunchOut,
      data: {
        'todayDate': todayDate,
        'today_date': todayDate,
        'date': todayDate,
        'lunchOutTime': lunchOutTime,
        'lunch_out_time': lunchOutTime,
        'lunch_out': lunchOutTime,
        'outTime': lunchOutTime,
        'out_time': lunchOutTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
      },
    );

    _checkBusinessResponse(response.data, response.statusCode);

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: todayDate,
      lunchOutTime: lunchOutTime,
      lunchStatus: 'complete',
      todayWorkingStatus: 'present',
    );
  }

  @override
  Future<AttendanceModel> breakInApi({
    required String breakDate,
    required String breakInTime,
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.breakIn,
      data: {
        'break_date': breakDate,
        'breakDate': breakDate,
        'todayDate': breakDate,
        'today_date': breakDate,
        'date': breakDate,
        'break_in': breakInTime,
        'breakInTime': breakInTime,
        'inTime': breakInTime,
        'in_time': breakInTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: breakDate,
      breakInTime: breakInTime,
      breakStatus: 'ongoing',
      todayWorkingStatus: 'present',
    );
  }

  @override
  Future<AttendanceModel> breakOutApi({
    required String breakDate,
    required String breakOutTime,
    required String empId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.breakOut,
      data: {
        'break_date': breakDate,
        'breakDate': breakDate,
        'todayDate': breakDate,
        'today_date': breakDate,
        'date': breakDate,
        'break_out': breakOutTime,
        'breakOutTime': breakOutTime,
        'outTime': breakOutTime,
        'out_time': breakOutTime,
        'empId': empId,
        'employee_id': empId,
        'emp_id': empId,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel(
      todayDate: breakDate,
      breakOutTime: breakOutTime,
      breakStatus: 'complete',
      todayWorkingStatus: 'present',
    );
  }

  @override
  Future<PolicyCheckResult> checkPoliciesApi({
    required String employeeId,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.policyList,
      data: {
        'employeeId': employeeId,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return PolicyCheckResult.fromJson(response.data as Map<String, dynamic>);
    }
    return const PolicyCheckResult(
      privacyPolicyRead: true,
      termsAndConditionsRead: true,
      unreadPolicies: [],
    );
  }

  @override
  Future<AttendanceModel> getDailyActivityApi({
    required String empId,
    required String date,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.dailyActivity,
      data: {
        'empId': empId,
        'date': date,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return AttendanceModel();
  }

  @override
  Future<Map<String, dynamic>> getRangeSummaryApi({
    required String empId,
    required String fromDate,
    required String toDate,
    required String secure,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.attendanceSummary,
      data: {
        'empId': empId,
        'from_date': fromDate,
        'to_date': toDate,
        'secure': secure,
      },
    );

    if (response.data is Map<String, dynamic>) {
      final res = response.data as Map<String, dynamic>;
      if (res['data'] is Map<String, dynamic>) {
        return res['data'] as Map<String, dynamic>;
      }
      return res;
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCompanyHolidaysApi({
    required String empId,
    required String year,
    required String secure,
  }) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.companyHolidays,
        data: {
          'empId': empId,
          'employeeId': empId,
          'year': year,
          'secure': secure,
        },
      );

      final data = response.data;
      List<dynamic> rawList = [];

      if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          rawList = data['data'] as List;
        } else if (data['holidays'] is List) {
          rawList = data['holidays'] as List;
        } else if (data['holiday_list'] is List) {
          rawList = data['holiday_list'] as List;
        } else if (data['data'] is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>;
          rawList = (inner['holidays'] ?? inner['holiday_list'] ?? inner['data'] ?? []) as List;
        }
      } else if (data is List) {
        rawList = data;
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => {
                'id': item['id'],
                'name': item['holidayName'] ?? item['holiday_name'] ?? item['name'] ?? 'Company Holiday',
                'date': item['holidayDate'] ?? item['holiday_date'] ?? item['date'] ?? '',
                'type': item['holidayType'] ?? item['holiday_type'] ?? item['type'] ?? 'Company',
                'description': item['holidayDescription'] ?? item['holiday_description'] ?? item['description'] ?? '',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Backward compatibility legacy methods
  @override
  Future<AttendanceModel> getTodayAttendance() async {
    throw UnimplementedError('Use fetchEmployeeDetails() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> punchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use punchInApi() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> punchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use punchOutApi() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> lunchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use lunchInApi() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> lunchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use lunchOutApi() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> breakIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use breakInApi() with explicit empId and secure parameters instead.');
  }

  @override
  Future<AttendanceModel> breakOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    throw UnimplementedError('Use breakOutApi() with explicit empId and secure parameters instead.');
  }
}

final attendanceRemoteDataSourceProvider =
    Provider<AttendanceRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AttendanceRemoteDataSourceImpl(dioClient: dioClient);
});
