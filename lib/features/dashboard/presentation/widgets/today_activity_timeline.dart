import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';

class AttendanceBadgeInfo {
  final String label;
  final Color color;
  final String? subtitle;

  const AttendanceBadgeInfo({
    required this.label,
    required this.color,
    this.subtitle,
  });
}

AttendanceBadgeInfo getTodayAttendanceBadge({
  required String todayWorkingStatus, // 'not_present' | 'present' | 'punch_out'
  required AttendanceEntity attendance,
  required DateTime currentTime,
}) {
  final backendStatus = attendance.backendStatus?.toLowerCase() ?? '';
  final holidayName = attendance.holidayName;
  final leaveType = attendance.leaveType;

  // 1. Office Off & Holiday Check (strictly from API or weekly off)
  final isOfficeOff = attendance.isOfficeOff(currentTime) ||
      backendStatus == 'office_off' ||
      backendStatus == 'office off' ||
      backendStatus == 'officeoff' ||
      backendStatus.contains('off') ||
      backendStatus.contains('weekend') ||
      backendStatus.contains('closed');
  final isHoliday = (holidayName != null && holidayName.trim().isNotEmpty) ||
      backendStatus == 'holiday';

  if (isOfficeOff) {
    return const AttendanceBadgeInfo(
      label: 'OFFICE OFF',
      color: Color(0xFF202124), // Black
    );
  }

  if (isHoliday) {
    return AttendanceBadgeInfo(
      label: 'HOLIDAY',
      color: const Color(0xFF1967D2), // Blue
      subtitle: holidayName,
    );
  }

  // 2. On Leave Check
  if (backendStatus == 'leave' || (leaveType != null && leaveType.trim().isNotEmpty)) {
    return AttendanceBadgeInfo(
      label: 'ON LEAVE',
      color: const Color(0xFF8B5CF6), // Purple
      subtitle: leaveType,
    );
  }

  // 3. Work Completed (Punch Out)
  if (todayWorkingStatus == 'punch_out') {
    return AttendanceBadgeInfo(
      label: 'COMPLETED',
      color: const Color(0xFF0D9488), // Teal
    );
  }

  // 4. Currently Working / Punched In
  if (todayWorkingStatus == 'present' || (attendance.punchInTime != null)) {
    final isLate = attendance.isLate;

    if (isLate) {
      return AttendanceBadgeInfo(
        label: 'LATE',
        color: const Color(0xFFF59E0B), // Amber / Orange
        subtitle: null, // Subtitle omitted from top-right badge as requested
      );
    } else {
      return AttendanceBadgeInfo(
        label: 'ON TIME',
        color: const Color(0xFF10B981), // Emerald Green
      );
    }
  }

  // 5. Not Punched In Yet (Check against shift opening time & 5-minute grace period buffer)
  final graceTime = attendance.getGraceTime(currentTime);
  if (graceTime != null) {
    // If current time is still before or within the 5-minute grace period:
    if (currentTime.isBefore(graceTime) || currentTime.isAtSameMomentAs(graceTime)) {
      return AttendanceBadgeInfo(
        label: 'NOT CHECKED IN',
        color: const Color(0xFF64748B), // Slate / Gray
      );
    }
  } else {
    return AttendanceBadgeInfo(
      label: 'NOT CHECKED IN',
      color: const Color(0xFF64748B), // Slate / Gray
    );
  }

  // Shift + 5-minute grace has passed and employee hasn't punched in on a workday:
  return AttendanceBadgeInfo(
    label: 'ABSENT',
    color: const Color(0xFFEF4444), // Red
  );
}

