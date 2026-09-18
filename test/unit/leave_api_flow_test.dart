import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/network/api_constants.dart';
import 'package:methotx_workforce/core/network/api_exceptions.dart';
import 'package:methotx_workforce/core/network/dio_client.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';
import 'package:methotx_workforce/features/leave/data/datasources/leave_remote_data_source.dart';
import 'package:methotx_workforce/features/leave/data/repositories/leave_repository_impl.dart';
import 'package:methotx_workforce/features/leave/domain/entities/leave_entity.dart';
import 'package:methotx_workforce/features/leave/domain/repositories/leave_repository.dart';
import 'package:methotx_workforce/features/leave/presentation/controllers/leave_controller.dart';
import 'package:methotx_workforce/shared/models/leave_model.dart';

class MockStorageService implements StorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> clearSecure() async => _store.clear();

  @override
  Future<void> clearAll() async => _store.clear();

  @override
  Future<void> deleteSecure(String key) async => _store.remove(key);

  @override
  Future<bool?> getBool(String key) async => _store[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _store[key] as int?;

  @override
  Future<String?> getSecure(String key) async => _store[key] as String?;

  @override
  Future<String?> getString(String key) async => _store[key] as String?;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> saveBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> saveInt(String key, int value) async => _store[key] = value;

  @override
  Future<void> saveSecure(String key, String value) async => _store[key] = value;

  @override
  Future<void> saveString(String key, String value) async => _store[key] = value;
}


class FakeDioAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{"success": true}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('1. Leave Model & Summary Parsing Tests', () {
    test('parses direct list item JSON with exact keys from spec', () {
      final json = {
        'id': 101,
        'emp_id': 'EMP001',
        'emp_name': 'John Doe',
        'from_date': '2026-09-10',
        'to_date': '2026-09-12',
        'total_days': 3,
        'leave_type': 'casual',
        'reason': 'Personal work',
        'status': 'pending',
        'created_at': '2026-09-05T10:00:00',
      };

      final model = LeaveApplicationModel.fromJson(json);

      expect(model.id, '101');
      expect(model.employeeId, 'EMP001');
      expect(model.employeeName, 'John Doe');
      expect(model.type, LeaveType.casual);
      expect(model.startDate, DateTime(2026, 9, 10));
      expect(model.endDate, DateTime(2026, 9, 12));
      expect(model.numberOfDays, 3);
      expect(model.reason, 'Personal work');
      expect(model.status, LeaveStatus.pending);
    });

    test('supports alternate date keys (start_date, end_date) and calculates total_days if missing', () {
      final json = {
        'id': 'L-99',
        'start_date': '2026-10-01',
        'end_date': '2026-10-05',
        'type': 'sick',
        'status': 'approved',
      };

      final model = LeaveApplicationModel.fromJson(json);

      expect(model.startDate, DateTime(2026, 10, 1));
      expect(model.endDate, DateTime(2026, 10, 5));
      expect(model.numberOfDays, 5); // 5 - 1 + 1 = 5
      expect(model.type, LeaveType.sick);
      expect(model.status, LeaveStatus.approved);
    });

    test('status mapping maps unknown or unapproved to pending and rejected to rejected', () {
      expect(LeaveStatus.fromString('approved'), LeaveStatus.approved);
      expect(LeaveStatus.fromString('rejected'), LeaveStatus.rejected);
      expect(LeaveStatus.fromString('cancelled'), LeaveStatus.cancelled);
      expect(LeaveStatus.fromString('other'), LeaveStatus.pending);
      expect(LeaveStatus.fromString('something_unknown'), LeaveStatus.pending);
      expect(LeaveStatus.fromString(null), LeaveStatus.pending);
    });

    test('LeaveSummaryModel parses summary object correctly and fallback calculates from leaves', () {
      final summaryJson = {
        'total': 8,
        'pending': 2,
        'approved': 5,
        'rejected': 1,
      };

      final summary = LeaveSummaryModel.fromJson(summaryJson);
      expect(summary.total, 8);
      expect(summary.pending, 2);
      expect(summary.approved, 5);
      expect(summary.rejected, 1);

      final leaves = [
        LeaveApplicationEntity(
          id: '1',
          type: LeaveType.casual,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 2),
          numberOfDays: 2,
          reason: 'Test',
          status: LeaveStatus.approved,
          appliedOn: DateTime.now(),
        ),
        LeaveApplicationEntity(
          id: '2',
          type: LeaveType.sick,
          startDate: DateTime(2026, 9, 5),
          endDate: DateTime(2026, 9, 5),
          numberOfDays: 1,
          reason: 'Sick',
          status: LeaveStatus.pending,
          appliedOn: DateTime.now(),
        ),
        LeaveApplicationEntity(
          id: '3',
          type: LeaveType.paid,
          startDate: DateTime(2026, 9, 8),
          endDate: DateTime(2026, 9, 8),
          numberOfDays: 1,
          reason: 'Vacation',
          status: LeaveStatus.rejected,
          appliedOn: DateTime.now(),
        ),
      ];

      final calculated = LeaveSummaryModel.fromLeaves(leaves);
      expect(calculated.total, 3);
      expect(calculated.approved, 1);
      expect(calculated.pending, 1);
      expect(calculated.rejected, 1);
    });
  });

  group('2. Leave Remote Data Source Tests', () {
    late Dio dio;
    late FakeDioAdapter fakeAdapter;
    late DioClient dioClient;
    late LeaveRemoteDataSourceImpl dataSource;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://test.methotx.in/api'));
      fakeAdapter = FakeDioAdapter();
      dio.httpClientAdapter = fakeAdapter;
      dioClient = DioClient(dio);
      dataSource = LeaveRemoteDataSourceImpl(dioClient: dioClient);
    });

    test('getListOfLeave parses direct list response format', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, contains('/users/employee/list-of-leave'));
        expect(options.data['empId'], 'EMP001');
        expect(options.data['secure'], 'SECURE123');

        return ResponseBody.fromString(
          '''
          {
            "success": true,
            "message": "Leave list fetched successfully",
            "data": [
              {
                "id": 101,
                "emp_id": "EMP001",
                "emp_name": "John Doe",
                "from_date": "2026-09-10",
                "to_date": "2026-09-12",
                "total_days": 3,
                "leave_type": "casual",
                "reason": "Personal work",
                "status": "pending",
                "created_at": "2026-09-05T10:00:00"
              }
            ]
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final result = await dataSource.getListOfLeave(
        empId: 'EMP001',
        secure: 'SECURE123',
      );

      expect(result.leaves.length, 1);
      expect(result.leaves.first.id, '101');
      expect(result.leaves.first.employeeName, 'John Doe');
      expect(result.summary.total, 1);
      expect(result.summary.pending, 1);
    });

    test('getListOfLeave parses summary object format with summary counters', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '''
          {
            "success": true,
            "message": "Leave list fetched successfully",
            "data": {
              "summary": {
                "total": 8,
                "pending": 2,
                "approved": 5,
                "rejected": 1
              },
              "leaves": [
                {
                  "id": 201,
                  "from_date": "2026-09-20",
                  "to_date": "2026-09-21",
                  "leave_type": "paid",
                  "reason": "Trip",
                  "status": "approved"
                }
              ]
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final result = await dataSource.getListOfLeave(
        empId: 'EMP001',
        secure: 'SECURE123',
      );

      expect(result.leaves.length, 1);
      expect(result.summary.total, 8);
      expect(result.summary.pending, 2);
      expect(result.summary.approved, 5);
      expect(result.summary.rejected, 1);
    });

    test('applyLeave converts 422 LEAVE_OVERLAP into friendly user message', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '''
          {
            "success": false,
            "error_code": "LEAVE_OVERLAP",
            "message": "Leave already exists for selected dates"
          }
          ''',
          422,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => dataSource.applyLeave(
          empId: 'EMP001',
          secure: 'SECURE123',
          fromDate: '2026-09-10',
          toDate: '2026-09-12',
          reason: 'Personal work',
          leaveType: 'casual',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'You have already applied for leave on the selected dates. Please choose different dates or cancel your previous leave request.',
          ),
        ),
      );
    });

    test('applyLeave successfully sends lowercase leave type and returns model', () async {
      fakeAdapter.handler = (options) {
        expect(options.data['leaveType'], 'casual');
        expect(options.data['fromDate'], '2026-09-10');
        expect(options.data['toDate'], '2026-09-10'); // single day

        return ResponseBody.fromString(
          '''
          {
            "success": true,
            "message": "Leave request submitted successfully",
            "data": {
              "id": 102,
              "status": "pending"
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final model = await dataSource.applyLeave(
        empId: 'EMP001',
        secure: 'SECURE123',
        fromDate: '2026-09-10',
        toDate: '2026-09-10',
        reason: 'Dentist appointment',
        leaveType: 'Casual',
      );

      expect(model.id, '102');
      expect(model.status, LeaveStatus.pending);
      expect(model.numberOfDays, 1);
    });

    test('getLeaveDetails loads and parses full leave details', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, contains('/users/employee/leave-details'));
        expect(options.data['leaveId'], '101');

        return ResponseBody.fromString(
          '''
          {
            "success": true,
            "message": "Leave details fetched successfully",
            "data": {
              "id": 101,
              "emp_id": "EMP001",
              "emp_name": "John Doe",
              "from_date": "2026-09-10",
              "to_date": "2026-09-12",
              "total_days": 3,
              "leave_type": "casual",
              "reason": "Personal work",
              "status": "approved",
              "created_at": "2026-09-05T10:00:00"
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final details = await dataSource.getLeaveDetails(
        empId: 'EMP001',
        secure: 'SECURE123',
        leaveId: '101',
      );

      expect(details.id, '101');
      expect(details.status, LeaveStatus.approved);
      expect(details.employeeName, 'John Doe');
      expect(details.numberOfDays, 3);
    });
  });

  group('3. Leave Repository Implementation Tests', () {
    late MockStorageService storage;
    late FakeLeaveRemoteDataSource mockRemote;
    late LeaveRepositoryImpl repository;

    setUp(() {
      storage = MockStorageService();
      mockRemote = FakeLeaveRemoteDataSource();
      repository = LeaveRepositoryImpl(
        remoteDataSource: mockRemote,
        storageService: storage,
      );
    });

    test('throws UnauthorizedException when session credentials are missing', () async {
      expect(
        () => repository.getAllLeaves(),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Session expired. Please login again.',
          ),
        ),
      );
    });

    test('partitions upcoming leaves (future dates or pending) vs history', () async {
      await storage.saveString(ApiConstants.storageEmpIdKey, 'EMP001');
      await storage.saveString(ApiConstants.storageSecureKey, 'SECURE_HASH');

      final now = DateTime.now();
      mockRemote.leavesToReturn = [
        LeaveApplicationModel(
          id: '1',
          type: LeaveType.casual,
          startDate: now.add(const Duration(days: 5)),
          endDate: now.add(const Duration(days: 6)),
          numberOfDays: 2,
          reason: 'Future leave',
          status: LeaveStatus.approved,
          appliedOn: now,
        ),
        LeaveApplicationModel(
          id: '2',
          type: LeaveType.sick,
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 9)),
          numberOfDays: 2,
          reason: 'Past pending leave',
          status: LeaveStatus.pending, // Pending stays in upcoming
          appliedOn: now,
        ),
        LeaveApplicationModel(
          id: '3',
          type: LeaveType.paid,
          startDate: now.subtract(const Duration(days: 20)),
          endDate: now.subtract(const Duration(days: 19)),
          numberOfDays: 2,
          reason: 'Past approved leave',
          status: LeaveStatus.approved,
          appliedOn: now,
        ),
      ];

      final upcoming = await repository.getUpcomingLeaves();
      final history = await repository.getLeaveHistory();

      expect(upcoming.map((l) => l.id), containsAll(['1', '2']));
      expect(history.map((l) => l.id), contains('3'));
    });

    test('applyLeave updates local cache optimistically and updates summary', () async {
      await storage.saveString(ApiConstants.storageEmpIdKey, 'EMP001');
      await storage.saveString(ApiConstants.storageSecureKey, 'SECURE_HASH');

      final newEntity = await repository.applyLeave(
        type: LeaveType.casual,
        startDate: DateTime.now().add(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 2)),
        reason: 'Optimistic test',
      );

      expect(newEntity.id, 'applied-1');
      final upcoming = await repository.getUpcomingLeaves();
      expect(upcoming.any((l) => l.id == 'applied-1'), isTrue);

      final summary = await repository.getLeaveSummary();
      expect(summary.total, 1);
      expect(summary.pending, 1);
    });
  });

  group('4. Leave Controller Integration & State Helpers', () {
    late FakeLeaveRepository fakeRepo;
    late LeaveController controller;

    setUp(() {
      fakeRepo = FakeLeaveRepository();
      controller = LeaveController(fakeRepo);
    });

    test('loads leaves and summary on init', () async {
      await controller.loadLeaveData();
      expect(controller.state.upcomingLeaves.length, 1);
      expect(controller.state.leaveHistory.length, 1);
      expect(controller.state.summary.total, 2);
    });

    test('applyLeave optimistically adds to upcoming leaves', () async {
      await controller.loadLeaveData();
      final success = await controller.applyLeave(
        type: LeaveType.sick,
        startDate: DateTime.now().add(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        reason: 'Flu symptoms',
      );

      expect(success, isTrue);
      expect(controller.state.upcomingLeaves.first.reason, 'Flu symptoms');
      expect(controller.state.summary.total, 3);
      expect(controller.state.summary.pending, 2);
    });

    test('local status update helpers (approve, reject, cancel) update in-memory state', () async {
      await controller.loadLeaveData();
      expect(controller.state.upcomingLeaves.first.status, LeaveStatus.pending);

      controller.approveLeave(controller.state.upcomingLeaves.first.id);
      expect(controller.state.upcomingLeaves.first.status, LeaveStatus.approved);

      controller.rejectLeave(controller.state.upcomingLeaves.first.id);
      expect(controller.state.upcomingLeaves.first.status, LeaveStatus.rejected);

      controller.cancelLeaveRequest(controller.state.upcomingLeaves.first.id);
      expect(controller.state.upcomingLeaves.first.status, LeaveStatus.cancelled);
    });
  });
}

