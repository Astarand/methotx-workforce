import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationDetailSheet extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback? onAction;

  const NotificationDetailSheet({
    super.key,
    required this.notification,
    this.onAction,
  });

  static void show(
    BuildContext context, {
    required NotificationEntity notification,
    VoidCallback? onAction,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NotificationDetailSheet(
        notification: notification,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat('dd MMM yyyy, hh:mm a').format(notification.timestamp);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeString,
                      style: AppTypography.labelTiny.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              notification.message,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
          if (onAction != null) ...[
            PrimaryButton(
              title: 'View Details',
              onPressed: () {
                Navigator.of(context).pop();
                onAction?.call();
              },
            ),
            const SizedBox(height: 10),
            GhostButton(
              title: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            PrimaryButton(
              title: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}
