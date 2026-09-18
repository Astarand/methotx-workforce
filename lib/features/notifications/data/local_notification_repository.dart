import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/models/notification_model.dart';
import '../domain/entities/notification_entity.dart';
import '../domain/repositories/notification_repository.dart';

/// Highly optimized, persistent notification repository backed by SharedPreferences.
///
/// Features:
/// - Memoized in-memory cache validated against raw storage signature (sub-microsecond reads).
/// - Strict 7-day retention cutoff automatically pruned on read & write.
/// - Deduplication by message ID and signature.
/// - Safe asynchronous writes to disk.
class LocalNotificationRepository implements NotificationRepository {
  static const String storageKey = 'app_push_notifications_v1';
  static final StreamController<void> _notificationEventController =
      StreamController<void>.broadcast();

  /// Global stream emitting whenever notification store changes.
  static Stream<void> get onNotificationsChanged =>
      _notificationEventController.stream;

  final SharedPreferences _prefs;

  /// Signature of last parsed raw JSON string.
  String? _lastRawJson;

  /// Fast memoized in-memory cache of valid notifications.
  List<NotificationEntity>? _cachedList;

  LocalNotificationRepository(this._prefs);

  /// 7-day retention cutoff threshold.
  static DateTime get _retentionCutoff =>
      DateTime.now().subtract(const Duration(days: 7));

  /// Maps backend push notification `type` to app's `NotificationCategory`.
  static NotificationCategory mapTypeToCategory(String? type) {
    switch (type?.toLowerCase().trim()) {
      case 'attendance':
        return NotificationCategory.attendance;
      case 'task':
      case 'tasks':
        return NotificationCategory.tasks;
      case 'payroll':
      case 'payslip':
        return NotificationCategory.payroll;
      case 'security':
        return NotificationCategory.security;
      case 'leave':
        return NotificationCategory.tasks;
      case 'hr_letter':
      case 'announcement':
      default:
        return NotificationCategory.announcement;
    }
  }

  /// Resolves the in-app navigation route from payload data.
  static String? resolveActionRoute(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;

    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      return route;
    }

