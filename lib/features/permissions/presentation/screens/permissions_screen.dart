import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routes/app_startup_notifier.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../controllers/permissions_controller.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(permissionsControllerProvider.notifier).checkPermissionsStatus();
    }
  }

  void _navigateToNext(BuildContext context) {
    final startupState = ref.read(appStartupProvider);
    if (startupState.isLoggedIn) {
      if (!startupState.hasPinSetup) {
        context.go('/create-pin');
      } else if (startupState.isAppLocked) {
        context.go('/pin-unlock');
      } else {
        context.go('/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(permissionsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable Content (Header & Permission Tiles)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security_outlined,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Required Permissions',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'MethotX needs these device access permissions to provide automated attendance and corporate security.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _buildPermissionTile(
                      icon: Icons.location_on_outlined,
                      title: 'Precise Geofencing Location',
                      description: 'Validates automated check-ins when you enter authorized office zones.',
                      isGranted: permState.isLocationGranted,
                    ),
                    const SizedBox(height: 12),

                    _buildPermissionTile(
                      icon: Icons.notifications_none_outlined,
                      title: 'Push Notifications',
                      description: 'Shift reminders, overtime alerts, leave approvals, and broadcast bulletins.',
                      isGranted: permState.isNotificationGranted,
                    ),
                    const SizedBox(height: 12),

                    _buildPermissionTile(
                      icon: Icons.folder_open_outlined,
                      title: 'Files & Documents Access',
                      description: 'Required to download payslips, export HR letters, and attach receipts for claims.',
                      isGranted: permState.isPhotosGranted,
                    ),
                    const SizedBox(height: 12),

                    _buildPermissionTile(
                      icon: Platform.isIOS ? Icons.face_rounded : Icons.fingerprint_outlined,
                      title: Platform.isIOS ? 'Face ID & Biometrics' : 'Biometric Authentication',
                      description: 'Enables quick biometric login without typing credentials each time.',
                      isGranted: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Action Bar with responsive layout
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.sm,
                AppSpacing.marginMobile,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    title: permState.isLoading ? 'Requesting...' : 'Allow & Continue',
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    onPressed: permState.isLoading
                        ? null
                        : () async {
                            final isLocationGranted = await ref
                                .read(permissionsControllerProvider.notifier)
                                .requestAllPermissions();
                            final currentPerms = ref.read(permissionsControllerProvider);

                            if (isLocationGranted || currentPerms.isLocationGranted) {
                              await ref.read(appStartupProvider.notifier).grantPermissions();
                              if (context.mounted) {
                                _navigateToNext(context);
                              }
                            } else if (currentPerms.locationStatus == PermissionStatus.permanentlyDenied) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Location permission is required for attendance check-in. Please enable it in Settings.',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Settings',
                                      onPressed: () => openAppSettings(),
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        await ref.read(appStartupProvider.notifier).grantPermissions();
                        if (context.mounted) {
                          _navigateToNext(context);
                        }
                      },
                      child: Text(
                        'Set Up Later in Settings',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.primaryContainer.withValues(alpha: 0.3)
                  : AppColors.primaryContainer.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (isGranted)
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
