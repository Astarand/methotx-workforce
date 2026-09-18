import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/remote_config_service.dart';

/// Native Platform Adaptive In-App Update Dialog
/// On Android: Renders authentic Google Play In-App Update Bottom Sheet (matching Google Play UI)
/// On iOS: Renders Apple CupertinoAlertDialog
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onUpdatePressed;
  final VoidCallback? onLaterPressed;
  final VoidCallback? onMoreInfoPressed;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onUpdatePressed,
    this.onLaterPressed,
    this.onMoreInfoPressed,
  });

  /// Static helper to display the platform-appropriate update UI
  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required RemoteConfigService remoteConfigService,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return showCupertinoDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: !updateInfo.isForceUpdate,
        builder: (dialogContext) {
          return PopScope(
            canPop: !updateInfo.isForceUpdate,
            child: AppUpdateDialog(
              updateInfo: updateInfo,
              onUpdatePressed: () async {
                await remoteConfigService.launchStoreUrl(updateInfo.storeUrl);
              },
              onLaterPressed: updateInfo.isForceUpdate
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                    },
            ),
          );
        },
      );
    }

    // Android: Display authentic Google Play In-App Update Bottom Sheet
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      isDismissible: !updateInfo.isForceUpdate,
      enableDrag: !updateInfo.isForceUpdate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return PopScope(
          canPop: !updateInfo.isForceUpdate,
          child: AppUpdateDialog(
            updateInfo: updateInfo,
            onUpdatePressed: () async {
              await remoteConfigService.launchStoreUrl(updateInfo.storeUrl);
            },
            onMoreInfoPressed: () async {
              await remoteConfigService.launchStoreUrl(updateInfo.storeUrl);
            },
            onLaterPressed: updateInfo.isForceUpdate
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                  },
          ),
        );
      },
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      return _buildCupertinoDialog(context);
    }
    return _buildGooglePlayBottomSheet(context);
  }

  /// Authentic Google Play Store In-App Update Bottom Sheet UI
  Widget _buildGooglePlayBottomSheet(BuildContext context) {
    final updateInfo = widget.updateInfo;
    final isForce = updateInfo.isForceUpdate;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          16 + (bottomPadding > 0 ? bottomPadding : 8),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Google Play Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const GooglePlayLogo(size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Google Play',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF202124),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const Spacer(),
                  if (!isForce && widget.onLaterPressed != null)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF5F6368),
                        size: 22,
                      ),
                      onPressed: widget.onLaterPressed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Title & Subtitle
              const Text(
                'Update available',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFF202124),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'To use this app, download the latest version.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFF5F6368),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // 3. App Identity Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE8EAED),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MethotX Workforce',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Color(0xFF202124),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${updateInfo.latestVersion} Available (Current: v${updateInfo.currentVersion})',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Color(0xFF5F6368),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. "What's new" Collapsible Section
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "What's new",
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Color(0xFF202124),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Updated for version ${updateInfo.latestVersion}',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Color(0xFF5F6368),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF5F6368),
                            size: 22,
                          ),
                        ],
                      ),
                      if (_isExpanded || updateInfo.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          updateInfo.releaseNotes.isNotEmpty
                              ? updateInfo.releaseNotes
                              : 'Bug fixes, performance improvements, and security enhancements.',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Color(0xFF3C4043),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. Action Buttons (Google Play Style)
              Row(
                children: [
                  // Secondary / More Info Button
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: widget.onMoreInfoPressed ??
                            widget.onLaterPressed ??
                            widget.onUpdatePressed,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFDADCE0),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          (!isForce && widget.onLaterPressed != null)
                              ? 'Update Later'
                              : 'More info',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Color(0xFF01875F),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Primary Google Play Green Update Button
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: widget.onUpdatePressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF01875F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Apple iOS Native CupertinoAlertDialog
  Widget _buildCupertinoDialog(BuildContext context) {
    final updateInfo = widget.updateInfo;
    final isForce = updateInfo.isForceUpdate;

    return CupertinoAlertDialog(
      title: const Text('Update Available'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'v${updateInfo.latestVersion} Available (Current: v${updateInfo.currentVersion})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeBlue,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isForce
                  ? 'To use this app, please download the latest version from the App Store.'
                  : 'A new version of MethotX Workforce is available on the App Store.',
            ),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "What's New:\n${updateInfo.releaseNotes}",
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isForce && widget.onLaterPressed != null)
          CupertinoDialogAction(
            onPressed: widget.onLaterPressed,
            child: const Text('Update Later'),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: widget.onUpdatePressed,
          child: const Text('Update'),
        ),
      ],
    );
  }
}

/// Precise Vector Logo Painter for Google Play Store Logo
class GooglePlayLogo extends StatelessWidget {
  final double size;
  const GooglePlayLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.05),
      painter: const _GooglePlayPainter(),
    );
  }
}

class _GooglePlayPainter extends CustomPainter {
  const _GooglePlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Authentic Google Play Brand Colors
    final cyanPaint = Paint()..color = const Color(0xFF00C3FF);
    final greenPaint = Paint()..color = const Color(0xFF00E676);
    final redPaint = Paint()..color = const Color(0xFFFF334B);
    final yellowPaint = Paint()..color = const Color(0xFFFFD400);

    // Coordinates of Play Triangle
    final pA = Offset(w * 0.08, h * 0.06); // Top-left
    final pB = Offset(w * 0.08, h * 0.94); // Bottom-left
    final pC = Offset(w * 0.92, h * 0.50); // Right tip
    final pD = Offset(w * 0.68, h * 0.35); // Top-right fold
    final pE = Offset(w * 0.68, h * 0.65); // Bottom-right fold
    final pO = Offset(w * 0.52, h * 0.50); // Center fold

    // 1. Top Cyan Shape
    final pathCyan = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pD.dx, pD.dy)
      ..lineTo(pO.dx, pO.dy)
      ..close();
    canvas.drawPath(pathCyan, cyanPaint);

    // 2. Bottom Red Shape
    final pathRed = Path()
      ..moveTo(pB.dx, pB.dy)
      ..lineTo(pE.dx, pE.dy)
      ..lineTo(pO.dx, pO.dy)
      ..close();
    canvas.drawPath(pathRed, redPaint);

    // 3. Left Green Shape
    final pathGreen = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pB.dx, pB.dy)
      ..lineTo(pO.dx, pO.dy)
      ..close();
    canvas.drawPath(pathGreen, greenPaint);

    // 4. Right Yellow Shape
    final pathYellow = Path()
      ..moveTo(pD.dx, pD.dy)
      ..lineTo(pC.dx, pC.dy)
      ..lineTo(pE.dx, pE.dy)
      ..lineTo(pO.dx, pO.dy)
      ..close();
    canvas.drawPath(pathYellow, yellowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
