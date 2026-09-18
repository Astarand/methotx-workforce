import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/attachment_viewer_helper.dart';
import '../../domain/entities/supply_entity.dart';
import '../controllers/supply_controller.dart';

class SupplyDetailsScreen extends ConsumerStatefulWidget {
  final SupplyEntity requisition;

  const SupplyDetailsScreen({
    super.key,
    required this.requisition,
  });

  @override
  ConsumerState<SupplyDetailsScreen> createState() => _SupplyDetailsScreenState();
}

class _SupplyDetailsScreenState extends ConsumerState<SupplyDetailsScreen> {
  late SupplyEntity _requisition;

  @override
  void initState() {
    super.initState();
    _requisition = widget.requisition;
    _fetchFreshDetails();
  }

  Future<void> _fetchFreshDetails() async {
    if (_requisition.id.isEmpty) return;
    final fresh = await ref
        .read(supplyControllerProvider.notifier)
        .getSupplyDetails(_requisition.id);
    if (mounted && fresh != null) {
      setState(() {
        _requisition = fresh;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Requisition Details',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Badge Banner
              _buildStatusBanner(),

              const SizedBox(height: AppSpacing.md),

              // Summary Card (Amount & Category)
              _buildSummaryCard(),

              const SizedBox(height: AppSpacing.md),

              // Specifications Card (Date, Quantity, Priority, Return/Exchange)
              _buildSpecsCard(),

              const SizedBox(height: AppSpacing.md),

              // Details & Requirement Card
              _buildDetailsCard(),

              // Comments / Notes Card
              if (_requisition.comments != null &&
                  _requisition.comments!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildCommentsCard(),
              ],

              // Attachment Preview Card (if present)
              if (_requisition.hasAttachment) ...[
                const SizedBox(height: AppSpacing.md),
                _buildAttachmentCard(),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _requisition.status.bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _requisition.status.textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _requisition.status.icon,
            size: 22,
            color: _requisition.status.textColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requisition Status: ${_requisition.status.label}',
                  style: AppTypography.labelMedium.copyWith(
                    color: _requisition.status.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _requisition.status == SupplyStatus.approved
                      ? 'This requisition has been verified and approved by management.'
                      : _requisition.status == SupplyStatus.rejected
                          ? 'This requisition was reviewed and rejected by management.'
                          : 'This requisition is Pending and awaiting approval.',
                  style: AppTypography.labelTiny.copyWith(
                    color: _requisition.status.textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Amount',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_requisition.id.isNotEmpty)
                Text(
                  '#${_requisition.id}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _requisition.formattedAmount,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 14),

          // Category Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _requisition.categoryIcon,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: AppTypography.labelTiny.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _requisition.categoryTitle,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requisition Specifications',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Date & Quantity Row
          Row(
            children: [
              Expanded(
                child: _buildSpecificationItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Requisition Date',
                  value: _requisition.formattedDate,
                ),
              ),
              Expanded(
                child: _buildSpecificationItem(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Quantity',
                  value: _requisition.quantity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority & Return/Exchange Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority',
                      style: AppTypography.labelTiny.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _requisition.priority.bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _requisition.priority.icon,
                            size: 14,
                            color: _requisition.priority.textColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _requisition.priority.label,
                            style: AppTypography.labelTiny.copyWith(
                              color: _requisition.priority.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_requisition.returnExchange != null &&
                  _requisition.returnExchange!.trim().isNotEmpty) ...[
                Expanded(
                  child: _buildSpecificationItem(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Return / Exchange',
                    value: _requisition.returnExchange!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelTiny.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Requirement Details',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _requisition.details.isNotEmpty
                ? _requisition.details
                : 'No additional details provided.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Comments / Remarks',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _requisition.comments!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard() {
    final url = _requisition.resolvedAttachmentUrl;
    final isPdf = _requisition.isPdfAttachment;
    final fileName = (_requisition.attachment ?? _requisition.attachmentUrl)
            ?.split('/')
            .last
            .split('?')
            .first ??
        (isPdf ? 'Document.pdf' : 'Attachment.jpg');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Attachment Document',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPdf
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPdf ? 'PDF' : 'IMAGE',
                style: AppTypography.labelTiny.copyWith(
                  color: isPdf ? AppColors.error : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (url != null) ...[
          if (!isPdf)
            GestureDetector(
              onTap: () {
                AttachmentViewerHelper.showImageViewer(
                  context,
                  url: url,
                  title: 'Attachment Preview',
                  fileName: fileName,
                );
              },
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                      placeholder: (context, url) => Container(
                        height: 220,
                        color: AppColors.surfaceContainerLow,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 140,
                        color: AppColors.surfaceContainerLow,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image_rounded,
                                size: 36,
                                color: AppColors.outline,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to view attachment',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to preview',
                            style: AppTypography.labelTiny.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () => AttachmentViewerHelper.openAttachment(
                context,
                url: url,
                fileName: fileName,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to view document',
                            style: AppTypography.labelTiny.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.outline),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (!isPdf) {
                  AttachmentViewerHelper.showImageViewer(
                    context,
                    url: url,
                    title: 'Attachment Preview',
                    fileName: fileName,
                  );
                } else {
                  AttachmentViewerHelper.openAttachment(
                    context,
                    url: url,
                    fileName: fileName,
                  );
                }
              },
                icon: Icon(
                  !isPdf ? Icons.fullscreen_rounded : Icons.open_in_new_rounded,
                  size: 18,
                ),
                label: Text(!isPdf ? 'View Full Attachment' : 'Open Attachment Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
