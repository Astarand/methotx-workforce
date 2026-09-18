import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/notification_service.dart';

class PermissionsState {
  final PermissionStatus locationStatus;
  final PermissionStatus notificationStatus;
  final PermissionStatus photosStatus;
  final bool isLoading;

  const PermissionsState({
    this.locationStatus = PermissionStatus.denied,
    this.notificationStatus = PermissionStatus.denied,
    this.photosStatus = PermissionStatus.denied,
    this.isLoading = false,
  });

  bool get isLocationGranted =>
      locationStatus.isGranted || locationStatus.isLimited;

  bool get isNotificationGranted =>
      notificationStatus.isGranted || notificationStatus.isProvisional;

  bool get isPhotosGranted =>
      photosStatus.isGranted || photosStatus.isLimited;

  bool get allGranted =>
      isLocationGranted && isNotificationGranted && isPhotosGranted;

  bool get hasPermanentlyDenied =>
      locationStatus.isPermanentlyDenied ||
      notificationStatus.isPermanentlyDenied ||
      photosStatus.isPermanentlyDenied;

  PermissionsState copyWith({
    PermissionStatus? locationStatus,
    PermissionStatus? notificationStatus,
    PermissionStatus? photosStatus,
    bool? isLoading,
  }) {
    return PermissionsState(
      locationStatus: locationStatus ?? this.locationStatus,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      photosStatus: photosStatus ?? this.photosStatus,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PermissionsController extends StateNotifier<PermissionsState> {
  PermissionsController() : super(const PermissionsState()) {
    checkPermissionsStatus();
  }

  /// Checks the current status of all critical permissions without triggering prompts
  Future<void> checkPermissionsStatus() async {
    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;
    final photos = Platform.isIOS ? await Permission.photos.status : PermissionStatus.granted;

    state = state.copyWith(
      locationStatus: location,
      notificationStatus: notification,
      photosStatus: photos,
    );
  }

  /// Requests Location, Notifications, and Photos/Storage permissions sequentially.
  /// If any permission is permanently denied, prompts openAppSettings().
  Future<bool> requestAllPermissions() async {
    state = state.copyWith(isLoading: true);

    try {
      // 1. Request Location Permission (When In Use)
      var locStatus = await Permission.locationWhenInUse.status;
      if (!locStatus.isGranted && !locStatus.isPermanentlyDenied) {
        locStatus = await Permission.locationWhenInUse.request();
      }

      // 2. Request Push Notifications Permission (Android 13+ & iOS)
      await NotificationService.instance.requestPermissions();
      var notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted && !notifStatus.isPermanentlyDenied) {
        notifStatus = await Permission.notification.request();
      }

      // 3. Request Media / Photos Storage Permission (iOS Photo Library only; Android uses system picker)
      PermissionStatus photoStatus = PermissionStatus.granted;
      if (Platform.isIOS) {
        photoStatus = await Permission.photos.status;
        if (!photoStatus.isGranted && !photoStatus.isPermanentlyDenied) {
          photoStatus = await Permission.photos.request();
        }
      }

      // 4. Update reactive state
      state = state.copyWith(
        locationStatus: locStatus,
        notificationStatus: notifStatus,
        photosStatus: photoStatus,
        isLoading: false,
      );

      // Returns true if critical location permission is granted
      return locStatus.isGranted || locStatus.isLimited;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// Explicit helper to open device application settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, PermissionsState>((ref) {
  return PermissionsController();
});
