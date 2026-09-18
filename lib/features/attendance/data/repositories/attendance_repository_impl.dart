import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/policy_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remoteDataSource;
  final StorageService storageService;

  static const String _cachedAttendanceKey = 'cached_today_attendance';
  static const String _offlineOutboxKey = 'offline_attendance_outbox';

  AttendanceRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  bool _isNetworkError(Object e) {
    return e is NetworkConnectionException || e is ApiTimeoutException;
  }

  @override
  Future<AttendanceEntity> fetchEmployeeDetails({
    required String empId,
    required String todayDate,
    required String secure,
  }) async {
    try {
      final model = await remoteDataSource.fetchEmployeeDetails(
        empId: empId,
        todayDate: todayDate,
        secure: secure,
      );
      final entity = model.toEntity();
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await _getCachedAttendance();
        if (cached != null) return cached;
        return const AttendanceEntity();
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> punchInWithParams({
    required String todayDate,
    required String punchInTime,
    required String empId,
    required String secure,
    required double punchInLat,
    required double punchInLong,
    required String workLocationStatus,
  }) async {
    try {
      final model = await remoteDataSource.punchInApi(
        todayDate: todayDate,
        punchInTime: punchInTime,
        empId: empId,
        secure: secure,
        punchInLat: punchInLat,
        punchInLong: punchInLong,
        workLocationStatus: workLocationStatus,
      );
      final entity = model.toEntity();
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('punchIn', {
          'todayDate': todayDate,
          'punchInTime': punchInTime,
          'empId': empId,
          'secure': secure,
          'punchInLat': punchInLat,
          'punchInLong': punchInLong,
          'work_location_status': workLocationStatus,
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          todayWorkingStatus: 'present',
          punchInLat: punchInLat,
          punchInLong: punchInLong,
          workLocationStatus: workLocationStatus,
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> punchOutWithParams({
    required String empId,
    double? punchOutLat,
    double? punchOutLong,
    required String punchOutTime,
    required String secure,
    required String todayDate,
  }) async {
    try {
      final model = await remoteDataSource.punchOutApi(
        todayDate: todayDate,
        punchOutTime: punchOutTime,
        empId: empId,
        secure: secure,
        punchOutLat: punchOutLat,
        punchOutLong: punchOutLong,
      );
      final entity = model.toEntity();
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('punchOut', {
          'todayDate': todayDate,
          'punchOutTime': punchOutTime,
          'empId': empId,
          'secure': secure,
          if (punchOutLat != null) ...{
            'punchOutLat': punchOutLat,
            'punchOutLong': punchOutLong,
          },
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          todayWorkingStatus: 'punch_out',
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> lunchInWithParams({
    required String todayDate,
    required String lunchInTime,
    required String empId,
    required String secure,
  }) async {
    try {
      await remoteDataSource.lunchInApi(
        todayDate: todayDate,
        lunchInTime: lunchInTime,
        empId: empId,
        secure: secure,
      );
      final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
      final entity = current.copyWith(
        lunchStatus: 'ongoing',
        lunchInTime: DateTime.now(),
      );
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('lunchIn', {
          'todayDate': todayDate,
          'lunchInTime': lunchInTime,
          'empId': empId,
          'secure': secure,
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          lunchStatus: 'ongoing',
          lunchInTime: DateTime.now(),
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> lunchOutWithParams({
    required String todayDate,
    required String lunchOutTime,
    required String empId,
    required String secure,
  }) async {
    try {
      await remoteDataSource.lunchOutApi(
        todayDate: todayDate,
        lunchOutTime: lunchOutTime,
        empId: empId,
        secure: secure,
      );
      final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
      final entity = current.copyWith(
        lunchStatus: 'complete',
        lunchOutTime: DateTime.now(),
      );
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('lunchOut', {
          'todayDate': todayDate,
          'lunchOutTime': lunchOutTime,
          'empId': empId,
          'secure': secure,
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          lunchStatus: 'complete',
          lunchOutTime: DateTime.now(),
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> breakInWithParams({
    required String breakDate,
    required String breakInTime,
    required String empId,
    required String secure,
  }) async {
    try {
      await remoteDataSource.breakInApi(
        breakDate: breakDate,
        breakInTime: breakInTime,
        empId: empId,
        secure: secure,
      );
      final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
      final entity = current.copyWith(
        breakStatus: 'ongoing',
        breakInTime: DateTime.now(),
      );
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('breakIn', {
          'break_date': breakDate,
          'break_in': breakInTime,
          'empId': empId,
          'secure': secure,
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          breakStatus: 'ongoing',
          breakInTime: DateTime.now(),
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<AttendanceEntity> breakOutWithParams({
    required String breakDate,
    required String breakOutTime,
    required String empId,
    required String secure,
  }) async {
    try {
      await remoteDataSource.breakOutApi(
        breakDate: breakDate,
        breakOutTime: breakOutTime,
        empId: empId,
        secure: secure,
      );
      final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
      final entity = current.copyWith(
        breakStatus: 'complete',
        breakOutTime: DateTime.now(),
      );
      await _cacheAttendance(entity);
      return entity;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineAction('breakOut', {
          'break_date': breakDate,
          'breakOutTime': breakOutTime,
          'empId': empId,
          'secure': secure,
        });
        final current = (await _getCachedAttendance()) ?? const AttendanceEntity();
        final updated = current.copyWith(
          breakStatus: 'complete',
          breakOutTime: DateTime.now(),
        );
        await _cacheAttendance(updated);
        return updated;
      }
      rethrow;
    }
  }

  @override
  Future<PolicyCheckResult> checkPolicies({
    required String employeeId,
    required String secure,
  }) async {
    try {
      return await remoteDataSource.checkPoliciesApi(
        employeeId: employeeId,
        secure: secure,
      );
    } catch (_) {
      return const PolicyCheckResult(
        privacyPolicyRead: true,
        termsAndConditionsRead: true,
        unreadPolicies: [],
      );
    }
  }

  @override
  Future<AttendanceEntity> getDailyActivity({
    required String empId,
    required String date,
    required String secure,
  }) async {
    try {
      final model = await remoteDataSource.getDailyActivityApi(
        empId: empId,
        date: date,
        secure: secure,
      );
      return model.toEntity();
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await _getCachedAttendance();
        if (cached != null) return cached;
      }
      return const AttendanceEntity();
    }
  }

  Future<String> _getEmpId() async {
    return (await storageService.getSecure(ApiConstants.storageEmpIdKey)) ??
        (await storageService.getString(ApiConstants.storageEmpIdKey)) ??
        '';
  }

  Future<String> _getSecureKey() async {
    return (await storageService.getSecure(ApiConstants.storageSecureKey)) ??
        (await storageService.getString(ApiConstants.storageSecureKey)) ??
        '';
  }

  // Legacy fallback implementation methods
  @override
  Future<AttendanceEntity> getTodayAttendance() async {
    final cached = await _getCachedAttendance();
    if (cached != null) return cached;
    return const AttendanceEntity();
  }

  @override
  Future<AttendanceEntity> punchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return punchInWithParams(
      todayDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      punchInTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
      punchInLat: latitude,
      punchInLong: longitude,
      workLocationStatus: 'WFO',
    );
  }

  @override
  Future<AttendanceEntity> punchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return punchOutWithParams(
      todayDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      punchOutTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
      punchOutLat: latitude,
      punchOutLong: longitude,
    );
  }

  @override
  Future<AttendanceEntity> lunchIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return lunchInWithParams(
      todayDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      lunchInTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
    );
  }

  @override
  Future<AttendanceEntity> lunchOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return lunchOutWithParams(
      todayDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      lunchOutTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
    );
  }

  @override
  Future<AttendanceEntity> breakIn({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return breakInWithParams(
      breakDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      breakInTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
    );
  }

  @override
  Future<AttendanceEntity> breakOut({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecureKey();
    final now = timestamp ?? DateTime.now();
    return breakOutWithParams(
      breakDate: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      breakOutTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      empId: empId,
      secure: secure,
    );
  }

  // Offline queue methods
  Future<void> _queueOfflineAction(String action, Map<String, dynamic> data) async {
    final existingStr = await storageService.getString(_offlineOutboxKey);
    List<dynamic> list = [];
    if (existingStr != null && existingStr.isNotEmpty) {
      try {
        list = jsonDecode(existingStr) as List<dynamic>;
      } catch (_) {}
    }
    list.add({
      'action': action,
      'payload': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await storageService.saveString(_offlineOutboxKey, jsonEncode(list));
  }

  @override
  Future<int> syncOfflineOutbox() async {
    final rawOutbox = await storageService.getString(_offlineOutboxKey);
    if (rawOutbox == null || rawOutbox.isEmpty) {
      return 0;
    }

    List<dynamic> queue;
    try {
      queue = jsonDecode(rawOutbox) as List<dynamic>;
    } catch (_) {
      await storageService.remove(_offlineOutboxKey);
      return 0;
    }

    if (queue.isEmpty) return 0;

    int syncedCount = 0;
    final List<dynamic> unhandledQueue = List.from(queue);

    for (final item in queue) {
      if (item is! Map<String, dynamic>) {
        unhandledQueue.remove(item);
        continue;
      }

      final action = item['action'] as String?;
      final payload = (item['payload'] as Map?)?.cast<String, dynamic>() ?? {};

      try {
        switch (action) {
          case 'punchIn':
            await remoteDataSource.punchInApi(
              todayDate: payload['todayDate'] as String? ?? '',
              punchInTime: payload['punchInTime'] as String? ?? '',
              empId: payload['empId'] as String? ?? '',
              secure: payload['secure'] as String? ?? '',
              punchInLat: (payload['punchInLat'] as num?)?.toDouble() ?? 0.0,
              punchInLong: (payload['punchInLong'] as num?)?.toDouble() ?? 0.0,
              workLocationStatus: payload['workLocationStatus'] as String? ?? 'WFO',
            );
            break;
          case 'punchOut':
            await remoteDataSource.punchOutApi(
              todayDate: payload['todayDate'] as String? ?? '',
              punchOutTime: payload['punchOutTime'] as String? ?? '',
              empId: payload['empId'] as String? ?? '',
              secure: payload['secure'] as String? ?? '',
              punchOutLat: (payload['punchOutLat'] as num?)?.toDouble(),
              punchOutLong: (payload['punchOutLong'] as num?)?.toDouble(),
            );
            break;
          case 'lunchIn':
            await remoteDataSource.lunchInApi(
              todayDate: payload['todayDate'] as String? ?? '',
              lunchInTime: payload['lunchInTime'] as String? ?? '',
              empId: payload['empId'] as String? ?? '',
              secure: payload['secure'] as String? ?? '',
            );
            break;
          case 'lunchOut':
            await remoteDataSource.lunchOutApi(
              todayDate: payload['todayDate'] as String? ?? '',
              lunchOutTime: payload['lunchOutTime'] as String? ?? '',
              empId: payload['empId'] as String? ?? '',
              secure: payload['secure'] as String? ?? '',
            );
            break;
          case 'breakIn':
            await remoteDataSource.breakInApi(
              breakDate: (payload['breakDate'] ?? payload['break_date']) as String? ?? '',
              breakInTime: (payload['breakInTime'] ?? payload['break_in']) as String? ?? '',
              empId: (payload['empId'] ?? payload['emp_id']) as String? ?? '',
              secure: payload['secure'] as String? ?? '',
            );
            break;
          case 'breakOut':
            await remoteDataSource.breakOutApi(
              breakDate: (payload['breakDate'] ?? payload['break_date']) as String? ?? '',
              breakOutTime: (payload['breakOutTime'] ?? payload['break_out']) as String? ?? '',
              empId: (payload['empId'] ?? payload['emp_id']) as String? ?? '',
              secure: payload['secure'] as String? ?? '',
            );
            break;
          default:
            break;
        }

        syncedCount++;
        unhandledQueue.remove(item);
      } catch (e) {
        if (_isNetworkError(e)) {
          // Connectivity is still failing, preserve remaining items for the next attempt
          break;
        } else {
          // Business logic or 4xx conflict (e.g. shift already closed or already punched),
          // discard so queue is not permanently poisoned
          unhandledQueue.remove(item);
        }
      }
    }

    if (unhandledQueue.isEmpty) {
      await storageService.remove(_offlineOutboxKey);
    } else {
      await storageService.saveString(_offlineOutboxKey, jsonEncode(unhandledQueue));
    }

    return syncedCount;
  }


  Future<void> _cacheAttendance(AttendanceEntity entity) async {
    final map = {
      'punchInTime': entity.punchInTime?.toIso8601String(),
      'punchOutTime': entity.punchOutTime?.toIso8601String(),
      'punchInLat': entity.punchInLat,
      'punchInLong': entity.punchInLong,
      'lunchInTime': entity.lunchInTime?.toIso8601String(),
      'lunchOutTime': entity.lunchOutTime?.toIso8601String(),
      'breakInTime': entity.breakInTime?.toIso8601String(),
      'breakOutTime': entity.breakOutTime?.toIso8601String(),
      'totalBreakMinutes': entity.totalBreakDuration.inMinutes,
      'totalLunchMinutes': entity.totalLunchDuration.inMinutes,
      'todayDate': entity.todayDate,
      'todayWorkingStatus': entity.todayWorkingStatus,
      'lunchStatus': entity.lunchStatus,
      'breakStatus': entity.breakStatus,
      'locationStatus': entity.locationStatus,
      'workLocationStatus': entity.workLocationStatus,
      'todayWorkLocation': entity.todayWorkLocation,
      'officeLat': entity.officeLat,
      'officeLong': entity.officeLong,
      'allowedRadiusMeters': entity.allowedRadiusMeters,
      'privacyPolicyRead': entity.privacyPolicyRead,
      'termsAndConditionsRead': entity.termsAndConditionsRead,
    };
    if (entity.officeLat != 0.0 && entity.officeLong != 0.0) {
      await storageService.saveString('cached_office_lat', entity.officeLat.toString());
      await storageService.saveString('cached_office_long', entity.officeLong.toString());
      await storageService.saveString('cached_office_radius', entity.allowedRadiusMeters.toString());
    }
    await storageService.saveString(_cachedAttendanceKey, jsonEncode(map));
  }

  Future<AttendanceEntity?> _getCachedAttendance() async {
    final jsonStr = await storageService.getString(_cachedAttendanceKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final cachedLatStr = await storageService.getString('cached_office_lat');
      final cachedLongStr = await storageService.getString('cached_office_long');
      final cachedRadiusStr = await storageService.getString('cached_office_radius');

      final fallbackLat = cachedLatStr != null ? double.tryParse(cachedLatStr) : null;
      final fallbackLong = cachedLongStr != null ? double.tryParse(cachedLongStr) : null;
      final fallbackRadius = cachedRadiusStr != null ? double.tryParse(cachedRadiusStr) : null;

      return AttendanceEntity(
        punchInTime: map['punchInTime'] != null
            ? DateTime.tryParse(map['punchInTime'] as String)
            : null,
        punchOutTime: map['punchOutTime'] != null
            ? DateTime.tryParse(map['punchOutTime'] as String)
            : null,
        punchInLat: (map['punchInLat'] as num?)?.toDouble(),
        punchInLong: (map['punchInLong'] as num?)?.toDouble(),
        lunchInTime: map['lunchInTime'] != null
            ? DateTime.tryParse(map['lunchInTime'] as String)
            : null,
        lunchOutTime: map['lunchOutTime'] != null
            ? DateTime.tryParse(map['lunchOutTime'] as String)
            : null,
        breakInTime: map['breakInTime'] != null
            ? DateTime.tryParse(map['breakInTime'] as String)
            : null,
        breakOutTime: map['breakOutTime'] != null
            ? DateTime.tryParse(map['breakOutTime'] as String)
            : null,
        totalBreakDuration:
            Duration(minutes: (map['totalBreakMinutes'] as num?)?.toInt() ?? 0),
        totalLunchDuration:
            Duration(minutes: (map['totalLunchMinutes'] as num?)?.toInt() ?? 0),
        todayDate: map['todayDate'] as String?,
        todayWorkingStatus: map['todayWorkingStatus'] as String? ?? 'not_present',
        lunchStatus: map['lunchStatus'] as String? ?? 'none',
        breakStatus: map['breakStatus'] as String? ?? 'none',
        locationStatus: map['locationStatus'] as String? ?? 'initial',
        workLocationStatus: map['workLocationStatus'] as String? ?? 'WFO',
        todayWorkLocation: map['todayWorkLocation'] as String? ?? 'work_from_office',
        officeLat: (map['officeLat'] as num?)?.toDouble() ?? fallbackLat ?? 0.0,
        officeLong: (map['officeLong'] as num?)?.toDouble() ?? fallbackLong ?? 0.0,
        allowedRadiusMeters: (map['allowedRadiusMeters'] as num?)?.toDouble() ?? fallbackRadius ?? 200.0,
        privacyPolicyRead: map['privacyPolicyRead'] as String? ?? 'read',
        termsAndConditionsRead: map['termsAndConditionsRead'] as String? ?? 'read',
      );
    } catch (_) {
      return null;
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final remoteDataSource = ref.watch(attendanceRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AttendanceRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
