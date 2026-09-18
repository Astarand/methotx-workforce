import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../domain/entities/supply_entity.dart';
import '../controllers/supply_controller.dart';

class ApplySupplyScreen extends ConsumerStatefulWidget {
  const ApplySupplyScreen({super.key});

  @override
  ConsumerState<ApplySupplyScreen> createState() => _ApplySupplyScreenState();
}

class _ApplySupplyScreenState extends ConsumerState<ApplySupplyScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'office_supplies';
  DateTime _selectedDate = DateTime.now();
  SupplyPriority _selectedPriority = SupplyPriority.normal;

  final _quantityController = TextEditingController(text: '1');
  final _amountController = TextEditingController();
  final _returnExchangeController = TextEditingController();
  final _detailsController = TextEditingController();
  final _commentsController = TextEditingController();

  File? _selectedAttachment;
  String? _attachmentFileName;
  int? _attachmentFileSize;

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    _returnExchangeController.dispose();
    _detailsController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
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
                subtitle: const Text('Select attachment from your Photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _executePickAttachment(FileType.image);
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
                  _executePickAttachment(FileType.custom, ['jpg', 'jpeg', 'png', 'pdf']);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executePickAttachment(FileType type, [List<String>? allowedExtensions]) async {
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
          _selectedAttachment = file;
          _attachmentFileName = picked.name;
          _attachmentFileSize = size;
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

  void _removeAttachment() {
    setState(() {
      _selectedAttachment = null;
      _attachmentFileName = null;
      _attachmentFileSize = null;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
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
      AppToast.showError(
        context,
        message: 'Please enter a valid amount greater than 0',
      );
      return;
    }

    final quantity = _quantityController.text.trim();
    if (quantity.isEmpty) {
      AppToast.showError(
        context,
        message: 'Please specify the quantity',
      );
      return;
    }

    final details = _detailsController.text.trim();
    final returnExchange = _returnExchangeController.text.trim();
    final comments = _commentsController.text.trim();

    final success = await ref
        .read(supplyControllerProvider.notifier)
        .submitSupplyRequisition(
          date: _selectedDate,
          category: _selectedCategory,
          details: details,
          quantity: quantity,
          amount: amount,
          priority: _selectedPriority,
          returnExchange: returnExchange.isNotEmpty ? returnExchange : null,
          comments: comments.isNotEmpty ? comments : null,
          attachment: _selectedAttachment,
        );

    if (mounted) {
      if (success) {
        AppToast.showSuccess(
          context,
          message: 'Supply requisition submitted successfully!',
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      } else {
        final err = ref.read(supplyControllerProvider).errorMessage ??
            'Failed to submit requisition';
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
    final state = ref.watch(supplyControllerProvider);

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
          'Apply for Requisition',
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            children: [
              // Category Field
              _buildSectionLabel('Supply Category *'),
              const SizedBox(height: 8),
              _buildCategoryDropdown(),

              const SizedBox(height: 18),

              // Date & Quantity Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Requisition Date *'),
                        const SizedBox(height: 8),
                        _buildDatePicker(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Quantity *'),
                        const SizedBox(height: 8),
                        _buildQuantityField(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Amount & Priority Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Estimated Amount (INR) *'),
                        const SizedBox(height: 8),
                        _buildAmountField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Priority *'),
                        const SizedBox(height: 8),
                        _buildPrioritySelector(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Return / Exchange Field (Optional)
              _buildSectionLabel('Return / Exchange (Optional)'),
              const SizedBox(height: 8),
              _buildReturnExchangeField(),

              const SizedBox(height: 18),

              // Requirement Details
              _buildSectionLabel('Requirement Details *'),
              const SizedBox(height: 8),
              _buildDetailsField(),

              const SizedBox(height: 18),

              // Attachment Document (Optional)
              _buildSectionLabel('Quotation / Attachment (JPG, PNG, PDF)'),
              const SizedBox(height: 8),
              _buildAttachmentSelector(),

              const SizedBox(height: 18),

              // Additional Comments
              _buildSectionLabel('Additional Comments (Optional)'),
              const SizedBox(height: 8),
              _buildCommentsField(),

              const SizedBox(height: 28),

              // Submit Button
              PrimaryButton(
                title: 'Submit Requisition Request',
                isLoading: state.isSubmitting,
                onPressed: _submitForm,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.outline),
          items: SupplyCategoryInfo.all.map((c) {
            return DropdownMenuItem<String>(
              value: c.key,
              child: Row(
                children: [
                  Icon(c.icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCategory = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final formatted = DateFormat('dd MMM yyyy').format(_selectedDate);
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                formatted,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'e.g. 5',
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(
          Icons.format_list_numbered_rounded,
          size: 20,
          color: AppColors.outline,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Quantity required';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: '0.00',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Center(
            widthFactor: 0.0,
            child: Text(
              '₹',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Amount is required';
        }
        return null;
      },
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SupplyPriority>(
          value: _selectedPriority,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.outline),
          items: SupplyPriority.values.map((p) {
            return DropdownMenuItem<SupplyPriority>(
              value: p,
              child: Row(
                children: [
                  Icon(p.icon, size: 18, color: p.textColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPriority = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildReturnExchangeField() {
    return TextFormField(
      controller: _returnExchangeController,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'e.g. Return defective mouse / Exchange size L',
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.swap_horiz_rounded, color: AppColors.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDetailsField() {
    return TextFormField(
      controller: _detailsController,
      maxLines: 3,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'State items needed, brand/model specifications, and business purpose...',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Please explain the requisition purpose and items';
        }
        return null;
      },
    );
  }

  Widget _buildAttachmentSelector() {
    if (_selectedAttachment != null) {
      final isPdf = _attachmentFileName?.toLowerCase().endsWith('.pdf') ?? false;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPdf
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? AppColors.error : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _attachmentFileName ?? 'Attachment File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (_attachmentFileSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(_attachmentFileSize!),
                      style: AppTypography.labelTiny.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Remove Attachment',
              onPressed: _removeAttachment,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickAttachment,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Tap to attach quotation or specification',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsField() {
    return TextFormField(
      controller: _commentsController,
      maxLines: 2,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Any delivery instructions or extra notes...',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}
