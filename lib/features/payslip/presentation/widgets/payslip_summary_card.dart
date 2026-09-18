import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../domain/entities/payslip_entity.dart';

class PayslipSummaryCard extends StatelessWidget {
  final PayslipEntity payslip;
  final VoidCallback onDownload;

  final bool isDownloading;
  final VoidCallback? onViewInApp;

  const PayslipSummaryCard({
    super.key,
    required this.payslip,
    required this.onDownload,
    this.isDownloading = false,
    this.onViewInApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge & Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${payslip.month} ${payslip.financialYear.split('-').first}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                payslip.payslipNumber,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Employee Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: AppColors.onPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslip.employeeName,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${payslip.designation} • ${payslip.employeeCode}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (payslip.bankName != null || payslip.accountNo != null || payslip.panNo != null || payslip.ifscCode != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (payslip.bankName != null && payslip.bankName!.isNotEmpty)
                    _buildMetaChip(Icons.account_balance, payslip.bankName!),
                  if (payslip.accountNo != null && payslip.accountNo!.isNotEmpty)
                    _buildMetaChip(Icons.credit_card, 'A/C: ${payslip.accountNo!}'),
                  if (payslip.ifscCode != null && payslip.ifscCode!.isNotEmpty)
                    _buildMetaChip(Icons.numbers, 'IFSC: ${payslip.ifscCode!}'),
                  if (payslip.panNo != null && payslip.panNo!.isNotEmpty)
                    _buildMetaChip(Icons.badge_outlined, 'PAN: ${payslip.panNo!}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Net Salary Highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NET TAKE-HOME SALARY',
                  style: AppTypography.labelTiny.copyWith(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.formatCurrency(payslip.netSalary),
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Salary Breakdown Highlights
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Gross Salary',
                  AppFormatters.formatCurrency(payslip.grossSalary),
                  AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBlock(
                  'Total Additions',
                  AppFormatters.formatCurrency(payslip.totalAdditions),
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBlock(
                  'Deductions',
                  AppFormatters.formatCurrency(payslip.totalDeductions),
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Attendance Overview
          Text(
            'Attendance Overview',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceChip('Working Days', '${payslip.workingDays}'),
                    _buildAttendanceChip('Holidays', '${payslip.holidays}'),
                    _buildAttendanceChip('Weekends', '${payslip.weekends}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceChip('Present', '${payslip.presentDays}'),
                    _buildAttendanceChip('On Time', '${payslip.onTimeDays}'),
                    _buildAttendanceChip('Late', '${payslip.lateDays}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceChip('Early Logout', '${payslip.earlyLogoutDays}'),
                    _buildAttendanceChip('Leaves', '${payslip.leaves}'),
                    _buildAttendanceChip('Overtime', '${payslip.overtimeHours}h'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Earnings & Deductions
          Text(
            'Earnings & Allowances',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...payslip.earnings.map(
            (e) => _buildItemRow(e.title, AppFormatters.formatCurrency(e.amount), isCredit: true),
          ),

          const SizedBox(height: 14),
          Text(
            'Deductions',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...payslip.deductions.map(
            (d) => _buildItemRow(d.title, '- ${AppFormatters.formatCurrency(d.amount)}', isCredit: false),
          ),

          const SizedBox(height: 24),

          // Download Action
          PrimaryButton(
            title: isDownloading ? 'Generating PDF...' : 'Download Payslip (PDF)',
            icon: const Icon(Icons.download, color: AppColors.onPrimary, size: 20),
            isLoading: isDownloading,
            onPressed: isDownloading ? () {} : onDownload,
          ),
          if (onViewInApp != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onViewInApp,
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
              label: Text(
                'View Downloaded PDF in App',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBlock(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelTiny.copyWith(
              color: AppColors.outline,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChip(String label, String val) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Text(
              val,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelTiny.copyWith(
                color: AppColors.outline,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(String title, String amount, {required bool isCredit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            amount,
            style: AppTypography.labelMedium.copyWith(
              color: isCredit ? AppColors.onSurface : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.labelTiny.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
