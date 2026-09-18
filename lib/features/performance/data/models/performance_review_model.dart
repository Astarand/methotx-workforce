import '../../domain/entities/performance_review_entity.dart';

class PerformanceReviewModel {
  final int reviewMonth;
  final int reviewYear;
  final int workRating;
  final int skillRating;
  final int attendanceRating;
  final int teamworkRating;
  final double totalPercentage;
  final String review;
  final DateTime createdAt;

  const PerformanceReviewModel({
    required this.reviewMonth,
    required this.reviewYear,
    required this.workRating,
    required this.skillRating,
    required this.attendanceRating,
    required this.teamworkRating,
    required this.totalPercentage,
    required this.review,
    required this.createdAt,
  });

  factory PerformanceReviewModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        return int.tryParse(val.trim()) ??
            double.tryParse(val.trim())?.toInt() ??
            fallback;
      }
      return fallback;
    }

    int parseRating(dynamic val) {
      final parsed = parseInt(val, 0);
      return parsed.clamp(0, 5);
    }

    double parseDouble(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.trim()) ?? fallback;
      return fallback;
    }

    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(str);
      } catch (_) {
        // Try parsing "yyyy-MM-dd HH:mm:ss" if not ISO
        try {
          return DateTime.parse(str.replaceAll(' ', 'T'));
        } catch (_) {
          return DateTime.now();
        }
      }
    }

    return PerformanceReviewModel(
      reviewMonth: parseInt(json['review_month'] ?? json['reviewMonth'] ?? json['month'], 0),
      reviewYear: parseInt(json['review_year'] ?? json['reviewYear'] ?? json['year'], DateTime.now().year),
      workRating: parseRating(json['work_rating'] ?? json['workRating']),
      skillRating: parseRating(json['skill_rating'] ?? json['skillRating']),
      attendanceRating: parseRating(json['attendance_rating'] ?? json['attendanceRating']),
      teamworkRating: parseRating(json['teamwork_rating'] ?? json['teamworkRating']),
      totalPercentage: parseDouble(json['total_percentage'] ?? json['totalPercentage'] ?? json['percentage']),
      review: (json['review'] ?? json['comments'] ?? json['feedback'] ?? '').toString().trim(),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt'] ?? json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'review_month': reviewMonth,
      'review_year': reviewYear,
      'work_rating': workRating,
      'skill_rating': skillRating,
      'attendance_rating': attendanceRating,
      'teamwork_rating': teamworkRating,
      'total_percentage': totalPercentage,
      'review': review,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PerformanceReviewEntity toEntity() {
    return PerformanceReviewEntity(
      reviewMonth: reviewMonth,
      reviewYear: reviewYear,
      workRating: workRating,
      skillRating: skillRating,
      attendanceRating: attendanceRating,
      teamworkRating: teamworkRating,
      totalPercentage: totalPercentage,
      review: review,
      createdAt: createdAt,
    );
  }
}
