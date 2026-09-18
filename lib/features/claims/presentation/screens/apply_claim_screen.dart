import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../domain/entities/claim_entity.dart';
import '../controllers/claim_controller.dart';

class ApplyClaimScreen extends ConsumerStatefulWidget {
  const ApplyClaimScreen({super.key});

  @override
  ConsumerState<ApplyClaimScreen> createState() => _ApplyClaimScreenState();
}

class _ApplyClaimScreenState extends ConsumerState<ApplyClaimScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'travel';
  String _selectedPaymentMethod = 'card';
  DateTime _selectedDate = DateTime.now();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  final _commentsController = TextEditingController();

  File? _selectedReceipt;
  String? _receiptFileName;
  int? _receiptFileSize;

  @override
  void dispose() {
    _amountController.dispose();
    _detailsController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.brandBlue),
                ),
                title: const Text('Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select receipt from your Photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _executePickReceipt(FileType.image);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_outlined, color: AppColors.brandBlue),
                ),
                title: const Text('Browse Files (PDF / Docs)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select a PDF or document file'),
                onTap: () {
                  Navigator.pop(ctx);
                  _executePickReceipt(FileType.custom, ['jpg', 'jpeg', 'png', 'pdf']);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executePickReceipt(FileType type, [List<String>? allowedExtensions]) async {
    try {
      final picked = await FilePicker.pickFile(
        type: type,
        allowedExtensions: allowedExtensions,
      );

      if (picked != null && picked.path != null) {
        final path = picked.path!;
        final file = File(path);
        final size = await file.length();
        setState(() {
          _selectedReceipt = file;
          _receiptFileName = picked.name;
          _receiptFileSize = size;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          message: 'Unable to select file: $e',
        );
      }
    }
  }

  void _removeReceipt() {
    setState(() {
      _selectedReceipt = null;
      _receiptFileName = null;
      _receiptFileSize = null;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawAmount = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      AppToast.showWarning(
        context,
        message: 'Please enter a valid claim amount',
      );
      return;
    }

    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      AppToast.showWarning(
        context,
        message: 'Please describe the expense purpose',
      );
      return;
    }

    final comments = _commentsController.text.trim();

    final success = await ref.read(claimControllerProvider.notifier).submitClaim(
      date: _selectedDate,
      category: _selectedCategory,
      claimAmount: amount,
      details: details,
      paymentMethod: _selectedPaymentMethod,
      comments: comments.isNotEmpty ? comments : null,
      receipt: _selectedReceipt,
    );

    if (mounted) {
      if (success) {
        AppToast.showSuccess(
          context,
          message: 'Expenditure claim submitted successfully!',
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      } else {
        final err = ref.read(claimControllerProvider).errorMessage ?? 'Failed to submit claim';
        AppToast.showError(
          context,
          message: err,
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Apply for Claim',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Selector
                _buildCategoryDropdown(),

                const SizedBox(height: AppSpacing.md),

                // Payment Method Selector
                _buildPaymentMethodDropdown(),

                const SizedBox(height: AppSpacing.md),

                // Claim Date Picker Tile
                _buildDatePickerTile(),

                const SizedBox(height: AppSpacing.md),

                // Amount Field
                _buildAmountField(),

                const SizedBox(height: AppSpacing.md),

                // Purpose & Details Field
                _buildDetailsField(),

                const SizedBox(height: AppSpacing.md),

                // Optional Comments
                _buildCommentsField(),

                const SizedBox(height: AppSpacing.md),

                // Receipt Attachment
                _buildReceiptAttachmentSection(),

                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                ElevatedButton(
                  onPressed: state.isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Claim Request',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expense Category *',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              items: ClaimCategoryMetadata.allCategories.map((c) {
                return DropdownMenuItem<String>(
                  value: c.key,
                  child: Row(
                    children: [
                      Icon(c.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        c.title,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method *',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPaymentMethod,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              items: PaymentMethodMetadata.allMethods.map((m) {
                return DropdownMenuItem<String>(
                  value: m.key,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Text(
                        m.title,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentMethod = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim Date *',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim Amount (INR) *',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Center(
                widthFactor: 0.0,
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
            hintText: '0.00',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Amount is required';
            }
            final n = double.tryParse(val.trim());
            if (n == null || n <= 0) {
              return 'Please enter an amount greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDetailsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purpose / Explanation *',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _detailsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Flight travel to client site, hotel stay for audit...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please explain the expenditure purpose';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCommentsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Comments (Optional)',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _commentsController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Any extra remarks for management approval...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptAttachmentSection() {
    final hasFile = _selectedReceipt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt Document (JPG, PNG, PDF)',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        if (!hasFile)
          InkWell(
            onTap: _pickReceipt,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.8),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Tap to attach receipt or bill',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _receiptFileName?.toLowerCase().endsWith('.pdf') == true
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _receiptFileName ?? 'Selected File',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (_receiptFileSize != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(_receiptFileSize!),
                          style: AppTypography.labelTiny.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
                  onPressed: _removeReceipt,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
