import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import '../../data/repositories/task_repository_impl.dart';

class TaskState {
  final List<TaskEntity> pendingTasks;
  final List<TaskEntity> completedTasks;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final TaskEntity? selectedTaskDetails;
  final bool isDetailsLoading;

  const TaskState({
    this.pendingTasks = const [],
    this.completedTasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.selectedTaskDetails,
    this.isDetailsLoading = false,
  });

  int get totalPendingCount => pendingTasks.length;
  int get totalCompletedCount => completedTasks.length;
  int get totalTasksCount => totalPendingCount + totalCompletedCount;
  int get totalOverdueCount =>
      pendingTasks.where((t) => t.isOverdue).length;

  double get completionRate {
    if (totalTasksCount == 0) return 0.0;
    return totalCompletedCount / totalTasksCount;
  }

  TaskState copyWith({
    List<TaskEntity>? pendingTasks,
    List<TaskEntity>? completedTasks,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    TaskEntity? selectedTaskDetails,
    bool? isDetailsLoading,
  }) {
    return TaskState(
      pendingTasks: pendingTasks ?? this.pendingTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      selectedTaskDetails: selectedTaskDetails ?? this.selectedTaskDetails,
      isDetailsLoading: isDetailsLoading ?? this.isDetailsLoading,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  final TaskRepository repository;

  TaskNotifier({required this.repository}) : super(const TaskState()) {
    fetchTasks();
  }

  /// Fetches both pending and completed tasks from the repository
  Future<void> fetchTasks({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final results = await Future.wait([
        repository.getPendingTasks(),
        repository.getCompletedTasks(),
      ]);

      final pending = sortPendingTasks(results[0]);
      final completed = filterAndSortCompletedTasks(results[1]);

      state = state.copyWith(
        pendingTasks: pending,
        completedTasks: completed,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch tasks: ${e.toString()}',
      );
    }
  }

  /// Sorts pending tasks so that closest due date & time appears first
  static List<TaskEntity> sortPendingTasks(List<TaskEntity> list) {
    final sorted = List<TaskEntity>.from(list);
    sorted.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      if (cmp != 0) return cmp;
      return _priorityWeight(a.priority).compareTo(_priorityWeight(b.priority));
    });
    return sorted;
  }

  /// Filters completed tasks to only include those completed within the last [maxDays] (default 7 days / 1 week)
  /// and sorts them by most recent completion date first.
  static List<TaskEntity> filterAndSortCompletedTasks(
    List<TaskEntity> list, {
    DateTime? referenceDate,
    int maxDays = 7,
  }) {
    final filtered = list
        .where((t) => t.isCompletedWithinDays(maxDays, referenceDate))
        .toList();
    return sortCompletedTasks(filtered);
  }

  /// Sorts completed tasks by most recently completed date first
  static List<TaskEntity> sortCompletedTasks(List<TaskEntity> list) {
    final sorted = List<TaskEntity>.from(list);
    sorted.sort((a, b) {
      final aDate = a.completedDate ?? a.dueDate;
      final bDate = b.completedDate ?? b.dueDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  static int _priorityWeight(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }

  /// Fetches detailed information for a specific task
  Future<TaskEntity?> fetchTaskDetails(String taskId) async {
    state = state.copyWith(isDetailsLoading: true, errorMessage: null);

    try {
      final details = await repository.getTaskDetails(taskId);
      if (!mounted) return details;

      state = state.copyWith(
        selectedTaskDetails: details,
        isDetailsLoading: false,
      );
      return details;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isDetailsLoading: false,
        errorMessage: 'Failed to load task details: ${e.toString()}',
      );
      return null;
    }
  }

  /// Clears the currently selected task details
  void clearSelectedTaskDetails() {
    state = state.copyWith(selectedTaskDetails: null, isDetailsLoading: false);
  }

  /// Updates a task's status (Pending, InProgress, Completed) and immediately refreshes
  Future<bool> updateTaskStatus({
    required String taskId,
    required TaskStatus newStatus,
    String? completedDate,
  }) async {
    // If completing and no completedDate provided, supply current timestamp
    final effectiveCompletedDate = completedDate ??
        (newStatus == TaskStatus.completed
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
            : null);

    // Optimistic UI state update
    final pending = List<TaskEntity>.from(state.pendingTasks);
    final completed = List<TaskEntity>.from(state.completedTasks);

    TaskEntity? target;
    final pendingIndex = pending.indexWhere((t) => t.id == taskId);
    if (pendingIndex != -1) {
      target = pending.removeAt(pendingIndex);
    } else {
      final completedIndex = completed.indexWhere((t) => t.id == taskId);
      if (completedIndex != -1) {
        target = completed.removeAt(completedIndex);
      }
    }

    if (target != null) {
      final updatedTask = target.copyWith(
        status: newStatus,
        completedDate: effectiveCompletedDate != null
            ? DateTime.tryParse(effectiveCompletedDate)
            : (newStatus == TaskStatus.completed ? DateTime.now() : null),
      );
      if (newStatus == TaskStatus.completed) {
        completed.insert(0, updatedTask);
      } else {
        pending.insert(0, updatedTask);
      }

      state = state.copyWith(
        pendingTasks: sortPendingTasks(pending),
        completedTasks: filterAndSortCompletedTasks(completed),
        selectedTaskDetails: state.selectedTaskDetails?.id == taskId
            ? updatedTask
            : state.selectedTaskDetails,
      );
    }

    try {
      final updatedEntity = await repository.updateTaskStatus(
        taskId,
        newStatus,
        completedDate: effectiveCompletedDate,
      );
      if (!mounted) return true;

      state = state.copyWith(
        selectedTaskDetails: state.selectedTaskDetails?.id == taskId
            ? updatedEntity
            : state.selectedTaskDetails,
        successMessage: 'Task marked as ${newStatus.label}.',
      );

      // Refresh list to synchronize with backend
      await fetchTasks(showLoading: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Failed to update task status: ${e.toString()}',
      );
      // Revert to backend state
      await fetchTasks(showLoading: false);
      return false;
    }
  }
}

final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TaskNotifier(repository: repository);
});
