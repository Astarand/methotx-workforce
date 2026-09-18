// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/attendance/domain/entities/attendance_entity.dart';
import '../../features/notifications/data/local_notification_repository.dart';
import '../../main.dart';
import '../../routes/app_routes.dart';
import '../network/api_constants.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../network/environment_config.dart';
import 'storage_service.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint('[NotificationService] $message');
  }
}

/// Top-level background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _log('Handling background message: ${message.messageId}');
  await LocalNotificationRepository.saveIncomingRemoteMessage(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;

  // Stream subscriptions – keep references for proper cancellation
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _backgroundSub;

  FlutterLocalNotificationsPlugin? _localNotificationsInstance;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      _localNotificationsInstance ??= FlutterLocalNotificationsPlugin();

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription =
      'This channel is used for critical workplace push notifications.';

  // Shift Reminder IDs
  static const int shiftStart30Id = 1001;
  static const int shiftStart15Id = 1002;
  static const int shiftStart5Id = 1003;
  static const int shiftEnd30Id = 2001;
  static const int shiftEnd10Id = 2002;

  bool _isInitialized = false;
  StorageService? _storageService;
  DioClient? _dioClient;

  /// Safely checks if Firebase has been initialized (prevents test crashes)
  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Configure service dependencies for token synchronization
  void configureDependencies({
    StorageService? storageService,
    DioClient? dioClient,
  }) {
    if (storageService != null) _storageService = storageService;
    if (dioClient != null) _dioClient = dioClient;
  }

  /// Initialize Firebase Messaging & Local Notification plugins
  Future<void> initialize({
    StorageService? storageService,
    DioClient? dioClient,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    configureDependencies(storageService: storageService, dioClient: dioClient);

    // 1. Initialize timezone database for local shift scheduling
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      _log('Timezone init exception: $e');
    }

    // 2. Initialize Local Notifications for Foreground display and local schedules
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );
    } catch (e) {
      _log('Local notifications init exception: $e');
    }

    // 3. Create Android High Importance Notification Channel
    if (!kIsWeb && Platform.isAndroid) {
      try {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(androidChannel);
      } catch (e) {
        _log('Android channel creation exception: $e');
      }
    }

    if (!isFirebaseAvailable) {
      _log('Firebase not initialized. Local scheduling active.');
      return;
    }

    try {
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Set Foreground presentation options for iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle Foreground Messages — show notification only, do NOT auto-navigate
      // Navigation will happen when the user taps the local notification
      _foregroundSub = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        _log('Foreground message received: ${message.notification?.title}');
        LocalNotificationRepository.saveIncomingRemoteMessage(message);
        _showForegroundNotification(message);
      });

      // Handle notification click when app is in background
      _backgroundSub = FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) {
        _log('Notification opened from background: ${message.data}');
        LocalNotificationRepository.saveIncomingRemoteMessage(message);
        _handleMessageNavigation(message);
      });

      // Check if app was launched from a terminated state via a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _log(
          'App launched from terminated state via notification: ${initialMessage.data}',
        );
        LocalNotificationRepository.saveIncomingRemoteMessage(initialMessage);
        // Delay navigation to give GoRouter time to initialize after cold boot
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleMessageNavigation(initialMessage);
        });
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _log('FCM Token refreshed: $newToken');
        syncFcmTokenWithBackend(customToken: newToken);
      });

      // Initial token sync in background (non-blocking so cold boot renders instantly)
      unawaited(syncFcmTokenWithBackend().catchError((_) {}));
    } catch (e) {
      _log('Failed to initialize Firebase messaging: $e');
    }
  }

  /// Request permissions for iOS and Android 13+
  /// Request notification permissions for iOS and Android (API 33+)
  Future<void> requestNotificationPermissions() async {
    if (!isFirebaseAvailable) return;
    if (Platform.isIOS) {
      // iOS permission request already handled via Firebase Messaging
      await requestPermissions();
    } else if (Platform.isAndroid) {
      // Android 13+ requires runtime permission for POST_NOTIFICATIONS
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        _log('Android notification permission status: $status');
      } else {
        _log('Android notification permission already granted');
      }
    }
  }

  // Deprecated: kept for backward compatibility
  Future<NotificationSettings?> requestPermissions() async {
    if (!isFirebaseAvailable) return null;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      _log('Permission status: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Automatically sync token as soon as permission is granted
        unawaited(syncFcmTokenWithBackend().catchError((_) {}));
      }
      return settings;
    } catch (e) {
      _log('Failed to request permissions: $e');
      return null;
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    if (!isFirebaseAvailable) return null;
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        int retries = 0;
        // On iOS, APNs token can take a couple seconds to be returned by Apple asynchronously
        while (apnsToken == null && retries < 5) {
          await Future.delayed(const Duration(milliseconds: 1000));
          apnsToken = await _messaging.getAPNSToken();
          retries++;
        }
        if (apnsToken == null) {
          _log(
            '⚠️ APNs token not yet available on iOS after retries. Ensure APNs key is configured in Firebase Console.',
          );
          return null;
        }
        _log('✅ APNs token acquired: $apnsToken');
      }
      final token = await _messaging.getToken();
      _log('✅ FCM token acquired: $token');
      return token;
    } catch (e) {
      _log('Failed to retrieve FCM token: $e');
      return null;
    }
  }

  /// Show heads-up notification in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // On iOS, setForegroundNotificationPresentationOptions already presents the banner natively.
    // Calling flutter_local_notifications on iOS produces duplicate notification banners.
    if (!kIsWeb && Platform.isIOS) return;

    final notification = message.notification;
    final title =
        message.data['title_en']?.toString() ??
        message.data['en_title']?.toString() ??
        notification?.title ??
        message.data['title']?.toString();
    final body =
        message.data['body_en']?.toString() ??
        message.data['en_body']?.toString() ??
        message.data['message_en']?.toString() ??
        message.data['en_message']?.toString() ??
        notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString();

    if (title == null && body == null) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id:
          notification?.hashCode ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: message.data.toString(),
    );
  }

  /// Show instant local notification on device
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      _log('Error showing notification: $e');
    }
  }

  /// Schedules a local notification at a specific date and time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _log('Scheduled shift reminder #$id for $scheduledDate');
    } catch (e) {
      _log('Error scheduling notification #$id: $e');
    }
  }

  /// Cancel a specific scheduled notification by ID
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
    } catch (_) {}
  }

  /// Cancels all Shift Start reminders (e.g. after punching in)
  Future<void> cancelShiftStartReminders() async {
    await cancelNotification(shiftStart30Id);
    await cancelNotification(shiftStart15Id);
    await cancelNotification(shiftStart5Id);
    _log('Shift start reminders cancelled.');
  }

  /// Cancels all Shift End reminders (e.g. after punching out)
  Future<void> cancelShiftEndReminders() async {
    await cancelNotification(shiftEnd30Id);
    await cancelNotification(shiftEnd10Id);
    _log('Shift end reminders cancelled.');
  }

  /// Cancels all scheduled shift reminders
  Future<void> cancelAllShiftReminders() async {
    await cancelShiftStartReminders();
    await cancelShiftEndReminders();
  }

  /// Schedule 30m, 15m, 5m start reminders and 30m, 10m end reminders from active Shift & Attendance
  Future<void> scheduleShiftReminders({
    required DateTime? shiftStart,
    required DateTime? shiftEnd,
    bool isPunchedIn = false,
    bool isPunchedOut = false,
  }) async {
    final now = DateTime.now();

    // 1. Shift Start Reminders (Only for employees who have NOT punched in yet for today)
    if (isPunchedIn) {
      await cancelShiftStartReminders();
    } else if (shiftStart != null) {
      // 30 minutes before
      final startMinus30 = shiftStart.subtract(const Duration(minutes: 30));
      if (startMinus30.isAfter(now)) {
        await scheduleNotification(
          id: shiftStart30Id,
          title: 'Shift Reminder (30 Minutes)',
          body: 'Your shift begins in 30 minutes. Please get ready.',
          scheduledDate: startMinus30,
        );
      }

      // 15 minutes before
      final startMinus15 = shiftStart.subtract(const Duration(minutes: 15));
      if (startMinus15.isAfter(now)) {
        await scheduleNotification(
          id: shiftStart15Id,
          title: 'Shift Reminder (15 Minutes)',
          body: 'Your shift starts in 15 minutes. Please be on your way.',
          scheduledDate: startMinus15,
        );
      }

      // 5 minutes before
      final startMinus5 = shiftStart.subtract(const Duration(minutes: 5));
      if (startMinus5.isAfter(now)) {
        await scheduleNotification(
          id: shiftStart5Id,
          title: 'Shift Starting Soon (5 Minutes)',
          body:
              'Only 5 minutes left until shift starts! Please ensure timely punch-in.',
          scheduledDate: startMinus5,
        );
      }
    }

    // 2. Shift End Reminders (Only for employees who HAVE punched in today and have NOT punched out yet)
    if (isPunchedOut) {
      await cancelShiftEndReminders();
    } else if (isPunchedIn && shiftEnd != null) {
      // 30 minutes before
      final endMinus30 = shiftEnd.subtract(const Duration(minutes: 30));
      if (endMinus30.isAfter(now)) {
        await scheduleNotification(
          id: shiftEnd30Id,
          title: 'Shift Ending Reminder (30 Minutes)',
          body: 'Your shift ends in 30 minutes. Please wrap up your tasks.',
          scheduledDate: endMinus30,
        );
      }

      // 10 minutes before
      final endMinus10 = shiftEnd.subtract(const Duration(minutes: 10));
      if (endMinus10.isAfter(now)) {
        await scheduleNotification(
          id: shiftEnd10Id,
          title: 'Shift Ending (10 Minutes)',
          body:
              'Your shift ends in 10 minutes. Don\'t forget to punch out before leaving.',
          scheduledDate: endMinus10,
        );
      }
    }
  }

  /// Helper to automatically schedule shift reminders directly from AttendanceEntity.
  /// Skips scheduling (and cancels any existing) if today is a non-working day:
  /// office closed, public holiday, weekly off (weekend), or employee on approved leave.
  Future<void> scheduleShiftRemindersFromAttendance(
    AttendanceEntity attendance,
  ) async {
    // Guard: Do NOT schedule reminders on non-working days
    if (attendance.isNonWorkingDay()) {
      final reason = attendance.isOnLeave
          ? 'employee on leave (${attendance.leaveType ?? "approved"})'
          : attendance.isHoliday
          ? 'holiday (${attendance.holidayName ?? "company holiday"})'
          : attendance.isOfficeOff()
          ? 'office closed'
          : 'weekly off / weekend';
      _log('⏭️ Skipping shift reminders — $reason');
      await cancelAllShiftReminders();
      return;
    }

    final start = attendance.getShiftStartDateTime();
    final end = attendance.getShiftEndDateTime();
    final isPunchedIn = attendance.punchInTime != null;
    final isPunchedOut = attendance.punchOutTime != null;

    await scheduleShiftReminders(
      shiftStart: start,
      shiftEnd: end,
      isPunchedIn: isPunchedIn,
      isPunchedOut: isPunchedOut,
    );
  }

  /// Syncs FCM Token with Laravel Backend via POST /api/users/employee/update-fcm-token
  Future<void> syncFcmTokenWithBackend({
    String? customToken,
    StorageService? storageService,
    DioClient? dioClient,
  }) async {
    if (!isFirebaseAvailable) {
      return;
    }

    try {
      final storage = storageService ?? _storageService;
      final dio = dioClient ?? _dioClient;

      final token = customToken ?? await getToken();
      if (token == null || token.trim().isEmpty) {
        _log('No FCM token available to sync.');
        return;
      }

      // Check if user is currently authenticated
      final authToken =
          await storage?.getSecure(ApiConstants.storageTokenKey) ??
          await storage?.getString(ApiConstants.storageTokenKey);

      if (authToken == null || authToken.trim().isEmpty) {
        _log('User not logged in yet. Caching pending FCM token.');
        await storage?.saveString('pending_fcm_token', token);
        return;
      }

      Response response;
      if (dio != null) {
        response = await dio.post(
          ApiEndpoints.updateFcmToken,
          data: {
            'fcm_token': token,
            'locale': 'en',
            'language': 'en',
            'lang': 'en',
          },
        );
      } else {
        // Fallback standalone Dio instance with authorization header
        final fallbackDio = Dio(
          BaseOptions(
            baseUrl: EnvironmentConfig.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {
              ApiConstants.headerContentType: ApiConstants.applicationJson,
              ApiConstants.headerAccept: ApiConstants.applicationJson,
              ApiConstants.headerAuthorization: 'Bearer $authToken',
              'Accept-Language': 'en,en-US;q=0.9',
              'X-Locale': 'en',
              'X-Language': 'en',
              'X-Localization': 'en',
              'Locale': 'en',
            },
          ),
        );
        response = await fallbackDio.post(
          ApiEndpoints.updateFcmToken,
          data: {
            'fcm_token': token,
            'locale': 'en',
            'language': 'en',
            'lang': 'en',
          },
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('FCM token successfully synchronized with Laravel backend.');
        await storage?.remove('pending_fcm_token');
      }
    } catch (e) {
      _log('Failed to sync FCM token with backend: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION NAVIGATION — Production-Grade Hybrid Approach
  // ─────────────────────────────────────────────────────────────────────────

  /// Routes that are safe to navigate to from a notification tap.
  /// Auth/security/setup screens are explicitly excluded.
  static const Set<String> _allowedNotificationRoutes = {
    AppRoutes.dashboard,
    AppRoutes.attendanceHistory,
    AppRoutes.tasks,
    AppRoutes.payslip,
    AppRoutes.leave,
    AppRoutes.profile,
    AppRoutes.hrLetter,
    AppRoutes.performance,
    AppRoutes.claims,
    AppRoutes.requisitions,
    AppRoutes.notifications,
  };

  /// Maps backend notification `type` values to Flutter app routes.
  /// This is the PRIMARY navigation strategy — no dependency on backend
  /// knowing Flutter route paths.
  static const Map<String, String> _typeToRoute = {
    'task': AppRoutes.tasks,
    'leave': AppRoutes.leave,
    'payslip': AppRoutes.payslip,
    'attendance': AppRoutes.dashboard,
    'hr_letter': AppRoutes.hrLetter,
    'performance': AppRoutes.performance,
    'claim': AppRoutes.claims,
    'requisition': AppRoutes.requisitions,
    'test': AppRoutes.dashboard,
  };

  /// Resolves the target route from a notification data payload.
  ///
  /// Strategy (Hybrid):
  /// 1. If `route` key exists AND is a whitelisted route → use it (backend override)
  /// 2. Else if `type` key exists AND maps to a known route → use the mapping
  /// 3. Else → fallback to dashboard
  String _resolveRouteFromData(Map<String, dynamic> data) {
    // 1. Check explicit route key from backend (validated)
    final explicitRoute = data['route'] as String?;
    if (explicitRoute != null &&
        _allowedNotificationRoutes.contains(explicitRoute)) {
      _log('Using explicit route from backend: $explicitRoute');
      return explicitRoute;
    }

    // 2. Map by notification type (primary strategy)
    final type = data['type'] as String?;
    if (type != null && _typeToRoute.containsKey(type)) {
      final mappedRoute = _typeToRoute[type]!;
      _log('Mapped type "$type" → route: $mappedRoute');
      return mappedRoute;
    }

    // 3. Fallback
    _log('No route or type match found, defaulting to dashboard');
    return AppRoutes.dashboard;
  }

  /// Navigate based on FCM notification payload (Background/Terminated tap)
  void _handleMessageNavigation(RemoteMessage message) {
    if (globalRouter == null) {
      _log('GoRouter not initialized yet, skipping navigation');
      return;
    }
    final route = _resolveRouteFromData(message.data);
    _log('Navigating to: $route');
    globalRouter!.go(route);
  }

  /// Navigate when user taps a local foreground notification
  void _onLocalNotificationTapped(NotificationResponse response) {
    _log('Local notification tapped: ${response.payload}');
    if (globalRouter == null || response.payload == null) return;

    try {
      // Payload is stored as data.toString(), attempt to parse it
      final payloadStr = response.payload!;
      // Dart's Map.toString() produces "{key: value, ...}" which isn't valid JSON.
      // Try JSON first, then fall back to type-based routing.
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(payloadStr));
      } catch (_) {
        // Payload isn't valid JSON — try simple key:value parsing
        data = _parseMapString(payloadStr);
      }
      final route = _resolveRouteFromData(data);
      _log('Local tap → navigating to: $route');
      globalRouter!.go(route);
    } catch (e) {
      _log('Failed to parse local notification payload: $e');
      globalRouter!.go(AppRoutes.dashboard);
    }
  }

  /// Parses Dart's Map.toString() format "{key: value, key2: value2}" into a Map.
  Map<String, dynamic> _parseMapString(String mapStr) {
    final cleaned = mapStr.trim();
    if (!cleaned.startsWith('{') || !cleaned.endsWith('}')) return {};
    final inner = cleaned.substring(1, cleaned.length - 1);
    final result = <String, dynamic>{};
    for (final pair in inner.split(',')) {
      final parts = pair.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        result[key] = value;
      }
    }
    return result;
  }

  /// Clean up stream subscriptions when the service is disposed (rarely needed for a singleton)
  void dispose() {
    _foregroundSub?.cancel();
    _backgroundSub?.cancel();
  }
}

/// Global Riverpod Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final dioClient = ref.watch(dioClientProvider);
  final service = NotificationService.instance;
  service.configureDependencies(
    storageService: storageService,
    dioClient: dioClient,
  );
  return service;
});