class FakeLeaveRemoteDataSource implements LeaveRemoteDataSource {
  List<LeaveApplicationModel> leavesToReturn = [];
  LeaveSummaryModel summaryToReturn = const LeaveSummaryModel();

  @override
  Future<LeaveListResult> getListOfLeave({
    required String empId,
    required String secure,
  }) async {
    return LeaveListResult(
      leaves: leavesToReturn,
      summary: summaryToReturn.total > 0
          ? summaryToReturn
          : LeaveSummaryModel.fromLeaves(leavesToReturn.map((m) => m.toEntity()).toList()),
    );
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
    return LeaveApplicationModel(
      id: 'applied-1',
      employeeId: empId,
      type: LeaveType.fromString(leaveType),
      startDate: DateTime.parse(fromDate),
      endDate: DateTime.parse(toDate),
      numberOfDays: 2,
      reason: reason,
      status: LeaveStatus.pending,
      appliedOn: DateTime.now(),
    );
  }

  @override
  Future<LeaveApplicationModel> getLeaveDetails({
    required String empId,
    required String secure,
    required String leaveId,
  }) async {
    return leavesToReturn.firstWhere(
      (l) => l.id == leaveId,
      orElse: () => LeaveApplicationModel(
        id: leaveId,
        type: LeaveType.casual,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        numberOfDays: 1,
        reason: 'Details',
        status: LeaveStatus.pending,
        appliedOn: DateTime.now(),
      ),
    );
  }
}

