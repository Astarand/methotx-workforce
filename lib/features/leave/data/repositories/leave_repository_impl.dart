import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/leave_model.dart';
import '../../domain/entities/leave_entity.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_remote_data_source.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final LeaveRemoteDataSource remoteDataSource;
  final StorageService storageService;

  List<LeaveApplicationEntity> _cachedLeaves = [];
  LeaveSummaryModel _cachedSummary = const LeaveSummaryModel();

  final List<LeaveBalanceEntity> _defaultBalances = const [
    LeaveBalanceEntity(
      type: LeaveType.casual,
      title: 'Casual Leave',
      total: 12,
      used: 0,
      remaining: 12,
    ),
    LeaveBalanceEntity(
      type: LeaveType.sick,
      title: 'Sick Leave',
      total: 8,
      used: 0,
      remaining: 8,
    ),
    LeaveBalanceEntity(
      type: LeaveType.paid,
      title: 'Paid Leave',
      total: 15,
      used: 0,
      remaining: 15,
    ),
  ];

  LeaveRepositoryImpl({
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
  Future<List<LeaveBalanceEntity>> getLeaveBalances() async {
    return _defaultBalances;
  }

  @override
  Future<List<LeaveApplicationEntity>> getAllLeaves() async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    try {
      final result = await remoteDataSource.getListOfLeave(
        empId: empId,
        secure: secure,
      );

      _cachedLeaves = result.leaves.map((m) => m.toEntity()).toList();
      _cachedSummary = result.summary;

      return _cachedLeaves;
    } catch (_) {
      if (_cachedLeaves.isNotEmpty) {
        return _cachedLeaves;
      }
      rethrow;
    }
  }

  @override
  Future<List<LeaveApplicationEntity>> getUpcomingLeaves() async {
    if (_cachedLeaves.isEmpty) {
      await getAllLeaves();
    }
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _cachedLeaves.where((l) {
      final isUpcomingDate = !l.startDate.isBefore(todayStart);
      return isUpcomingDate || l.status == LeaveStatus.pending;
    }).toList();
  }

  @override
  Future<List<LeaveApplicationEntity>> getLeaveHistory() async {
    if (_cachedLeaves.isEmpty) {
      await getAllLeaves();
    }
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _cachedLeaves.where((l) {
      final isPastDate = l.startDate.isBefore(todayStart);
      return isPastDate && l.status != LeaveStatus.pending;
    }).toList();
  }

  @override
  Future<LeaveSummaryModel> getLeaveSummary() async {
    if (_cachedLeaves.isEmpty) {
      try {
        await getAllLeaves();
      } catch (_) {}
    }

    if (_cachedSummary.total == 0 && _cachedLeaves.isNotEmpty) {
      _cachedSummary = LeaveSummaryModel.fromLeaves(_cachedLeaves);
    }

    return _cachedSummary;
  }

  @override
  Future<LeaveApplicationEntity> getLeaveDetails(String leaveId) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    try {
      final model = await remoteDataSource.getLeaveDetails(
        empId: empId,
        secure: secure,
        leaveId: leaveId,
      );
      final entity = model.toEntity();

      // Update in cache if found
      final index = _cachedLeaves.indexWhere((l) => l.id == leaveId);
      if (index >= 0) {
        _cachedLeaves[index] = entity;
      }

      return entity;
    } catch (_) {
      final cachedMatch = _cachedLeaves.firstWhere(
        (l) => l.id == leaveId,
        orElse: () => throw const NotFoundException(
          message: 'Leave details could not be retrieved.',
          statusCode: 404,
        ),
      );
      return cachedMatch;
    }
  }

  @override
  Future<LeaveApplicationEntity> applyLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final fromDate = DateFormat('yyyy-MM-dd').format(startDate);
    final toDate = DateFormat('yyyy-MM-dd').format(endDate);

    final model = await remoteDataSource.applyLeave(
      empId: empId,
      secure: secure,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      leaveType: type.toApiKey(),
    );

    final entity = model.toEntity();

    // Insert optimistic / created application into cache
    _cachedLeaves.insert(0, entity);
    _cachedSummary = LeaveSummaryModel.fromLeaves(_cachedLeaves);

    return entity;
  }
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  final remoteDataSource = ref.watch(leaveRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return LeaveRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