class TodayActivityTimeline extends ConsumerWidget {
  const TodayActivityTimeline({super.key});

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatLateDuration(String? rawLateBy, DateTime? punchInTime, AttendanceEntity attendance) {
    if (rawLateBy != null && rawLateBy.trim().isNotEmpty) {
      final formatted = AppFormatters.formatLateDuration(rawLateBy);
      if (formatted.isNotEmpty) return formatted;
    }

    if (punchInTime != null && attendance.openingTime != null && attendance.openingTime!.trim().isNotEmpty) {
      final shiftStart = attendance.getShiftStartDateTime(punchInTime);
      if (shiftStart != null && punchInTime.isAfter(shiftStart)) {
        final diff = punchInTime.difference(shiftStart);
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        if (hours > 0 && mins > 0) {
          final hUnit = hours == 1 ? 'hour' : 'hours';
          final mUnit = mins == 1 ? 'minute' : 'minutes';
          return '$hours $hUnit $mins $mUnit';
        } else if (hours > 0) {
          final hUnit = hours == 1 ? 'hour' : 'hours';
          return '$hours $hUnit';
        } else if (mins > 0) {
          final mUnit = mins == 1 ? 'minute' : 'minutes';
          return '$mins $mUnit';
        } else if (diff.inSeconds > 0) {
          return '${diff.inSeconds} seconds';
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceNotifierProvider);
    final currentTime = state.trustedCurrentTime;

    final badgeInfo = getTodayAttendanceBadge(
      todayWorkingStatus: state.todayWorkingStatus,
      attendance: state.attendance,
      currentTime: currentTime,
    );

    final isPresent = state.todayWorkingStatus == 'present' ||
        state.todayWorkingStatus == 'punch_out' ||
        state.attendance.punchInTime != null;

    String checkInValue;
    if (isPresent) {
      final baseTime = state.attendance.punchInTime != null
          ? _formatTime(state.attendance.punchInTime)
          : 'Punched In';

      if (state.attendance.isLate) {
        final lateStr = _formatLateDuration(
          state.attendance.lateBy,
          state.attendance.punchInTime,
          state.attendance,
        );
        if (lateStr.isNotEmpty) {
          checkInValue = '$baseTime (Late by $lateStr)';
        } else {
          checkInValue = '$baseTime (Late)';
        }
      } else {
        checkInValue = baseTime;
      }
    } else {
      checkInValue = 'Not checked in';
    }

    final checkOutValue = state.attendance.punchOutTime != null
        ? _formatTime(state.attendance.punchOutTime)
        : 'Not checked out';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: AppShadows.low,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Activity",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeInfo.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: badgeInfo.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badgeInfo.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeInfo.color,
                      ),
                    ),
                    if (badgeInfo.subtitle != null && badgeInfo.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        badgeInfo.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: badgeInfo.color.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              // Vertical Line
              Positioned(
                left: 9,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 1.5,
                  color: AppColors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              Column(
                children: [
                  _buildTimelineRow(
                    label: 'Check In',
                    value: checkInValue,
                    isActive: isPresent,
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineRow(
                    label: 'Check Out',
                    value: checkOutValue,
                    isActive: state.attendance.punchOutTime != null,
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineRow(
                    label: 'Working Hours',
                    value: '',
                    customValueWidget: const LiveWorkingHoursText(),
                    isActive: true,
                    isHighlighted: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required String label,
    required String value,
    Widget? customValueWidget,
    required bool isActive,
    bool isHighlighted = false,
  }) {
    final dotColor = isActive
        ? (isHighlighted ? const Color(0xFF16A6A6) /* soft-teal */ : AppColors.outlineVariant)
        : AppColors.outlineVariant.withValues(alpha: 0.7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive && isHighlighted
                  ? const Color(0xFF16A6A6).withValues(alpha: 0.4)
                  : AppColors.outlineVariant,
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: 2),
            customValueWidget ??
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: isHighlighted ? 16 : 14,
                    fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                    color: isHighlighted ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class LiveWorkingHoursText extends ConsumerWidget {
  const LiveWorkingHoursText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
    final attendanceState = ref.watch(attendanceNotifierProvider);

    return Text(
      attendanceState.netWorkingHoursString(currentTime),
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }
}
