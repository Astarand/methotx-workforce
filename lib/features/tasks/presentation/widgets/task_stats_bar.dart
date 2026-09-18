import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class TaskStatsBar extends StatelessWidget {
  final Map<String, int> stats;

  const TaskStatsBar({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.today,
            iconColor: AppColors.primary,
            label: 'Due Today',
            count: stats['dueToday']?.toString() ?? '2',
            bgColor: AppColors.surfaceContainerLow,
            borderColor: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.pending_outlined,
            iconColor: AppColors.primaryContainer,
            label: 'In Progress',
            count: stats['inProgress']?.toString() ?? '3',
            bgColor: AppColors.surfaceContainerLow,
            borderColor: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF0B8043),
            label: 'Completed',
            count: stats['completed']?.toString() ?? '12',
            bgColor: AppColors.surfaceContainerLow,
            borderColor: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            label: 'Overdue',
            count: stats['overdue']?.toString() ?? '1',
            bgColor: AppColors.errorContainer.withValues(alpha: 0.3),
            borderColor: AppColors.errorContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String count,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: 114,
      height: 94,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelTiny.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                count,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
