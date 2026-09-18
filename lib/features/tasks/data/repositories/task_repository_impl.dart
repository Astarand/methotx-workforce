import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_data_source.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource remoteDataSource;
  final StorageService storageService;

  static const String _cachedPendingTasksKey = 'cached_pending_tasks';
  static const String _cachedCompletedTasksKey = 'cached_completed_tasks';

  TaskRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  @override
  Future<List<TaskEntity>> getPendingTasks() async {
    try {
      final models = await remoteDataSource.getPendingTasks();
      final entities = models.map((m) => m.toEntity()).toList();
      await _cacheTasks(_cachedPendingTasksKey, entities);
      return entities;
    } catch (_) {
      final cached = await _getCachedTasks(_cachedPendingTasksKey);
      if (cached.isNotEmpty) return cached;
      return [];
    }
  }

  @override
  Future<List<TaskEntity>> getCompletedTasks() async {
    try {
      final models = await remoteDataSource.getCompletedTasks();
      final entities = models.map((m) => m.toEntity()).toList();
      // Only cache and return completed tasks from the last 7 days to keep memory and local storage lightweight
      final recent = entities.where((t) => t.isCompletedWithinDays(7)).toList();
      await _cacheTasks(_cachedCompletedTasksKey, recent);
      return recent;
    } catch (_) {
      final cached = await _getCachedTasks(_cachedCompletedTasksKey);
      if (cached.isNotEmpty) {
        return cached.where((t) => t.isCompletedWithinDays(7)).toList();
      }
      return [];
    }
  }

  @override
  Future<TaskEntity> getTaskDetails(String taskId) async {
    try {
      final model = await remoteDataSource.getTaskDetails(taskId);
      return model.toEntity();
    } catch (_) {
      final all = [
        ...await getPendingTasks(),
        ...await getCompletedTasks(),
      ];
      return all.firstWhere(
        (t) => t.id == taskId,
        orElse: () => TaskEntity(
          id: taskId,
          title: 'Task Details',
          description: 'No detailed description available.',
        ),
      );
    }
  }

  @override
  Future<TaskEntity> updateTaskStatus(
    String taskId,
    TaskStatus status, {
    String? completedDate,
  }) async {
    try {
      final model = await remoteDataSource.updateTaskStatus(
        taskId,
        status.apiValue,
        completedDate: completedDate,
      );
      final entity = model.toEntity().copyWith(
            status: status,
            completedDate: completedDate != null
                ? DateTime.tryParse(completedDate)
                : (status == TaskStatus.completed ? DateTime.now() : null),
          );
      return entity;
    } catch (_) {
      // Local optimistic update fallback
      return TaskEntity(
        id: taskId,
        title: 'Task',
        description: '',
        status: status,
        completedDate: status == TaskStatus.completed ? DateTime.now() : null,
      );
    }
  }

  Future<void> _cacheTasks(String key, List<TaskEntity> tasks) async {
    final list = tasks.map((t) => {
      'id': t.id,
      'title': t.title,
      'description': t.description,
      'priority': t.priority,
      'status': t.status.name,
      'dueDate': t.dueDate?.toIso8601String(),
      'addedByName': t.addedByName,
      'completedDate': t.completedDate?.toIso8601String(),
      'isOverdue': t.isOverdue,
      'overdueDays': t.overdueDays,
      'createdAt': t.createdAt?.toIso8601String(),
    }).toList();
    await storageService.saveString(key, jsonEncode(list));
  }

  Future<List<TaskEntity>> _getCachedTasks(String key) async {
    final jsonStr = await storageService.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final status = TaskStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => TaskStatus.pending,
        );
        return TaskEntity(
          id: map['id'] ?? '',
          title: map['title'] ?? '',
          description: map['description'] ?? '',
          priority: map['priority'],
          status: status,
          dueDate: map['dueDate'] != null
              ? DateTime.tryParse(map['dueDate'])
              : (map['deadline'] != null ? DateTime.tryParse(map['deadline']) : null),
          addedByName: map['addedByName'] ?? map['assignedBy'],
          completedDate: map['completedDate'] != null
              ? DateTime.tryParse(map['completedDate'])
              : null,
          isOverdue: map['isOverdue'] == true,
          overdueDays: (map['overdueDays'] as num?)?.toInt() ?? 0,
          createdAt: map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'])
              : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final remoteDataSource = ref.watch(taskRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return TaskRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
