import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Domain entity representing an employee monthly performance review
class PerformanceReviewEntity {
  final int reviewMonth;
  final int reviewYear;
  final int workRating;
  final int skillRating;
  final int attendanceRating;
  final int teamworkRating;
  final double totalPercentage;
  final String review;
  final DateTime createdAt;

  const PerformanceReviewEntity({
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

  /// Human-readable month name (e.g., "August")
  String get monthName {
    if (reviewMonth < 1 || reviewMonth > 12) return '-';
    return DateFormat('MMMM').format(DateTime(2026, reviewMonth));
  }

  /// Review period display title (e.g. "August 2026")
  String get periodTitle {
    if (monthName == '-') return 'Review $reviewYear';
    return '$monthName $reviewYear';
  }

  /// Formatted creation timestamp (e.g. "31 Aug 2026, 05:30 PM")
  String get formattedCreatedDate =>
      DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);

  /// Average star rating out of 5
  double get averageRating =>
      (workRating + skillRating + attendanceRating + teamworkRating) / 4.0;

  /// Performance Grade text
  String get performanceGrade {
    if (totalPercentage >= 85) return 'Outstanding';
    if (totalPercentage >= 70) return 'Good';
    if (totalPercentage >= 50) return 'Satisfactory';
    return 'Needs Improvement';
  }

  /// Percentage badge text color
  Color get percentageColor {
    if (totalPercentage >= 85) return const Color(0xFF166534); // Green
    if (totalPercentage >= 70) return const Color(0xFF0284C7); // Blue
    if (totalPercentage >= 50) return const Color(0xFFD97706); // Orange
    return const Color(0xFFDC2626); // Red
  }

  /// Percentage badge background color
  Color get percentageBgColor {
    if (totalPercentage >= 85) return const Color(0xFFDCFCE7);
    if (totalPercentage >= 70) return const Color(0xFFE0F2FE);
    if (totalPercentage >= 50) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  /// Progress bar fill color
  Color get progressFillColor {
    if (totalPercentage >= 85) return const Color(0xFF10B981);
    if (totalPercentage >= 70) return const Color(0xFF0284C7);
    if (totalPercentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceReviewEntity &&
          runtimeType == other.runtimeType &&
          reviewMonth == other.reviewMonth &&
          reviewYear == other.reviewYear &&
          totalPercentage == other.totalPercentage &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      reviewMonth.hashCode ^
      reviewYear.hashCode ^
      totalPercentage.hashCode ^
      createdAt.hashCode;
}
