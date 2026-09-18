import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/attendance_record_model.dart';
import '../controllers/attendance_notifier.dart';

final _holidayDateCache = <String, DateTime?>{};

final _dfDashDay = DateFormat('dd-MM-yyyy');
final _dfDashYear = DateFormat('yyyy-MM-dd');
final _dfSlashDay = DateFormat('dd/MM/yyyy');
final _dfSlashYear = DateFormat('yyyy/MM/dd');
final _dfTextShort = DateFormat('dd MMM yyyy');
final _dfTextFull = DateFormat('dd MMMM yyyy');

DateTime? parseHolidayDate(String? rawDate) {
  if (rawDate == null || rawDate.trim().isEmpty) return null;
  final clean = rawDate.trim();
  if (_holidayDateCache.containsKey(clean)) {
    return _holidayDateCache[clean];
  }

  // 1. Fast ISO-8601 path (no exception overhead)
  final parsed = DateTime.tryParse(clean);
  if (parsed != null) {
    _holidayDateCache[clean] = parsed;
    return parsed;
  }

  // 2. Structured matching to avoid throwing across all formatters
  DateTime? result;
  if (clean.contains('-')) {
    try {
      result = _dfDashDay.parseLoose(clean);
    } catch (_) {
      try {
        result = _dfDashYear.parseLoose(clean);
      } catch (_) {}
    }
  } else if (clean.contains('/')) {
    try {
      result = _dfSlashDay.parseLoose(clean);
    } catch (_) {
      try {
        result = _dfSlashYear.parseLoose(clean);
      } catch (_) {}
    }
  } else {
    try {
      result = _dfTextShort.parseLoose(clean);
    } catch (_) {
      try {
        result = _dfTextFull.parseLoose(clean);
      } catch (_) {}
    }
  }

  _holidayDateCache[clean] = result;
  return result;
}

Map<String, dynamic>? getHolidayForDate(
    DateTime targetDate, List<Map<String, dynamic>> holidays) {
  for (final h in holidays) {
    final rawDate = h['date']?.toString() ??
        h['holiday_date']?.toString() ??
        h['holidayDate']?.toString();
    final parsed = parseHolidayDate(rawDate);
    if (parsed != null &&
        parsed.year == targetDate.year &&
        parsed.month == targetDate.month &&
        parsed.day == targetDate.day) {
      return h;
    }
  }
  return null;
}

int getHolidayCountForMonth(
    DateTime month, List<Map<String, dynamic>> holidays) {
  int count = 0;
  for (final h in holidays) {
    final rawDate = h['date']?.toString() ??
        h['holiday_date']?.toString() ??
        h['holidayDate']?.toString();
    final parsed = parseHolidayDate(rawDate);
    if (parsed != null &&
        parsed.year == month.year &&
        parsed.month == month.month) {
      count++;
    }
  }
  return count;
}

class AttendanceCalendarView extends ConsumerWidget {
  final DateTime selectedMonth;
  final DateTime selectedDate;
  final List<AttendanceDayRecord> records;
  final List<Map<String, dynamic>> holidayList;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const AttendanceCalendarView({
    super.key,
    required this.selectedMonth,
    required this.selectedDate,
    required this.records,
    this.holidayList = const [],
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAttendanceState = ref.watch(attendanceNotifierProvider);
    final isTodayWorking = liveAttendanceState.isPunchedIn ||
        liveAttendanceState.todayWorkingStatus == 'present' ||
        liveAttendanceState.attendance.punchInTime != null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final monthTitle = DateFormat('MMMM yyyy').format(selectedMonth);
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday;
    // DateTime weekday: 1 = Monday, 7 = Sunday. For Sunday-first calendar:
    final offset = firstWeekday % 7;

    // Pre-index records and holidays for O(1) cell lookup instead of O(N) linear scans with parser overhead
    final Map<int, AttendanceDayRecord> recordsByDay = {
      for (final r in records)
        if (r.date.year == selectedMonth.year && r.date.month == selectedMonth.month)
          r.date.day: r
    };

    final Map<int, Map<String, dynamic>> holidaysByDay = {};
    for (final h in holidayList) {
      final rawDate = h['date']?.toString() ??
          h['holiday_date']?.toString() ??
          h['holidayDate']?.toString();
      final parsed = parseHolidayDate(rawDate);
      if (parsed != null &&
          parsed.year == selectedMonth.year &&
          parsed.month == selectedMonth.month) {
        holidaysByDay[parsed.day] = h;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(22, 126, 149, 0.04),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.onSurfaceVariant),
                onPressed: onPreviousMonth,
                splashRadius: 20,
              ),
              Text(
                monthTitle,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                onPressed: onNextMonth,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Days Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _DayHeaderCell('S'),
              _DayHeaderCell('M'),
              _DayHeaderCell('T'),
              _DayHeaderCell('W'),
              _DayHeaderCell('T'),
              _DayHeaderCell('F'),
              _DayHeaderCell('S'),
            ],
          ),
          const SizedBox(height: 10),

          // Calendar Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < offset) {
                return const SizedBox.shrink();
              }

