import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';
import '../../../attendance/presentation/widgets/policy_acceptance_sheet.dart';
import '../../../authentication/presentation/controllers/auth_notifier.dart';
import '../widgets/break_tiffin_controls.dart';
import '../widgets/swipe_punch_button.dart';
import '../widgets/work_snapshot_bento.dart';
import '../widgets/today_activity_timeline.dart';
import '../widgets/dashboard_summary_cards.dart';
import '../widgets/outside_office_card.dart';

/// Enterprise Dashboard Screen displaying live shift attendance,
/// interactive Swipe-to-Punch, responsive break toggles, geofencing & live ticking clock.
///
/// Strictly preserves 100% of existing UI design while wiring complete HRMS business logic.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Future<bool> _showPunchOutConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Confirm Punch Out',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: Text(
              'Are you sure you want to Punch Out for today? All further shift actions will be locked for the day.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: AppColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Punch Out',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch live shift & ticking clock state
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final attendanceNotifier = ref.read(attendanceNotifierProvider.notifier);

    // 2. Watch authenticated employee profile
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final fullName = user?.fullName ?? 'Employee';
    final firstName = fullName.split(' ').first;
    final designation = user?.designation ?? 'Team Member';
    final workMode = attendanceState.workLocationStatus == 'WFH'
        ? 'Work From Home'
        : 'Office';

    // 3. Listen for toast messages & pending policy sheet prompts
    ref.listen<AttendanceState>(attendanceNotifierProvider, (previous, next) {
      if (next.needsPolicyRead && next.pendingPolicies.isNotEmpty) {
        PolicyAcceptanceSheet.show(
          context,
          pendingPolicies: next.pendingPolicies,
          onAccept: () {
            attendanceNotifier.markPoliciesAsRead();
            AppToast.showSuccess(
              context,
              title: 'Policies Acknowledged',
              message: 'You can now proceed to Punch Out.',
            );
          },
        );
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppToast.showError(
          context,
          title: 'Attendance Notice',
          message: next.errorMessage!,
        );
      } else if (next.actionSuccessMessage != null &&
          next.actionSuccessMessage != previous?.actionSuccessMessage) {
        AppToast.showSuccess(
          context,
          title: 'Status Updated',
          message: next.actionSuccessMessage!,
        );
      }
    });

    final isPunchedIn = attendanceState.isPunchedIn;

    // Location status determination
    final isLocationRefreshing = attendanceState.locationStatus == 'checking' ||
        attendanceState.locationStatus == 'calculating';
    final isInsideOffice = attendanceState.locationStatus == 'inside' ||
        attendanceState.workLocationStatus == 'WFH';
    final locationStatusText = () {
      if (attendanceState.isWFH) return 'Home Office';
      if (isLocationRefreshing) return 'Checking...';
      if (attendanceState.locationStatus == 'inside') return 'Inside Office';
      if (attendanceState.locationStatus == 'outside') return 'Outside Office';
      if (attendanceState.locationStatus == 'error') return 'GPS Error';
      return 'Detect Location';
    }();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([
              attendanceNotifier.syncPendingOfflineData(),
              attendanceNotifier.fetchTodayAttendance(),
              attendanceNotifier.refreshDailyActivity(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              AppSpacing.md,
              AppSpacing.marginMobile,
              120.0, // Clearance for persistent bottom navigation shell
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Welcome Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: '${_getGreeting()},\n',
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                                height: 1.2,
                                letterSpacing: -0.4,
                              ),
                              children: [
                                TextSpan(
                                  text: firstName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandBlue,
                                    height: 1.2,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            designation,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCurrentStatusChip(attendanceState.currentStatus),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. 2x2 Work Snapshot Bento Grid
                WorkSnapshotBento(
                  dateText: attendanceState.shortDate(DateTime.now()),
                  workMode: workMode,
                  attendanceStatus: isPunchedIn
                      ? (attendanceState.attendance.isLate
                          ? AttendanceStatusType.late
                          : AttendanceStatusType.onTime)
                      : AttendanceStatusType.notCheckedIn,
                  attendanceStatusText: isPunchedIn
                      ? (attendanceState.attendance.isLate ? 'Late' : 'On Time')
                      : (attendanceState.isWeekend()
                          ? 'Weekly Off'
                          : (attendanceState.isHoliday
                              ? (attendanceState.attendance.holidayName ?? 'Holiday')
                              : (attendanceState.isOnLeave
                                  ? (attendanceState.attendance.leaveType ?? 'On Leave')
                                  : attendanceState.currentStatus.label))),
                  locationStatusText: locationStatusText,
                  isInsideOffice: isInsideOffice,
                  isLocationRefreshing: isLocationRefreshing,
                  onRefreshLocation: () => attendanceNotifier.refreshLocation(),
                ),
                const SizedBox(height: 16),

                // 3. Main 'Swipe to Punch In/Out' Card with Live Ticking Digital Clock
                SwipePunchCard(
                  onSwipeComplete: () async {
                    if (attendanceState.isPunchedIn) {
                      final confirmed =
                          await _showPunchOutConfirmationDialog(context);
                      if (confirmed) {
                        await attendanceNotifier.punchOut();
                      }
                    } else if (attendanceState.isNotPunchedIn) {
                      await attendanceNotifier.punchIn();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 4. Quick Action Controls for 'Tiffin Break' and 'Short Break'
                BreakLunchControls(
                  isPunchedIn: isPunchedIn,
                  isPunchedOut: attendanceState.isPunchedOut,
                  isBreakOngoing: attendanceState.isOnBreak,
                  isBreakLoading: attendanceState.isBreakLoading,
                  isLunchLoading: attendanceState.isLunchLoading,
                  lunchStatus: attendanceState.lunchStatus,
                  onToggleBreak: () => attendanceNotifier.toggleBreak(),
                  onToggleTiffin: () => attendanceNotifier.toggleTiffin(),
                ),
                const SizedBox(height: 16),

                // 5. Today's Activity Timeline
                const TodayActivityTimeline(),
                const SizedBox(height: 16),

                // 6. Break & Tiffin Summary Cards
                const DashboardSummaryCards(),

                // 7. Outside Office Tracking Card (WFO Employees Only)
                if (attendanceState.isWFO) const OutsideOfficeCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusChip(AttendanceStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case AttendanceStatus.working:
        bg = AppColors.successContainer.withValues(alpha: 0.2);
        fg = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case AttendanceStatus.onBreak:
        bg = AppColors.warningContainer.withValues(alpha: 0.25);
        fg = const Color(0xFFD97706);
        icon = Icons.coffee_rounded;
        break;
      case AttendanceStatus.onTiffin:
        bg = AppColors.primaryContainer.withValues(alpha: 0.2);
        fg = AppColors.primary;
        icon = Icons.restaurant_rounded;
        break;
      case AttendanceStatus.punchedOut:
        bg = AppColors.errorContainer.withValues(alpha: 0.2);
        fg = AppColors.error;
        icon = Icons.logout_rounded;
        break;
      case AttendanceStatus.officeOff:
        bg = const Color(0xFF64748B).withValues(alpha: 0.15);
        fg = const Color(0xFF475569);
        icon = Icons.weekend_rounded;
        break;
      case AttendanceStatus.holiday:
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        icon = Icons.beach_access_rounded;
        break;
      case AttendanceStatus.onLeave:
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
        fg = const Color(0xFF7C3AED);
        icon = Icons.event_busy_rounded;
        break;
      case AttendanceStatus.notPunchedIn:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        icon = Icons.access_time_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
