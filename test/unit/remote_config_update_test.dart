import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/core/services/remote_config_service.dart';
import 'package:methotx_workforce/shared/widgets/app_update_dialog.dart';

void main() {
  group('RemoteConfigService Version Comparison Tests', () {
    test('Identifies equal versions correctly', () {
      expect(RemoteConfigService.compareVersions('1.1.0', '1.1.0'), 0);
      expect(RemoteConfigService.compareVersions('1.1.0+2', '1.1.0+5'), 0);
      expect(RemoteConfigService.compareVersions('2.0', '2.0.0'), 0);
    });

    test('Identifies client version behind latest version', () {
      expect(RemoteConfigService.compareVersions('1.1.0', '1.1.1'), isNegative);
      expect(RemoteConfigService.compareVersions('1.1.0', '1.2.0'), isNegative);
      expect(RemoteConfigService.compareVersions('1.0.9', '1.1.0'), isNegative);
      expect(RemoteConfigService.compareVersions('1.9.0', '1.10.0'), isNegative);
      expect(RemoteConfigService.compareVersions('1.1.0+2', '2.0.0'), isNegative);
    });

    test('Identifies client version ahead of remote version', () {
      expect(RemoteConfigService.compareVersions('1.2.0', '1.1.0'), isPositive);
      expect(RemoteConfigService.compareVersions('2.0.0', '1.9.9'), isPositive);
      expect(RemoteConfigService.compareVersions('1.10.0', '1.9.0'), isPositive);
    });
  });

  group('AppUpdateDialog Widget Tests', () {
    testWidgets('Renders flexible update bottom sheet with Update Later option',
        (tester) async {
      const updateInfo = AppUpdateInfo(
        hasUpdate: true,
        isForceUpdate: false,
        currentVersion: '1.1.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.1.0',
        releaseNotes: 'Fixed bug in attendance check-in.',
        storeUrl: 'https://play.google.com/store/apps/details?id=com.clickngotech.methotx_workforce',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              updateInfo: updateInfo,
              onUpdatePressed: () {},
              onLaterPressed: () {},
            ),
          ),
        ),
      );

      // Verify Google Play Title & Header
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('To use this app, download the latest version.'), findsOneWidget);
      expect(find.text('v1.2.0 Available (Current: v1.1.0)'), findsOneWidget);

      // Verify Release notes
      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('Fixed bug in attendance check-in.'), findsOneWidget);

      // Verify Buttons: Both Update and Update Later should be present
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Update Later'), findsOneWidget);
    });

    testWidgets('Renders mandatory Google Play force update without Update Later option',
        (tester) async {
      const updateInfo = AppUpdateInfo(
        hasUpdate: true,
        isForceUpdate: true,
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.1.0',
        releaseNotes: 'Security patch required to continue.',
        storeUrl: 'https://play.google.com/store/apps/details?id=com.clickngotech.methotx_workforce',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              updateInfo: updateInfo,
              onUpdatePressed: () {},
            ),
          ),
        ),
      );

      // Verify Google Play Header & Title
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('v1.2.0 Available (Current: v1.0.0)'), findsOneWidget);

      // Verify Only Update and More info are present; Update Later MUST NOT exist
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('More info'), findsOneWidget);
      expect(find.text('Update Later'), findsNothing);
    });

    testWidgets('Renders iOS native CupertinoAlertDialog on iOS platform',
        (tester) async {
      const updateInfo = AppUpdateInfo(
        hasUpdate: true,
        isForceUpdate: true,
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.1.0',
        releaseNotes: 'Performance improvements and bug fixes.',
        storeUrl: 'https://apps.apple.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: AppUpdateDialog(
              updateInfo: updateInfo,
              onUpdatePressed: () {},
            ),
          ),
        ),
      );

      // Verify iOS title and buttons
      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('v1.2.0 Available (Current: v1.0.0)'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Update Later'), findsNothing);
    });
  });
}
