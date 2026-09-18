import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/task_entity.dart';
import 'task_details_sheet.dart';

/// Interactive Task Card supporting swipe-to-update and tap-to-toggle
class TaskCard extends StatelessWidget {
  final TaskEntity task;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onTap;
  final bool isReadOnly;

  const TaskCard({
    super.key,
    required this.task,
    this.onStatusChanged,
    this.onTap,
    this.isReadOnly = false,
  });

  Color _getPriorityColor() {
    switch (task.priority?.toLowerCase()) {
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
    final isCompleted = task.status == TaskStatus.completed;
    final isInProgress = task.status == TaskStatus.inProgress;

    return Dismissible(
      key: Key('task_dismiss_${task.id}'),
      direction: isReadOnly
          ? DismissDirection.none
          : (isCompleted
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart),
      background: Container(
        alignment: isCompleted ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.warning.withValues(alpha: 0.9)
              : AppColors.success.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted
                  ? Icons.replay_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isCompleted ? 'Reopen' : 'Complete',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (isReadOnly || onStatusChanged == null) return false;
        HapticFeedback.mediumImpact();
        if (isCompleted) {
          onStatusChanged!(TaskStatus.inProgress);
        } else {
          onStatusChanged!(TaskStatus.completed);
        }
        return false; // Retain item in view until parent list rebuilds
      },
      child: InkWell(
        onTap: onTap ?? () => TaskDetailsSheet.show(context, task),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? AppColors.outlineVariant.withValues(alpha: 0.2)
                  : (isInProgress
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : AppColors.outlineVariant.withValues(alpha: 0.35)),
              width: isInProgress ? 1.5 : 1,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Priority, Overdue Tag & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getPriorityColor().withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                size: 12,
                                color: _getPriorityColor(),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.priority!.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getPriorityColor(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (task.isOverdue && !isCompleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            task.overdueLabel.isNotEmpty
                                ? task.overdueLabel
                                : 'Overdue',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildStatusChip(context),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                task.title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? AppColors.onSurfaceVariant.withValues(alpha: 0.6)
                      : AppColors.onSurface,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              if (task.description.isNotEmpty) ...[
                Text(
                  task.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],

              // Divider
              Divider(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 10),

              // Footer: Due Date / Completed Date & Quick Status Toggle Checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_circle_outline_rounded
                              : Icons.calendar_today_outlined,
                          size: 13,
                          color: isCompleted
                              ? AppColors.success
                              : (task.isOverdue
                                  ? AppColors.error
                                  : AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isCompleted
                              ? (task.formattedCompletedDate.isNotEmpty
                                  ? 'Done: ${task.formattedCompletedDate}'
                                  : 'Completed')
                              : task.formattedDueDate,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: (!isCompleted && task.isOverdue)
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isCompleted
                                ? AppColors.success
                                : (task.isOverdue
                                    ? AppColors.error
                                    : AppColors.onSurfaceVariant),
                          ),
                        ),
                        if (task.addedByName != null || task.assignedBy != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: AppColors.outlineVariant),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              task.addedByName ?? task.assignedBy!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Quick Action Button or Read-Only Chevron
                  if (isReadOnly)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    )
                  else
                    PopupMenuButton<TaskStatus>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onSelected: (status) {
                        HapticFeedback.selectionClick();
                        onStatusChanged?.call(status);
                      },
                      itemBuilder: (context) => [
                        if (!task.status.isPending)
                          const PopupMenuItem(
                            value: TaskStatus.pending,
                            child: Text('Mark as Pending'),
                          ),
                        if (!task.status.isInProgress)
                          const PopupMenuItem(
                            value: TaskStatus.inProgress,
                            child: Text('Mark as In Progress'),
                          ),
                        if (!task.status.isCompleted)
                          const PopupMenuItem(
                            value: TaskStatus.completed,
                            child: Text('Mark as Completed'),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (task.status) {
      case TaskStatus.completed:
        bg = AppColors.successContainer.withValues(alpha: 0.25);
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.inProgress:
        bg = AppColors.primaryContainer.withValues(alpha: 0.2);
        fg = AppColors.primary;
        icon = Icons.pending_outlined;
        break;
      case TaskStatus.pending:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        icon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return InkWell(
      onTap: (isReadOnly || onStatusChanged == null)
          ? null
          : () {
              HapticFeedback.selectionClick();
              if (task.status == TaskStatus.completed) {
                onStatusChanged!(TaskStatus.inProgress);
              } else {
                onStatusChanged!(TaskStatus.completed);
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              task.status.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
