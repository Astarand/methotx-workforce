import '../entities/performance_review_entity.dart';

abstract class PerformanceReviewRepository {
  Future<List<PerformanceReviewEntity>> getReviews();
}
