import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Data class holding evaluated In-App Update state
class AppUpdateInfo {
  final bool hasUpdate;
  final bool isForceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String releaseNotes;
  final String storeUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.releaseNotes,
    required this.storeUrl,
  });

  @override
  String toString() {
    return 'AppUpdateInfo(hasUpdate: $hasUpdate, isForceUpdate: $isForceUpdate, current: $currentVersion, latest: $latestVersion)';
  }
}

/// Service managing Firebase Remote Config parameters & Version Gating
class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  static const String keyLatestVersion = 'latest_version';
  static const String keyMinRequiredVersion = 'min_required_version';
  static const String keyForceUpdate = 'force_update';
  static const String keyUpdateUrlAndroid = 'update_url_android';
  static const String keyUpdateUrlIos = 'update_url_ios';
  static const String keyReleaseNotes = 'release_notes';

  static const Map<String, dynamic> _defaults = {
    keyLatestVersion: '1.1.0',
    keyMinRequiredVersion: '1.1.0',
    keyForceUpdate: true,
    keyUpdateUrlAndroid:
        'https://play.google.com/store/apps/details?id=com.clickngotech.methotx_workforce',
    keyUpdateUrlIos: 'https://apps.apple.com',
    keyReleaseNotes:
        'Performance improvements, bug fixes, and enhanced security.',
  };

  /// Initializes Remote Config with fallback defaults and fetches live data
  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults(_defaults);
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfig] Warning: Failed to fetch/activate: $e');
    }
  }

  /// Evaluates whether an update is available or mandatory
  Future<AppUpdateInfo?> checkAppUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final latestVersion = _remoteConfig.getString(keyLatestVersion).trim();
      final minRequiredVersion =
          _remoteConfig.getString(keyMinRequiredVersion).trim();
      final forceUpdateFlag = _remoteConfig.getBool(keyForceUpdate);
      final releaseNotes = _remoteConfig.getString(keyReleaseNotes).trim();

      final storeUrl = Platform.isIOS
          ? _remoteConfig.getString(keyUpdateUrlIos).trim()
          : _remoteConfig.getString(keyUpdateUrlAndroid).trim();

      final isBehindLatest = compareVersions(currentVersion, latestVersion) < 0;
      final isBehindMin =
          compareVersions(currentVersion, minRequiredVersion) < 0;

      final hasUpdate = isBehindLatest || isBehindMin;
      // Enforce mandatory update condition: if an update exists, it must be installed
      final isForceUpdate = forceUpdateFlag || isBehindMin || hasUpdate;

      if (!hasUpdate) {
        return null;
      }

      return AppUpdateInfo(
        hasUpdate: hasUpdate,
        isForceUpdate: isForceUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minRequiredVersion: minRequiredVersion,
        releaseNotes: releaseNotes.isNotEmpty
            ? releaseNotes
            : 'New features, improvements, and bug fixes available.',
        storeUrl: storeUrl,
      );
    } catch (e) {
      debugPrint('[RemoteConfig] Error evaluating update: $e');
      return null;
    }
  }

  /// Safely compares semantic versions (e.g. "1.1.0" vs "1.2.0")
  /// Returns:
  /// - Negative integer if v1 < v2
  /// - Zero if v1 == v2
  /// - Positive integer if v1 > v2
  static int compareVersions(String v1, String v2) {
    try {
      final v1Clean = v1.split('+').first.trim();
      final v2Clean = v2.split('+').first.trim();

      final v1Parts =
          v1Clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final v2Parts =
          v2Clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLength = v1Parts.length > v2Parts.length
          ? v1Parts.length
          : v2Parts.length;

      for (int i = 0; i < maxLength; i++) {
        final part1 = i < v1Parts.length ? v1Parts[i] : 0;
        final part2 = i < v2Parts.length ? v2Parts[i] : 0;

        if (part1 != part2) {
          return part1.compareTo(part2);
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Opens the Play Store or App Store page
  Future<bool> launchStoreUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      debugPrint('[RemoteConfig] Could not launch store URL ($url): $e');
      return false;
    }
  }
}

/// Global Riverpod Provider for RemoteConfigService
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});
