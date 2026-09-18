import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> fetchEmployeeDetails({
    required String empId,
    required String secure,
  });

  Future<ProfileModel> fetchEmployeeProfile();

  Future<ProfileModel> updateEmployeeProfile({
    required String name,
    required String email,
    required String contactNumber,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final DioClient dioClient;

  ProfileRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<ProfileModel> fetchEmployeeProfile() async {
    final response = await dioClient.get(ApiEndpoints.employeeProfile);
    if (response.data is Map<String, dynamic>) {
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Failed to parse employee profile response');
  }

  @override
  Future<ProfileModel> updateEmployeeProfile({
    required String name,
    required String email,
    required String contactNumber,
  }) async {
    final payload = {
      'name': name.trim(),
      'email': email.trim(),
      'contact_number': contactNumber.trim(),
    };

    Response response;
    try {
      response = await dioClient.put(
        ApiEndpoints.employeeProfile,
        data: payload,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        response = await dioClient.patch(
          ApiEndpoints.employeeProfile,
          data: payload,
        );
      } else {
        rethrow;
      }
    }

    if (response.data is Map<String, dynamic>) {
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    }

    return ProfileModel(
      id: '0',
      empId: '0',
      employeeCode: '0',
      fullName: name.trim(),
      email: email.trim(),
      phone: contactNumber.trim(),
      designation: '',
      department: '',
      workMode: '',
    );
  }

  @override
  Future<ProfileModel> fetchEmployeeDetails({
    required String empId,
    required String secure,
  }) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Fetch live employee profile (name, email, contact_number) from dedicated profile API
    ProfileModel? mainProfile;
    try {
      mainProfile = await fetchEmployeeProfile();
    } catch (_) {}

    // 2. Fetch Daily Employee Details (Attendance, work location, avatar, designation)
    ProfileModel? dailyProfile;
    try {
      final response = await dioClient.post(
        ApiEndpoints.employeeDetails,
        data: {
          'empId': empId,
          'today_date': todayStr,
          'todayDate': todayStr,
          'date': todayStr,
          'secure': secure,
        },
      );
      if (response.data is Map<String, dynamic>) {
        dailyProfile = ProfileModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    // 3. Combine profiles into a single comprehensive entity
    var combinedEntity = dailyProfile?.toEntity();
    if (mainProfile != null) {
      combinedEntity = combinedEntity != null
          ? combinedEntity.merge(mainProfile.toEntity())
          : mainProfile.toEntity();
    }

    if (combinedEntity != null) {
      return ProfileModel.fromEntity(combinedEntity);
    }

    throw Exception('Failed to fetch employee profile details from server');
  }
}

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProfileRemoteDataSourceImpl(dioClient: dioClient);
});
