import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class BreakLunchControls extends StatelessWidget {
  final bool isPunchedIn;
  final bool isPunchedOut;
  final bool isBreakOngoing;
  final bool isBreakLoading;
  final bool isLunchLoading;
  final String lunchStatus; // 'none', 'ongoing', 'complete'
  final VoidCallback onToggleBreak;
  final VoidCallback onToggleTiffin;

  const BreakLunchControls({
    super.key,
    required this.isPunchedIn,
    this.isPunchedOut = false,
    required this.isBreakOngoing,
    this.isBreakLoading = false,
    this.isLunchLoading = false,
    required this.lunchStatus,
    required this.onToggleBreak,
    required this.onToggleTiffin,
  });

  @override
  Widget build(BuildContext context) {
    final isLunchOngoing = lunchStatus == 'ongoing';
    final isLunchCompleted = lunchStatus == 'complete' || lunchStatus == 'ended';

    // Break title and subtitle
    String breakTitle = 'Break';
    String breakSubtitle;
    if (isBreakLoading) {
      breakSubtitle = 'LOADING...';
    } else if (isBreakOngoing) {
      breakTitle = 'Break End';
      breakSubtitle = 'ACTIVE';
    } else if (!isPunchedIn || isPunchedOut) {
      breakSubtitle = 'UNAVAILABLE';
    } else {
      breakSubtitle = 'TAP TO START';
    }

    // Tiffin title and subtitle
    String tiffinTitle;
    String tiffinSubtitle;
    IconData tiffinIcon = Icons.restaurant_rounded;

    if (isLunchLoading) {
      tiffinTitle = 'Tiffin Time';
      tiffinSubtitle = 'LOADING...';
    } else if (isLunchCompleted) {
      tiffinTitle = "Today's Lunch Complete";
      tiffinSubtitle = 'COMPLETED';
      tiffinIcon = Icons.check_circle_outline_rounded;
    } else if (isLunchOngoing) {
      tiffinTitle = 'Tiffin End';
      tiffinSubtitle = 'ACTIVE';
    } else {
      tiffinTitle = 'Tiffin Time';
      tiffinSubtitle = isPunchedIn && !isPunchedOut ? 'TAP TO START' : 'UNAVAILABLE';
    }

    return Row(
      children: [
        // ☕ Break Card (Fixed Size)
        Expanded(
          child: _FixedSessionCard(
            title: breakTitle,
            subtitle: breakSubtitle,
            icon: Icons.coffee_rounded,
            isActive: isBreakOngoing,
            isLoading: isBreakLoading,
            isDisabled: !isPunchedIn || isLunchOngoing || isPunchedOut || isBreakLoading,
            activeColor: const Color(0xFFEA580C),
            activeBgColor: const Color(0xFFFFF7ED),
            activeBorderColor: const Color(0xFFFDBA74),
            onTap: !isPunchedIn || isLunchOngoing || isPunchedOut || isBreakLoading
                ? () {}
                : onToggleBreak,
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // 🍴 Tiffin Time Card (Fixed Size)
        Expanded(
          child: _FixedSessionCard(
            title: tiffinTitle,
            subtitle: tiffinSubtitle,
            icon: tiffinIcon,
            isActive: isLunchOngoing,
            isCompleted: isLunchCompleted,
            isLoading: isLunchLoading,
            isDisabled: !isPunchedIn || isBreakOngoing || isLunchCompleted || isPunchedOut || isLunchLoading,
            activeColor: const Color(0xFFEA580C),
            activeBgColor: const Color(0xFFFFF7ED),
            activeBorderColor: const Color(0xFFFDBA74),
            onTap: !isPunchedIn || isBreakOngoing || isLunchCompleted || isPunchedOut || isLunchLoading
                ? () {}
                : onToggleTiffin,
          ),
        ),
      ],
    );
  }
}

class _FixedSessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isCompleted;
  final bool isLoading;
  final bool isDisabled;
  final Color activeColor;
  final Color activeBgColor;
  final Color activeBorderColor;
  final VoidCallback onTap;

  const _FixedSessionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    this.isCompleted = false,
    this.isLoading = false,
    required this.isDisabled,
    required this.activeColor,
    required this.activeBgColor,
    required this.activeBorderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double cardOpacity = isDisabled && !isActive ? 0.45 : 1.0;

    return Opacity(
      opacity: cardOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 74, // Fixed height at all times
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.surfaceContainerLowest
                  : (isActive ? activeBgColor : AppColors.surfaceContainerLowest),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted
                    ? AppColors.outlineVariant.withValues(alpha: 0.25)
                    : (isActive
                        ? activeBorderColor
                        : AppColors.outlineVariant.withValues(alpha: 0.35)),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ]
                  : AppShadows.low,
            ),
            child: Row(
              children: [
                // Clean static icon / spinner container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.surfaceContainerHigh
                        : (isActive
                            ? activeColor.withValues(alpha: 0.18)
                            : AppColors.brandBlueUltralight),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isActive ? activeColor : AppColors.brandBlue,
                            ),
                          )
                        : Icon(
                            icon,
                            color: isCompleted
                                ? AppColors.outline
                                : (isActive ? activeColor : AppColors.brandBlue),
                            size: 21,
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Text & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppColors.outline
                              : (isActive ? activeColor : AppColors.onSurface),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isCompleted
                              ? AppColors.outline
                              : (isActive
                                  ? activeColor
                                  : AppColors.onSurfaceVariant),
                          letterSpacing: 0.2,
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
        ),
      ),
    );
  }
}
