import '../entities/notification_entity.dart';
import '../../../../shared/models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getNotifications({NotificationCategory? category});
  Future<int> getUnreadCount();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
}