    final type = (data['type'] as String?)?.toLowerCase().trim();
    switch (type) {
      case 'task':
        return '/tasks';
      case 'leave':
        return '/leave';
      case 'payslip':
        return '/payslip';
      case 'attendance':
        return '/dashboard';
      case 'hr_letter':
        return '/hr-letter';
      case 'performance':
        return '/performance';
      case 'claim':
        return '/claims';
      case 'requisition':
        return '/requisitions';
      default:
        return null;
    }
  }

  /// Saves an incoming RemoteMessage into persistent storage.
  /// Accessible from background isolate or main UI isolate.
  static Future<void> saveIncomingRemoteMessage(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title =
          message.data['title_en']?.toString() ??
          message.data['en_title']?.toString() ??
          message.notification?.title ??
          message.data['title']?.toString() ??
          'Notification';
      final body =
          message.data['body_en']?.toString() ??
          message.data['en_body']?.toString() ??
          message.data['message_en']?.toString() ??
          message.data['en_message']?.toString() ??
          message.notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '';

      // Discard empty heartbeats or silent pings without text
      if (title.trim().isEmpty && body.trim().isEmpty) return;

      final messageId =
          message.messageId ??
          'notif_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}';
      final timestamp = message.sentTime ?? DateTime.now();
      final category = mapTypeToCategory(message.data['type']?.toString());
      final actionRoute = resolveActionRoute(message.data);

      final newEntity = NotificationEntity(
        id: messageId,
        title: title,
        message: body,
        timestamp: timestamp,
        isRead: false,
        category: category,
        actionRoute: actionRoute,
        data: message.data.isNotEmpty
            ? Map<String, dynamic>.from(message.data)
            : null,
      );

      final rawList = prefs.getString(storageKey);
      final List<NotificationEntity> existingList = [];
      final cutoff = _retentionCutoff;

      if (rawList != null && rawList.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawList) as List<dynamic>;
          for (final item in decoded) {
            final entity = NotificationEntity.fromJson(
              item as Map<String, dynamic>,
            );
            // Discard notifications older than 7 days
            if (entity.timestamp.isAfter(cutoff)) {
              existingList.add(entity);
            }
          }
        } catch (_) {}
      }

      // Deduplicate: replace any existing item with identical ID or identical title+timestamp
      existingList.removeWhere(
        (n) =>
            n.id == newEntity.id ||
            (n.title == newEntity.title && n.timestamp == newEntity.timestamp),
      );

      // Insert at head (most recent first)
      existingList.insert(0, newEntity);

      // Persist to SharedPreferences
      await prefs.setString(
        storageKey,
        jsonEncode(existingList.map((e) => e.toJson()).toList()),
      );

      // Notify UI subscribers
      _notificationEventController.add(null);
    } catch (_) {}
  }

  /// Internal parser that extracts valid non-expired entries from raw JSON.
  List<NotificationEntity> _parseAndPrune(String? rawList) {
    if (rawList == null || rawList.isEmpty) return [];

    try {
      final decoded = jsonDecode(rawList) as List<dynamic>;
      final cutoff = _retentionCutoff;
      final List<NotificationEntity> list = [];
      bool hadExpiredItems = false;

      for (final item in decoded) {
        final entity = NotificationEntity.fromJson(
          item as Map<String, dynamic>,
        );
        if (entity.timestamp.isAfter(cutoff)) {
          list.add(entity);
        } else {
          hadExpiredItems = true;
        }
      }

      // Sort newest-first
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Asynchronously write back pruned list if any expired items were dropped
      if (hadExpiredItems) {
        final cleanedJson = jsonEncode(list.map((e) => e.toJson()).toList());
        _lastRawJson = cleanedJson;
        unawaited(_prefs.setString(storageKey, cleanedJson));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  /// Returns valid notifications using cached list when storage string hasn't changed.
  List<NotificationEntity> get _activeNotifications {
    final rawList = _prefs.getString(storageKey);
    final cutoff = _retentionCutoff;

    // Fast-path: return memoized cache if raw storage string is unchanged
    if (rawList == _lastRawJson && _cachedList != null) {
      final initialCount = _cachedList!.length;
      _cachedList!.removeWhere((n) => n.timestamp.isBefore(cutoff));
      if (_cachedList!.length < initialCount) {
        unawaited(_commit(_cachedList!));
      }
      return _cachedList!;
    }

    _lastRawJson = rawList;
    _cachedList = _parseAndPrune(rawList);
    return _cachedList!;
  }

  /// Synchronizes cache to disk and notifies listeners.
  Future<void> _commit(List<NotificationEntity> list) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    _lastRawJson = encoded;
    _cachedList = list;
    await _prefs.setString(storageKey, encoded);
    _notificationEventController.add(null);
  }

  @override
  Future<List<NotificationEntity>> getNotifications({
    NotificationCategory? category,
  }) async {
    final all = _activeNotifications;
    if (category == null) {
      return List.unmodifiable(all);
    }
    return all.where((n) => n.category == category).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final all = _activeNotifications;
    int count = 0;
    for (final n in all) {
      if (!n.isRead) count++;
    }
    return count;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final all = List<NotificationEntity>.from(_activeNotifications);
    bool found = false;

    for (int i = 0; i < all.length; i++) {
      if (all[i].id == notificationId) {
        if (!all[i].isRead) {
          all[i] = all[i].copyWith(isRead: true);
          found = true;
        }
        break;
      }
    }

    if (found) {
      await _commit(all);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final all = List<NotificationEntity>.from(_activeNotifications);
    bool anyUpdated = false;

    for (int i = 0; i < all.length; i++) {
      if (!all[i].isRead) {
        all[i] = all[i].copyWith(isRead: true);
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      await _commit(all);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final all = List<NotificationEntity>.from(_activeNotifications);
    final initialLength = all.length;
    all.removeWhere((n) => n.id == notificationId);

    if (all.length < initialLength) {
      await _commit(all);
    }
  }

  /// Clears in-memory cache to force a fresh disk read.
  void invalidateCache() {
    _lastRawJson = null;
    _cachedList = null;
  }
}
