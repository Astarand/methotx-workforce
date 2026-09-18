import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/task_entity.dart';
import '../controllers/task_notifier.dart';

/// Modal bottom sheet displaying complete 10-field Task Information
/// and interactive status update transitions.
class TaskDetailsSheet extends ConsumerStatefulWidget {
  final TaskEntity initialTask;

  const TaskDetailsSheet({
    super.key,
    required this.initialTask,
  });

  static Future<void> show(BuildContext context, TaskEntity task) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailsSheet(initialTask: task),
    );
  }

  @override
  ConsumerState<TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends ConsumerState<TaskDetailsSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch full task details from backend API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(taskNotifierProvider.notifier)
          .fetchTaskDetails(widget.initialTask.id);
    });
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return AppColors.brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    // Use fetched task details if available and matches, else fallback to initial
    final task = (taskState.selectedTaskDetails != null &&
            taskState.selectedTaskDetails!.id == widget.initialTask.id)
        ? taskState.selectedTaskDetails!
        : widget.initialTask;

    final isCompleted = task.status == TaskStatus.completed;
    final isPending = task.status == TaskStatus.pending;

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final effectiveBottomPadding = viewInsetsBottom +
        (bottomSafeArea > 0 ? bottomSafeArea + 16 : 28);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: effectiveBottomPadding),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.id.isNotEmpty ? '#${task.id}' : '#TASK',
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (taskState.isDetailsLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Overdue Alert Banner
              if (task.isOverdue && !isCompleted)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.overdueLabel.isNotEmpty
                              ? '${task.overdueLabel} — Immediate Action Required'
                              : 'This task is overdue — Immediate Action Required',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Title and Priority
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (task.priority != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 14,
                                  color: _getPriorityColor(task.priority),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.priority!.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _getPriorityColor(task.priority),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Information Grid Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.outlineVariant
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.info_outline_rounded,
                            label: 'Status',
                            valueWidget: _buildStatusPill(task.status),
                          ),
                          const Divider(height: 18),
                          _buildDetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Due Date',
                            value: task.formattedDueDate,
                            isWarning: task.isOverdue && !isCompleted,
                          ),
                          const Divider(height: 18),
                          _buildDetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Assigned By',
                            value: task.addedByName ?? 'Management',
                          ),
                          if (task.completedDate != null || isCompleted) ...[
                            const Divider(height: 18),
                            _buildDetailRow(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Completed On',
                              value: task.formattedCompletedDate.isNotEmpty
                                  ? task.formattedCompletedDate
                                  : 'Recently',
                              isSuccess: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Description Section
                    Text(
                      'Description',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        task.description.isNotEmpty
                            ? task.description
                            : 'No specific requirements or notes provided for this task.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Status Action Buttons
                    Row(
                      children: [
                        if (isCompleted) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pop();
                                await ref
                                    .read(taskNotifierProvider.notifier)
                                    .updateTaskStatus(
                                      taskId: task.id,
                                      newStatus: TaskStatus.inProgress,
                                    );
                              },
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: const Text('Reopen Task'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                    color: AppColors.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          if (isPending)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                  await ref
                                      .read(taskNotifierProvider.notifier)
                                      .updateTaskStatus(
                                        taskId: task.id,
                                        newStatus: TaskStatus.inProgress,
                                      );
                                },
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 20),
                                label: const Text('Start Work'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  foregroundColor: AppColors.primary,
                                  side:
                                      const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (isPending) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pop();
                                await ref
                                    .read(taskNotifierProvider.notifier)
                                    .updateTaskStatus(
                                      taskId: task.id,
                                      newStatus: TaskStatus.completed,
                                    );
                              },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 20,
                              ),
                              label: const Text('Mark Complete'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    bool isWarning = false,
    bool isSuccess = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning
              ? AppColors.error
              : (isSuccess ? AppColors.success : AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (valueWidget != null)
          valueWidget
        else
          Text(
            value ?? '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning
                  ? AppColors.error
                  : (isSuccess ? AppColors.success : AppColors.onSurface),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusPill(TaskStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case TaskStatus.completed:
        bg = AppColors.successContainer.withValues(alpha: 0.25);
        fg = AppColors.success;
        break;
      case TaskStatus.inProgress:
        bg = AppColors.primaryContainer.withValues(alpha: 0.2);
        fg = AppColors.primary;
        break;
      case TaskStatus.pending:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
