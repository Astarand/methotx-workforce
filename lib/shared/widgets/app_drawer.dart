import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/attendance/presentation/controllers/attendance_notifier.dart';
import '../../features/authentication/presentation/controllers/auth_notifier.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import 'secure_network_image.dart';

String? resolveProfileImageUrl(String? path) {
  return ApiEndpoints.resolveImageUrl(path);
}

class AppDrawer extends ConsumerWidget {
  final String currentRoute;
  final Function(String route) onNavigate;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.onLogout,
  });

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
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

    if (confirm == true) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      onLogout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Access dynamic employee profile from authenticated & attendance states
    final authState = ref.watch(authNotifierProvider);
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final user = authState.user;

    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : '';
    final designation = user?.designation.trim().isNotEmpty == true
        ? user!.designation.trim()
        : '';
    final empCode = user?.empId.trim().isNotEmpty == true
        ? user!.empId.trim()
        : '';

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

    final profileState = ref.watch(profileControllerProvider);

    final rawProfilePath = selectValidPath([
      profileState.profile.avatarUrl,
      attendanceState.attendance.profileImg,
      user?.profileImg,
    ]);
    final resolvedPath = resolveProfileImageUrl(rawProfilePath);

    String resolveDrawerEmpCode() {
      final code1 = profileState.profile.employeeCode.trim();
      if (code1.isNotEmpty && code1 != '0') return code1;
      final code2 = profileState.profile.empId.trim();
      if (code2.isNotEmpty && code2 != '0') return code2;
      final code3 = user?.empId.trim() ?? '';
      if (code3.isNotEmpty && code3 != '0') return code3;
      return '';
    }

    final effectiveEmpCode = resolveDrawerEmpCode();
    final fullImageUrl = (resolvedPath != null && resolvedPath.isNotEmpty)
        ? resolvedPath
        : (effectiveEmpCode.isNotEmpty
              ? ApiEndpoints.employeeProfileImage(effectiveEmpCode)
              : null);

    int drawerImageVersion = DateTime.now().millisecondsSinceEpoch;
    try {
      final v = profileState.imageVersion;
      if (v > 0) drawerImageVersion = v;
    } catch (_) {}

    String? versionedDrawerUrl(String? base) {
      if (base == null || base.isEmpty) return null;
      final clean = base.trim();
      final sep = clean.contains('?') ? '&' : '?';
      return '$clean${sep}v=$drawerImageVersion';
    }

    final finalDrawerImageUrl = versionedDrawerUrl(fullImageUrl);

    return Drawer(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header Profile Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryContainer],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.onPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: SecureNetworkImage.employeeProfile(
                            url: finalDrawerImageUrl,
                            token: user?.token,
                            size: 60,
                            cacheKey: finalDrawerImageUrl,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryFixed,
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            designation,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onPrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (empCode.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.secondaryContainer
                                      .withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                empCode,
                                style: AppTypography.labelTiny.copyWith(
                                  color: AppColors.secondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildGroupHeader('MAIN'),
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  title: AppStrings.navDashboard,
                  route: '/dashboard',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  title: AppStrings.navAttendanceHistory,
                  route: '/attendance-history',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment,
                  title: AppStrings.navTaskManagement,
                  route: '/tasks',
                  context: context,
                ),

                const SizedBox(height: 12),
                Divider(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  height: 1,
                ),
                const SizedBox(height: 12),

                _buildGroupHeader('WORK & PAYROLL'),
                _buildDrawerItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  title: AppStrings.navGeneratePayslip,
                  route: '/payslip',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.event_busy_outlined,
                  activeIcon: Icons.event_busy,
                  title: AppStrings.navLeaveManagement,
                  route: '/leave',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  title: AppStrings.navHRLetter,
                  route: '/hr-letter',
                  context: context,
                ),

                const SizedBox(height: 12),
                Divider(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  height: 1,
                ),
                const SizedBox(height: 12),

                _buildGroupHeader('MORE'),
                _buildDrawerItem(
                  icon: Icons.trending_up_outlined,
                  activeIcon: Icons.trending_up,
                  title: AppStrings.navPerformanceReview,
                  route: '/performance',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.request_quote_outlined,
                  activeIcon: Icons.request_quote,
                  title: AppStrings.navExpenditureClaims,
                  route: '/claims',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  title: AppStrings.navSupplyRequisitions,
                  route: '/requisitions',
                  context: context,
                ),
              ],
            ),
          ),

          // Logout Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(
                top: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleLogout(context, ref),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.navLogout,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.labelTiny.copyWith(
          color: AppColors.outline,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String route,
    required BuildContext context,
  }) {
    final bool isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            onNavigate(route);
          },
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: isActive
                        ? AppTypography.labelLarge.copyWith(
                            color: AppColors.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          )
                        : AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
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
}
