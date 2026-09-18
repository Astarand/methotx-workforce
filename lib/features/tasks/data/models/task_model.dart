import 'package:intl/intl.dart';
import '../../domain/entities/task_entity.dart';

/// Data Transfer Object for Task Management with complete 10-field API parsing
class TaskModel {
  final String id;
  final String title;
  final String? priority;
  final String description;
  final String? status;
  final String? dueDate;
  final String? addedByName;
  final String? completedDate;
  final bool isOverdue;
  final int overdueDays;
  final String? createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.priority,
    required this.description,
    this.status,
    this.dueDate,
    this.addedByName,
    this.completedDate,
    this.isOverdue = false,
    this.overdueDays = 0,
    this.createdAt,
  });

  // Backward-compatibility getters
  String? get deadline => dueDate;
  String? get assignedBy => addedByName;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id']?.toString() ??
        json['_id']?.toString() ??
        json['taskId']?.toString() ??
        json['task_id']?.toString() ??
        '';

    final parsedTitle = json['title']?.toString() ??
        json['task_title']?.toString() ??
        json['name']?.toString() ??
        '';

    final parsedPriority = json['priority']?.toString() ??
        json['task_priority']?.toString();

    final parsedDesc = json['description']?.toString() ??
        json['task_description']?.toString() ??
        json['details']?.toString() ??
        '';

    final parsedStatus = json['status']?.toString() ??
        json['task_status']?.toString();

    final rawDueDate = json['dueDate']?.toString() ??
        json['due_date']?.toString() ??
        json['deadline']?.toString();

    final rawDueTime = json['dueTime']?.toString() ??
        json['due_time']?.toString() ??
        json['time']?.toString() ??
        json['task_time']?.toString();

    String? parsedDueDate = rawDueDate;
    if (rawDueDate != null &&
        rawDueDate.trim().isNotEmpty &&
        rawDueTime != null &&
        rawDueTime.trim().isNotEmpty) {
      if (!rawDueDate.contains(':')) {
        parsedDueDate = '${rawDueDate.trim()} ${rawDueTime.trim()}';
      }
    }

    final parsedAddedBy = json['addedByName']?.toString() ??
        json['added_by_name']?.toString() ??
        json['addedBy']?.toString() ??
        json['added_by']?.toString() ??
        json['assignedBy']?.toString() ??
        json['assigned_by']?.toString();

    final parsedCompletedDate = json['completedDate']?.toString() ??
        json['completed_date']?.toString() ??
        json['completed_at']?.toString() ??
        json['completedAt']?.toString();

    // Parse isOverdue flag
    bool parsedIsOverdue = json['isOverdue'] == true ||
        json['is_overdue'] == true ||
        json['isOverdue'] == 1 ||
        json['is_overdue'] == 1 ||
        json['isOverdue'] == '1' ||
        json['is_overdue'] == '1';

    // Parse overdueDays
    int parsedOverdueDays = int.tryParse(json['overdueDays']?.toString() ??
            json['overdue_days']?.toString() ??
            '') ??
        0;

    // Fallback calculation if not explicitly provided by backend
    final dueDateTime = _parseDateTime(parsedDueDate);
    final statusEnum = _parseStatus(parsedStatus);
    if (!parsedIsOverdue &&
        dueDateTime != null &&
        statusEnum != TaskStatus.completed) {
      final now = DateTime.now();
      // If no explicit time was provided in dueDate (e.g. 00:00:00), evaluate deadline as the END of that day (23:59:59)
      final effectiveDeadline = (dueDateTime.hour == 0 && dueDateTime.minute == 0)
          ? DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day, 23, 59, 59)
          : dueDateTime;

      if (now.isAfter(effectiveDeadline)) {
        parsedIsOverdue = true;
        if (parsedOverdueDays == 0) {
          final diff = now.difference(effectiveDeadline).inDays;
          parsedOverdueDays = diff <= 0 ? 1 : diff;
        }
      }
    }

    return TaskModel(
      id: parsedId,
      title: parsedTitle,
      priority: parsedPriority,
      description: parsedDesc,
      status: parsedStatus,
      dueDate: parsedDueDate,
      addedByName: parsedAddedBy,
      completedDate: parsedCompletedDate,
      isOverdue: parsedIsOverdue,
      overdueDays: parsedOverdueDays,
      createdAt:
          json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'description': description,
      'status': status,
      'dueDate': dueDate,
      'addedByName': addedByName,
      'completedDate': completedDate,
      'isOverdue': isOverdue,
      'overdueDays': overdueDays,
      'createdAt': createdAt,
    };
  }

  TaskEntity toEntity() {
    return TaskEntity(
      id: id,
      title: title,
      priority: priority,
      description: description,
      status: _parseStatus(status),
      dueDate: _parseDateTime(dueDate),
      addedByName: addedByName,
      completedDate: _parseDateTime(completedDate),
      isOverdue: isOverdue,
      overdueDays: overdueDays,
      createdAt: _parseDateTime(createdAt),
    );
  }

  static DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final clean = dateStr.trim();

    // 1. Standard ISO 8601 or standard DateTime string
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;

    // 2. Common formats via DateFormat
    final patterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd hh:mm a',
      'yyyy-MM-dd',
      'dd MMM yyyy HH:mm:ss',
      'dd MMM yyyy HH:mm',
      'dd MMM yyyy hh:mm a',
      'dd MMM yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy hh:mm a',
      'dd-MM-yyyy',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy hh:mm a',
      'dd/MM/yyyy',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy',
    ];

    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parse(clean);
      } catch (_) {}
    }

    // 3. Fallback: split by space and try parsing first segment
    try {
      final parts = clean.split(' ');
      if (parts.isNotEmpty) {
        final fallback = DateTime.tryParse(parts[0]);
        if (fallback != null) return fallback;
      }
    } catch (_) {}

    return null;
  }

  static TaskStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return TaskStatus.pending;
    final s = statusStr.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (s.contains('complet') || s.contains('done')) {
      return TaskStatus.completed;
    } else if (s.contains('progress') || s.contains('ongoing')) {
      return TaskStatus.inProgress;
    } else {
      return TaskStatus.pending;
    }
  }
}
