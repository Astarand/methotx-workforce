import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/shared/widgets/app_bottom_nav.dart';

void main() {
  group('AppBottomNavigation Active State Tests', () {
    testWidgets('Renders with currentIndex = 0 (Dashboard selected)', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      // Label for Dashboard should be displayed
      expect(find.text('Dashboard'), findsOneWidget);
      // Other labels should not be displayed
      expect(find.text('Task'), findsNothing);
      expect(find.text('Leave'), findsNothing);
      expect(find.text('Profile'), findsNothing);

      // Tap on Task tab (index 1)
      await tester.tap(find.byIcon(Icons.assignment_outlined));
      expect(tappedIndex, 1);
    });

    testWidgets('Renders with currentIndex = null (Secondary pages like Payslip - no tab selected)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: null,
              onTap: (_) {},
            ),
          ),
        ),
      );

      // None of the selected labels should be visible
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Task'), findsNothing);
      expect(find.text('Leave'), findsNothing);
      expect(find.text('Profile'), findsNothing);

      // All 4 outline icons should be visible
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Filled active icons should NOT be visible
      expect(find.byIcon(Icons.dashboard), findsNothing);
      expect(find.byIcon(Icons.assignment), findsNothing);
      expect(find.byIcon(Icons.event_busy), findsNothing);
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });
}
