import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../controllers/leave_controller.dart';
import '../../domain/entities/leave_entity.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/apply_leave_sheet.dart';
import '../widgets/leave_details_sheet.dart';

class LeaveManagementScreen extends ConsumerWidget {
  const LeaveManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaveControllerProvider);
    final controller = ref.read(leaveControllerProvider.notifier);

    final displayList =
        state.activeTabIndex == 0 ? state.upcomingLeaves : state.leaveHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadLeaveData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              AppSpacing.md,
              AppSpacing.marginMobile,
              120.0, // bottom padding for fixed navigation
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leave Management',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PrimaryButton(
                      title: 'Apply',
                      height: 40,
                      width: 104,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      icon: const Icon(Icons.add, size: 16, color: AppColors.onPrimary),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        ApplyLeaveSheet.show(
                          context,
                          onApply: controller.applyLeave,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Balance Cards
                LeaveBalanceCards(balances: state.balances),
                const SizedBox(height: 20),

                // Segmented Tab Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: 'Upcoming (${state.upcomingLeaves.length})',
                        isSelected: state.activeTabIndex == 0,
                        onTap: () => controller.setActiveTab(0),
                      ),
                      _buildTabButton(
                        label: 'History (${state.leaveHistory.length})',
                        isSelected: state.activeTabIndex == 1,
                        onTap: () => controller.setActiveTab(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Leave Applications List States
                if (state.isLoading && displayList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (state.errorMessage != null && displayList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            title: 'Retry',
                            height: 40,
                            width: 120,
                            onPressed: controller.loadLeaveData,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (displayList.isEmpty)
                  const EmptyStateView(
                    icon: Icons.event_available,
                    title: 'No Leave Records',
                    message: 'You have no leave records in this category.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final leave = displayList[index];
                      return _buildLeaveCard(context, leave);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? AppShadows.low : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveApplicationEntity leave) {
    String typeTitle;
    Color typeColor;
    switch (leave.type) {
      case LeaveType.casual:
        typeTitle = 'Casual Leave';
        typeColor = AppColors.primary;
        break;
      case LeaveType.sick:
        typeTitle = 'Sick Leave';
        typeColor = AppColors.error;
        break;
      case LeaveType.paid:
        typeTitle = 'Paid Leave';
        typeColor = AppColors.success;
        break;
      default:
        typeTitle = 'Leave';
        typeColor = AppColors.tertiary;
        break;
    }

    final start = DateFormat('dd MMM').format(leave.startDate);
    final end = DateFormat('dd MMM yyyy').format(leave.endDate);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => LeaveDetailsSheet.show(context, leave: leave),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(22, 126, 149, 0.04),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        typeTitle,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLeaveStatusBadge(leave.status),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.outline,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$start - $end • ${leave.numberOfDays} ${leave.numberOfDays == 1 ? "day" : "days"}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                leave.reason,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (leave.status == LeaveStatus.approved ||
                  (leave.approvedBy != null && leave.approvedBy!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Text(
                  'Approver: ${leave.formattedApprover}',
                  style: AppTypography.labelTiny.copyWith(
                    color: AppColors.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLeaveStatusBadge(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return const StatusBadge(
          label: 'Approved',
          backgroundColor: AppColors.successContainer,
          textColor: AppColors.onSuccessContainer,
        );
      case LeaveStatus.pending:
        return const StatusBadge(
          label: 'Pending',
          backgroundColor: AppColors.warningContainer,
          textColor: AppColors.warning,
        );
      case LeaveStatus.rejected:
        return const StatusBadge(
          label: 'Rejected',
          backgroundColor: AppColors.errorContainer,
          textColor: AppColors.error,
        );
      case LeaveStatus.cancelled:
        return const StatusBadge(
          label: 'Cancelled',
          backgroundColor: AppColors.offContainer,
          textColor: AppColors.offGray,
        );
    }
  }
}
