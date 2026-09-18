import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  group('AttendanceEntity - 2-Hour Early Punch Window & 5-Minute Grace Period', () {
    final refDate = DateTime(2026, 9, 4); // September 4, 2026

    test('Parses various openingTime formats correctly', () {
      // 12-hour format with AM/PM
      const entity12h = AttendanceEntity(openingTime: '09:30 AM');
      final start12h = entity12h.getShiftStartDateTime(refDate);
      expect(start12h, equals(DateTime(2026, 9, 4, 9, 30)));

      // Lowercase am
      const entityLower = AttendanceEntity(openingTime: '9:30 am');
      final startLower = entityLower.getShiftStartDateTime(refDate);
      expect(startLower, equals(DateTime(2026, 9, 4, 9, 30)));

      // 24-hour format with seconds
      const entity24hSec = AttendanceEntity(openingTime: '09:30:00');
      final start24hSec = entity24hSec.getShiftStartDateTime(refDate);
      expect(start24hSec, equals(DateTime(2026, 9, 4, 9, 30)));

      // 24-hour format without seconds
      const entity24h = AttendanceEntity(openingTime: '09:30');
      final start24h = entity24h.getShiftStartDateTime(refDate);
      expect(start24h, equals(DateTime(2026, 9, 4, 9, 30)));
    });

    test('Calculates earliest punch-in time exactly 2 hours before shift start', () {
      const entity930 = AttendanceEntity(openingTime: '09:30 AM');
      final earliest930 = entity930.getEarliestPunchInTime(refDate);
      expect(earliest930, equals(DateTime(2026, 9, 4, 7, 30)));

      const entity900 = AttendanceEntity(openingTime: '09:00 AM');
      final earliest900 = entity900.getEarliestPunchInTime(refDate);
      expect(earliest900, equals(DateTime(2026, 9, 4, 7, 0)));
    });

    test('Enforces 2-hour early punch window check', () {
      const entity = AttendanceEntity(openingTime: '09:30 AM');

      // 1 minute before window opens (07:29 AM) -> window is closed
      final beforeWindow = DateTime(2026, 9, 4, 7, 29);
      expect(entity.isPunchInWindowOpen(beforeWindow), isFalse);

      // Exact moment window opens (07:30 AM) -> window is open
      final windowOpens = DateTime(2026, 9, 4, 7, 30);
      expect(entity.isPunchInWindowOpen(windowOpens), isTrue);

      // Early arrival (08:15 AM) -> window is open
      final earlyArrival = DateTime(2026, 9, 4, 8, 15);
      expect(entity.isPunchInWindowOpen(earlyArrival), isTrue);

      // Normal shift time (09:30 AM) -> window is open
      final onTimeArrival = DateTime(2026, 9, 4, 9, 30);
      expect(entity.isPunchInWindowOpen(onTimeArrival), isTrue);
    });

    test('Calculates 5-minute grace period buffer accurately', () {
      const entity = AttendanceEntity(openingTime: '09:30 AM');
      final graceDeadline = entity.getGraceTime(refDate);
      // 09:30 + 5 minutes = 09:35 AM
      expect(graceDeadline, equals(DateTime(2026, 9, 4, 9, 35)));
    });

    test('Classifies punch-in as ON-TIME vs LATE and calculates late duration', () {
      const entity = AttendanceEntity(openingTime: '09:30 AM');

      // Example 1: Early arrival (08:50 AM) -> ON-TIME, NOT LATE
      final earlyPunch = DateTime(2026, 9, 4, 8, 50);
      expect(entity.isPunchInOnTime(earlyPunch), isTrue);
      expect(entity.isPunchInLate(earlyPunch), isFalse);

      // Example 2: Exact shift time (09:30 AM) -> ON-TIME, NOT LATE
      final exactPunch = DateTime(2026, 9, 4, 9, 30);
      expect(entity.isPunchInOnTime(exactPunch), isTrue);
      expect(entity.isPunchInLate(exactPunch), isFalse);

      // Example 3: Punch-in at 09:33 AM -> LATE by 3 minutes, but within 5-min grace buffer
      final punch933 = DateTime(2026, 9, 4, 9, 33);
      expect(entity.isPunchInLate(punch933), isTrue);
      expect(entity.isPunchInOnTime(punch933), isFalse);
      expect(entity.isWithinGraceBuffer(punch933), isTrue);
      final shiftStart = entity.getShiftStartDateTime(punch933)!;
      final diff933 = punch933.difference(shiftStart).inMinutes;
      expect(diff933, equals(3)); // Employee sees "Late by 3m"

      // Example 4: Punch-in at 09:36 AM -> LATE by 6 minutes, exceeded grace buffer
      final punch936 = DateTime(2026, 9, 4, 9, 36);
      expect(entity.isPunchInLate(punch936), isTrue);
      expect(entity.isWithinGraceBuffer(punch936), isFalse);
      final diff936 = punch936.difference(shiftStart).inMinutes;
      expect(diff936, equals(6)); // Employee sees "Late by 6m"

      // Example 5: Punch-in at 10:00 AM -> VERY LATE by 30 minutes
      final punch1000 = DateTime(2026, 9, 4, 10, 0);
      expect(entity.isPunchInLate(punch1000), isTrue);
      expect(entity.isWithinGraceBuffer(punch1000), isFalse);
      final diff1000 = punch1000.difference(shiftStart).inMinutes;
      expect(diff1000, equals(30)); // Employee sees "Late by 30m"
    });

    test('Gracefully handles missing or empty openingTime', () {
      const nullEntity = AttendanceEntity(openingTime: null);
      expect(nullEntity.getShiftStartDateTime(refDate), isNull);
      expect(nullEntity.getEarliestPunchInTime(refDate), isNull);
      expect(nullEntity.getGraceTime(refDate), isNull);
      // Should allow punch in if schedule is unconfigured
      expect(nullEntity.isPunchInWindowOpen(DateTime(2026, 9, 4, 6, 0)), isTrue);
      expect(nullEntity.isPunchInOnTime(DateTime(2026, 9, 4, 9, 45)), isTrue);
      expect(nullEntity.isPunchInLate(DateTime(2026, 9, 4, 9, 45)), isFalse);
    });
  });
}
