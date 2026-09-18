import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../shared/models/attendance_record_model.dart';
import 'datasources/attendance_remote_data_source.dart';
import 'mock_attendance_repository.dart';

abstract class AttendanceDataRepository {
  Future<MonthlyAttendanceSummary> getMonthlySummary(DateTime month);
  Future<List<AttendanceDayRecord>> getMonthAttendanceRecords(DateTime month);
  Future<AttendanceDayRecord> getDayOverview(DateTime date);
  Future<List<Map<String, dynamic>>> getHolidayList(int year);
}

final attendanceHistoryRepositoryProvider = Provider<AttendanceDataRepository>((ref) {
  final remoteDataSource = ref.watch(attendanceRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return MockAttendanceRepository(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});

