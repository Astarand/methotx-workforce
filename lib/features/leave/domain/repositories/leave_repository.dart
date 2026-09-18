import '../entities/leave_entity.dart';
import '../../../../shared/models/leave_model.dart'; // For Enums

abstract class LeaveRepository {
  Future<List<LeaveBalanceEntity>> getLeaveBalances();
  Future<List<LeaveApplicationEntity>> getUpcomingLeaves();
  Future<List<LeaveApplicationEntity>> getLeaveHistory();
  Future<List<LeaveApplicationEntity>> getAllLeaves();
  Future<LeaveSummaryModel> getLeaveSummary();
  Future<LeaveApplicationEntity> getLeaveDetails(String leaveId);
  Future<LeaveApplicationEntity> applyLeave({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  });
}

