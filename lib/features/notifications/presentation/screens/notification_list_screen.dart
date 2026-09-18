import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/notification_model.dart';
import '../../domain/entities/notification_entity.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../controllers/notification_controller.dart';
import '../widgets/notification_detail_sheet.dart';

final _notifDateFormat = DateFormat('hh:mm a • dd MMM');

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  static IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.attendance:
        return Icons.access_time;
      case NotificationCategory.payroll:
        return Icons.receipt_long;
      case NotificationCategory.tasks:
        return Icons.assignment;
      case NotificationCategory.announcement:
        return Icons.campaign;
      case NotificationCategory.security:
        return Icons.security;
    }
  }

  static IconData _getNotificationIcon(NotificationEntity notif) {
    if (notif.actionRoute == '/hr-letter' || notif.data?['type'] == 'hr_letter') {
      return Icons.mail_outline;
    }
    return _getCategoryIcon(notif.category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => controller.markAllAsRead(),
              child: Text(
                'Mark All Read',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildChip(
                      label: 'All',
                      isSelected: state.activeCategory == null,
                      onTap: () => controller.filterByCategory(null),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: 'Attendance',
                      isSelected: state.activeCategory == NotificationCategory.attendance,
                      onTap: () => controller.filterByCategory(NotificationCategory.attendance),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: 'Payroll',
                      isSelected: state.activeCategory == NotificationCategory.payroll,
                      onTap: () => controller.filterByCategory(NotificationCategory.payroll),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: 'Tasks',
                      isSelected: state.activeCategory == NotificationCategory.tasks,
                      onTap: () => controller.filterByCategory(NotificationCategory.tasks),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: 'Announcements',
                      isSelected: state.activeCategory == NotificationCategory.announcement,
                      onTap: () => controller.filterByCategory(NotificationCategory.announcement),
                    ),
                  ],
                ),
              ),
            ),

            // Notifications List
            Expanded(
              child: state.notifications.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () => controller.loadNotifications(),
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const EmptyStateView(
                            icon: Icons.notifications_off_outlined,
                            title: 'No Notifications',
                            message: 'You have caught up with all your updates from the last 7 days.',
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => controller.loadNotifications(),
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          // Show More Pagination Button at the bottom
                          if (index == state.notifications.length) {
                            final remaining = state.totalCount - state.notifications.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: OutlinedButton.icon(
                                  onPressed: () => controller.showMore(),
                                  icon: const Icon(Icons.expand_more, size: 20, color: AppColors.primary),
                                  label: Text(
                                    'Show More ($remaining remaining)',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final notif = state.notifications[index];
                          final timeString = _notifDateFormat.format(notif.timestamp);

                          return Dismissible(
                            key: ValueKey(notif.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppColors.error),
                            ),
                            onDismissed: (_) {
                              controller.deleteNotification(notif.id);
                            },
                            child: InkWell(
                              onTap: () {
                                controller.markAsRead(notif.id);
                                NotificationDetailSheet.show(
                                  context,
                                  notification: notif,
                                  onAction: notif.actionRoute != null
                                      ? () {
                                          context.go(notif.actionRoute!);
                                        }
                                      : null,
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: notif.isRead
                                      ? AppColors.surfaceContainerLowest
                                      : AppColors.primaryContainer.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: notif.isRead
                                        ? AppColors.outlineVariant.withValues(alpha: 0.3)
                                        : AppColors.primaryContainer.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: notif.isRead
                                            ? AppColors.surfaceContainerLow
                                            : AppColors.primaryContainer.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(notif),
                                        size: 20,
                                        color: notif.isRead ? AppColors.outline : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: AppTypography.labelLarge.copyWith(
                                                    color: AppColors.onSurface,
                                                    fontWeight: notif.isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (!notif.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.message,
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            timeString,
                                            style: AppTypography.labelTiny.copyWith(
                                              color: AppColors.outline,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
