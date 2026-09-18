import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';

class DashboardSummaryCards extends StatelessWidget {
  const DashboardSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildDurationCard(
            title: 'Break Taken',
            duration: '',
            customDurationWidget: const LiveBreakText(),
            icon: Icons.coffee_rounded,
            color: const Color(0xFFD97706),
            bgColor: AppColors.warningContainer.withValues(alpha: 0.25),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDurationCard(
            title: 'Tiffin Taken',
            duration: '',
            customDurationWidget: const LiveTiffinText(),
            icon: Icons.restaurant_rounded,
            color: AppColors.primary,
            bgColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationCard({
    required String title,
    required String duration,
    Widget? customDurationWidget,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          customDurationWidget ?? Text(
            duration,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveBreakText extends ConsumerWidget {
  const LiveBreakText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
    final attendanceState = ref.watch(attendanceNotifierProvider);
    
    return Text(
      attendanceState.totalBreakString(currentTime),
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}

class LiveTiffinText extends ConsumerWidget {
  const LiveTiffinText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
    final attendanceState = ref.watch(attendanceNotifierProvider);
    
    return Text(
      attendanceState.totalTiffinString(currentTime),
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}
