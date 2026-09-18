import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/attendance_record_model.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/leave_entity.dart';
import '../controllers/leave_controller.dart';

class LeaveDetailsSheet extends ConsumerStatefulWidget {
  final LeaveApplicationEntity initialLeave;

  const LeaveDetailsSheet({
    super.key,
    required this.initialLeave,
  });

  static Future<void> show(
    BuildContext context, {
    required LeaveApplicationEntity leave,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LeaveDetailsSheet(initialLeave: leave),
    );
  }

  static Future<void> showFromDayRecord(
    BuildContext context, {
    required AttendanceDayRecord record,
  }) {
    final leaveEntity = LeaveApplicationEntity(
      id: 'leave-${record.date.millisecondsSinceEpoch}',
      type: LeaveType.fromString(record.leaveType),
      startDate: record.date,
      endDate: record.date,
      numberOfDays: 1,
      reason: (record.notes != null && record.notes!.isNotEmpty)
          ? record.notes!
          : 'Approved Leave by Management',
      status: LeaveStatus.approved,
      appliedOn: record.date,
    );
    return show(context, leave: leaveEntity);
  }

  @override
  ConsumerState<LeaveDetailsSheet> createState() => _LeaveDetailsSheetState();
}

class _LeaveDetailsSheetState extends ConsumerState<LeaveDetailsSheet> {
  late LeaveApplicationEntity _leave;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _leave = widget.initialLeave;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.initialLeave.id.isNotEmpty &&
          !widget.initialLeave.id.startsWith('leave-')) {
        _fetchDetails();
      }
    });
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final details = await ref
          .read(leaveControllerProvider.notifier)
          .fetchLeaveDetails(widget.initialLeave.id);

      if (mounted) {
        setState(() {
          if (details != null) {
            _leave = details;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final startStr = DateFormat('dd MMM yyyy').format(_leave.startDate);
    final endStr = DateFormat('dd MMM yyyy').format(_leave.endDate);
    final appliedStr = DateFormat('dd MMM yyyy, hh:mm a').format(_leave.appliedOn);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + bottomInset + (bottomInset == 0 ? bottomPadding : 0),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Leave Request Details',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(_leave.status),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFFFEF7E0),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFE37400)),
                    ),
                  ),
                ),

              // Main Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Employee Name (if available)
                      if (_leave.employeeName != null &&
                          _leave.employeeName!.isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Employee',
                          value: _leave.employeeName!,
                        ),
                        const Divider(height: 20),
                      ],

                      // Leave Type
                      _buildInfoRow(
                        icon: Icons.category_outlined,
                        label: 'Leave Type',
                        value: _leave.type.displayName,
                      ),
                      const Divider(height: 20),

                      // Date Range & Total Days
                      _buildInfoRow(
                        icon: Icons.date_range_outlined,
                        label: 'Duration',
                        value: '$startStr - $endStr',
                        subtitle: '${_leave.numberOfDays} ${_leave.numberOfDays == 1 ? "day" : "days"}',
                      ),
                      const Divider(height: 20),

                      // Applied On
                      _buildInfoRow(
                        icon: Icons.access_time_outlined,
                        label: 'Applied On',
                        value: appliedStr,
                      ),

                      // Approver (if approved or approver present)
                      if (_leave.status == LeaveStatus.approved ||
                          (_leave.approvedBy != null &&
                              _leave.approvedBy!.isNotEmpty)) ...[
                        const Divider(height: 20),
                        _buildInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Approver',
                          value: _leave.formattedApprover,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reason for Leave',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _leave.reason.isNotEmpty
                            ? _leave.reason
                            : 'No specific reason provided.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: AppColors.outlineVariant),
                    ),
                    child: Text(
                      'Close',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelTiny.copyWith(
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return const StatusBadge(
          label: 'Approved',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
        );
      case LeaveStatus.pending:
        return const StatusBadge(
          label: 'Pending',
          backgroundColor: Color(0xFFFEF7E0),
          textColor: Color(0xFFE37400),
        );
      case LeaveStatus.rejected:
        return const StatusBadge(
          label: 'Rejected',
          backgroundColor: Color(0xFFFCE8E6),
          textColor: Color(0xFFC5221F),
        );
      case LeaveStatus.cancelled:
        return const StatusBadge(
          label: 'Cancelled',
          backgroundColor: Color(0xFFF1F3F4),
          textColor: Color(0xFF5F6368),
        );
    }
  }
}
