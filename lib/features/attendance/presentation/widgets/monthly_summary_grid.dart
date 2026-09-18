import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/attendance_record_model.dart';

class MonthlySummaryGrid extends StatelessWidget {
  final MonthlyAttendanceSummary summary;
  final int? holidayCountOverride;

  const MonthlySummaryGrid({
    super.key,
    required this.summary,
    this.holidayCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    final displayHolidayCount = holidayCountOverride ?? summary.holidayCount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.check,
                iconBg: const Color(0xFFE6F4EA),
                iconColor: const Color(0xFF137333),
                label: 'Present',
                count: summary.presentCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.close,
                iconBg: const Color(0xFFFCE8E6),
                iconColor: const Color(0xFFC5221F),
                label: 'Absent',
                count: summary.absentCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.flight_takeoff,
                iconBg: const Color(0xFFFEF7E0),
                iconColor: const Color(0xFFE37400),
                label: 'Leave',
                count: summary.leaveCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.beach_access,
                iconBg: const Color(0xFFE8F0FE),
                iconColor: const Color(0xFF1967D2),
                label: 'Holiday',
                count: displayHolidayCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.domain_disabled,
                iconBg: const Color(0xFFE8EAED),
                iconColor: const Color(0xFF202124),
                label: 'Office Off',
                count: summary.officeOffCount.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String count,
  }) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(22, 126, 149, 0.03),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.labelTiny.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          Text(
            count,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
