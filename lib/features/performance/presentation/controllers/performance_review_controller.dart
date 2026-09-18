import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/performance_review_entity.dart';
import '../../domain/repositories/performance_review_repository.dart';
import '../../data/repositories/performance_review_repository_impl.dart';

const Object _sentinel = Object();

class PerformanceReviewState {
  final List<PerformanceReviewEntity> reviews;
  final bool isLoading;
  final String? errorMessage;
  final int? selectedYear;

  const PerformanceReviewState({
    this.reviews = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedYear,
  });

  PerformanceReviewState copyWith({
    List<PerformanceReviewEntity>? reviews,
    bool? isLoading,
    String? errorMessage,
    Object? selectedYear = _sentinel,
  }) {
    return PerformanceReviewState(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedYear: selectedYear == _sentinel
          ? this.selectedYear
          : (selectedYear as int?),
    );
  }

  /// Available years extracted from reviews + current year, sorted descending
  List<int> get availableYears {
    final currentYear = DateTime.now().year;
    final years = reviews
        .map((r) => r.reviewYear)
        .where((y) => y > 1900 && y < 2100)
        .toSet();
    years.add(currentYear);
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Reviews filtered by selectedYear (if null, returns all reviews)
  List<PerformanceReviewEntity> get filteredReviews {
    if (selectedYear == null) {
      return reviews;
    }
    return reviews.where((r) => r.reviewYear == selectedYear).toList();
  }

  int get totalReviews => filteredReviews.length;
}

class PerformanceReviewController extends StateNotifier<PerformanceReviewState> {
  final PerformanceReviewRepository _repository;

  PerformanceReviewController(this._repository)
      : super(PerformanceReviewState(selectedYear: DateTime.now().year)) {
    loadReviews();
  }

  void setYear(int? year) {
    if (state.selectedYear == year) return;
    state = state.copyWith(selectedYear: year);
  }

  Future<void> loadReviews() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final reviews = await _repository.getReviews();

      // If currently selected year has no reviews, but there are reviews in other years,
      // fallback to the latest year available so the user sees results immediately.
      int? year = state.selectedYear;
      if (year != null &&
          reviews.isNotEmpty &&
          !reviews.any((r) => r.reviewYear == year)) {
        year = reviews.first.reviewYear;
      }

      state = state.copyWith(
        reviews: reviews,
        isLoading: false,
        errorMessage: null,
        selectedYear: year,
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
      );
    }
  }
}

final performanceReviewControllerProvider =
    StateNotifierProvider<PerformanceReviewController, PerformanceReviewState>((ref) {
  final repository = ref.watch(performanceReviewRepositoryProvider);
  return PerformanceReviewController(repository);
});
