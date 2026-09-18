import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../domain/entities/task_entity.dart';
import '../controllers/task_notifier.dart';
import '../widgets/task_card.dart';
import '../widgets/task_shimmer_loader.dart';

/// Enterprise Task Management Screen
///
/// Features:
/// - 3 Segmented Filter Tabs matching Leave Management Screen styling:
///   1. Active Task
///   2. Overdue Task
///   3. Complete Task
/// - TabController with synchronized horizontal swipe and tap transitions.
/// - Shimmer skeleton loaders when [TaskState.isLoading] is true.
/// - Interactive TaskCard with swipe & tap status updates.
/// - Pull-to-refresh synchronization.
class TaskManagementScreen extends ConsumerStatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  ConsumerState<TaskManagementScreen> createState() =>
      _TaskManagementScreenState();
}

class _TaskManagementScreenState extends ConsumerState<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.animation?.addListener(_handleTabAnimation);
  }

  void _handleTabAnimation() {
    final newIndex = _tabController.animation!.value.round();
    if (_selectedTabIndex != newIndex) {
      setState(() {
        _selectedTabIndex = newIndex;
      });
    }
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_handleTabAnimation);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_selectedTabIndex == index) return;
    _tabController.animateTo(index);
    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final taskNotifier = ref.read(taskNotifierProvider.notifier);

    // Filter tasks into 3 distinct lists and sort Date & Time wise (closest first)
    final activeTasks = taskState.pendingTasks
        .where((t) => !t.isOverdue)
        .toList()
      ..sort(_compareActiveTasks);

    final overdueTasks = taskState.pendingTasks
        .where((t) => t.isOverdue)
        .toList()
      ..sort(_compareOverdueTasks);

    final completedTasks = taskState.completedTasks
        .where((t) => t.isCompletedWithinDays(7))
        .toList()
      ..sort(_compareCompletedTasks);

    // Listen for status update toast notifications
    ref.listen<TaskState>(taskNotifierProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppToast.showError(
          context,
          title: 'Task Update Failed',
          message: next.errorMessage!,
        );
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        AppToast.showSuccess(
          context,
          title: 'Task Updated',
          message: next.successMessage!,
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMobile,
                    AppSpacing.md,
                    AppSpacing.marginMobile,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Task Management',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          IconButton(
                            onPressed: () => taskNotifier.fetchTasks(),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Refresh tasks',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track active priorities, milestones, and deliverables',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress Metric Card
                      _buildProgressSummaryCard(
                        state: taskState,
                        activeCount: activeTasks.length,
                        overdueCount: overdueTasks.length,
                        completedCount: completedTasks.length,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverSegmentedTabDelegate(
                  child: _buildSegmentedTabBar(
                    activeCount: activeTasks.length,
                    overdueCount: overdueTasks.length,
                    completedCount: completedTasks.length,
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Active Tasks (On-schedule, not overdue)
              _buildTaskList(
                context: context,
                tasks: activeTasks,
                isLoading: taskState.isLoading,
                emptyTitle: 'No Active Tasks',
                emptySubtitle:
                    'All caught up! New assigned deliverables will appear here.',
                emptyIcon: Icons.checklist_rounded,
                onRefresh: () => taskNotifier.fetchTasks(showLoading: false),
                onStatusChanged: (task, newStatus) {
                  taskNotifier.updateTaskStatus(
                    taskId: task.id,
                    newStatus: newStatus,
                  );
                },
                isReadOnly: false,
              ),

              // Tab 2: Overdue Tasks (Past deadline deliverables)
              _buildTaskList(
                context: context,
                tasks: overdueTasks,
                isLoading: taskState.isLoading,
                emptyTitle: 'No Overdue Tasks',
                emptySubtitle:
                    'Outstanding! All tasks are currently on schedule with no overdue items.',
                emptyIcon: Icons.verified_rounded,
                onRefresh: () => taskNotifier.fetchTasks(showLoading: false),
                onStatusChanged: (task, newStatus) {
                  taskNotifier.updateTaskStatus(
                    taskId: task.id,
                    newStatus: newStatus,
                  );
                },
                isReadOnly: false,
              ),

              // Tab 3: Completed Tasks (Read-only catalog - last 7 days)
              _buildTaskList(
                context: context,
                tasks: completedTasks,
                isLoading: taskState.isLoading,
                emptyTitle: 'No Completed Tasks',
                emptySubtitle:
                    'No completed tasks found in the last 7 days.',
                emptyIcon: Icons.assignment_turned_in_outlined,
                onRefresh: () => taskNotifier.fetchTasks(showLoading: false),
                isReadOnly: true,
                headerWidget: completedTasks.isNotEmpty
                    ? _buildCompletedFilterBanner(completedTasks.length)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Segmented tab switcher inspired by the Leave Management Screen aesthetic
  Widget _buildSegmentedTabBar({
    required int activeCount,
    required int overdueCount,
    required int completedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildTabButton(
              label: 'Active Task',
              count: activeCount,
              isSelected: _selectedTabIndex == 0,
              onTap: () => _onTabTapped(0),
            ),
            _buildTabButton(
              label: 'Overdue Task',
              count: overdueCount,
              isSelected: _selectedTabIndex == 1,
              onTap: () => _onTabTapped(1),
              isOverdueTab: true,
            ),
            _buildTabButton(
              label: 'Complete Task',
              count: completedCount,
              isSelected: _selectedTabIndex == 2,
              onTap: () => _onTabTapped(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool isOverdueTab = false,
  }) {
    Color badgeBg;
    Color badgeFg;

    if (isOverdueTab && count > 0) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
    } else if (isSelected) {
      badgeBg = AppColors.primary.withValues(alpha: 0.12);
      badgeFg = AppColors.primary;
    } else {
      badgeBg = AppColors.surfaceContainerHigh;
      badgeFg = AppColors.onSurfaceVariant;
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? AppShadows.low : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isOverdueTab && count > 0
                            ? const Color(0xFFDC2626)
                            : AppColors.primary)
                        : AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard({
    required TaskState state,
    required int activeCount,
    required int overdueCount,
    required int completedCount,
  }) {
    final ratePercent = (state.completionRate * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sprint Progress',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '$ratePercent% Done',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.completionRate,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeCount Active',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (overdueCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$overdueCount Overdue',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              Text(
                '$completedCount Completed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList({
    required BuildContext context,
    required List<TaskEntity> tasks,
    required bool isLoading,
    required String emptyTitle,
    required String emptySubtitle,
    IconData emptyIcon = Icons.checklist_rounded,
    required Future<void> Function() onRefresh,
    void Function(TaskEntity task, TaskStatus newStatus)? onStatusChanged,
    bool isReadOnly = false,
    Widget? headerWidget,
  }) {
    if (isLoading && tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.md,
        ),
        child: TaskShimmerLoader(itemCount: 4),
      );
    }

    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: EmptyStateView(
            title: emptyTitle,
            message: emptySubtitle,
            icon: emptyIcon,
          ),
        ),
      );
    }

    final hasHeader = headerWidget != null;
    final totalCount = tasks.length + (hasHeader ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          AppSpacing.md,
          AppSpacing.marginMobile,
          120.0, // Clearance for shell bottom nav bar
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: totalCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (hasHeader && index == 0) {
            return headerWidget;
          }
          final taskIndex = hasHeader ? index - 1 : index;
          final task = tasks[taskIndex];
          return TaskCard(
            task: task,
            isReadOnly: isReadOnly,
            onStatusChanged: onStatusChanged != null
                ? (newStatus) => onStatusChanged(task, newStatus)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildCompletedFilterBanner(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing completed tasks from the last 7 days ($count)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _compareActiveTasks(TaskEntity a, TaskEntity b) {
    if (a.dueDate == null && b.dueDate == null) return 0;
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    final cmp = a.dueDate!.compareTo(b.dueDate!);
    if (cmp != 0) return cmp;
    return _priorityWeight(a.priority).compareTo(_priorityWeight(b.priority));
  }

  static int _compareOverdueTasks(TaskEntity a, TaskEntity b) {
    if (a.dueDate == null && b.dueDate == null) return 0;
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    // Closest to now (most recently overdue first)
    final cmp = b.dueDate!.compareTo(a.dueDate!);
    if (cmp != 0) return cmp;
    return _priorityWeight(a.priority).compareTo(_priorityWeight(b.priority));
  }

  static int _compareCompletedTasks(TaskEntity a, TaskEntity b) {
    final aDate = a.completedDate ?? a.dueDate;
    final bDate = b.completedDate ?? b.dueDate;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  static int _priorityWeight(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }
}

class _SliverSegmentedTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverSegmentedTabDelegate({required this.child});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF9FBFC),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverSegmentedTabDelegate oldDelegate) {
    return true;
  }
}
