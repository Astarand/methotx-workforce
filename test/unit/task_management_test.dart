import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:methotx_workforce/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:methotx_workforce/features/tasks/data/models/task_model.dart';
import 'package:methotx_workforce/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:methotx_workforce/features/tasks/domain/entities/task_entity.dart';
import 'package:methotx_workforce/features/tasks/presentation/controllers/task_notifier.dart';
import 'package:methotx_workforce/core/services/storage_service.dart';

class MockTaskRemoteDataSource implements TaskRemoteDataSource {
  List<TaskModel> pending = [];
  List<TaskModel> completed = [];
  Map<String, dynamic> lastUpdatedPayload = {};

  @override
  Future<List<TaskModel>> getPendingTasks() async => pending;

  @override
  Future<List<TaskModel>> getCompletedTasks() async => completed;

  @override
  Future<TaskModel> getTaskDetails(String taskId) async {
    final all = [...pending, ...completed];
    return all.firstWhere(
      (t) => t.id == taskId,
      orElse: () => TaskModel(
        id: taskId,
        title: 'Task $taskId',
        description: 'Details for $taskId',
      ),
    );
  }

  @override
  Future<TaskModel> updateTaskStatus(
    String taskId,
    String status, {
    String? completedDate,
  }) async {
    lastUpdatedPayload = {
      'taskId': taskId,
      'status': status,
      'completedDate': completedDate,
    };
    return TaskModel(
      id: taskId,
      title: 'Updated Task',
      description: 'Updated Description',
      status: status,
      completedDate: completedDate,
    );
  }
}

class MockStorageService implements StorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clearAll() async => _store.clear();

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> clearSecure() async => _store.clear();

  @override
  Future<void> deleteSecure(String key) async => _store.remove(key);

  @override
  Future<String?> getSecure(String key) async => _store[key] as String?;

  @override
  Future<void> saveSecure(String key, String value) async => _store[key] = value;

  @override
  Future<bool?> getBool(String key) async => _store[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _store[key] as int?;

  @override
  Future<String?> getString(String key) async => _store[key] as String?;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> saveBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> saveInt(String key, int value) async => _store[key] = value;

  @override
  Future<void> saveString(String key, String value) async => _store[key] = value;
}

