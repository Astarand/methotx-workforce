import 'package:intl/intl.dart';

/// Task status lifecycle state
enum TaskStatus {
  pending,
  inProgress,
  completed,
}

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  String get apiValue {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  bool get isPending => this == TaskStatus.pending;
  bool get isInProgress => this == TaskStatus.inProgress;
  bool get isCompleted => this == TaskStatus.completed;
}

/// Core Clean Architecture Domain Entity representing a Task with 10 parsed fields
class TaskEntity {
  final String id;
  final String title;
  final String? priority;
  final String description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? addedByName;
  final DateTime? completedDate;
  final bool isOverdue;
  final int overdueDays;
  final DateTime? createdAt;

  const TaskEntity({
    required this.id,
    required this.title,
    required this.description,
    this.priority,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.addedByName,
    this.completedDate,
    this.isOverdue = false,
    this.overdueDays = 0,
    this.createdAt,
    DateTime? deadline, // backward compatibility
    String? assignedBy, // backward compatibility
  })  : _legacyDeadline = deadline,
        _legacyAssignedBy = assignedBy;

  final DateTime? _legacyDeadline;
  final String? _legacyAssignedBy;

  DateTime? get deadline => dueDate ?? _legacyDeadline;
  String? get assignedBy => addedByName ?? _legacyAssignedBy;

  String get formattedDueDate {
    final dt = dueDate ?? _legacyDeadline;
    if (dt == null) return 'No Due Date';
    if (dt.hour == 0 && dt.minute == 0) {
      return DateFormat('dd MMM yyyy').format(dt);
    }
    return DateFormat('dd MMM yyyy • hh:mm a').format(dt);
  }

  String get formattedDeadline => formattedDueDate;

  String get formattedCompletedDate {
    if (completedDate == null) return '';
    if (completedDate!.hour == 0 && completedDate!.minute == 0) {
      return DateFormat('dd MMM yyyy').format(completedDate!);
    }
    return DateFormat('dd MMM yyyy • hh:mm a').format(completedDate!);
  }

  String get overdueLabel {
    if (!isOverdue) return '';
    if (overdueDays > 0) {
      return 'Overdue by $overdueDays ${overdueDays == 1 ? "day" : "days"}';
    }
    return 'Overdue';
  }

  bool get isPending => status.isPending;
  bool get isInProgress => status.isInProgress;
  bool get isCompleted => status.isCompleted;

  /// Checks if this task was completed within the last [days] (default 7 days / 1 week).
  ///
  /// Evaluates [completedDate], falling back to [dueDate] or [createdAt].
  /// Uses midnight of [days] ago as cutoff to cover full calendar days.
  bool isCompletedWithinDays([int days = 7, DateTime? referenceDate]) {
    final date = completedDate ?? dueDate ?? createdAt;
    if (date == null) return false;
    final now = referenceDate ?? DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
  }

  TaskEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    TaskStatus? status,
    DateTime? dueDate,
    String? addedByName,
    DateTime? completedDate,
    bool? isOverdue,
    int? overdueDays,
    DateTime? createdAt,
    DateTime? deadline,
    String? assignedBy,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? deadline ?? this.dueDate,
      addedByName: addedByName ?? assignedBy ?? this.addedByName,
      completedDate: completedDate ?? this.completedDate,
      isOverdue: isOverdue ?? this.isOverdue,
      overdueDays: overdueDays ?? this.overdueDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Domain Entity representing Task Overview statistics
class TaskOverviewEntity {
  final int totalTasks;
  final int totalActive;
  final int totalCompleted;
  final int totalOverdue;
  final double completionRate;

  const TaskOverviewEntity({
    this.totalTasks = 0,
    this.totalActive = 0,
    this.totalCompleted = 0,
    this.totalOverdue = 0,
    this.completionRate = 0.0,
  });
}
