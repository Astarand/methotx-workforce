import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/attendance/domain/entities/attendance_entity.dart';
import 'package:methotx_workforce/features/attendance/presentation/controllers/attendance_notifier.dart';
import 'package:methotx_workforce/features/dashboard/presentation/widgets/swipe_punch_button.dart';

void main() {
  group('Weekend, Holiday & Office-Off Domain Tests', () {
    test('Sunday without punch activity is accurately detected as weekend', () {
      final sundayDate = DateTime(2026, 9, 6, 10, 0); // Sunday
      expect(sundayDate.weekday, DateTime.sunday);

      const entity = AttendanceEntity(
        openingTime: '11:00:00',
        backendStatus: 'weekend',
      );

      expect(entity.isWeekend(sundayDate), isTrue);
      expect(entity.isOfficeOff(sundayDate), isTrue);
      expect(entity.isNonWorkingDay(sundayDate), isTrue);
    });

    test('getEarliestPunchInTime returns null on weekend even if openingTime is configured', () {
      final sundayDate = DateTime(2026, 9, 6, 8, 30);
      const entity = AttendanceEntity(
        openingTime: '11:00:00',
        backendStatus: 'weekend',
      );

      // On a working day, 11:00 AM would yield 9:00 AM early punch window.
      // On a weekend, it must return null to prevent misleading countdown.
      expect(entity.getEarliestPunchInTime(sundayDate), isNull);
      expect(entity.isPunchInWindowOpen(sundayDate), isFalse);
    });

    test('Holiday is accurately detected and suppresses punch-in window', () {
      final mondayDate = DateTime(2026, 9, 7, 10, 0); // Monday
      const entity = AttendanceEntity(
        openingTime: '11:00:00',
        holidayName: 'Gandhi Jayanti',
        backendStatus: 'holiday',
      );

      expect(entity.isHoliday, isTrue);
      expect(entity.isNonWorkingDay(mondayDate), isTrue);
      expect(entity.getEarliestPunchInTime(mondayDate), isNull);
      expect(entity.isPunchInWindowOpen(mondayDate), isFalse);
    });

    test('Approved Leave is accurately detected and suppresses punch-in window', () {
      final wednesdayDate = DateTime(2026, 9, 9, 10, 0);
      const entity = AttendanceEntity(
        openingTime: '11:00:00',
        leaveType: 'Sick Leave',
        backendStatus: 'leave',
      );

      expect(entity.isOnLeave, isTrue);
      expect(entity.isNonWorkingDay(wednesdayDate), isTrue);
      expect(entity.getEarliestPunchInTime(wednesdayDate), isNull);
      expect(entity.isPunchInWindowOpen(wednesdayDate), isFalse);
    });

    test('Working day allows punch-in window calculations normally', () {
      final mondayDate = DateTime(2026, 9, 7, 9, 30); // Monday 9:30 AM
      const entity = AttendanceEntity(
        openingTime: '11:00 AM',
        backendStatus: 'not_present',
      );

      expect(entity.isWeekend(mondayDate), isFalse);
      expect(entity.isHoliday, isFalse);
      expect(entity.isNonWorkingDay(mondayDate), isFalse);

      final earliest = entity.getEarliestPunchInTime(mondayDate);
      expect(earliest, isNotNull);
      expect(earliest!.hour, 9);
      expect(earliest.minute, 0);
      expect(entity.isPunchInWindowOpen(mondayDate), isTrue);
    });

    test('Active punch-in on weekend overrides non-working day status for active work', () {
      final sundayDate = DateTime(2026, 9, 6, 12, 0);
      final entity = AttendanceEntity(
        punchInTime: DateTime(2026, 9, 6, 11, 0),
        todayWorkingStatus: 'present',
        backendStatus: 'weekend',
      );

      expect(entity.isPunchedIn, isTrue);
      // Active work takes priority so employee can work and punch out
      expect(entity.isNonWorkingDay(sundayDate), isFalse);
    });
  });

  group('AttendanceState Status Mapping Tests', () {
    test('AttendanceState evaluates currentStatus to officeOff on weekend', () {
      const state = AttendanceState(
        attendance: AttendanceEntity(
          backendStatus: 'weekend',
        ),
      );

      expect(state.currentStatus, AttendanceStatus.officeOff);
      expect(state.currentStatus.label, 'Office Closed');
    });

    test('AttendanceState evaluates currentStatus to holiday on public holiday', () {
      const state = AttendanceState(
        attendance: AttendanceEntity(
          holidayName: 'Independence Day',
          backendStatus: 'holiday',
        ),
      );

      expect(state.currentStatus, AttendanceStatus.holiday);
      expect(state.currentStatus.label, 'Holiday');
    });

    test('AttendanceState evaluates currentStatus to onLeave when on approved leave', () {
      const state = AttendanceState(
        attendance: AttendanceEntity(
          leaveType: 'Casual Leave',
          backendStatus: 'leave',
        ),
      );

      expect(state.currentStatus, AttendanceStatus.onLeave);
      expect(state.currentStatus.label, 'On Leave');
    });
  });

  group('SwipeSliderBar Weekend UX Widget Tests', () {
    testWidgets('SwipeSliderBar renders "Office Closed (Weekend)" when isWeekend is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeSliderBar(
                todayWorkingStatus: 'not_present',
                isLoading: false,
                isWindowOpen: false,
                isNonWorkingDay: true,
                isWeekend: true,
                onSwipeComplete: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Office Closed (Weekend)'), findsOneWidget);
      expect(find.byIcon(Icons.weekend_rounded), findsWidgets);
      expect(find.text('Punch In opens at'), findsNothing);
      expect(find.text('Swipe to Punch In'), findsNothing);
    });

    testWidgets('SwipeSliderBar renders Holiday text when isHoliday is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeSliderBar(
                todayWorkingStatus: 'not_present',
                isLoading: false,
                isWindowOpen: false,
                isNonWorkingDay: true,
                isHoliday: true,
                holidayName: 'Diwali',
                onSwipeComplete: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Holiday • Diwali'), findsOneWidget);
      expect(find.byIcon(Icons.celebration_rounded), findsWidgets);
    });
  });
}