class FakeLeaveRepository implements LeaveRepository {
  List<LeaveApplicationEntity> leaves = [
    LeaveApplicationEntity(
      id: 'up-1',
      type: LeaveType.casual,
      startDate: DateTime.now().add(const Duration(days: 3)),
      endDate: DateTime.now().add(const Duration(days: 4)),
      numberOfDays: 2,
      reason: 'Travel',
      status: LeaveStatus.pending,
      appliedOn: DateTime.now(),
    ),
    LeaveApplicationEntity(
      id: 'hist-1',
      type: LeaveType.paid,
      startDate: DateTime.now().subtract(const Duration(days: 15)),
      endDate: DateTime.now().subtract(const Duration(days: 14)),
      numberOfDays: 2,
      reason: 'Vacation',
      status: LeaveStatus.approved,
      appliedOn: DateTime.now(),
    ),
  ];

  @override
  Future<List<LeaveBalanceEntity>> getLeaveBalances() async => const [];

  @override
  Future<List<LeaveApplicationEntity>> getAllLeaves() async => leaves;

  @override
  Future<List<LeaveApplicationEntity>> getUpcomingLeaves() async {
    return leaves.where((l) => l.id.startsWith('up')).toList();
  }

  @override
  Future<List<LeaveApplicationEntity>> getLeaveHistory() async {
    return leaves.where((l) => l.id.startsWith('hist')).toList();
  }

  @override
  Future<LeaveSummaryModel> getLeaveSummary() async {
    return LeaveSummaryModel.fromLeaves(leaves);
  }

  @override
  Future<LeaveApplicationEntity> getLeaveDetails(String leaveId) async {
    return leaves.firstWhere((l) => l.id == leaveId);
  }

  @override
  Future<LeaveApplicationEntity> applyLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final entity = LeaveApplicationEntity(
      id: 'app-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: endDate.difference(startDate).inDays + 1,
      reason: reason,
      status: LeaveStatus.pending,
      appliedOn: DateTime.now(),
    );
    leaves.insert(0, entity);
    return entity;
  }
}
