import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/attendance_record_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/attendance_notifier.dart';
import '../widgets/monthly_summary_grid.dart';
import '../widgets/attendance_calendar_view.dart';
import '../widgets/daily_overview_card.dart';
import '../widgets/holiday_list_sheet.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceControllerProvider);
    final controller = ref.read(attendanceControllerProvider.notifier);

    final monthString = DateFormat('MMMM yyyy').format(state.selectedMonth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.md,
            AppSpacing.marginMobile,
            120.0, // prevent bottom navigation overlap
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance History',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          monthString,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HolidayListSheet.show(context, state.holidayList);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_note,
                            size: 16,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Show Holiday List',
                            style: AppTypography.labelSmall.copyWith(
                              color: const Color(0xFFEA580C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Monthly Summary Grid with Dynamic Holiday Count for Current Month
              MonthlySummaryGrid(
                summary: state.summary,
                holidayCountOverride: state.currentMonthHolidayCount,
              ),
              const SizedBox(height: 18),

              // Calendar View with Eradicated Future Red Dots & Live Synchronization
              AttendanceCalendarView(
                selectedMonth: state.selectedMonth,
                selectedDate: state.selectedDate,
                records: state.monthRecords,
                holidayList: state.holidayList,
                onDateSelected: (date) => controller.selectDate(date),
                onPreviousMonth: () => controller.previousMonth(),
                onNextMonth: () => controller.nextMonth(),
              ),
              const SizedBox(height: 18),

              // Daily Overview Card with Isolated Real-time Live Synchronization
              AttendanceDailyOverviewSection(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isolated widget for Daily Overview to prevent 1 Hz clock ticks from rebuilding
/// the calendar, summary grid, and entire AttendanceHistoryScreen.
class AttendanceDailyOverviewSection extends ConsumerWidget {
  final AttendanceHistoryState state;

  const AttendanceDailyOverviewSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedStart = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );

    final isToday = selectedStart.isAtSameMomentAs(todayStart);
    final isFuture = selectedStart.isAfter(todayStart);

    final liveAttendanceState = ref.watch(attendanceNotifierProvider);
    final isCurrentlyWorking = liveAttendanceState.todayWorkingStatus == 'present' ||
        liveAttendanceState.isPunchedIn;

    AttendanceDayRecord overviewRecord;

    // 🔴 CASE A: TODAY'S DATE & CURRENT SHIFT (Live Sync with Dashboard State)
    if (isToday &&
        (isCurrentlyWorking ||
            liveAttendanceState.attendance.punchInTime != null ||
            liveAttendanceState.todayWorkingStatus == 'punch_out')) {
      final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
      final punchIn = liveAttendanceState.attendance.punchInTime;
      final punchOut = liveAttendanceState.attendance.punchOutTime;

      final inTimeStr = punchIn != null
          ? AppFormatters.time12Hour.format(punchIn)
          : AppFormatters.formatTime12Hour(state.selectedDayOverview.checkInTime);

      final outTimeStr = liveAttendanceState.todayWorkingStatus == 'punch_out'
          ? (punchOut != null
              ? AppFormatters.time12Hour.format(punchOut)
              : 'Punched Out')
          : (isCurrentlyWorking
              ? 'Active Shift'
              : AppFormatters.formatTime12Hour(state.selectedDayOverview.checkOutTime));

      final netWork = liveAttendanceState.liveNetWorkingDuration(currentTime);

      var breakDur = liveAttendanceState.totalBreakDuration;
      if (liveAttendanceState.isOnBreak &&
          liveAttendanceState.attendance.breakInTime != null) {
        breakDur +=
            currentTime.difference(liveAttendanceState.attendance.breakInTime!);
      }

      var lunchDur = liveAttendanceState.totalLunchDuration;
      if (liveAttendanceState.isOnTiffin &&
          liveAttendanceState.attendance.lunchInTime != null) {
        lunchDur +=
            currentTime.difference(liveAttendanceState.attendance.lunchInTime!);
      }

      var outsideDur = liveAttendanceState.totalOutsideDuration;
      if (liveAttendanceState.isCurrentlyOutside &&
          liveAttendanceState.outsideStartTime != null) {
        outsideDur +=
            currentTime.difference(liveAttendanceState.outsideStartTime!);
      }

      overviewRecord = AttendanceDayRecord(
        date: state.selectedDate,
        status: AttendanceStatus.present,
        checkInTime: inTimeStr,
        checkOutTime: outTimeStr,
        workingDuration: netWork,
        breakDuration: breakDur,
        lunchDuration: lunchDur,
        outsideOfficeDuration: outsideDur,
        isLate: liveAttendanceState.attendance.isLate,
        lateBy: AppFormatters.formatLateDuration(liveAttendanceState.attendance.lateBy),
        holidayName: state.selectedDayOverview.holidayName,
        leaveType: state.selectedDayOverview.leaveType,
      );
    }
    // 🔴 CASE B: FUTURE DATE
    else if (isFuture) {
      final holiday = getHolidayForDate(state.selectedDate, state.holidayList);
      final monthRec = state.monthRecords.where((r) =>
          r.date.year == state.selectedDate.year &&
          r.date.month == state.selectedDate.month &&
          r.date.day == state.selectedDate.day).firstOrNull;
      final isOfficeOff = monthRec?.status == AttendanceStatus.officeOff ||
          state.selectedDayOverview.status == AttendanceStatus.officeOff;
      final isLeave = monthRec?.status == AttendanceStatus.leave ||
          state.selectedDayOverview.status == AttendanceStatus.leave;

      if (holiday != null) {
        final hName = holiday['name']?.toString() ?? 'Company Holiday';
        final hType = holiday['type']?.toString() ?? 'Holiday';
        overviewRecord = AttendanceDayRecord(
          date: state.selectedDate,
          status: AttendanceStatus.holiday,
          holidayName: '$hName • $hType',
          checkInTime: 'Office Holiday',
          checkOutTime: 'Office Holiday',
        );
      } else if (isOfficeOff) {
        overviewRecord = AttendanceDayRecord(
          date: state.selectedDate,
          status: AttendanceStatus.officeOff,
          checkInTime: 'Office Off',
          checkOutTime: 'Office Off',
        );
      } else if (isLeave) {
        overviewRecord = AttendanceDayRecord(
          date: state.selectedDate,
          status: AttendanceStatus.leave,
          leaveType: state.selectedDayOverview.leaveType ?? monthRec?.leaveType ?? 'Approved Leave',
          notes: state.selectedDayOverview.notes ?? monthRec?.notes,
          checkInTime: 'On Leave',
          checkOutTime: 'On Leave',
        );
      } else {
        overviewRecord = AttendanceDayRecord(
          date: state.selectedDate,
          status: AttendanceStatus.notRecorded,
          checkInTime: 'Not arrived yet',
          checkOutTime: 'Not arrived yet',
          workingDuration: Duration.zero,
          breakDuration: Duration.zero,
          lunchDuration: Duration.zero,
          outsideOfficeDuration: Duration.zero,
        );
      }
    }
    // 🔴 CASE C: PAST DATE (Use API record)
    else {
      overviewRecord = state.selectedDayOverview;
    }

    return DailyOverviewCard(
      overview: overviewRecord,
      isLoading: state.isOverviewLoading,
    );
  }
}
