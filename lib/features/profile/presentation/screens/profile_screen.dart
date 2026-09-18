import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../routes/app_routes.dart';
import '../../../../routes/app_startup_notifier.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/secure_network_image.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';
import '../../../authentication/domain/entities/auth_entity.dart';
import '../../../authentication/presentation/controllers/auth_notifier.dart';
import '../../domain/entities/profile_entity.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileControllerProvider).profile;
    _nameController = TextEditingController(text: profile.fullName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncControllersWithProfile(ProfileEntity profile) {
    if (_nameController.text != profile.fullName &&
        !_nameController.selection.isValid) {
      _nameController.text = profile.fullName;
    }
    if (_emailController.text != profile.email &&
        !_emailController.selection.isValid) {
      _emailController.text = profile.email;
    }
    if (_phoneController.text != profile.phone &&
        !_phoneController.selection.isValid) {
      _phoneController.text = profile.phone;
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      AppToast.showError(context, message: 'Please enter your name');
      return;
    }

    if (email.isEmpty || !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
      AppToast.showError(context, message: 'Please enter a valid email address');
      return;
    }

    if (phone.isEmpty) {
      AppToast.showError(context, message: 'Please enter your contact number');
      return;
    }

    final controller = ref.read(profileControllerProvider.notifier);
    final success = await controller.updateProfile(
      fullName: name,
      email: email,
      phone: phone,
    );

    if (success && mounted) {
      ref.read(authNotifierProvider.notifier).updateUserInfo(
        fullName: name,
        email: email,
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.8),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(authNotifierProvider.notifier).logout();
                    await ref.read(appStartupProvider.notifier).logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileControllerProvider, (prev, next) {
      _syncControllersWithProfile(next.profile);

      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        AppToast.showError(context, message: next.errorMessage!);
      }
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        AppToast.showSuccess(context, message: next.successMessage!);
      }
    });

    final profileState = ref.watch(profileControllerProvider);
    final profileController = ref.read(profileControllerProvider.notifier);
    final profile = profileState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => profileController.fetchProfile(isRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              AppSpacing.md,
              AppSpacing.marginMobile,
              120.0, // bottom padding for bottom navigation
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Profile Card
                _buildHeaderCard(context, profile, profileState.isRefreshing),
                const SizedBox(height: 18),

                // 2. Personal Information Section
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                  badge: 'API Synchronized',
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _emailController,
                      label: 'Corporate Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Contact Phone',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      title: 'Save Changes',
                      height: 48,
                      isLoading: profileState.isSaving,
                      onPressed: _handleSave,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Note: If you change your email, make sure to use that new email for your next login.',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Work Information Section
                _buildSectionCard(
                  title: 'Work Information',
                  icon: Icons.work_outline_rounded,
                  badge: profile.displayStatus,
                  badgeColor: profile.isActive
                      ? AppColors.success
                      : AppColors.outline,
                  children: [
                    _buildWorkInfoTile(
                      label: 'Employee ID',
                      value: profile.employeeCode,
                      icon: Icons.fingerprint_rounded,
                      actionIcon: Icons.copy_rounded,
                      onAction: () {
                        Clipboard.setData(
                          ClipboardData(text: profile.employeeCode),
                        );
                        AppToast.showInfo(
                          context,
                          message: 'Employee ID copied to clipboard',
                        );
                      },
                    ),
                    const Divider(height: 18),
                    _buildWorkInfoTile(
                      label: 'Designation',
                      value: profile.designation,
                      icon: Icons.badge_outlined,
                    ),
                    const Divider(height: 18),
                    _buildWorkInfoTile(
                      label: 'Department',
                      value: profile.department,
                      icon: Icons.apartment_rounded,
                    ),
                    const Divider(height: 18),
                    _buildWorkInfoTile(
                      label: 'Work Mode',
                      value: profile.displayWorkMode,
                      icon: profile.isWFH
                          ? Icons.home_work_outlined
                          : Icons.business_rounded,
                      customTrailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: profile.isWFH
                              ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                              : const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: profile.isWFH
                                ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                : const Color(
                                    0xFF0D9488,
                                  ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              profile.isWFH
                                  ? Icons.home_rounded
                                  : Icons.business_rounded,
                              size: 13,
                              color: profile.isWFH
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.displayWorkMode,
                              style: AppTypography.labelSmall.copyWith(
                                color: profile.isWFH
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 18),
                    _buildWorkInfoTile(
                      label: 'Date Joined',
                      value: profile.formattedJoiningDate,
                      icon: Icons.calendar_today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. App Settings Section
                _buildSectionCard(
                  title: 'App Settings',
                  icon: Icons.settings_outlined,
                  children: [
                    SwitchListTile.adaptive(
                      value: profileState.biometricAuthEnabled,
                      title: Row(
                        children: [
                          Icon(
                            Platform.isIOS
                                ? Icons.face_rounded
                                : Icons.fingerprint_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Platform.isIOS
                                  ? 'Face ID / Touch ID Unlock'
                                  : 'Biometric Quick Unlock',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          profileState.isHardwareBiometricsSupported
                              ? (profileState.biometricAuthEnabled
                                    ? (Platform.isIOS
                                          ? 'Face ID / Touch ID unlock enabled'
                                          : 'Fingerprint / Face ID unlock enabled')
                                    : (Platform.isIOS
                                          ? 'Unlock app swiftly with Face ID'
                                          : 'Unlock app swiftly with Fingerprint / Face ID'))
                              : 'Biometric hardware is not available on this device',
                          style: AppTypography.bodySmall.copyWith(
                            color: profileState.isHardwareBiometricsSupported
                                ? AppColors.onSurfaceVariant
                                : AppColors.error,
                          ),
                        ),
                      ),
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final success = await profileController
                            .toggleBiometrics(val);
                        if (!success && context.mounted) {
                          AppToast.showError(
                            context,
                            message:
                                profileState.errorMessage ??
                                'Biometrics not supported or authentication failed',
                          );
                        } else if (context.mounted) {
                          AppToast.showSuccess(
                            context,
                            message: val
                                ? 'Biometric quick unlock enabled'
                                : 'Biometric quick unlock disabled',
                          );
                        }
                      },
                    ),
                    const Divider(height: 16),
                    SwitchListTile.adaptive(
                      value: profileState.pushNotificationsEnabled,
                      title: Row(
                        children: [
                          const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Push Notifications',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          profileState.pushNotificationsEnabled
                              ? 'Receive check-in reminders & payroll alerts'
                              : 'Notifications are silenced',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final success = await profileController
                            .togglePushNotifications(val);
                        if (context.mounted) {
                          if (success) {
                            AppToast.showSuccess(
                              context,
                              message: val
                                  ? 'Push notifications turned on'
                                  : 'Push notifications silenced',
                            );
                          } else {
                            AppToast.showError(
                              context,
                              message:
                                  profileState.errorMessage ??
                                  'Failed to update notifications',
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Change Security PIN',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Update your 4-digit security unlock PIN',
                        style: AppTypography.bodySmall,
                      ),
                      contentPadding: EdgeInsets.zero,
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.outline,
                      ),
                      onTap: () {
                        context.push(AppRoutes.changePin);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 5. Logout Button Card
                InkWell(
                  onTap: () => _confirmLogout(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.errorContainer,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ProfileEntity profile,
    bool isRefreshing,
  ) {
    AuthEntity? authUser;
    AttendanceState? attendanceState;
    try {
      authUser = ref.watch(authNotifierProvider).user;
    } catch (_) {}
    try {
      attendanceState = ref.watch(attendanceNotifierProvider);
    } catch (_) {}

    final token = authUser?.token;

    String? selectValidPath(List<String?> candidates) {
      for (final p in candidates) {
        if (p != null) {
          final clean = p.trim();
          if (clean.isNotEmpty &&
              clean != 'null' &&
              !clean.startsWith('assets/') &&
              !clean.contains('avatar-dummy')) {
            return clean;
          }
        }
      }
      return null;
    }

    final rawProfilePath = selectValidPath([
      profile.avatarUrl,
      attendanceState?.attendance.profileImg,
      authUser?.profileImg,
    ]);

    final resolvedUrl = ApiEndpoints.resolveImageUrl(rawProfilePath);
    String resolveEmpCode() {
      if (profile.employeeCode.trim().isNotEmpty && profile.employeeCode != '0') {
        return profile.employeeCode.trim();
      }
      if (profile.empId.trim().isNotEmpty && profile.empId != '0') {
        return profile.empId.trim();
      }
      final uEmpId = authUser?.empId.trim();
      if (uEmpId != null && uEmpId.isNotEmpty && uEmpId != '0') {
        return uEmpId;
      }
      return '';
    }

    int effectiveImageVersion = DateTime.now().millisecondsSinceEpoch;
    try {
      final v = ref.watch(profileControllerProvider).imageVersion;
      if (v > 0) effectiveImageVersion = v;
    } catch (_) {}

    final empCode = resolveEmpCode();

    final avatarUrl = (resolvedUrl != null && resolvedUrl.isNotEmpty)
        ? resolvedUrl
        : (empCode.isNotEmpty ? ApiEndpoints.employeeProfileImage(empCode) : null);

    String? versionedUrl(String? base) {
      if (base == null || base.isEmpty) return null;
      final clean = base.trim();
      final sep = clean.contains('?') ? '&' : '?';
      return '$clean${sep}v=$effectiveImageVersion';
    }

    final finalAvatarUrl = versionedUrl(avatarUrl);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 100, 119, 0.22),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Stack
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: SecureNetworkImage.employeeProfile(
                  url: finalAvatarUrl,
                  token: token,
                  size: 72,
                  cacheKey: finalAvatarUrl,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: profile.isActive
                        ? const Color(0xFF22C55E)
                        : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Header Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.designation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        profile.employeeCode,
                        style: AppTypography.labelTiny.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        profile.department,
                        style: AppTypography.labelTiny.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? badge,
    Color? badgeColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.low,
      ),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.primary).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (badgeColor ?? AppColors.primary).withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: AppTypography.labelTiny.copyWith(
                          color: badgeColor ?? AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkInfoTile({
    required String label,
    required String value,
    required IconData icon,
    IconData? actionIcon,
    VoidCallback? onAction,
    Widget? customTrailing,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        if (customTrailing != null)
          Flexible(child: customTrailing)
        else
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value.isEmpty ? 'N/A' : value,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (actionIcon != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(actionIcon, size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
