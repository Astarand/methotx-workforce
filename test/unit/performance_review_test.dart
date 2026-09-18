import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/performance/data/models/performance_review_model.dart';
import 'package:methotx_workforce/features/performance/data/repositories/performance_review_repository_impl.dart';
import 'package:methotx_workforce/features/performance/domain/entities/performance_review_entity.dart';
import 'package:methotx_workforce/features/performance/domain/repositories/performance_review_repository.dart';
import 'package:methotx_workforce/features/performance/presentation/controllers/performance_review_controller.dart';
import 'package:methotx_workforce/features/performance/presentation/screens/performance_review_details_screen.dart';
import 'package:methotx_workforce/features/performance/presentation/screens/performance_review_list_screen.dart';

class FakePerformanceReviewRepository implements PerformanceReviewRepository {
  List<PerformanceReviewEntity> mockReviews = [];
  bool shouldThrow = false;
  String errorMessage = 'Server connection error';

  @override
  Future<List<PerformanceReviewEntity>> getReviews() async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockReviews;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PerformanceReviewModel & Entity Tests', () {
    test('PerformanceReviewModel.fromJson parses complete API payload accurately', () {
      final json = {
        'review_month': '8',
        'review_year': '2026',
        'work_rating': '4',
        'skill_rating': '5',
        'attendance_rating': '4',
        'teamwork_rating': '5',
        'total_percentage': '90.00',
        'review': 'Excellent project execution, proactive communication, and leadership during sprints.',
        'created_at': '2026-08-31 17:30:00',
      };

      final model = PerformanceReviewModel.fromJson(json);
      expect(model.reviewMonth, 8);
      expect(model.reviewYear, 2026);
      expect(model.workRating, 4);
      expect(model.skillRating, 5);
      expect(model.attendanceRating, 4);
      expect(model.teamworkRating, 5);
      expect(model.totalPercentage, 90.0);
      expect(model.review, contains('Excellent project execution'));
      expect(model.createdAt.year, 2026);
      expect(model.createdAt.month, 8);
      expect(model.createdAt.day, 31);

      final entity = model.toEntity();
      expect(entity.monthName, 'August');
      expect(entity.periodTitle, 'August 2026');
      expect(entity.averageRating, 4.5);
      expect(entity.performanceGrade, 'Outstanding');
      expect(entity.percentageColor, const Color(0xFF166534)); // Green
    });

    test('Clamps ratings between 0 and 5 and handles null fallbacks safely', () {
      final json = {
        'review_month': null,
        'review_year': null,
        'work_rating': '10', // Exceeds 5
        'skill_rating': '-3', // Below 0
        'attendance_rating': null,
        'teamwork_rating': 4,
        'total_percentage': '45.5',
        'review': null,
        'created_at': null,
      };

      final model = PerformanceReviewModel.fromJson(json);
      expect(model.workRating, 5);
      expect(model.skillRating, 0);
      expect(model.attendanceRating, 0);
      expect(model.teamworkRating, 4);
      expect(model.totalPercentage, 45.5);
      expect(model.review, '');

      final entity = model.toEntity();
      expect(entity.performanceGrade, 'Needs Improvement');
      expect(entity.percentageColor, const Color(0xFFDC2626)); // Red
    });

    test('Performance grades and colors match scale correctly', () {
      final review85 = PerformanceReviewEntity(
        reviewMonth: 8,
        reviewYear: 2026,
        workRating: 5,
        skillRating: 5,
        attendanceRating: 4,
        teamworkRating: 4,
        totalPercentage: 85.0,
        review: 'Superb',
        createdAt: DateTime(2026, 8, 31),
      );
      expect(review85.performanceGrade, 'Outstanding');

      final review70 = PerformanceReviewEntity(
        reviewMonth: 7,
        reviewYear: 2026,
        workRating: 4,
        skillRating: 4,
        attendanceRating: 3,
        teamworkRating: 4,
        totalPercentage: 72.0,
        review: 'Good work',
        createdAt: DateTime(2026, 7, 31),
      );
      expect(review70.performanceGrade, 'Good');
      expect(review70.percentageColor, const Color(0xFF0284C7)); // Blue

      final review50 = PerformanceReviewEntity(
        reviewMonth: 6,
        reviewYear: 2026,
        workRating: 3,
        skillRating: 3,
        attendanceRating: 2,
        teamworkRating: 3,
        totalPercentage: 55.0,
        review: 'Average',
        createdAt: DateTime(2026, 6, 30),
      );
      expect(review50.performanceGrade, 'Satisfactory');
      expect(review50.percentageColor, const Color(0xFFD97706)); // Orange

      final review30 = PerformanceReviewEntity(
        reviewMonth: 5,
        reviewYear: 2026,
        workRating: 2,
        skillRating: 2,
        attendanceRating: 1,
        teamworkRating: 1,
        totalPercentage: 35.0,
        review: 'Needs attention',
        createdAt: DateTime(2026, 5, 31),
      );
      expect(review30.performanceGrade, 'Needs Improvement');
      expect(review30.percentageColor, const Color(0xFFDC2626)); // Red
    });

