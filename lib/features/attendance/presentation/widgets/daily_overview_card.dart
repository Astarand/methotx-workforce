import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/attendance_record_model.dart';
import '../../../leave/presentation/widgets/leave_details_sheet.dart';
import '../../data/models/attendance_model.dart';

class AttendanceBadgeInfo {
  final String label;
  final Color color;
  final Color bgColor;
  final String? subtext;

  const AttendanceBadgeInfo({
    required this.label,
    required this.color,
    required this.bgColor,
    this.subtext,
  });
}

AttendanceBadgeInfo getAttendanceBadge(AttendanceDayRecord record) {
  final date = record.date;

  // 1. Holiday check
  if (record.holidayName != null && record.holidayName!.isNotEmpty) {
    return AttendanceBadgeInfo(
      label: 'HOLIDAY',
      color: const Color(0xFF0284C7),
      bgColor: const Color(0xFFF0F9FF),
      subtext: record.holidayName,
    );
  }
  if (record.status == AttendanceStatus.holiday) {
    return const AttendanceBadgeInfo(
      label: 'HOLIDAY',
      color: Color(0xFF0284C7),
      bgColor: Color(0xFFF0F9FF),
    );
  }

  // 2. Approved Leave check
  if (record.leaveType != null && record.leaveType!.isNotEmpty) {
    return AttendanceBadgeInfo(
      label: 'LEAVE',
      color: const Color(0xFFE37400),
      bgColor: const Color(0xFFFEF7E0),
      subtext: record.leaveType,
    );
  }
  if (record.status == AttendanceStatus.leave) {
    return const AttendanceBadgeInfo(
      label: 'LEAVE',
      color: Color(0xFFE37400),
      bgColor: Color(0xFFFEF7E0),
    );
  }

  // 3. Check-In recorded (Working / Present)
  if (record.checkInTime != null &&
      record.checkInTime!.isNotEmpty &&
      record.checkInTime != 'Not recorded') {
    if (record.isLate) {
      final formattedLate = AppFormatters.formatLateDuration(record.lateBy);
      final lateText = formattedLate.isNotEmpty
          ? 'Late by $formattedLate'
          : 'Late Check-In';
      return AttendanceBadgeInfo(
        label: 'LATE',
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        subtext: lateText,
      );
    } else {
      return const AttendanceBadgeInfo(
        label: 'ON TIME',
        color: Color(0xFF10B981),
        bgColor: Color(0xFFECFDF5),
      );
    }
  }

  // 4. Office Off check (Dynamic from API)
  if (record.status == AttendanceStatus.officeOff) {
    return const AttendanceBadgeInfo(
      label: 'OFFICE OFF',
      color: Color(0xFF202124),
      bgColor: Color(0xFFE8EAED),
    );
  }

  // 5. Future date / not recorded
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final dateStart = DateTime(date.year, date.month, date.day);

  if (dateStart.isAfter(todayStart) || record.status == AttendanceStatus.notRecorded) {
    if (dateStart.isAfter(todayStart)) {
      return const AttendanceBadgeInfo(
        label: 'UPCOMING',
        color: Color(0xFF64748B),
        bgColor: Color(0xFFF8FAFC),
      );
    }
    return const AttendanceBadgeInfo(
      label: 'NOT RECORDED',
      color: Color(0xFF64748B),
      bgColor: Color(0xFFF8FAFC),
    );
  }

  // 6. Past Date Absent check
  if (dateStart.isBefore(todayStart) || record.status == AttendanceStatus.absent) {
    return const AttendanceBadgeInfo(
      label: 'ABSENT',
      color: Color(0xFFEF4444),
      bgColor: Color(0xFFFEF2F2),
    );
  }

  return const AttendanceBadgeInfo(
    label: 'NOT RECORDED',
    color: Color(0xFF64748B),
    bgColor: Color(0xFFF8FAFC),
  );
}

class DailyOverviewCard extends StatelessWidget {
  final AttendanceDayRecord overview;
  final bool isLoading;

  const DailyOverviewCard({
    super.key,
    required this.overview,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF0284C7),
          ),
        ),
      );
    }

    final formattedDate = DateFormat('EEEE, dd MMM yyyy').format(overview.date);
    final badge = getAttendanceBadge(overview);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Section Title + Date + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Overview',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badge.bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badge.color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: badge.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badge.label,
                      style: GoogleFonts.inter(
                        color: badge.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (overview.status == AttendanceStatus.leave)
            _buildLeaveOverview(context, overview)
          else ...[
            // 2. Check In & Check Out Unified Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                // Check In Tile
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.login_rounded,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check In',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              AppFormatters.formatTime12Hour(overview.checkInTime),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (overview.isLate &&
                                overview.lateBy != null &&
                                overview.lateBy!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Late by ${AppFormatters.formatLateDuration(overview.lateBy)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD97706),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Connector Divider
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),

                // Check Out Tile
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check Out',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              AppFormatters.formatTime12Hour(overview.checkOutTime),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. 2x2 Bento Metric Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildBentoMetricTile(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  label: 'Working Hours',
                  value: formatDurationToDisplay(overview.workingDuration),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoMetricTile(
                  icon: Icons.coffee_outlined,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  label: 'Total Break',
                  value: formatDurationToDisplay(overview.breakDuration),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildBentoMetricTile(
                  icon: Icons.restaurant_outlined,
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  borderColor: const Color(0xFFC7D2FE),
                  label: 'Total Tiffin',
                  value: formatDurationToDisplay(overview.lunchDuration),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoMetricTile(
                  icon: Icons.directions_walk_outlined,
                  iconColor: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFF1F2),
                  borderColor: const Color(0xFFFECDD3),
                  label: 'Outside Office',
                  value: formatDurationToDisplay(overview.outsideOfficeDuration),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

  Widget _buildLeaveOverview(BuildContext context, AttendanceDayRecord overview) {
    final leaveType = (overview.leaveType != null && overview.leaveType!.isNotEmpty)
        ? overview.leaveType!
        : 'Approved Leave';
    final reason = (overview.notes != null && overview.notes!.isNotEmpty)
        ? overview.notes!
        : 'Approved by Management';

    return Material(
      color: const Color(0xFFFEF7E0),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => LeaveDetailsSheet.showFromDayRecord(context, record: overview),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFDE68A),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE37400).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 22,
                      color: Color(0xFFE37400),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved Leave',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Leave request has been approved by management',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE37400).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE37400),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFFE37400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: Color(0xFFFDE68A),
              thickness: 1,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LEAVE',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE37400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Type',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leaveType,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Reason',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildBentoMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