              final day = index - offset + 1;
              final date = DateTime(selectedMonth.year, selectedMonth.month, day);
              final target = DateTime(date.year, date.month, date.day);

              final isSelected = date.day == selectedDate.day &&
                  date.month == selectedDate.month &&
                  date.year == selectedDate.year;

              final holiday = holidaysByDay[day];
              final record = recordsByDay[day] ??
                  AttendanceDayRecord(
                    date: date,
                    status: target.isAfter(today)
                        ? AttendanceStatus.notRecorded
                        : AttendanceStatus.absent,
                  );

              final isHoliday = holiday != null || record.status == AttendanceStatus.holiday;
              final isOfficeOff = record.status == AttendanceStatus.officeOff;
              final isLeave = record.status == AttendanceStatus.leave;

              Color? dotColor;

              // 🔴 RULE 1: HOLIDAYS, OFFICE OFF & APPROVED LEAVE (FROM API)
              if (isHoliday) {
                dotColor = const Color(0xFF1967D2); // 🔵 Blue dot for Holiday
              } else if (isOfficeOff) {
                dotColor = const Color(0xFF202124); // ⚫ Black dot for Office Off
              } else if (isLeave) {
                dotColor = const Color(0xFFE37400); // 🟠 Orange dot for Leave
              }
              // 🔴 RULE 2: FUTURE WORKING DAYS (NEVER MARK AS ABSENT / ZERO DOTS)
              else if (target.isAfter(today)) {
                dotColor = null; // 🚫 ZERO DOTS FOR UNPUNCHED FUTURE WORKDAYS!
              }

              // 🔴 RULE 3: TODAY'S DATE (MUST REFLECT LIVE PUNCH STATUS)
              else if (target.isAtSameMomentAs(today)) {
                if (record.status == AttendanceStatus.present || isTodayWorking) {
                  dotColor = const Color(0xFF137333); // 🟢 Green Dot for Working Today
                } else {
                  dotColor = const Color(0xFF9AA0A6); // Gray dot if not checked in yet
                }
              }
              // 🔴 RULE 4: PAST WORKING DATES
              else {
                switch (record.status) {
                  case AttendanceStatus.present:
                    dotColor = const Color(0xFF137333); // Green
                    break;
                  case AttendanceStatus.leave:
                    dotColor = const Color(0xFFE37400); // Orange
                    break;
                  case AttendanceStatus.absent:
                    dotColor = const Color(0xFFC5221F); // Red (ONLY FOR PAST WORKING DAYS!)
                    break;
                  case AttendanceStatus.notRecorded:
                    dotColor = const Color(0xFF9AA0A6); // Gray
                    break;
                  default:
                    dotColor = null;
                    break;
                }
              }

              return InkWell(
                onTap: () => onDateSelected(date),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: isSelected
                            ? AppTypography.labelLarge.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                              )
                            : AppTypography.bodyMedium.copyWith(
                                color: isOfficeOff
                                    ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
                                    : AppColors.onSurface,
                              ),
                      ),
                      if (dotColor != null)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.onPrimary : dotColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  final String title;

  const _DayHeaderCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          title,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