    test('PerformanceReviewState filters reviews by selectedYear accurately', () {
      final r2026 = PerformanceReviewEntity(
        reviewMonth: 8,
        reviewYear: 2026,
        workRating: 5,
        skillRating: 5,
        attendanceRating: 4,
        teamworkRating: 4,
        totalPercentage: 88.0,
        review: '2026 review',
        createdAt: DateTime(2026, 8, 31),
      );
      final r2025 = PerformanceReviewEntity(
        reviewMonth: 12,
        reviewYear: 2025,
        workRating: 4,
        skillRating: 4,
        attendanceRating: 4,
        teamworkRating: 4,
        totalPercentage: 78.0,
        review: '2025 review',
        createdAt: DateTime(2025, 12, 31),
      );

      final state = PerformanceReviewState(
        reviews: [r2026, r2025],
        selectedYear: 2026,
      );

      expect(state.availableYears, containsAll([2026, 2025]));
      expect(state.filteredReviews.length, 1);
      expect(state.filteredReviews.first.reviewYear, 2026);

      final state2025 = state.copyWith(selectedYear: 2025);
      expect(state2025.filteredReviews.length, 1);
      expect(state2025.filteredReviews.first.reviewYear, 2025);

      final stateAll = state.copyWith(selectedYear: null);
      expect(stateAll.filteredReviews.length, 2);
    });
  });

  group('Performance Review Presentation & Widget Tests', () {
    late FakePerformanceReviewRepository fakeRepo;

    final review2026 = PerformanceReviewEntity(
      reviewMonth: 8,
      reviewYear: 2026,
      workRating: 4,
      skillRating: 5,
      attendanceRating: 4,
      teamworkRating: 5,
      totalPercentage: 90.0,
      review: 'Top notch contribution across frontend and backend modules.',
      createdAt: DateTime(2026, 8, 31, 17, 30),
    );

    final review2025 = PerformanceReviewEntity(
      reviewMonth: 11,
      reviewYear: 2025,
      workRating: 4,
      skillRating: 4,
      attendanceRating: 4,
      teamworkRating: 4,
      totalPercentage: 75.0,
      review: 'Consistent delivery on sprint targets.',
      createdAt: DateTime(2025, 11, 30, 16, 0),
    );

    setUp(() {
      fakeRepo = FakePerformanceReviewRepository();
    });

    testWidgets('Renders empty state when review list is empty', (tester) async {
      fakeRepo.mockReviews = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            performanceReviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: PerformanceReviewListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Performance Reviews'), findsOneWidget);
      expect(find.text('No Performance Reviews'), findsOneWidget);
      expect(find.textContaining('No appraisal records have been published'), findsOneWidget);
    });

    testWidgets('Renders error state when repository throws error', (tester) async {
      fakeRepo.shouldThrow = true;
      fakeRepo.errorMessage = 'Network connection failed';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            performanceReviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: PerformanceReviewListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Reviews'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Renders review cards correctly with month badge and feedback preview', (tester) async {
      fakeRepo.mockReviews = [review2026];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            performanceReviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: PerformanceReviewListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('AUG'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget);
      expect(find.text('4.5 / 5.0 Avg'), findsOneWidget);
      expect(find.textContaining('Top notch contribution across'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('Yearly dropdown filter switches displayed reviews between years', (tester) async {
      fakeRepo.mockReviews = [review2026, review2025];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            performanceReviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: PerformanceReviewListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // By default, 2026 is selected
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('November 2025'), findsNothing);

      // Tap Dropdown to select 2025
      await tester.tap(find.text('Year 2026'));
      await tester.pumpAndSettle();

      // Tap Year 2025 in dropdown menu
      await tester.tap(find.text('Year 2025').last);
      await tester.pumpAndSettle();

      // 2025 review should now be visible and 2026 hidden
      expect(find.text('November 2025'), findsOneWidget);
      expect(find.text('August 2026'), findsNothing);

      // Tap Dropdown to select All Years
      await tester.tap(find.text('Year 2025'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Years').last);
      await tester.pumpAndSettle();

      // Both reviews should now be visible
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('November 2025'), findsOneWidget);
    });

    testWidgets('Renders PerformanceReviewDetailsScreen with all breakdown sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceReviewDetailsScreen(review: review2026),
        ),
      );

      await tester.pumpAndSettle();

      // Title
      expect(find.text('August 2026'), findsOneWidget);

      // Overall Score
      expect(find.text('Performance Score'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget);

      // Metrics Breakdown
      expect(find.text('Rating Metrics'), findsOneWidget);
      expect(find.text('Work Performance'), findsOneWidget);
      expect(find.text('Skill & Technicality'), findsOneWidget);
      expect(find.text('Attendance & Punctuality'), findsOneWidget);
      expect(find.text('Teamwork & Collaboration'), findsOneWidget);

      // Feedback
      expect(find.text('Manager Feedback'), findsOneWidget);
      expect(find.text(review2026.review), findsOneWidget);

      // Footer
      expect(find.text('Reviewed on:'), findsOneWidget);
    });
  });
}
