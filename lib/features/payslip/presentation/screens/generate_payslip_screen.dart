import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../controllers/payslip_controller.dart';
import '../widgets/payslip_summary_card.dart';
import 'payslip_pdf_viewer_screen.dart';

class GeneratePayslipScreen extends ConsumerWidget {
  const GeneratePayslipScreen({super.key});

  void _showDownloadSuccessSheet(BuildContext context, String filePath, String month, String year) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payslip Downloaded',
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            filePath.split('/').last,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  title: 'Open in App',
                  icon: const Icon(Icons.visibility, color: AppColors.onPrimary, size: 20),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => PayslipPdfViewerScreen(
                          filePath: filePath,
                          title: 'Payslip - $month $year',
                        ),
                        settings: const RouteSettings(name: '/payslip/preview'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final res = await OpenFilex.open(filePath);
                      if (res.type != ResultType.done && context.mounted) {
                        AppToast.showError(
                          context,
                          title: 'Cannot Open',
                          message: res.message,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.showError(
                          context,
                          title: 'Error',
                          message: 'Could not open file: $e',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                  label: Text(
                    'Open with Device App',
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(payslipControllerProvider);
    final controller = ref.read(payslipControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.md,
            AppSpacing.marginMobile,
            120.0, // bottom padding for fixed navigation
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Generate Payslip',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select salary cycle and view comprehensive attendance & earnings statement.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              // Pay Period Selector Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select Pay Period',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Month Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: state.selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        prefixIcon: const Icon(Icons.calendar_month, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      items: state.availableMonths.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) controller.setMonth(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Financial Year Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: state.selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Financial Year',
                        prefixIcon: const Icon(Icons.date_range, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      items: state.availableYears.map((y) {
                        return DropdownMenuItem(value: y, child: Text(y));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) controller.setYear(val);
                      },
                    ),
                    const SizedBox(height: 18),

                    // Generate Button
                    PrimaryButton(
                      title: 'Generate Payslip',
                      icon: const Icon(Icons.receipt_long, color: AppColors.onPrimary, size: 20),
                      isLoading: state.isGenerating,
                      onPressed: () async {
                        final success = await controller.generatePayslip();
                        if (context.mounted) {
                          if (success && state.successMessage != null) {
                            AppToast.showSuccess(
                              context,
                              title: 'Payslip Generated',
                              message: state.successMessage!,
                            );
                          } else if (!success && state.errorMessage != null) {
                            AppToast.showError(
                              context,
                              title: 'Generation Failed',
                              message: state.errorMessage!,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Error Banner (if any)
              if (state.errorMessage != null && !state.isGenerating) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Generated Payslip or Empty State
              if (state.payslip != null)
                PayslipSummaryCard(
                  payslip: state.payslip!,
                  isDownloading: state.isDownloading,
                  onDownload: () async {
                    final filePath = await controller.downloadAndSavePdf();
                    if (context.mounted && filePath != null) {
                      _showDownloadSuccessSheet(
                        context,
                        filePath,
                        state.selectedMonth,
                        state.selectedYear,
                      );
                    } else if (context.mounted && state.errorMessage != null) {
                      AppToast.showError(
                        context,
                        title: 'Download Failed',
                        message: state.errorMessage!,
                      );
                    }
                  },
                  onViewInApp: state.lastDownloadedFilePath != null
                      ? () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => PayslipPdfViewerScreen(
                                filePath: state.lastDownloadedFilePath!,
                                title: 'Payslip - ${state.selectedMonth} ${state.selectedYear}',
                              ),
                            ),
                          );
                        }
                      : null,
                )
              else if (!state.isGenerating)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Payslip Generated Yet',
                    message: 'Select a month and financial year above and tap "Generate Payslip" to view your earnings summary.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
