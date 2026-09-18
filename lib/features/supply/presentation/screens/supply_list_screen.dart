import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../domain/entities/supply_entity.dart';
import '../controllers/supply_controller.dart';
import 'apply_supply_screen.dart';
import 'supply_details_screen.dart';

class SupplyListScreen extends ConsumerWidget {
  const SupplyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplyControllerProvider);
    final controller = ref.read(supplyControllerProvider.notifier);
    final displayedSupplies = state.filteredSupplies;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadSupply,
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
                                  'Supply Requisitions',
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Request office equipment and track approval status',
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
                                  builder: (_) => const ApplySupplyScreen(),
                                  settings: const RouteSettings(name: '/apply-requisition'),
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
              if (state.isLoading && state.supplies.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (state.errorMessage != null && state.supplies.isEmpty)
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
                            'Failed to Load Requisitions',
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
                            onPressed: controller.loadSupply,
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
              else if (state.supplies.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    title: 'No requisitions yet',
                    message: 'Tap Apply to submit a new requisition.',
                    icon: Icons.inventory_2_outlined,
                  ),
                )
              else if (displayedSupplies.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    title: 'No matching requisitions',
                    message:
                        'No requisitions match the selected "${state.selectedStatusFilter?.label}" filter.',
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
                        final supply = displayedSupplies[index];
                        return _buildSupplyCard(
                          context: context,
                          supply: supply,
                          onTap: () async {
                            await Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => SupplyDetailsScreen(requisition: supply),
                                settings: const RouteSettings(
                                  name: '/requisition-details',
                                ),
                              ),
                            );
                            if (context.mounted) {
                              controller.loadSupply();
                            }
                          },
                        );
                      },
                      childCount: displayedSupplies.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(SupplyState state, SupplyController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: 'All (${state.totalSupplies})',
            isSelected: state.selectedStatusFilter == null,
            onTap: () => controller.setFilter(null),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pending (${state.pendingCount})',
            isSelected: state.selectedStatusFilter == SupplyStatus.pending,
            activeColor: AppColors.warning,
            onTap: () => controller.setFilter(SupplyStatus.pending),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Approved (${state.approvedCount})',
            isSelected: state.selectedStatusFilter == SupplyStatus.approved,
            activeColor: AppColors.success,
            onTap: () => controller.setFilter(SupplyStatus.approved),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Rejected (${state.rejectedCount})',
            isSelected: state.selectedStatusFilter == SupplyStatus.rejected,
            activeColor: AppColors.error,
            onTap: () => controller.setFilter(SupplyStatus.rejected),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : AppColors.outlineVariant.withValues(alpha: 0.7),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSupplyCard({
    required BuildContext context,
    required SupplyEntity supply,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.7),
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
                // Top Row: Category Icon, Title, and Status Badge
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
                        supply.categoryIcon,
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
                            supply.categoryTitle,
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                supply.formattedDate,
                                style: AppTypography.labelTiny.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Priority Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: supply.priority.bgColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  supply.priority.label,
                                  style: AppTypography.labelTiny.copyWith(
                                    color: supply.priority.textColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                        color: supply.status.bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: supply.status.textColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        supply.status.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: supply.status.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Details preview
                if (supply.details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    supply.details,
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

                // Bottom Row: Amount, Quantity, and Attachment Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          supply.formattedAmount,
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
                            'Qty: ${supply.quantity}',
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
                        if (supply.hasAttachment) ...[
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
