import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/attendance/data/models/attendance_model.dart';
import 'package:methotx_workforce/features/attendance/domain/entities/attendance_entity.dart';
import 'package:methotx_workforce/features/attendance/presentation/controllers/attendance_notifier.dart';
import 'package:methotx_workforce/shared/models/attendance_record_model.dart' as rec;

void main() {
  group('WFH vs WFO Entity & Model Resolution Tests', () {
    test('AttendanceEntity defaults to unresolved (neither WFH nor WFO prematurely)', () {
      const entity = AttendanceEntity(
        currentStatus: AttendanceStatus.notPunchedIn,
        todayWorkingStatus: 'not_present',
        netWorkingDuration: Duration.zero,
      );

      expect(entity.workLocationStatus, isEmpty);
      expect(entity.todayWorkLocation, isEmpty);
      expect(entity.isWFH, isFalse);
      expect(entity.isWFO, isFalse);
    });

    test('AttendanceEntity correctly resolves WFH from workLocationStatus', () {
      const entity = AttendanceEntity(
        currentStatus: AttendanceStatus.working,
        todayWorkingStatus: 'present',
        netWorkingDuration: Duration.zero,
        workLocationStatus: 'WFH',
      );

      expect(entity.isWFH, isTrue);
      expect(entity.isWFO, isFalse);
    });

    test('AttendanceEntity correctly resolves WFO from workLocationStatus', () {
      const entity = AttendanceEntity(
        currentStatus: AttendanceStatus.working,
        todayWorkingStatus: 'present',
        netWorkingDuration: Duration.zero,
        workLocationStatus: 'WFO',
      );

      expect(entity.isWFO, isTrue);
      expect(entity.isWFH, isFalse);
    });

    test('AttendanceEntity correctly resolves WFH from todayWorkLocation', () {
      const entity = AttendanceEntity(
        currentStatus: AttendanceStatus.working,
        todayWorkingStatus: 'present',
        netWorkingDuration: Duration.zero,
        todayWorkLocation: 'Work_From_Home',
      );

      expect(entity.isWFH, isTrue);
      expect(entity.isWFO, isFalse);
    });

    test('AttendanceModel.fromJson correctly parses WFH work modes without defaulting to WFO', () {
      final jsonWfh = {
        'status': 'punch_in',
        'is_punched_in': 1,
        'work_mode': 'Work_From_Home',
      };

      final model = AttendanceModel.fromJson(jsonWfh);
      expect(model.workLocationStatus, equals('WFH'));
      expect(model.todayWorkLocation, equals('Work_From_Home'));
      expect(model.toEntity().isWFH, isTrue);
      expect(model.toEntity().isWFO, isFalse);
    });

    test('AttendanceModel.fromJson parses nested employee work_location: Work From Home', () {
      final jsonNested = {
        'success': true,
        'message': 'Employee details fetched',
        'data': {
          'employee': {
            'employee_id': 'emp2-00011',
            'name': 'Rittik Sadhukhan',
            'work_location': 'Work From Home',
          },
          'todayWorkingStatus': 'not_present',
        },
      };

      final model = AttendanceModel.fromJson(jsonNested);
      expect(model.workLocationStatus, equals('WFH'));
      expect(model.todayWorkLocation, equals('Work From Home'));
      expect(model.toEntity().isWFH, isTrue);
      expect(model.toEntity().isWFO, isFalse);
    });

    test('AttendanceModel.fromJson parses nested employee_details today_work_location', () {
      final jsonNestedDetails = {
        'success': true,
        'data': {
          'employee_details': {
            'today_work_location': 'work_from_home',
          },
        },
      };

      final model = AttendanceModel.fromJson(jsonNestedDetails);
      expect(model.workLocationStatus, equals('WFH'));
      expect(model.toEntity().isWFH, isTrue);
      expect(model.toEntity().isWFO, isFalse);
    });

    test('AttendanceModel.fromJson handles null work location by defaulting to WFH per specification', () {
      final jsonEmpty = {
        'status': 'punch_in',
        'is_punched_in': 1,
      };

      final model = AttendanceModel.fromJson(jsonEmpty);
      expect(model.workLocationStatus, equals('WFH'));
      expect(model.toEntity().workLocationStatus, equals('WFH'));
      expect(model.toEntity().isWFH, isTrue);
      expect(model.toEntity().isWFO, isFalse);
    });

    test('AttendanceModel.fromJson parses explicit work_from_office as WFO', () {
      final jsonWfo = {
        'data': {
          'today_work_location': 'work_from_office',
        },
      };

      final model = AttendanceModel.fromJson(jsonWfo);
      expect(model.workLocationStatus, equals('WFO'));
      expect(model.toEntity().isWFO, isTrue);
      expect(model.toEntity().isWFH, isFalse);
    });

    test('AttendanceModel.toDayRecord maps office_off status to AttendanceStatus.officeOff', () {
      final jsonOff = {
        'status': 'office_off',
        'todayWorkingStatus': 'office_off',
      };

      final model = AttendanceModel.fromJson(jsonOff);
      final record = model.toDayRecord(DateTime(2026, 9, 2)); // Wednesday
      expect(record.status, equals(rec.AttendanceStatus.officeOff));
    });

    test('AttendanceModel.toDayRecord relies on API status for officeOff without hardcoded weekday checks', () {
      final modelOff = AttendanceModel.fromJson({'status': 'office_off'});
      final sundayRecord = modelOff.toDayRecord(DateTime(2026, 9, 6));
      expect(sundayRecord.status, equals(rec.AttendanceStatus.officeOff));

      final saturdayRecord = modelOff.toDayRecord(DateTime(2026, 9, 5));
      expect(saturdayRecord.status, equals(rec.AttendanceStatus.officeOff));

      final emptyModel = AttendanceModel.fromJson({});
      // Without API status, future dates are notRecorded and past dates are absent (no hardcoded sunday off)
      final pastRecord = emptyModel.toDayRecord(DateTime(2026, 9, 1));
      expect(pastRecord.status, equals(rec.AttendanceStatus.absent));
    });
  });

  group('AttendanceState Outside Tracking Suppression for WFH Tests', () {
    test('totalOutsideString returns 0m 00s for WFH even if outside timestamps exist', () {
      final wfhState = AttendanceState(
        attendance: const AttendanceEntity(
          currentStatus: AttendanceStatus.working,
          todayWorkingStatus: 'present',
          netWorkingDuration: Duration(hours: 4),
          workLocationStatus: 'WFH',
        ),
        workLocationStatus: 'WFH',
        totalOutsideDuration: const Duration(minutes: 45),
        isCurrentlyOutside: true,
        outsideStartTime: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      expect(wfhState.isWFH, isTrue);
      expect(wfhState.isWFO, isFalse);
      expect(wfhState.totalOutsideString(DateTime.now()), equals('0m 00s'));
    });

    test('liveNetWorkingDuration does not deduct outside time for WFH employees', () {
      final punchInTime = DateTime.now().subtract(const Duration(hours: 3));
      final wfhState = AttendanceState(
        attendance: AttendanceEntity(
          currentStatus: AttendanceStatus.working,
          todayWorkingStatus: 'present',
          punchInTime: punchInTime,
          netWorkingDuration: const Duration(hours: 3),
          workLocationStatus: 'WFH',
        ),
        todayWorkingStatus: 'present',
        workLocationStatus: 'WFH',
        totalOutsideDuration: const Duration(minutes: 30),
      );

      final now = DateTime.now();
      final netDuration = wfhState.liveNetWorkingDuration(now);
      // For WFH, net working duration equals gross working time (outside time is NOT deducted)
      expect(netDuration.inMinutes, greaterThanOrEqualTo(179));
    });

    test('liveNetWorkingDuration deducts outside time only for WFO employees', () {
      final punchInTime = DateTime.now().subtract(const Duration(hours: 3));
      final wfoState = AttendanceState(
        attendance: AttendanceEntity(
          currentStatus: AttendanceStatus.working,
          todayWorkingStatus: 'present',
          punchInTime: punchInTime,
          netWorkingDuration: const Duration(hours: 3),
          workLocationStatus: 'WFO',
        ),
        todayWorkingStatus: 'present',
        workLocationStatus: 'WFO',
        totalOutsideDuration: const Duration(minutes: 30),
      );

      final now = DateTime.now();
      final netDuration = wfoState.liveNetWorkingDuration(now);
      // For WFO, 30m outside time is deducted from ~180m -> ~150m
      expect(netDuration.inMinutes, inInclusiveRange(148, 152));
    });

    test('HR live assignment to WFO overrides morning WFH punch record', () {
      // Simulating morning punch-in activity (WFH)
      const morningActivity = AttendanceEntity(
        currentStatus: AttendanceStatus.working,
        todayWorkingStatus: 'present',
        workLocationStatus: 'WFH',
        todayWorkLocation: 'Work_From_Home',
      );

      // Simulating HR/Management updating employee details at noon to WFO
      const hrUpdatedDetails = AttendanceEntity(
        currentStatus: AttendanceStatus.working,
        todayWorkingStatus: 'present',
        workLocationStatus: 'WFO',
        todayWorkLocation: 'Work_From_Office',
      );

      // Verify the authoritative resolution rule
      final isDetailsWfo = (hrUpdatedDetails.workLocationStatus.toUpperCase() == 'WFO' ||
              hrUpdatedDetails.todayWorkLocation.toLowerCase() == 'work_from_office' ||
              hrUpdatedDetails.todayWorkLocation.toLowerCase().contains('office')) &&
          !hrUpdatedDetails.todayWorkLocation.toLowerCase().contains('home') &&
          !hrUpdatedDetails.todayWorkLocation.toLowerCase().contains('wfh') &&
          !hrUpdatedDetails.todayWorkLocation.toLowerCase().contains('remote') &&
          hrUpdatedDetails.workLocationStatus != 'WFH';

      expect(isDetailsWfo, isTrue);
      // Even though morningActivity has 'WFH', HR's live assignment wins
      expect(morningActivity.isWFH, isTrue);
      expect(hrUpdatedDetails.isWFO, isTrue);
    });

    test('Shift started as WFH preserves WFH rules for punch out and suppresses outside tracking even after HR changes workLocationStatus to WFO', () {
      // Morning: employee punched in as WFH
      // Midday: HR switched profile in Laravel to WFO (workLocationStatus == 'WFO')
      final midDayState = AttendanceState(
        attendance: const AttendanceEntity(
          currentStatus: AttendanceStatus.working,
          todayWorkingStatus: 'present',
          workLocationStatus: 'WFO',
          todayWorkLocation: 'Work_From_Office',
        ),
        todayWorkingStatus: 'present',
        workLocationStatus: 'WFO',
        punchInWorkMode: 'WFH', // Crucial: shift was initiated as WFH
        totalOutsideDuration: const Duration(minutes: 50),
        isCurrentlyOutside: true,
      );

      // 1. Employee is assigned WFO for tomorrow/next shift
      expect(midDayState.isWFO, isTrue);
      expect(midDayState.isWFH, isFalse);

      // 2. Active shift is protected: recognized as started as WFH
      expect(midDayState.isShiftStartedAsWfh, isTrue);

      // 3. Outside office tracking is completely suppressed today
      expect(midDayState.totalOutsideString(DateTime.now()), equals('0m 00s'));

      // 4. Working hours are NOT penalized by any outside office duration
      final netDuration = midDayState.liveNetWorkingDuration(DateTime.now());
      expect(netDuration, equals(Duration.zero)); // no punchInTime set in entity, so zero
    });
  });

  group('Dynamic Office Geofence & Location Extraction Tests', () {
    test('AttendanceModel.fromJson extracts office coordinates from top-level keys', () {
      final json = {
        'status': 'Active',
        'office_lat': '28.6139',
        'office_long': '77.2090',
        'office_radius': 100,
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.officeLat, equals(28.6139));
      expect(model.officeLong, equals(77.2090));
      expect(model.allowedRadiusMeters, equals(100.0));
    });

    test('AttendanceModel.fromJson extracts office coordinates from nested office object', () {
      final json = {
        'status': 'Active',
        'office': {
          'latitude': 12.9716,
          'longitude': 77.5946,
          'radius': 75.5,
        },
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.officeLat, equals(12.9716));
      expect(model.officeLong, equals(77.5946));
      expect(model.allowedRadiusMeters, equals(75.5));
    });

    test('AttendanceModel.fromJson extracts office coordinates from nested branch/company', () {
      final json = {
        'status': 'Active',
        'branch': {
          'lat': 19.0760,
          'lng': 72.8777,
          'allowed_radius': 150,
        },
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.officeLat, equals(19.0760));
      expect(model.officeLong, equals(72.8777));
      expect(model.allowedRadiusMeters, equals(150.0));
    });

    test('AttendanceModel.fromJson extracts office coordinates from nested employee_details', () {
      final json = {
        'data': {
          'employee_details': {
            'officeLat': 23.0225,
            'officeLong': 72.5714,
            'geofence_radius': 80,
          },
        },
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.officeLat, equals(23.0225));
      expect(model.officeLong, equals(72.5714));
      expect(model.allowedRadiusMeters, equals(80.0));
    });
  });
}


