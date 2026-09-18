import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/attendance_record_model.dart';
import '../../data/attendance_data_repository.dart';
import '../widgets/attendance_calendar_view.dart';

class AttendanceHistoryState {
  final DateTime selectedMonth;
  final DateTime selectedDate;
  final MonthlyAttendanceSummary summary;
  final List<AttendanceDayRecord> monthRecords;
  final AttendanceDayRecord selectedDayOverview;
  final List<Map<String, dynamic>> holidayList;
  final bool isLoading;
  final bool isOverviewLoading;

  const AttendanceHistoryState({
    required this.selectedMonth,
    required this.selectedDate,
    required this.summary,
    required this.monthRecords,
    required this.selectedDayOverview,
    required this.holidayList,
    this.isLoading = false,
    this.isOverviewLoading = false,
  });

  int get currentMonthHolidayCount =>
      getHolidayCountForMonth(selectedMonth, holidayList);

  AttendanceHistoryState copyWith({
    DateTime? selectedMonth,
    DateTime? selectedDate,
    MonthlyAttendanceSummary? summary,
    List<AttendanceDayRecord>? monthRecords,
    AttendanceDayRecord? selectedDayOverview,
    List<Map<String, dynamic>>? holidayList,
    bool? isLoading,
    bool? isOverviewLoading,
  }) {
    return AttendanceHistoryState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      summary: summary ?? this.summary,
      monthRecords: monthRecords ?? this.monthRecords,
      selectedDayOverview: selectedDayOverview ?? this.selectedDayOverview,
      holidayList: holidayList ?? this.holidayList,
      isLoading: isLoading ?? this.isLoading,
      isOverviewLoading: isOverviewLoading ?? this.isOverviewLoading,
    );
  }
}

class AttendanceController extends StateNotifier<AttendanceHistoryState> {
  final AttendanceDataRepository _repository;

  AttendanceController(this._repository)
      : super(AttendanceHistoryState(
          selectedMonth: DateTime.now(),
          selectedDate: DateTime.now(),
          summary: const MonthlyAttendanceSummary(),
          monthRecords: const [],
          selectedDayOverview: AttendanceDayRecord(
            date: DateTime.now(),
            status: AttendanceStatus.notRecorded,
          ),
          holidayList: const [],
        )) {
    _initData();
  }

  Future<void> _initData() async {
    final now = DateTime.now();
    await loadHolidays();
    await loadMonthData(now);
    await selectDate(now);
  }

  Future<void> loadMonthData(DateTime month) async {
    state = state.copyWith(isLoading: true, selectedMonth: month);
    final summary = await _repository.getMonthlySummary(month);
    final records = await _repository.getMonthAttendanceRecords(month);

    state = state.copyWith(
      selectedMonth: month,
      summary: summary,
      monthRecords: records,
      isLoading: false,
    );
  }

  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      isOverviewLoading: true,
    );

    var overview = await _repository.getDayOverview(date);

    // Cross-reference with company holiday list
    final holiday = getHolidayForDate(date, state.holidayList);
    if (holiday != null) {
      final hName = holiday['name']?.toString() ?? 'Company Holiday';
      final hType = holiday['type']?.toString() ?? 'Holiday';
      overview = overview.copyWith(
        status: AttendanceStatus.holiday,
        holidayName: '$hName • $hType',
        checkInTime: 'Office Holiday',
        checkOutTime: 'Office Holiday',
      );
    } else {
      final matchingMonthRec = state.monthRecords.where((r) =>
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day).firstOrNull;
      if (matchingMonthRec != null) {
        if (matchingMonthRec.status == AttendanceStatus.officeOff) {
          overview = overview.copyWith(
            status: AttendanceStatus.officeOff,
            checkInTime: 'Office Off',
            checkOutTime: 'Office Off',
          );
        } else if (matchingMonthRec.status == AttendanceStatus.leave) {
          overview = overview.copyWith(
            status: AttendanceStatus.leave,
            leaveType: overview.leaveType ?? matchingMonthRec.leaveType ?? 'Approved Leave',
            notes: overview.notes ?? matchingMonthRec.notes,
            checkInTime: 'On Leave',
            checkOutTime: 'On Leave',
          );
        }
      }

    }

    state = state.copyWith(
      selectedDate: date,
      selectedDayOverview: overview,
      isOverviewLoading: false,
    );
  }

  Future<void> previousMonth() async {
    final prev = DateTime(state.selectedMonth.year, state.selectedMonth.month - 1);
    await loadMonthData(prev);
    final newDate = DateTime(prev.year, prev.month, state.selectedDate.day.clamp(1, DateTime(prev.year, prev.month + 1, 0).day));
    await selectDate(newDate);
  }

  Future<void> nextMonth() async {
    final next = DateTime(state.selectedMonth.year, state.selectedMonth.month + 1);
    await loadMonthData(next);
    final newDate = DateTime(next.year, next.month, state.selectedDate.day.clamp(1, DateTime(next.year, next.month + 1, 0).day));
    await selectDate(newDate);
  }

  Future<void> loadHolidays() async {
    final holidays = await _repository.getHolidayList(state.selectedMonth.year);
    state = state.copyWith(holidayList: holidays);
  }
}

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AttendanceHistoryState>((ref) {
  final repository = ref.watch(attendanceHistoryRepositoryProvider);
  return AttendanceController(repository);
});
