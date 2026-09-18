import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:methotx_workforce/shared/models/notification_model.dart';
import 'package:methotx_workforce/features/notifications/domain/entities/notification_entity.dart';
import 'package:methotx_workforce/features/notifications/data/local_notification_repository.dart';
import 'package:methotx_workforce/features/notifications/presentation/controllers/notification_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalNotificationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalNotificationRepository(prefs);
  });

  group('LocalNotificationRepository Unit Tests', () {
    test('Stores and retrieves notifications within last 7 days', () async {
      final now = DateTime.now();
      final within7Days = NotificationEntity(
        id: 'n-1',
        title: 'Task Assigned',
        message: 'Review module',
        timestamp: now.subtract(const Duration(days: 2)),
        category: NotificationCategory.tasks,
        actionRoute: '/tasks',
      );

      final olderThan7Days = NotificationEntity(
        id: 'n-old',
        title: 'Old Notification',
        message: 'This is 8 days old',
        timestamp: now.subtract(const Duration(days: 8)),
        category: NotificationCategory.announcement,
      );

      // Store directly into mock SharedPreferences JSON
      await prefs.setString(
        LocalNotificationRepository.storageKey,
        '[${within7Days.toJson().toString()}, ${olderThan7Days.toJson().toString()}]',
      );

      // Use proper JSON encoding
      await prefs.setString(
        LocalNotificationRepository.storageKey,
        '''[
          {
            "id": "${within7Days.id}",
            "title": "${within7Days.title}",
            "message": "${within7Days.message}",
            "timestamp": "${within7Days.timestamp.toIso8601String()}",
            "isRead": false,
            "category": "${within7Days.category.name}",
            "actionRoute": "${within7Days.actionRoute}"
          },
          {
            "id": "${olderThan7Days.id}",
            "title": "${olderThan7Days.title}",
            "message": "${olderThan7Days.message}",
            "timestamp": "${olderThan7Days.timestamp.toIso8601String()}",
            "isRead": false,
            "category": "${olderThan7Days.category.name}"
          }
        ]''',
      );

      final result = await repository.getNotifications();
      // olderThan7Days should be automatically filtered out!
      expect(result.length, equals(1));
      expect(result.first.id, equals('n-1'));
    });

    test('markAsRead, markAllAsRead, deleteNotification work correctly', () async {
      final now = DateTime.now();
      await prefs.setString(
        LocalNotificationRepository.storageKey,
        '''[
          {
            "id": "item-1",
            "title": "Title 1",
            "message": "Msg 1",
            "timestamp": "${now.toIso8601String()}",
            "isRead": false,
            "category": "attendance"
          },
          {
            "id": "item-2",
            "title": "Title 2",
            "message": "Msg 2",
            "timestamp": "${now.subtract(const Duration(hours: 1)).toIso8601String()}",
            "isRead": false,
            "category": "tasks"
          }
        ]''',
      );

      expect(await repository.getUnreadCount(), equals(2));

      await repository.markAsRead('item-1');
      expect(await repository.getUnreadCount(), equals(1));

      await repository.markAllAsRead();
      expect(await repository.getUnreadCount(), equals(0));

      await repository.deleteNotification('item-2');
      final remaining = await repository.getNotifications();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('item-1'));
    });

    test('mapTypeToCategory maps all backend notification types properly', () {
      expect(LocalNotificationRepository.mapTypeToCategory('attendance'), equals(NotificationCategory.attendance));
      expect(LocalNotificationRepository.mapTypeToCategory('task'), equals(NotificationCategory.tasks));
      expect(LocalNotificationRepository.mapTypeToCategory('tasks'), equals(NotificationCategory.tasks));
      expect(LocalNotificationRepository.mapTypeToCategory('payslip'), equals(NotificationCategory.payroll));
      expect(LocalNotificationRepository.mapTypeToCategory('payroll'), equals(NotificationCategory.payroll));
      expect(LocalNotificationRepository.mapTypeToCategory('hr_letter'), equals(NotificationCategory.announcement));
      expect(LocalNotificationRepository.mapTypeToCategory('security'), equals(NotificationCategory.security));
      expect(LocalNotificationRepository.mapTypeToCategory('unknown'), equals(NotificationCategory.announcement));
    });

    test('resolveActionRoute maps route and type correctly', () {
      expect(LocalNotificationRepository.resolveActionRoute({'route': '/custom-route'}), equals('/custom-route'));
      expect(LocalNotificationRepository.resolveActionRoute({'type': 'task'}), equals('/tasks'));
      expect(LocalNotificationRepository.resolveActionRoute({'type': 'leave'}), equals('/leave'));
      expect(LocalNotificationRepository.resolveActionRoute({'type': 'payslip'}), equals('/payslip'));
      expect(LocalNotificationRepository.resolveActionRoute({'type': 'hr_letter'}), equals('/hr-letter'));
    });
  });

  group('NotificationController Pagination Tests', () {
    test('Shows 15 items initially and expands on showMore()', () async {
      final now = DateTime.now();
      // Generate 25 notifications within last 7 days
      final jsonListBuffer = StringBuffer('[');
      for (int i = 0; i < 25; i++) {
        if (i > 0) jsonListBuffer.write(',');
        jsonListBuffer.write('''{
          "id": "notif-$i",
          "title": "Notification $i",
          "message": "Content $i",
          "timestamp": "${now.subtract(Duration(minutes: i * 10)).toIso8601String()}",
          "isRead": false,
          "category": "announcement"
        }''');
      }
      jsonListBuffer.write(']');

      await prefs.setString(
        LocalNotificationRepository.storageKey,
        jsonListBuffer.toString(),
      );

      final controller = NotificationController(repository);
      await controller.loadNotifications();

      // Initial state must show exactly 15 items
      expect(controller.state.notifications.length, equals(15));
      expect(controller.state.totalCount, equals(25));
      expect(controller.state.hasMore, isTrue);

      // Trigger showMore()
      controller.showMore();

      // Now all 25 items should be displayed and hasMore becomes false
      expect(controller.state.notifications.length, equals(25));
      expect(controller.state.hasMore, isFalse);

      controller.dispose();
    });
  });
}
