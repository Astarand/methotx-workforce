import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../domain/entities/claim_entity.dart';
import '../controllers/claim_controller.dart';
import 'apply_claim_screen.dart';
import 'claim_details_screen.dart';

class ClaimsListScreen extends ConsumerWidget {
  const ClaimsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(claimControllerProvider);
    final controller = ref.read(claimControllerProvider.notifier);
    final displayedClaims = state.filteredClaims;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadClaims,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMobile,
                    AppSpacing.md,
                    AppSpacing.marginMobile,
                    12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expenditure Claims',
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Submit bills and track reimbursement status',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          PrimaryButton(
                            title: 'Apply',
                            height: 40,
                            width: 104,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            icon: const Icon(Icons.add, size: 16, color: AppColors.onPrimary),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => const ApplyClaimScreen(),
                                  settings: const RouteSettings(name: '/apply-claim'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Status Filter Chips
                      _buildFilterChips(state, controller),
                    ],
                  ),
                ),
              ),

              // State Handling: Loading, Error, Empty or List
              if (state.isLoading && state.claims.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (state.errorMessage != null && state.claims.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to Load Claims',
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: controller.loadClaims,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (state.claims.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    title: 'No claims yet',
                    message: 'Tap Apply to submit a new reimbursement claim.',
                    icon: Icons.receipt_long_outlined,
                  ),
                )
              else if (displayedClaims.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    title: 'No matching claims',
                    message:
                        'No claims match the selected "${state.selectedStatusFilter?.label}" filter.',
                    icon: Icons.filter_alt_off_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMobile,
                    0,
                    AppSpacing.marginMobile,
                    96.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final claim = displayedClaims[index];
                        return _buildClaimCard(
                          context: context,
                          claim: claim,
                          onTap: () async {
                            await Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => ClaimDetailsScreen(claim: claim),
                                settings: const RouteSettings(
                                  name: '/claim-details',
                                ),
                              ),
                            );
                            if (context.mounted) {
                              controller.loadClaims();
                            }
                          },
                        );
                      },
                      childCount: displayedClaims.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ClaimState state, ClaimController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: 'All (${state.totalClaims})',
            isSelected: state.selectedStatusFilter == null,
            onTap: () => controller.setFilter(null),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pending (${state.pendingCount})',
            isSelected: state.selectedStatusFilter == ClaimStatus.pending,
            activeColor: AppColors.warning,
            onTap: () => controller.setFilter(ClaimStatus.pending),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Approved (${state.approvedCount})',
            isSelected: state.selectedStatusFilter == ClaimStatus.approved,
            activeColor: AppColors.onSuccessContainer,
            onTap: () => controller.setFilter(ClaimStatus.approved),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Rejected (${state.rejectedCount})',
            isSelected: state.selectedStatusFilter == ClaimStatus.rejected,
            activeColor: AppColors.error,
            onTap: () => controller.setFilter(ClaimStatus.rejected),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? color : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard({
    required BuildContext context,
    required ClaimEntity claim,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon, Name, and Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        claim.categoryIcon,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.categoryTitle,
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            claim.formattedDate,
                            style: AppTypography.labelTiny.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: claim.status.bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: claim.status.textColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        claim.status.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: claim.status.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Details preview
                if (claim.details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    claim.details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.6),
                const SizedBox(height: 10),

                // Bottom Row: Amount, Payment Method, and Attachment Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          claim.formattedAmount,
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            claim.paymentMethodTitle,
                            style: AppTypography.labelTiny.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (claim.hasReceipt) ...[
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'View',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
