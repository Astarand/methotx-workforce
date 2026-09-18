import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';

class OutsideOfficeCard extends ConsumerWidget {
  const OutsideOfficeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceNotifierProvider);

    final isWFO = state.isWFO && !state.isWFH;
    if (!isWFO) return const SizedBox.shrink();

    final isShiftEnded = state.todayWorkingStatus == 'punch_out';
    final isOutsideNow = state.isCurrentlyOutside && !isShiftEnded;

    final statusText = isShiftEnded
        ? 'Shift Ended'
        : (isOutsideNow ? 'Currently Outside' : 'Inside Premises');

    final statusColor = isShiftEnded
        ? const Color(0xFF64748B)
        : (isOutsideNow ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    final iconData = isShiftEnded
        ? Icons.check_circle_outline_rounded
        : (isOutsideNow ? Icons.location_off_rounded : Icons.directions_walk_rounded);

    final iconColor = isShiftEnded
        ? const Color(0xFF64748B)
        : (isOutsideNow ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutsideNow
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : AppColors.outlineVariant.withValues(alpha: 0.5),
          width: isOutsideNow ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.low,
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title and Status Indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outside Office',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isOutsideNow
                            ? const Color(0xFFEF4444)
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Outside Duration Value (Isolated scoped ticker)
          LiveOutsideDurationText(isOutsideNow: isOutsideNow),
        ],
      ),
    );
  }
}

class LiveOutsideDurationText extends ConsumerWidget {
  final bool isOutsideNow;

  const LiveOutsideDurationText({
    super.key,
    required this.isOutsideNow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
    final state = ref.watch(attendanceNotifierProvider);

    return Text(
      state.totalOutsideString(currentTime),
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isOutsideNow
            ? const Color(0xFFEF4444)
            : AppColors.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }
}