void main() {
  group('Enterprise Task Management - 10 Fields Model Parsing', () {
    test('TaskModel parses all 10 fields accurately from camelCase payload', () {
      final futureDate = DateTime.now().add(const Duration(days: 3));
      final futureDateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(futureDate);
      final json = {
        'id': 'TASK-501',
        'title': 'Deploy Biometric Auth Module',
        'priority': 'High',
        'description': 'Finalize WebAuthn and passkey fallback for iOS/Android',
        'status': 'In Progress',
        'dueDate': futureDateStr,
        'addedByName': 'Lead Architect',
        'completedDate': null,
        'isOverdue': false,
        'overdueDays': 0,
      };

      final model = TaskModel.fromJson(json);
      expect(model.id, equals('TASK-501'));
      expect(model.title, equals('Deploy Biometric Auth Module'));
      expect(model.priority, equals('High'));
      expect(model.description, contains('WebAuthn'));
      expect(model.status, equals('In Progress'));
      expect(model.dueDate, equals(futureDateStr));
      expect(model.addedByName, equals('Lead Architect'));
      expect(model.completedDate, isNull);
      expect(model.isOverdue, isFalse);
      expect(model.overdueDays, equals(0));

      final entity = model.toEntity();
      expect(entity.status, equals(TaskStatus.inProgress));
      expect(entity.isInProgress, isTrue);
      expect(entity.formattedDueDate, contains(DateFormat('dd MMM yyyy').format(futureDate)));
    });

    test('TaskModel parses all 10 fields from snake_case Laravel response', () {
      final json = {
        'task_id': 'TASK-888',
        'task_title': 'Quarterly Compliance Sign-off',
        'task_priority': 'Low',
        'task_description': 'Sign off on data audit compliance checklist',
        'task_status': 'Completed',
        'due_date': '2026-08-30',
        'added_by_name': 'Chief Security Officer',
        'completed_date': '2026-08-29 15:30:00',
        'is_overdue': 0,
        'overdue_days': 0,
      };

      final model = TaskModel.fromJson(json);
      expect(model.id, equals('TASK-888'));
      expect(model.title, equals('Quarterly Compliance Sign-off'));
      expect(model.priority, equals('Low'));
      expect(model.status, equals('Completed'));
      expect(model.dueDate, equals('2026-08-30'));
      expect(model.addedByName, equals('Chief Security Officer'));
      expect(model.completedDate, equals('2026-08-29 15:30:00'));
      expect(model.isOverdue, isFalse);

      final entity = model.toEntity();
      expect(entity.status, equals(TaskStatus.completed));
      expect(entity.isCompleted, isTrue);
      expect(entity.formattedCompletedDate, contains('29 Aug 2026'));
    });

    test('Overdue logic calculates overdue days if past due date', () {
      final json = {
        'id': 'TASK-OVERDUE-1',
        'title': 'Resolve Production Incident',
        'description': 'Fix crash in location service',
        'priority': 'High',
        'status': 'Pending',
        'dueDate': '2026-08-01 10:00:00',
        'addedByName': 'Incident Manager',
        'isOverdue': true,
        'overdueDays': 34,
      };

      final model = TaskModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.isOverdue, isTrue);
      expect(entity.overdueDays, equals(34));
      expect(entity.overdueLabel, equals('Overdue by 34 days'));
    });
  });

  group('Task Repository & Remote Data Source Integration', () {
    late MockTaskRemoteDataSource mockRemoteDataSource;
    late MockStorageService mockStorageService;
    late TaskRepositoryImpl repository;

    setUp(() {
      mockRemoteDataSource = MockTaskRemoteDataSource();
      mockStorageService = MockStorageService();
      repository = TaskRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        storageService: mockStorageService,
      );
    });

    test('getPendingTasks retrieves active tasks and caches them', () async {
      mockRemoteDataSource.pending = [
        TaskModel(
          id: 'TASK-10',
          title: 'Active Task 10',
          description: 'Description 10',
          priority: 'Medium',
          status: 'Pending',
          dueDate: '2026-09-15',
          addedByName: 'Manager A',
        ),
      ];

      final tasks = await repository.getPendingTasks();
      expect(tasks.length, equals(1));
      expect(tasks.first.id, equals('TASK-10'));
      expect(tasks.first.addedByName, equals('Manager A'));

      // Verify cached in storage
      final cachedJson = await mockStorageService.getString('cached_pending_tasks');
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('TASK-10'));
    });

    test('updateTaskStatus sends optional completedDate when marking completed', () async {
      final nowStr = '2026-09-04 13:00:00';
      final updated = await repository.updateTaskStatus(
        'TASK-10',
        TaskStatus.completed,
        completedDate: nowStr,
      );

      expect(updated.status, equals(TaskStatus.completed));
      expect(mockRemoteDataSource.lastUpdatedPayload['taskId'], equals('TASK-10'));
      expect(mockRemoteDataSource.lastUpdatedPayload['status'], equals('Completed'));
      expect(mockRemoteDataSource.lastUpdatedPayload['completedDate'], equals(nowStr));
    });
  });

  group('TaskNotifier Presentation State Management', () {
    late MockTaskRemoteDataSource mockRemoteDataSource;
    late MockStorageService mockStorageService;
    late TaskRepositoryImpl repository;
    late TaskNotifier notifier;

    setUp(() {
      mockRemoteDataSource = MockTaskRemoteDataSource();
      mockStorageService = MockStorageService();

      final now = DateTime.now();
      final activeDueDate = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 3)));
      final overdueDueDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 10)));
      final completedDueDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final completedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.subtract(const Duration(days: 1)));

      mockRemoteDataSource.pending = [
        TaskModel(
          id: 'TASK-01',
          title: 'Implement Task API',
          description: 'Connect all 4 endpoints',
          priority: 'High',
          status: 'Pending',
          dueDate: activeDueDate,
          addedByName: 'Lead Dev',
          isOverdue: false,
        ),
        TaskModel(
          id: 'TASK-02',
          title: 'Review Overdue Deliverable',
          description: 'Verify SLA',
          priority: 'High',
          status: 'In Progress',
          dueDate: overdueDueDate,
          addedByName: 'Lead Dev',
          isOverdue: true,
          overdueDays: 10,
        ),
      ];

      mockRemoteDataSource.completed = [
        TaskModel(
          id: 'TASK-03',
          title: 'Early Punch Grace Implementation',
          description: 'Completed earlier sprint',
          priority: 'Medium',
          status: 'Completed',
          dueDate: completedDueDate,
          addedByName: 'HR Lead',
          completedDate: completedDateTime,
        ),
      ];

      repository = TaskRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        storageService: mockStorageService,
      );
      notifier = TaskNotifier(repository: repository);
    });

    test('TaskNotifier loads active and completed tasks with metrics', () async {
      await notifier.fetchTasks();

      expect(notifier.state.pendingTasks.length, equals(2));
      expect(notifier.state.completedTasks.length, equals(1));
      expect(notifier.state.totalTasksCount, equals(3));
      expect(notifier.state.totalOverdueCount, equals(1));
      expect(notifier.state.completionRate, closeTo(1 / 3, 0.01));
    });

    test('TaskNotifier fetchTaskDetails updates selectedTaskDetails', () async {
      final details = await notifier.fetchTaskDetails('TASK-01');
      expect(details, isNotNull);
      expect(details!.id, equals('TASK-01'));
      expect(notifier.state.selectedTaskDetails?.id, equals('TASK-01'));
    });

    test('TaskNotifier updateTaskStatus transitions task and refreshes', () async {
      await notifier.fetchTasks();

      final success = await notifier.updateTaskStatus(
        taskId: 'TASK-01',
        newStatus: TaskStatus.completed,
      );

      expect(success, isTrue);
      expect(mockRemoteDataSource.lastUpdatedPayload['taskId'], equals('TASK-01'));
      expect(mockRemoteDataSource.lastUpdatedPayload['status'], equals('Completed'));
      expect(mockRemoteDataSource.lastUpdatedPayload['completedDate'], isNotNull);
    });

    test('3-Tab Partitioning: correctly splits active on-schedule, overdue, and completed', () async {
      await notifier.fetchTasks();

      final activeTasks =
          notifier.state.pendingTasks.where((t) => !t.isOverdue).toList();
      final overdueTasks =
          notifier.state.pendingTasks.where((t) => t.isOverdue).toList();
      final completedTasks = notifier.state.completedTasks;

      expect(activeTasks.length, equals(1));
      expect(activeTasks.first.id, equals('TASK-01'));
      expect(activeTasks.first.isOverdue, isFalse);

      expect(overdueTasks.length, equals(1));
      expect(overdueTasks.first.id, equals('TASK-02'));
      expect(overdueTasks.first.isOverdue, isTrue);
      expect(overdueTasks.first.overdueDays, equals(10));

      expect(completedTasks.length, equals(1));
      expect(completedTasks.first.id, equals('TASK-03'));
      expect(completedTasks.first.isCompleted, isTrue);
    });

    test('Date & Time sorting: sorts tasks with nearest due date & time first', () {
      final t1 = TaskEntity(
        id: 'T1',
        title: 'Due 05 Sep Afternoon',
        description: '',
        dueDate: DateTime(2026, 9, 5, 15, 0),
      );
      final t2 = TaskEntity(
        id: 'T2',
        title: 'Due 04 Sep Morning',
        description: '',
        dueDate: DateTime(2026, 9, 4, 9, 30),
      );
      final t3 = TaskEntity(
        id: 'T3',
        title: 'Due 05 Sep Morning',
        description: '',
        dueDate: DateTime(2026, 9, 5, 10, 0),
      );
      final t4 = TaskEntity(
        id: 'T4',
        title: 'Due 04 Sep Afternoon',
        description: '',
        dueDate: DateTime(2026, 9, 4, 16, 45),
      );

      final sorted = TaskNotifier.sortPendingTasks([t1, t2, t3, t4]);

      expect(sorted.map((t) => t.id).toList(), equals(['T2', 'T4', 'T3', 'T1']));
      expect(sorted[0].formattedDueDate, contains('04 Sep 2026 • 09:30 AM'));
      expect(sorted[1].formattedDueDate, contains('04 Sep 2026 • 04:45 PM'));
      expect(sorted[2].formattedDueDate, contains('05 Sep 2026 • 10:00 AM'));
      expect(sorted[3].formattedDueDate, contains('05 Sep 2026 • 03:00 PM'));
    });
  });

  group('Completed Tasks 1-Week (7-Day) Filtering Tests', () {
    final refDate = DateTime(2026, 9, 4, 18, 30);

    test('TaskEntity isCompletedWithinDays correctly distinguishes tasks within/outside 7 days', () {
      final taskToday = TaskEntity(
        id: 'T-TODAY',
        title: 'Today Task',
        description: '',
        completedDate: DateTime(2026, 9, 4, 12, 0),
      );
      final task3DaysAgo = TaskEntity(
        id: 'T-3DAYS',
        title: '3 Days Ago Task',
        description: '',
        completedDate: DateTime(2026, 9, 1, 15, 0),
      );
      final task7DaysAgo = TaskEntity(
        id: 'T-7DAYS',
        title: '7 Days Ago Task (Boundary)',
        description: '',
        completedDate: DateTime(2026, 8, 28, 9, 0),
      );
      final task8DaysAgo = TaskEntity(
        id: 'T-8DAYS',
        title: '8 Days Ago Task',
        description: '',
        completedDate: DateTime(2026, 8, 27, 23, 0),
      );
      final task30DaysAgo = TaskEntity(
        id: 'T-30DAYS',
        title: 'Last Month Task',
        description: '',
        completedDate: DateTime(2026, 8, 4, 10, 0),
      );
      final taskNoDate = TaskEntity(
        id: 'T-NODATE',
        title: 'No Date Task',
        description: '',
      );

      expect(taskToday.isCompletedWithinDays(7, refDate), isTrue);
      expect(task3DaysAgo.isCompletedWithinDays(7, refDate), isTrue);
      expect(task7DaysAgo.isCompletedWithinDays(7, refDate), isTrue);
      expect(task8DaysAgo.isCompletedWithinDays(7, refDate), isFalse);
      expect(task30DaysAgo.isCompletedWithinDays(7, refDate), isFalse);
      expect(taskNoDate.isCompletedWithinDays(7, refDate), isFalse);
    });

    test('TaskNotifier filterAndSortCompletedTasks filters older than 7 days and sorts newest first', () {
      final tRecent = TaskEntity(
        id: 'T-RECENT',
        title: 'Recent',
        description: '',
        completedDate: DateTime(2026, 9, 4, 10, 0),
      );
      final tMid = TaskEntity(
        id: 'T-MID',
        title: 'Mid Week',
        description: '',
        completedDate: DateTime(2026, 9, 2, 14, 0),
      );
      final tOld = TaskEntity(
        id: 'T-OLD',
        title: 'Old (10 days ago)',
        description: '',
        completedDate: DateTime(2026, 8, 25, 10, 0),
      );

      final result = TaskNotifier.filterAndSortCompletedTasks(
        [tOld, tMid, tRecent],
        referenceDate: refDate,
        maxDays: 7,
      );

      expect(result.length, equals(2));
      expect(result.map((t) => t.id).toList(), equals(['T-RECENT', 'T-MID']));
    });

    test('TaskRepositoryImpl getCompletedTasks only caches and returns tasks within 7 days', () async {
      final mockDataSource = MockTaskRemoteDataSource();
      final mockStorage = MockStorageService();

      mockDataSource.completed = [
        TaskModel(
          id: 'T-NEW',
          title: 'Recent completed task',
          description: '',
          status: 'Completed',
          completedDate: '2026-09-03 10:00:00',
        ),
        TaskModel(
          id: 'T-ANCIENT',
          title: 'Year old task',
          description: '',
          status: 'Completed',
          completedDate: '2025-09-03 10:00:00',
        ),
      ];

      final repo = TaskRepositoryImpl(
        remoteDataSource: mockDataSource,
        storageService: mockStorage,
      );

      final results = await repo.getCompletedTasks();

      // Ancient task from 2025 must be filtered out
      expect(results.any((t) => t.id == 'T-ANCIENT'), isFalse);
    });
  });
}
