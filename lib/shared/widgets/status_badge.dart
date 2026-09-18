import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

enum BadgeType {
  active,
  absent,
  present,
  leave,
  holiday,
  officeOff,
  inProgress,
  todo,
  completed,
  overdue,
  highPriority,
  mediumPriority,
  lowPriority,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType? type;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? leading;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.label,
    this.type,
    this.backgroundColor,
    this.textColor,
    this.leading,
    this.showDot = false,
  });

  factory StatusBadge.active() => const StatusBadge(
        label: 'Active',
        type: BadgeType.active,
        showDot: true,
      );

  factory StatusBadge.absent() => const StatusBadge(
        label: 'ABSENT',
        type: BadgeType.absent,
      );

  factory StatusBadge.present() => const StatusBadge(
        label: 'PRESENT',
        type: BadgeType.present,
      );

  factory StatusBadge.inProgress() => const StatusBadge(
        label: 'In Progress',
        type: BadgeType.inProgress,
      );

  factory StatusBadge.todo() => const StatusBadge(
        label: 'To Do',
        type: BadgeType.todo,
      );

  factory StatusBadge.completed() => const StatusBadge(
        label: 'Completed',
        type: BadgeType.completed,
      );

  factory StatusBadge.highPriority() => StatusBadge(
        label: 'High',
        type: BadgeType.highPriority,
        leading: const Icon(
          Icons.keyboard_double_arrow_up,
          size: 13,
          color: AppColors.error,
        ),
      );

  factory StatusBadge.mediumPriority() => StatusBadge(
        label: 'Medium',
        type: BadgeType.mediumPriority,
        leading: const Icon(
          Icons.drag_handle,
          size: 13,
          color: AppColors.onSurfaceVariant,
        ),
      );

  factory StatusBadge.lowPriority() => StatusBadge(
        label: 'Low',
        type: BadgeType.lowPriority,
        leading: const Icon(
          Icons.keyboard_arrow_down,
          size: 13,
          color: AppColors.primary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.active:
        bg = AppColors.secondaryContainer.withValues(alpha: 0.5);
        fg = AppColors.onSecondaryContainer;
        break;
      case BadgeType.absent:
        bg = const Color(0xFFFCE8E6);
        fg = const Color(0xFFC5221F);
        break;
      case BadgeType.present:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case BadgeType.leave:
        bg = const Color(0xFFFEF7E0);
        fg = const Color(0xFFE37400);
        break;
      case BadgeType.holiday:
        bg = const Color(0xFFE8F0FE);
        fg = const Color(0xFF1967D2);
        break;
      case BadgeType.officeOff:
        bg = const Color(0xFFE8EAED);
        fg = const Color(0xFF202124);
        break;
      case BadgeType.inProgress:
        bg = AppColors.primaryContainer.withValues(alpha: 0.15);
        fg = AppColors.primary;
        break;
      case BadgeType.todo:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        break;
      case BadgeType.completed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case BadgeType.overdue:
        bg = AppColors.errorContainer.withValues(alpha: 0.5);
        fg = AppColors.error;
        break;
      case BadgeType.highPriority:
        bg = AppColors.errorContainer.withValues(alpha: 0.5);
        fg = AppColors.error;
        break;
      case BadgeType.mediumPriority:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        break;
      case BadgeType.lowPriority:
        bg = AppColors.secondaryContainer.withValues(alpha: 0.4);
        fg = AppColors.primary;
        break;
      case null:
        bg = backgroundColor ?? AppColors.surfaceContainerHigh;
        fg = textColor ?? AppColors.onSurface;
        break;
    }

    if (backgroundColor != null) bg = backgroundColor!;
    if (textColor != null) fg = textColor!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: fg.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.softTeal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelTiny.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
