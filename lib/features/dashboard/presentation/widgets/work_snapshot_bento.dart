import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum AttendanceStatusType {
  notCheckedIn,
  onTime,
  late,
}

class WorkSnapshotBento extends StatelessWidget {
  final String dateText;
  final String workMode;
  final AttendanceStatusType attendanceStatus;
  final String attendanceStatusText;
  final String locationStatusText;
  final bool isInsideOffice;
  final bool isLocationRefreshing;
  final VoidCallback? onRefreshLocation;

  const WorkSnapshotBento({
    super.key,
    required this.dateText,
    required this.workMode,
    required this.attendanceStatus,
    required this.attendanceStatusText,
    required this.locationStatusText,
    this.isInsideOffice = true,
    this.isLocationRefreshing = false,
    this.onRefreshLocation,
  });

  Color _getAttendanceIndicatorColor() {
    switch (attendanceStatus) {
      case AttendanceStatusType.onTime:
        return const Color(0xFF10B981); // Subtle green
      case AttendanceStatusType.late:
        return const Color(0xFFF59E0B); // Subtle amber/orange
      case AttendanceStatusType.notCheckedIn:
        return const Color(0xFF94A3B8); // Neutral grey
    }
  }

  IconData _getAttendanceIcon() {
    switch (attendanceStatus) {
      case AttendanceStatusType.onTime:
        return Icons.check_circle_outline_rounded;
      case AttendanceStatusType.late:
        return Icons.access_time_rounded;
      case AttendanceStatusType.notCheckedIn:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  Color _getLocationIndicatorColor() {
    if (isLocationRefreshing) {
      return AppColors.brandBlue;
    }
    if (locationStatusText.toLowerCase().contains('inside')) {
      return const Color(0xFF10B981); // Green
    }
    if (locationStatusText.toLowerCase().contains('outside')) {
      return const Color(0xFFEF4444); // Red/Amber
    }
    if (locationStatusText.toLowerCase().contains('home')) {
      return const Color(0xFF10B981); // Green for WFH
    }
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: AppShadows.low,
      ),
      child: Column(
        children: [
          // Row 1: Date & Work Mode
          Row(
            children: [
              Expanded(
                child: _buildBentoCell(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: dateText,
                ),
              ),
              Container(
                width: 1,
                height: 72,
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _buildBentoCell(
                  icon: Icons.work_outline_rounded,
                  label: 'Work Mode',
                  value: workMode,
                ),
              ),
            ],
          ),
          Divider(
            color: AppColors.outlineVariant.withValues(alpha: 0.25),
            height: 1,
          ),
          // Row 2: Attendance Status & Real-time Location
          Row(
            children: [
              Expanded(
                child: _buildBentoCell(
                  icon: _getAttendanceIcon(),
                  label: 'Attendance',
                  value: attendanceStatusText,
                  badgeColor: _getAttendanceIndicatorColor(),
                ),
              ),
              Container(
                width: 1,
                height: 72,
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _buildBentoCell(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: locationStatusText,
                  badgeColor: _getLocationIndicatorColor(),
                  trailingAction: GestureDetector(
                    onTap: isLocationRefreshing ? null : onRefreshLocation,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: isLocationRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppColors.brandBlue,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppColors.brandBlue,
                            ),
                    ),
                  ),
                  onTap: isLocationRefreshing ? null : onRefreshLocation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCell({
    required IconData icon,
    required String label,
    required String value,
    Color? badgeColor,
    Widget? trailingAction,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: badgeColor ?? AppColors.brandBlue,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailingAction,
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeColor != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
