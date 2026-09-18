import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/network/api_endpoints.dart';
import 'package:methotx_workforce/core/services/notification_service.dart';
import 'package:methotx_workforce/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  group('NotificationService & FCM Endpoints Unit Tests', () {
    test('ApiEndpoints.updateFcmToken correctly matches backend Laravel route', () {
      expect(
        ApiEndpoints.updateFcmToken,
        contains('/users/employee/update-fcm-token'),
      );
    });

    test('NotificationService.instance is a singleton', () {
      final instance1 = NotificationService.instance;
      final instance2 = NotificationService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('NotificationService channel constants are configured correctly', () {
      expect(NotificationService.channelId, equals('high_importance_channel'));
      expect(NotificationService.channelName, equals('High Importance Notifications'));
    });

    test('NotificationService shift reminder IDs are defined and unique', () {
      expect(NotificationService.shiftStart30Id, equals(1001));
      expect(NotificationService.shiftStart15Id, equals(1002));
      expect(NotificationService.shiftStart5Id, equals(1003));
      expect(NotificationService.shiftEnd30Id, equals(2001));
      expect(NotificationService.shiftEnd10Id, equals(2002));
    });

    test('isFirebaseAvailable safely returns boolean without throwing in unit tests', () {
      expect(() => NotificationService.isFirebaseAvailable, returnsNormally);
    });

    test('AttendanceEntity parses getShiftEndDateTime accurately', () {
      final today = DateTime(2026, 9, 6);

      // 12-hour AM/PM format
      const entity12 = AttendanceEntity(
        openingTime: '09:30 AM',
        closingTime: '06:30 PM',
      );
      final end12 = entity12.getShiftEndDateTime(today);
      expect(end12, isNotNull);
      expect(end12!.hour, equals(18));
      expect(end12.minute, equals(30));

      // 24-hour HH:mm format
      const entity24 = AttendanceEntity(
        openingTime: '09:30',
        closingTime: '19:00',
      );
      final end24 = entity24.getShiftEndDateTime(today);
      expect(end24, isNotNull);
      expect(end24!.hour, equals(19));
      expect(end24.minute, equals(0));
    });

    test('NotificationService shift reminders scheduling executes safely', () async {
      final service = NotificationService.instance;

      const dummyAttendance = AttendanceEntity(
        openingTime: '10:00 AM',
        closingTime: '07:00 PM',
      );

      // Should execute without throwing in headless test environment
      await expectLater(
        service.scheduleShiftRemindersFromAttendance(dummyAttendance),
        completes,
      );

      // Test cancel methods execute safely
      await expectLater(service.cancelShiftStartReminders(), completes);
      await expectLater(service.cancelShiftEndReminders(), completes);
      await expectLater(service.cancelAllShiftReminders(), completes);
    });
  });
}
