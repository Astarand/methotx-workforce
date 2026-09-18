import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_toast.dart';

class ApplyLeaveSheet extends StatefulWidget {
  final Future<bool> Function({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) onApply;

  const ApplyLeaveSheet({
    super.key,
    required this.onApply,
  });

  static void show(
    BuildContext context, {
    required Future<bool> Function({
      required LeaveType type,
      required DateTime startDate,
      required DateTime endDate,
      required String reason,
    }) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ApplyLeaveSheet(onApply: onApply),
    );
  }

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  LeaveType _selectedType = LeaveType.casual;
  bool _isSingleDay = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_isSingleDay || _endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    // Validation 1: Date selections
    final effectiveEndDate = _isSingleDay ? _startDate : _endDate;

    if (_endDate.isBefore(_startDate) && !_isSingleDay) {
      AppToast.showWarning(
        context,
        title: 'Validation Error',
        message: 'To date cannot be before from date',
      );
      return;
    }

    // Validation 2: Reason
    if (_reasonController.text.trim().isEmpty) {
      AppToast.showWarning(
        context,
        title: 'Validation Error',
        message: 'Please enter reason for leave',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final success = await widget.onApply(
        type: _selectedType,
        startDate: _startDate,
        endDate: effectiveEndDate,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.of(context).pop();
          AppToast.showSuccess(
            context,
            title: 'Leave Submitted',
            message: 'Leave request submitted successfully',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        AppToast.showError(
          context,
          title: 'Application Error',
          message: errorMsg,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final startMidnight = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endMidnight = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final totalDays = endMidnight.difference(startMidnight).inDays + 1;

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
            const SizedBox(height: 16),

            Text(
              'Apply for Leave',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Leave Type Dropdown
            DropdownButtonFormField<LeaveType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Leave Type',
                prefixIcon: const Icon(Icons.category_outlined, color: AppColors.outline),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(value: LeaveType.casual, child: Text('Casual Leave')),
                DropdownMenuItem(value: LeaveType.sick, child: Text('Sick Leave')),
                DropdownMenuItem(value: LeaveType.paid, child: Text('Paid Leave')),
                DropdownMenuItem(value: LeaveType.unpaid, child: Text('Unpaid Leave')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 14),

            // Single Day / Multiple Days Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isSingleDay = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isSingleDay ? AppColors.surfaceContainerLowest : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isSingleDay ? AppShadows.low : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Multiple Days',
                          style: AppTypography.labelMedium.copyWith(
                            color: !_isSingleDay ? AppColors.primary : AppColors.onSurfaceVariant,
                            fontWeight: !_isSingleDay ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isSingleDay = true;
                          _endDate = _startDate;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isSingleDay ? AppColors.surfaceContainerLowest : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isSingleDay ? AppShadows.low : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Single Day',
                          style: AppTypography.labelMedium.copyWith(
                            color: _isSingleDay ? AppColors.primary : AppColors.onSurfaceVariant,
                            fontWeight: _isSingleDay ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Date Selection
            if (_isSingleDay)
              InkWell(
                onTap: _selectStartDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: AppTypography.labelTiny.copyWith(color: AppColors.outline),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(_startDate),
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From Date',
                              style: AppTypography.labelTiny.copyWith(color: AppColors.outline),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(_startDate),
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Date',
                              style: AppTypography.labelTiny.copyWith(color: AppColors.outline),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(_endDate),
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: $totalDays ${totalDays == 1 ? "day" : "days"}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Reason Text Field
            AppTextField(
              controller: _reasonController,
              label: 'Reason for Leave',
              hint: 'Describe your reason...',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Submit Button
            PrimaryButton(
              title: 'Submit Leave Request',
              isLoading: _isSubmitting,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    ),
  );
  }
}

