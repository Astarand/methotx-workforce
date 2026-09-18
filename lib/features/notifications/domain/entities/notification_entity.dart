import '../../../../shared/models/notification_model.dart'; // For Enums

/// Pure Domain Entity for Notifications
class NotificationEntity {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final NotificationCategory category;
  final String? actionRoute;
  final Map<String, dynamic>? data;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.category = NotificationCategory.announcement,
    this.actionRoute,
    this.data,
  });
  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    NotificationCategory? category,
    String? actionRoute,
    Map<String, dynamic>? data,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      actionRoute: actionRoute ?? this.actionRoute,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'category': category.name,
      'actionRoute': actionRoute,
      'data': data,
    };
  }

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    NotificationCategory category = NotificationCategory.announcement;
    final catName = json['category'] as String?;
    if (catName != null) {
      for (final val in NotificationCategory.values) {
        if (val.name == catName) {
          category = val;
          break;
        }
      }
    }

    return NotificationEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      category: category,
      actionRoute: json['actionRoute'] as String?,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
    );
  }
}
