import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/notification_model.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/entities/notification_entity.dart';
import '../../data/local_notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalNotificationRepository(prefs);
});

class NotificationState {
  final List<NotificationEntity> notifications;
  final NotificationCategory? activeCategory;
  final int totalCount;
  final int displayLimit;
  final bool hasMore;
  final int unreadCount;
  final bool isLoading;

  const NotificationState({
    required this.notifications,
    this.activeCategory,
    this.totalCount = 0,
    this.displayLimit = 15,
    this.hasMore = false,
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<NotificationEntity>? notifications,
    NotificationCategory? Function()? activeCategory,
    int? totalCount,
    int? displayLimit,
    bool? hasMore,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      activeCategory: activeCategory != null ? activeCategory() : this.activeCategory,
      totalCount: totalCount ?? this.totalCount,
      displayLimit: displayLimit ?? this.displayLimit,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationController extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  StreamSubscription<void>? _changeSub;
  List<NotificationEntity> _allCategoryItems = [];

  NotificationController(this._repository)
      : super(const NotificationState(notifications: [])) {
    loadNotifications();

    // Listen for new push notifications arriving in real time
    _changeSub = LocalNotificationRepository.onNotificationsChanged.listen((_) {
      loadNotifications(silent: true);
    });
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    _allCategoryItems = await _repository.getNotifications(category: state.activeCategory);
    final count = await _repository.getUnreadCount();

    final limit = state.displayLimit;
    final displayed = _allCategoryItems.take(limit).toList();
    final hasMore = _allCategoryItems.length > displayed.length;

    state = state.copyWith(
      notifications: displayed,
      totalCount: _allCategoryItems.length,
      hasMore: hasMore,
      unreadCount: count,
      isLoading: false,
    );
  }

  void showMore() {
    final newLimit = state.displayLimit + 15;
    final displayed = _allCategoryItems.take(newLimit).toList();
    final hasMore = _allCategoryItems.length > displayed.length;

    state = state.copyWith(
      displayLimit: newLimit,
      notifications: displayed,
      hasMore: hasMore,
    );
  }

  Future<void> filterByCategory(NotificationCategory? category) async {
    state = state.copyWith(
      activeCategory: () => category,
      displayLimit: 15,
      isLoading: true,
    );
    _allCategoryItems = await _repository.getNotifications(category: category);
    final displayed = _allCategoryItems.take(15).toList();
    final hasMore = _allCategoryItems.length > displayed.length;

    state = state.copyWith(
      notifications: displayed,
      totalCount: _allCategoryItems.length,
      hasMore: hasMore,
      isLoading: false,
    );
  }

  Future<void> markAsRead(String id) async {
    // Instant optimistic update
    final updatedList = state.notifications.map((n) {
      if (n.id == id && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final bool wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 9999) : state.unreadCount,
    );

    await _repository.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    // Instant optimistic update
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    );

    await _repository.markAllAsRead();
  }

  Future<void> deleteNotification(String id) async {
    // Instant optimistic update
    final item = state.notifications.cast<NotificationEntity?>().firstWhere(
      (n) => n?.id == id,
      orElse: () => null,
    );
    final wasUnread = item != null && !item.isRead;
    final updatedList = state.notifications.where((n) => n.id != id).toList();

    state = state.copyWith(
      notifications: updatedList,
      totalCount: (state.totalCount - 1).clamp(0, 9999),
      unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 9999) : state.unreadCount,
    );

    await _repository.deleteNotification(id);
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationController(repository);
});
