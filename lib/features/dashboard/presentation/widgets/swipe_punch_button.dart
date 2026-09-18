import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../attendance/presentation/controllers/attendance_notifier.dart';

class SwipePunchCard extends ConsumerWidget {
  final Future<void> Function() onSwipeComplete;

  const SwipePunchCard({
    super.key,
    required this.onSwipeComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final isPunchedIn = attendanceState.isPunchedIn;
    final isPunchedOut = attendanceState.isPunchedOut;
    final isLoading = attendanceState.isPunchingIn ||
        attendanceState.isPunchingOut ||
        attendanceState.isLoading;

    final isNonWorkingDay = attendanceState.isNonWorkingDay(now);
    final isWeekend = attendanceState.isWeekend(now);
    final isHoliday = attendanceState.isHoliday;
    final isOnLeave = attendanceState.isOnLeave;
    final isOfficeOff = attendanceState.isOfficeOff;

    final isWindowOpen = !isNonWorkingDay &&
        (isPunchedIn ||
            isPunchedOut ||
            attendanceState.isPunchInWindowOpen(now));
    final earliestPunchTime = isNonWorkingDay
        ? null
        : attendanceState.earliestPunchInTime(now);
    final shiftStart = isNonWorkingDay
        ? null
        : attendanceState.shiftStartTime(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPunchedOut
              ? const Color(0xFF10B981).withValues(alpha: 0.25)
              : (isPunchedIn
                  ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                  : (isNonWorkingDay
                      ? (isHoliday
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                          : const Color(0xFF64748B).withValues(alpha: 0.25))
                      : AppColors.outlineVariant.withValues(alpha: 0.35))),
          width: 1,
        ),
        boxShadow: AppShadows.low,
      ),
      child: Column(
        children: [
          // Isolated Live Clock Display (only this sub-widget ticks every second)
          const LiveDigitalClockDisplay(),
          const SizedBox(height: 18),

          // Integrated Swipe To Punch Bar with animated thumb icon
          SwipeSliderBar(
            todayWorkingStatus: attendanceState.isPunchedOut
                ? 'punch_out'
                : (attendanceState.isPunchedIn
                    ? 'present'
                    : attendanceState.todayWorkingStatus),
            isLoading: isLoading,
            isWindowOpen: isWindowOpen,
            isNonWorkingDay: isNonWorkingDay,
            isWeekend: isWeekend,
            isHoliday: isHoliday,
            isOnLeave: isOnLeave,
            isOfficeOff: isOfficeOff,
            holidayName: attendanceState.attendance.holidayName,
            leaveType: attendanceState.attendance.leaveType,
            earliestPunchInTime: earliestPunchTime,
            shiftStartTime: shiftStart,
            onSwipeComplete: onSwipeComplete,
            onDisabledTap: () {
              if (isNonWorkingDay) {
                if (isWeekend) {
                  AppToast.showInfo(
                    context,
                    title: 'Office Closed',
                    message:
                        'Today is a scheduled weekly off (Weekend). Attendance is not required today.',
                  );
                } else if (isHoliday) {
                  final hName = attendanceState.attendance.holidayName;
                  AppToast.showInfo(
                    context,
                    title: 'Public Holiday',
                    message:
                        'Today is an official office holiday${hName != null && hName.isNotEmpty ? ' ($hName)' : ''}. Enjoy your day off!',
                  );
                } else if (isOnLeave) {
                  final lType = attendanceState.attendance.leaveType;
                  AppToast.showInfo(
                    context,
                    title: 'On Leave',
                    message:
                        'You are on approved leave today${lType != null && lType.isNotEmpty ? ' ($lType)' : ''}.',
                  );
                } else {
                  AppToast.showInfo(
                    context,
                    title: 'Office Closed',
                    message:
                        'The office is closed today. Attendance is not required.',
                  );
                }
              } else if (!isWindowOpen && earliestPunchTime != null) {
                final earliestFormatted =
                    DateFormat('h:mm a').format(earliestPunchTime);
                final shiftFormatted = shiftStart != null
                    ? DateFormat('h:mm a').format(shiftStart)
                    : '';
                AppToast.showInfo(
                  context,
                  title: 'Punch In Notice',
                  message:
                      'Punch In will be enabled at $earliestFormatted (2 hours before shift start${shiftFormatted.isNotEmpty ? ' at $shiftFormatted' : ''}).',
                );
              }
            },
          ),

          // Informative chip if employee opened app on weekend, holiday, or before 2-hour window
          if (!isPunchedIn && !isPunchedOut) ...[
            if (isNonWorkingDay) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isWeekend
                      ? const Color(0xFF64748B).withValues(alpha: 0.1)
                      : (isHoliday
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: isWeekend
                        ? const Color(0xFF64748B).withValues(alpha: 0.22)
                        : (isHoliday
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.22)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.22)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isWeekend
                          ? Icons.beach_access_rounded
                          : (isHoliday
                              ? Icons.celebration_rounded
                              : Icons.event_busy_rounded),
                      size: 14,
                      color: isWeekend
                          ? const Color(0xFF475569)
                          : (isHoliday
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isWeekend
                            ? 'Weekly Off • No attendance required today'
                            : (isHoliday
                                ? 'Holiday • ${attendanceState.attendance.holidayName ?? 'Office Closed'}'
                                : (isOnLeave
                                    ? 'Leave • ${attendanceState.attendance.leaveType ?? 'Approved Leave'}'
                                    : 'Office Closed Today')),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? const Color(0xFF334155)
                              : (isHoliday
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF6D28D9)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!isWindowOpen && earliestPunchTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Punch In enables at ${DateFormat('h:mm a').format(earliestPunchTime)} (2h early)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class SwipeSliderBar extends StatefulWidget {
  final String todayWorkingStatus; // 'not_present', 'present', 'punch_out'
  final bool isLoading;
  final bool isWindowOpen;
  final bool isNonWorkingDay;
  final bool isWeekend;
  final bool isHoliday;
  final bool isOnLeave;
  final bool isOfficeOff;
  final String? holidayName;
  final String? leaveType;
  final DateTime? earliestPunchInTime;
  final DateTime? shiftStartTime;
  final VoidCallback? onDisabledTap;
  final Future<void> Function() onSwipeComplete;

  const SwipeSliderBar({
    super.key,
    required this.todayWorkingStatus,
    required this.isLoading,
    this.isWindowOpen = true,
    this.isNonWorkingDay = false,
    this.isWeekend = false,
    this.isHoliday = false,
    this.isOnLeave = false,
    this.isOfficeOff = false,
    this.holidayName,
    this.leaveType,
    this.earliestPunchInTime,
    this.shiftStartTime,
    this.onDisabledTap,
    required this.onSwipeComplete,
  });

  @override
  State<SwipeSliderBar> createState() => _SwipeSliderBarState();
}

class _SwipeSliderBarState extends State<SwipeSliderBar>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (!widget.isWindowOpen ||
        widget.isLoading ||
        widget.isNonWorkingDay ||
        widget.todayWorkingStatus == 'punch_out') {
      return;
    }
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) async {
    if (!widget.isWindowOpen ||
        widget.isLoading ||
        widget.isNonWorkingDay ||
        widget.todayWorkingStatus == 'punch_out') {
      return;
    }
    if (_dragPosition >= maxDrag * 0.72) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dragPosition = maxDrag;
      });
      await widget.onSwipeComplete();
      _resetSlider();
    } else {
      _resetSlider();
    }
  }

  void _resetSlider() {
    _resetAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.todayWorkingStatus;
    final isPunchedIn =
        status == 'present' || status == 'lunch' || status == 'break';
    final isPunchedOut = status == 'punch_out';
    final isWindowOpen =
        (widget.isWindowOpen || isPunchedIn || isPunchedOut) &&
            !widget.isNonWorkingDay;

    String trackText;
    if (widget.isLoading) {
      trackText = 'Processing...';
    } else if (isPunchedOut) {
      trackText = 'Work Complete';
    } else if (isPunchedIn) {
      trackText = 'Swipe to Punch Out';
    } else if (widget.isNonWorkingDay) {
      if (widget.isWeekend) {
        trackText = 'Office Closed (Weekend)';
      } else if (widget.isHoliday) {
        trackText = widget.holidayName != null && widget.holidayName!.isNotEmpty
            ? 'Holiday • ${widget.holidayName}'
            : 'Office Holiday';
      } else if (widget.isOnLeave) {
        trackText = widget.leaveType != null && widget.leaveType!.isNotEmpty
            ? 'On Leave (${widget.leaveType})'
            : 'On Approved Leave';
      } else {
        trackText = 'Office Closed';
      }
    } else if (!isWindowOpen && widget.earliestPunchInTime != null) {
      final timeFormatted =
          DateFormat('h:mm a').format(widget.earliestPunchInTime!);
      trackText = 'Punch In opens at $timeFormatted';
    } else {
      trackText = 'Swipe to Punch In';
    }

    final Gradient sliderGradient;
    final Color shadowColor;

    if (isPunchedOut) {
      sliderGradient = const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      );
      shadowColor = const Color(0xFF10B981).withValues(alpha: 0.28);
    } else if (isPunchedIn) {
      sliderGradient = const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
      );
      shadowColor = const Color(0xFFDC2626).withValues(alpha: 0.28);
    } else if (widget.isNonWorkingDay) {
      if (widget.isWeekend) {
        sliderGradient = const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF334155)],
        );
        shadowColor = const Color(0xFF475569).withValues(alpha: 0.25);
      } else if (widget.isHoliday) {
        sliderGradient = const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        );
        shadowColor = const Color(0xFF2563EB).withValues(alpha: 0.25);
      } else if (widget.isOnLeave) {
        sliderGradient = const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        );
        shadowColor = const Color(0xFF7C3AED).withValues(alpha: 0.25);
      } else {
        sliderGradient = const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF334155)],
        );
        shadowColor = const Color(0xFF475569).withValues(alpha: 0.25);
      }
    } else if (!isWindowOpen) {
      sliderGradient = const LinearGradient(
        colors: [Color(0xFF64748B), Color(0xFF475569)],
      );
      shadowColor = const Color(0xFF64748B).withValues(alpha: 0.20);
    } else {
      sliderGradient = const LinearGradient(
        colors: [Color(0xFF0A86C6), Color(0xFF269FE6)],
      );
      shadowColor = const Color(0xFF0A86C6).withValues(alpha: 0.28);
    }

    final IconData knobIcon;
    final Color knobIconColor;

    if (isPunchedOut) {
      knobIcon = Icons.check_circle_rounded;
      knobIconColor = const Color(0xFF10B981);
    } else if (isPunchedIn) {
      knobIcon = Icons.power_settings_new_rounded;
      knobIconColor = const Color(0xFFDC2626);
    } else if (widget.isNonWorkingDay) {
      if (widget.isWeekend) {
        knobIcon = Icons.weekend_rounded;
        knobIconColor = const Color(0xFF475569);
      } else if (widget.isHoliday) {
        knobIcon = Icons.celebration_rounded;
        knobIconColor = const Color(0xFF2563EB);
      } else if (widget.isOnLeave) {
        knobIcon = Icons.event_busy_rounded;
        knobIconColor = const Color(0xFF7C3AED);
      } else {
        knobIcon = Icons.business_rounded;
        knobIconColor = const Color(0xFF475569);
      }
    } else if (!isWindowOpen) {
      knobIcon = Icons.lock_clock_rounded;
      knobIconColor = const Color(0xFF64748B);
    } else {
      knobIcon = Icons.fingerprint_rounded;
      knobIconColor = const Color(0xFF0A86C6);
    }

    const double knobSize = 46.0;
    const double trackHeight = 54.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - knobSize - 8;

        return GestureDetector(
          onTap: () {
            if ((!isWindowOpen || widget.isNonWorkingDay) && !widget.isLoading) {
              widget.onDisabledTap?.call();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: trackHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: sliderGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track Label Text
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isPunchedOut &&
                          !widget.isLoading &&
                          isWindowOpen &&
                          !widget.isNonWorkingDay)
                        const SizedBox(width: 34),
                      if (widget.isNonWorkingDay && !widget.isLoading) ...[
                        Icon(
                          widget.isWeekend
                              ? Icons.weekend_rounded
                              : (widget.isHoliday
                                  ? Icons.beach_access_rounded
                                  : (widget.isOnLeave
                                      ? Icons.event_busy_rounded
                                      : Icons.business_rounded)),
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                      ] else if (!isWindowOpen && !widget.isLoading) ...[
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          trackText,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (!isPunchedOut &&
                          !widget.isLoading &&
                          isWindowOpen &&
                          !widget.isNonWorkingDay) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ),

                // Sliding Knob with integrated animated Fingerprint / Power / Check / Lock / Spinner icon
                Positioned(
                  left: 4.0 + (isPunchedOut ? 0.0 : _dragPosition),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) =>
                        _onHorizontalDragUpdate(details, maxDrag),
                    onHorizontalDragEnd: (details) =>
                        _onHorizontalDragEnd(details, maxDrag),
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isPunchedIn
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF0A86C6),
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  knobIcon,
                                  key: ValueKey<String>(
                                      '${status}_${isWindowOpen}_${widget.isNonWorkingDay}_${widget.isWeekend}'),
                                  size: 24,
                                  color: knobIconColor,
                                ),
                              ),
                      ),
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
}

/// Isolated digital clock component that listens to [clockProvider] without
/// causing 1 Hz rebuilds of the SwipeSliderBar, gesture detectors, and parent layout.
class LiveDigitalClockDisplay extends ConsumerWidget {
  const LiveDigitalClockDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(clockProvider).value ?? DateTime.now();
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final timeString = attendanceState.formattedTime(currentTime);
    final amPmString = attendanceState.amPm(currentTime);

    return Column(
      children: [
        Text(
          'Current Time',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              timeString,
              style: GoogleFonts.outfit(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.0,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amPmString,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
