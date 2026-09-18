import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/leave_model.dart';
import '../../data/repositories/leave_repository_impl.dart';
import '../../domain/entities/leave_entity.dart';
import '../../domain/repositories/leave_repository.dart';

class LeaveState {
  final List<LeaveBalanceEntity> balances;
  final List<LeaveApplicationEntity> upcomingLeaves;
  final List<LeaveApplicationEntity> leaveHistory;
  final LeaveSummaryModel summary;
  final int activeTabIndex; // 0 = Upcoming, 1 = History
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final LeaveApplicationEntity? selectedLeaveDetails;
  final bool isDetailsLoading;

  const LeaveState({
    required this.balances,
    required this.upcomingLeaves,
    required this.leaveHistory,
    this.summary = const LeaveSummaryModel(),
    this.activeTabIndex = 0,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.selectedLeaveDetails,
    this.isDetailsLoading = false,
  });

  LeaveState copyWith({
    List<LeaveBalanceEntity>? balances,
    List<LeaveApplicationEntity>? upcomingLeaves,
    List<LeaveApplicationEntity>? leaveHistory,
    LeaveSummaryModel? summary,
    int? activeTabIndex,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    LeaveApplicationEntity? selectedLeaveDetails,
    bool? isDetailsLoading,
  }) {
    return LeaveState(
      balances: balances ?? this.balances,
      upcomingLeaves: upcomingLeaves ?? this.upcomingLeaves,
      leaveHistory: leaveHistory ?? this.leaveHistory,
      summary: summary ?? this.summary,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      selectedLeaveDetails: selectedLeaveDetails ?? this.selectedLeaveDetails,
      isDetailsLoading: isDetailsLoading ?? this.isDetailsLoading,
    );
  }
}

class LeaveController extends StateNotifier<LeaveState> {
  final LeaveRepository _repository;

  LeaveController(this._repository)
      : super(const LeaveState(
          balances: [],
          upcomingLeaves: [],
          leaveHistory: [],
          isLoading: true,
        )) {
    Future.microtask(() => loadLeaveData());
  }

  Future<void> loadLeaveData() async {
    if (!state.isLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      // Always refresh from remote API so management approvals/rejections update
      await _repository.getAllLeaves();

      final balances = await _repository.getLeaveBalances();
      final upcoming = await _repository.getUpcomingLeaves();
      final history = await _repository.getLeaveHistory();
      final summary = await _repository.getLeaveSummary();

      state = state.copyWith(
        balances: balances,
        upcomingLeaves: upcoming,
        leaveHistory: history,
        summary: summary,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }


  void setActiveTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  Future<bool> applyLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newLeave = await _repository.applyLeave(
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

      // Optimistic local update
      final updatedUpcoming = [newLeave, ...state.upcomingLeaves];
      final allLeaves = [...updatedUpcoming, ...state.leaveHistory];
      final updatedSummary = LeaveSummaryModel.fromLeaves(allLeaves);

      state = state.copyWith(
        upcomingLeaves: updatedUpcoming,
        summary: updatedSummary,
        isLoading: false,
        successMessage: 'Leave request submitted successfully',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      rethrow;
    }
  }

  Future<LeaveApplicationEntity?> fetchLeaveDetails(String leaveId) async {
    state = state.copyWith(isDetailsLoading: true);
    try {
      final details = await _repository.getLeaveDetails(leaveId);
      state = state.copyWith(
        selectedLeaveDetails: details,
        isDetailsLoading: false,
      );
      return details;
    } catch (e) {
      final fallback = state.upcomingLeaves
          .followedBy(state.leaveHistory)
          .firstWhere(
            (l) => l.id == leaveId,
            orElse: () => state.upcomingLeaves.isNotEmpty
                ? state.upcomingLeaves.first
                : (state.leaveHistory.isNotEmpty
                    ? state.leaveHistory.first
                    : LeaveApplicationEntity(
                        id: leaveId,
                        type: LeaveType.casual,
                        startDate: DateTime.now(),
                        endDate: DateTime.now(),
                        numberOfDays: 1,
                        reason: 'Leave details unavailable',
                        status: LeaveStatus.pending,
                        appliedOn: DateTime.now(),
                      )),
          );
      state = state.copyWith(
        selectedLeaveDetails: fallback,
        isDetailsLoading: false,
      );
      return fallback;
    }
  }

  // Section 10 helpers for local state updates
  void updateLeaveStatus(String leaveId, LeaveStatus newStatus) {
    final updatedUpcoming = state.upcomingLeaves.map((l) {
      return l.id == leaveId ? l.copyWith(status: newStatus) : l;
    }).toList();

    final updatedHistory = state.leaveHistory.map((l) {
      return l.id == leaveId ? l.copyWith(status: newStatus) : l;
    }).toList();

    final all = [...updatedUpcoming, ...updatedHistory];
    state = state.copyWith(
      upcomingLeaves: updatedUpcoming,
      leaveHistory: updatedHistory,
      summary: LeaveSummaryModel.fromLeaves(all),
    );
  }

  void approveLeave(String leaveId) => updateLeaveStatus(leaveId, LeaveStatus.approved);
  void rejectLeave(String leaveId) => updateLeaveStatus(leaveId, LeaveStatus.rejected);
  void cancelLeaveRequest(String leaveId) => updateLeaveStatus(leaveId, LeaveStatus.cancelled);
}

final leaveControllerProvider =
    StateNotifierProvider<LeaveController, LeaveState>((ref) {
  final repository = ref.watch(leaveRepositoryProvider);
  return LeaveController(repository);
});
