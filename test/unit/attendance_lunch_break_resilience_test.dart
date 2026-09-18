import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/attendance/data/models/attendance_model.dart';
import 'package:methotx_workforce/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  group('Attendance Lunch & Break Resilience Tests', () {
    test('Correctly parses lunch_in and lunch_out from Laravel daily-activity response', () {
      final json = {
        'success': true,
        'message': 'Daily activity fetched successfully.',
        'data': {
          'date': '04 Sep 2026',
          'dayName': 'Friday',
          'status': 'late',
          'inTime': '09:31:52',
          'outTime': null,
          'lunch_in': '14:51:46',
          'lunch_out': '16:35:00',
          'lunch_status': 'ended',
          'total_lunch_time': '01:43',
        },
      };

      final model = AttendanceModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.punchInTime, isNotNull);
      expect(entity.punchInTime!.hour, equals(9));
      expect(entity.punchInTime!.minute, equals(31));

      expect(entity.lunchInTime, isNotNull);
      expect(entity.lunchInTime!.hour, equals(14));
      expect(entity.lunchInTime!.minute, equals(51));

      expect(entity.lunchOutTime, isNotNull);
      expect(entity.lunchOutTime!.hour, equals(16));
      expect(entity.lunchOutTime!.minute, equals(35));

      expect(entity.lunchStatus, equals('complete'));
      expect(entity.isLunchComplete, isTrue);
      expect(entity.isOnLunch, isFalse);

      expect(entity.totalLunchDuration.inMinutes, equals(103));
      expect(entity.isPunchedIn, isTrue);
    });

    test('Shift sanity check preserves isPunchedIn when punchInTime exists and punchOutTime is null', () {
      final json = {
        'data': {
          'todayDate': '2026-09-04',
          'todayWorkingStatus': 'not_present',
          'punchInTime': '09:31:52',
          'punchOutTime': null,
        }
      };

      final model = AttendanceModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.todayWorkingStatus, equals('present'));
      expect(entity.isPunchedIn, isTrue);
      expect(entity.isPunchedOut, isFalse);
      expect(entity.isNotPresent, isFalse);
    });

    test('todayWorkingStatus = lunch or break evaluates to isPunchedIn = true', () {
      const lunchEntity = AttendanceEntity(
        todayWorkingStatus: 'lunch',
        lunchStatus: 'ongoing',
      );
      expect(lunchEntity.isPunchedIn, isTrue);
      expect(lunchEntity.isOnLunch, isTrue);

      const breakEntity = AttendanceEntity(
        todayWorkingStatus: 'break',
        breakStatus: 'ongoing',
      );
      expect(breakEntity.isPunchedIn, isTrue);
      expect(breakEntity.isOnBreak, isTrue);
    });

    test('Ongoing lunch with non-null lunchInTime calculates dynamic duration properly', () {
      final lunchIn = DateTime(2026, 9, 4, 14, 51, 46);
      final current = DateTime(2026, 9, 4, 16, 24, 0);

      final entity = AttendanceEntity(
        punchInTime: DateTime(2026, 9, 4, 9, 31, 52),
        lunchInTime: lunchIn,
        lunchStatus: 'ongoing',
        todayWorkingStatus: 'present',
      );

      expect(entity.isOnLunch, isTrue);
      final elapsed = current.difference(entity.lunchInTime!);
      expect(elapsed.inMinutes, equals(92));
      expect(elapsed.inSeconds, equals(92 * 60 + 14));
    });
  });
}
