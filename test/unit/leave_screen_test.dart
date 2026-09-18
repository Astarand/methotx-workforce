import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/leave/presentation/widgets/leave_balance_card.dart';
import 'package:methotx_workforce/features/leave/presentation/widgets/leave_details_sheet.dart';
import 'package:methotx_workforce/features/leave/domain/entities/leave_entity.dart';
import 'package:methotx_workforce/shared/models/attendance_record_model.dart';
import 'package:methotx_workforce/shared/models/leave_model.dart';
import 'package:methotx_workforce/shared/widgets/app_buttons.dart';

void main() {
  group('Leave Management Screen & Balance Card Tests', () {
    testWidgets('LeaveBalanceCards displays Coming Soon badge on each leave card', (tester) async {
      const balances = [
        LeaveBalanceEntity(
          type: LeaveType.casual,
          title: 'Casual Leave',
          total: 12,
          used: 4,
          remaining: 8,
        ),
        LeaveBalanceEntity(
          type: LeaveType.sick,
          title: 'Sick Leave',
          total: 8,
          used: 3,
          remaining: 5,
        ),
        LeaveBalanceEntity(
          type: LeaveType.paid,
          title: 'Paid Leave',
          total: 15,
          used: 5,
          remaining: 10,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveBalanceCards(balances: balances),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('Sick Leave'), findsOneWidget);
      expect(find.text('Paid Leave'), findsOneWidget);

      // Verify that 'Coming Soon' is rendered 3 times (for each leave type card)
      expect(find.text('Coming Soon'), findsNWidgets(3));
    });

    testWidgets('PrimaryButton renders within constrained width without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 104,
              child: PrimaryButton(
                title: 'Apply',
                height: 40,
                width: 104,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('Tapping a LeaveBalanceCard opens balance quota info modal sheet', (tester) async {
      const balances = [
        LeaveBalanceEntity(
          type: LeaveType.casual,
          title: 'Casual Leave',
          total: 12,
          used: 4,
          remaining: 8,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveBalanceCards(balances: balances),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Casual Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Quota and Balance Information'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Quota and Balance Information'), findsNothing);
    });

    testWidgets('LeaveDetailsSheet.showFromDayRecord opens and displays leave details modal', (tester) async {
      final dayRecord = AttendanceDayRecord(
        date: DateTime(2026, 9, 10),
        status: AttendanceStatus.leave,
        leaveType: 'Casual',
        notes: 'Personal work',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => LeaveDetailsSheet.showFromDayRecord(
                    context,
                    record: dayRecord,
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify modal sheet is opened and renders full leave metadata
      expect(find.text('Leave Request Details'), findsOneWidget);
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('Personal work'), findsOneWidget);
      expect(find.text('Reason for Leave'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Request Details'), findsNothing);
    });

    test('LeaveApplicationModel resolves numeric approver ID 2 to Management and extracts human names', () {
      // Case 1: Backend sends numeric ID 2
      final modelWithId = LeaveApplicationModel.fromJson({
        'id': 15,
        'leave_type': 'sick',
        'status': 'approved',
        'approved_by': 2,
        'from_date': '2026-09-08',
        'to_date': '2026-09-08',
        'reason': 'fever',
      });
      expect(modelWithId.approvedBy, 'Management');
      expect(modelWithId.formattedApprover, 'Management');
      expect(modelWithId.toEntity().formattedApprover, 'Management');

      // Case 2: Backend sends string numeric ID "2"
      final modelWithStringId = LeaveApplicationModel.fromJson({
        'id': 16,
        'leave_type': 'casual',
        'status': 'approved',
        'approved_by': '2',
        'from_date': '2026-09-10',
        'to_date': '2026-09-10',
      });
      expect(modelWithStringId.approvedBy, 'Management');
      expect(modelWithStringId.formattedApprover, 'Management');

      // Case 3: Backend sends dedicated approver name
      final modelWithName = LeaveApplicationModel.fromJson({
        'id': 17,
        'leave_type': 'paid',
        'status': 'approved',
        'approved_by': 2,
        'approver_name': 'Subrata Sen',
        'from_date': '2026-09-12',
        'to_date': '2026-09-12',
      });
      expect(modelWithName.approvedBy, 'Subrata Sen');
      expect(modelWithName.formattedApprover, 'Subrata Sen');

      // Case 4: Backend sends approver object with first and last name
      final modelWithObj = LeaveApplicationModel.fromJson({
        'id': 18,
        'leave_type': 'sick',
        'status': 'approved',
        'approver': {
          'first_name': 'Vikram',
          'last_name': 'Roy',
        },
        'from_date': '2026-09-15',
        'to_date': '2026-09-15',
      });
      expect(modelWithObj.approvedBy, 'Vikram Roy');
      expect(modelWithObj.formattedApprover, 'Vikram Roy');

      // Case 5: Entity with raw '2' in cache formats safely to Management
      final entityWithRaw2 = LeaveApplicationEntity(
        id: '19',
        type: LeaveType.sick,
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 8),
        numberOfDays: 1,
        reason: 'fever',
        status: LeaveStatus.approved,
        appliedOn: DateTime(2026, 9, 5),
        approvedBy: '2',
      );
      expect(entityWithRaw2.formattedApprover, 'Management');
    });

    testWidgets('LeaveDetailsSheet displays Management and NOT raw ID 2 when approver is numeric 2', (tester) async {
      final leaveWithRaw2 = LeaveApplicationEntity(
        id: 'leave-test-2',
        type: LeaveType.sick,
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 8),
        numberOfDays: 1,
        reason: 'fever',
        status: LeaveStatus.approved,
        appliedOn: DateTime(2026, 9, 5, 14, 50),
        approvedBy: '2',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => LeaveDetailsSheet.show(
                    context,
                    leave: leaveWithRaw2,
                  ),
                  child: const Text('Open Details'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Verify header and fields
      expect(find.text('Leave Request Details'), findsOneWidget);
      expect(find.text('Sick Leave'), findsOneWidget);
      expect(find.text('Approver'), findsOneWidget);

      // Verify 'Management' is displayed and raw '2' is NOT displayed as the Approver value
      expect(find.text('Management'), findsOneWidget);
      expect(find.widgetWithText(Row, '2'), findsNothing);
    });
  });
}

