import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/utils/formatters.dart';
import 'package:methotx_workforce/features/attendance/data/models/attendance_model.dart';
import 'package:methotx_workforce/features/attendance/presentation/widgets/daily_overview_card.dart';

void main() {
  group('Attendance Time 12-Hour Formatting Tests', () {
    test('Converts 24-hour time strings with seconds into 12-hour AM/PM format', () {
      expect(AppFormatters.formatTime12Hour('13:39:54'), '01:39 PM');
      expect(AppFormatters.formatTime12Hour('20:54:14'), '08:54 PM');
      expect(AppFormatters.formatTime12Hour('09:30:00'), '09:30 AM');
      expect(AppFormatters.formatTime12Hour('00:05:30'), '12:05 AM');
      expect(AppFormatters.formatTime12Hour('12:00:00'), '12:00 PM');
      expect(AppFormatters.formatTime12Hour('23:59:59'), '11:59 PM');
    });

    test('Converts 24-hour time strings without seconds into 12-hour AM/PM format', () {
      expect(AppFormatters.formatTime12Hour('13:39'), '01:39 PM');
      expect(AppFormatters.formatTime12Hour('20:54'), '08:54 PM');
      expect(AppFormatters.formatTime12Hour('09:30'), '09:30 AM');
      expect(AppFormatters.formatTime12Hour('9:30'), '09:30 AM');
    });

    test('Preserves already 12-hour format strings and normalizes to hh:mm a', () {
      expect(AppFormatters.formatTime12Hour('01:39 PM'), '01:39 PM');
      expect(AppFormatters.formatTime12Hour('1:39 PM'), '01:39 PM');
      expect(AppFormatters.formatTime12Hour('08:54:14 PM'), '08:54 PM');
    });

    test('Preserves system placeholders and handles null/empty gracefully', () {
      expect(AppFormatters.formatTime12Hour(null), 'Not recorded');
      expect(AppFormatters.formatTime12Hour(''), 'Not recorded');
      expect(AppFormatters.formatTime12Hour('null'), 'Not recorded');
      expect(AppFormatters.formatTime12Hour('Not recorded'), 'Not recorded');
      expect(AppFormatters.formatTime12Hour('Office Holiday'), 'Office Holiday');
      expect(AppFormatters.formatTime12Hour('Weekend Off'), 'Weekend Off');
      expect(AppFormatters.formatTime12Hour('Active Shift'), 'Active Shift');
      expect(AppFormatters.formatTime12Hour('Punched Out'), 'Punched Out');
    });
  });

  group('Late By Duration Formatting Tests', () {
    test('Converts "04:09" and "04:09:00" to "4 hours 9 minutes"', () {
      expect(AppFormatters.formatLateDuration('04:09'), '4 hours 9 minutes');
      expect(AppFormatters.formatLateDuration('04:09:00'), '4 hours 9 minutes');
      expect(AppFormatters.formatLateDuration('Late by 04:09'), '4 hours 9 minutes');
    });

    test('Handles singular and plural hour/minute combinations', () {
      expect(AppFormatters.formatLateDuration('01:01'), '1 hour 1 minute');
      expect(AppFormatters.formatLateDuration('01:15'), '1 hour 15 minutes');
      expect(AppFormatters.formatLateDuration('02:01'), '2 hours 1 minute');
      expect(AppFormatters.formatLateDuration('02:00'), '2 hours');
      expect(AppFormatters.formatLateDuration('01:00'), '1 hour');
      expect(AppFormatters.formatLateDuration('00:09'), '9 minutes');
      expect(AppFormatters.formatLateDuration('00:01'), '1 minute');
    });

    test('Handles already formatted strings and short notation', () {
      expect(AppFormatters.formatLateDuration('4h 9m'), '4 hours 9 minutes');
      expect(AppFormatters.formatLateDuration('1h 1m'), '1 hour 1 minute');
      expect(AppFormatters.formatLateDuration('4 hours 9 minutes'), '4 hours 9 minutes');
      expect(AppFormatters.formatLateDuration('15 minutes'), '15 minutes');
    });

    test('Handles single numeric minutes and null/empty gracefully', () {
      expect(AppFormatters.formatLateDuration('25'), '25 minutes');
      expect(AppFormatters.formatLateDuration('1'), '1 minute');
      expect(AppFormatters.formatLateDuration(null), '');
      expect(AppFormatters.formatLateDuration(''), '');
      expect(AppFormatters.formatLateDuration('null'), '');
    });
  });

  group('Daily Overview & AttendanceModel Integration Tests', () {
    test('AttendanceModel toDayRecord converts 24H times to 12H and formats late duration', () {
      final model = AttendanceModel(
        punchInTime: '13:39:54',
        punchOutTime: '20:54:14',
        isLate: true,
        lateBy: '04:09',
        todayWorkingStatus: 'punch_out',
      );

      final date = DateTime(2026, 9, 3);
      final dayRecord = model.toDayRecord(date);

      expect(dayRecord.checkInTime, '01:39 PM');
      expect(dayRecord.checkOutTime, '08:54 PM');
      expect(dayRecord.lateBy, '4 hours 9 minutes');
      expect(dayRecord.isLate, isTrue);

      final badge = getAttendanceBadge(dayRecord);
      expect(badge.label, 'LATE');
      expect(badge.subtext, 'Late by 4 hours 9 minutes');
    });
  });
}
