import '../entities/task_entity.dart';

/// Abstract repository interface for Task Management
abstract class TaskRepository {
  /// Fetches pending/active tasks for the logged in user
  Future<List<TaskEntity>> getPendingTasks();

  /// Fetches completed tasks for the logged in user
  Future<List<TaskEntity>> getCompletedTasks();

  /// Fetches detailed information for a specific task
  Future<TaskEntity> getTaskDetails(String taskId);

  /// Updates status of a task (Pending, InProgress, Completed) with optional completedDate
  Future<TaskEntity> updateTaskStatus(
    String taskId,
    TaskStatus status, {
    String? completedDate,
  });
}
