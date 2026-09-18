import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../data/models/attendance_model.dart';

class AttendanceState {
  final AttendanceEntity attendance;
  final bool isLoading;
  final bool isPunchingIn;
  final bool isPunchingOut;
  final bool isLunchLoading;
  final bool isBreakLoading;
  final String? errorMessage;
  final String? actionSuccessMessage;

  // State Machine Variables
  final String todayWorkingStatus; // 'not_present', 'present', 'punch_out'
  final String lunchStatus;        // 'none', 'ongoing', 'complete'
  final String breakStatus;        // 'none', 'ongoing', 'complete'
  final String locationStatus;     // 'initial', 'checking', 'calculating', 'inside', 'outside', 'error'
  final String workLocationStatus; // 'WFO', 'WFH'
  final String punchInWorkMode;    // The work mode ('WFH' or 'WFO') at the time shift was started

  // Unauthorized Outside Office Tracking
  final Duration totalOutsideDuration;
  final bool isCurrentlyOutside;
  final DateTime? outsideStartTime;

  // Anti-Time Spoofing Server Clock Offset
  final Duration serverOffset;

  // Policy & Geofence metrics
  final List<String> pendingPolicies;
  final bool needsPolicyRead;
  final double officeLat;
  final double officeLong;
  final double allowedRadiusMeters;

  const AttendanceState({
    this.attendance = const AttendanceEntity(),
    this.isLoading = false,
    this.isPunchingIn = false,
    this.isPunchingOut = false,
    this.isLunchLoading = false,
    this.isBreakLoading = false,
    this.errorMessage,
    this.actionSuccessMessage,
    this.todayWorkingStatus = 'not_present',
    this.lunchStatus = 'none',
    this.breakStatus = 'none',
    this.locationStatus = 'initial',
    this.workLocationStatus = '',
    this.punchInWorkMode = '',
    this.totalOutsideDuration = Duration.zero,
    this.isCurrentlyOutside = false,
    this.outsideStartTime,
    this.serverOffset = Duration.zero,
    this.pendingPolicies = const [],
    this.needsPolicyRead = false,
    this.officeLat = 22.572646,
    this.officeLong = 88.363895,
    this.allowedRadiusMeters = 50.0, // Strict 50-meter default perimeter
  });

  // Server-Authoritative Trusted Clock
  DateTime get trustedCurrentTime => DateTime.now().add(serverOffset);

  // Status conveniences
  AttendanceStatus get currentStatus {
    if (isPunchedOut) return AttendanceStatus.punchedOut;
    if (isOnBreak) return AttendanceStatus.onBreak;
    if (isOnTiffin) return AttendanceStatus.onTiffin;
    if (isPunchedIn) return AttendanceStatus.working;
    if (isHoliday) return AttendanceStatus.holiday;
    if (isOnLeave) return AttendanceStatus.onLeave;
    if (isOfficeOff) return AttendanceStatus.officeOff;
    if (isWeekend()) return AttendanceStatus.officeOff;
    return AttendanceStatus.notPunchedIn;
  }

  // Non-working day & Weekly off checks
  bool isWeekend([DateTime? currentTime]) =>
      attendance.isWeekend(currentTime ?? trustedCurrentTime);
  bool get isOfficeOff =>
      attendance.isOfficeOff(trustedCurrentTime);
  bool get isHoliday => attendance.isHoliday;
  bool get isOnLeave => attendance.isOnLeave;
  bool isNonWorkingDay([DateTime? currentTime]) =>
      attendance.isNonWorkingDay(currentTime ?? trustedCurrentTime);

  bool get isPunchedIn =>
      todayWorkingStatus == 'present' ||
      todayWorkingStatus == 'lunch' ||
      todayWorkingStatus == 'break' ||
      (attendance.punchInTime != null && attendance.punchOutTime == null);
  bool get isPunchedOut =>
      todayWorkingStatus == 'punch_out' ||
      attendance.punchOutTime != null;
  bool get isNotPunchedIn => !isPunchedIn && !isPunchedOut;
  bool get isWorking =>
      isPunchedIn &&
      breakStatus != 'ongoing' &&
      lunchStatus != 'ongoing';
  bool get isOnBreak => breakStatus == 'ongoing';
  bool get isOnTiffin => lunchStatus == 'ongoing';
  bool get isLunchCompleted =>
      lunchStatus == 'complete' || lunchStatus == 'ended';
  bool get isInsideGeofence => locationStatus == 'inside';
  bool get isWFH {
    final status = workLocationStatus.toUpperCase();
    final loc = attendance.todayWorkLocation.toLowerCase();
    return status == 'WFH' ||
        loc.contains('home') ||
        loc.contains('wfh') ||
        loc.contains('remote');
  }
  bool get isWFO {
    if (isWFH) return false;
    final status = workLocationStatus.toUpperCase();
    final loc = attendance.todayWorkLocation.toLowerCase();
    return (status == 'WFO' || loc.contains('office') || loc.contains('wfo')) &&
        (status.isNotEmpty || loc.isNotEmpty);
  }

  /// Returns true if the currently active shift was started as WFH.
  /// Even if HR changes the profile to WFO midday (intended for tomorrow),
  /// the active shift retains its WFH permissions (Punch out from home, no outside tracking).
  bool get isShiftStartedAsWfh {
    if (punchInWorkMode.isNotEmpty) {
      return punchInWorkMode.toUpperCase() == 'WFH';
    }
    // Fallback if punchInWorkMode not yet populated: check if today's assigned mode is WFH
    return isWFH;
  }

  // Digital clock formatters (Requiring injected currentTime)
  String formattedTime(DateTime currentTime) =>
      DateFormat('hh:mm').format(currentTime);
  String formattedSeconds(DateTime currentTime) =>
      DateFormat('ss').format(currentTime);
  String amPm(DateTime currentTime) => DateFormat('a').format(currentTime);
  String formattedDate(DateTime currentTime) =>
      DateFormat('EEEE, dd MMMM yyyy').format(currentTime);
  String shortDate(DateTime currentTime) =>
      DateFormat('dd MMM').format(currentTime);

  // 2-Hour Early Punch Window & 5-Minute Grace Period calculations
  DateTime? shiftStartTime([DateTime? currentTime]) =>
      attendance.getShiftStartDateTime(currentTime ?? trustedCurrentTime);

  DateTime? earliestPunchInTime([DateTime? currentTime]) =>
      attendance.getEarliestPunchInTime(currentTime ?? trustedCurrentTime);

  DateTime? graceTime([DateTime? currentTime]) =>
      attendance.getGraceTime(currentTime ?? trustedCurrentTime);

  bool isPunchInWindowOpen([DateTime? currentTime]) =>
      attendance.isPunchInWindowOpen(currentTime ?? trustedCurrentTime);

  bool isPunchInOnTime(DateTime punchInTime) =>
      attendance.isPunchInOnTime(punchInTime);

  bool isPunchInLate(DateTime punchInTime) =>
      attendance.isPunchInLate(punchInTime);

  bool isWithinGraceBuffer(DateTime punchInTime) =>
      attendance.isWithinGraceBuffer(punchInTime);

  // Duration Metrics
  Duration get totalWorkDuration => attendance.netWorkingDuration;
  Duration get totalBreakDuration => attendance.totalBreakDuration;
  Duration get totalLunchDuration => attendance.totalLunchDuration;

  // Real-time Net Working Duration (Automatically Pauses during Break, Tiffin, or Unauthorized Outside Office)
  Duration liveNetWorkingDuration(DateTime currentTime) {
    if (attendance.punchInTime == null) return Duration.zero;

    final end = attendance.punchOutTime ?? currentTime;
    final totalGrossElapsed = end.difference(attendance.punchInTime!);
    if (totalGrossElapsed.isNegative) return Duration.zero;

    // 1. Live Break duration (if currently ongoing)
    final liveBreak = isOnBreak && attendance.breakInTime != null
        ? attendance.totalBreakDuration + currentTime.difference(attendance.breakInTime!)
        : attendance.totalBreakDuration;

    // 2. Live Tiffin duration (if currently ongoing)
    final liveLunch = isOnTiffin && attendance.lunchInTime != null
        ? attendance.totalLunchDuration + currentTime.difference(attendance.lunchInTime!)
        : attendance.totalLunchDuration;

    // 3. 🔴 Live Outside Office duration (ONLY for WFO employees on WFO shift)
    final liveOutside = (isWFO && !isWFH && !isShiftStartedAsWfh && isCurrentlyOutside && outsideStartTime != null)
        ? totalOutsideDuration + currentTime.difference(outsideStartTime!)
        : (isWFO && !isWFH && !isShiftStartedAsWfh ? totalOutsideDuration : Duration.zero);

    // 4. Total Non-Working / Away Deductions
    final totalDeductions = liveBreak + liveLunch + liveOutside;

    // 5. Net Effective Working Duration
    final netWorkingDuration = totalGrossElapsed - totalDeductions;
    return netWorkingDuration.isNegative ? Duration.zero : netWorkingDuration;
  }

  String netWorkingHoursString(DateTime currentTime) {
    final dur = liveNetWorkingDuration(currentTime);
    final hours = dur.inHours.toString().padLeft(2, '0');
    final minutes = (dur.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (dur.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String totalBreakString(DateTime currentTime) {
    var dur = attendance.totalBreakDuration;
    if (isOnBreak && attendance.breakInTime != null) {
      dur += currentTime.difference(attendance.breakInTime!);
    }
    return formatDurationToDisplay(dur);
  }

  String totalTiffinString(DateTime currentTime) {
    var dur = attendance.totalLunchDuration;
    if (isOnTiffin && attendance.lunchInTime != null) {
      dur += currentTime.difference(attendance.lunchInTime!);
    }
    return formatDurationToDisplay(dur);
  }

  String totalOutsideString(DateTime currentTime) {
    if (isWFH || !isWFO || isShiftStartedAsWfh) return '0m 00s';
    var dur = totalOutsideDuration;
    if (isCurrentlyOutside && outsideStartTime != null) {
      dur += currentTime.difference(outsideStartTime!);
    }
    return formatDurationToDisplay(dur);
  }

  AttendanceState copyWith({
    AttendanceEntity? attendance,
    bool? isLoading,
    bool? isPunchingIn,
    bool? isPunchingOut,
    bool? isLunchLoading,
    bool? isBreakLoading,
    String? errorMessage,
    String? actionSuccessMessage,
    String? todayWorkingStatus,
    String? lunchStatus,
    String? breakStatus,
    String? locationStatus,
    String? workLocationStatus,
    String? punchInWorkMode,
    Duration? totalOutsideDuration,
    bool? isCurrentlyOutside,
    DateTime? outsideStartTime,
    Duration? serverOffset,
    List<String>? pendingPolicies,
    bool? needsPolicyRead,
    double? officeLat,
    double? officeLong,
    double? allowedRadiusMeters,
  }) {
    return AttendanceState(
      attendance: attendance ?? this.attendance,
      isLoading: isLoading ?? this.isLoading,
      isPunchingIn: isPunchingIn ?? this.isPunchingIn,
      isPunchingOut: isPunchingOut ?? this.isPunchingOut,
      isLunchLoading: isLunchLoading ?? this.isLunchLoading,
      isBreakLoading: isBreakLoading ?? this.isBreakLoading,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      todayWorkingStatus: todayWorkingStatus ?? this.todayWorkingStatus,
      lunchStatus: lunchStatus ?? this.lunchStatus,
      breakStatus: breakStatus ?? this.breakStatus,
      locationStatus: locationStatus ?? this.locationStatus,
      workLocationStatus: workLocationStatus ?? this.workLocationStatus,
      punchInWorkMode: punchInWorkMode ?? this.punchInWorkMode,
      totalOutsideDuration: totalOutsideDuration ?? this.totalOutsideDuration,
      isCurrentlyOutside: isCurrentlyOutside ?? this.isCurrentlyOutside,
      outsideStartTime: outsideStartTime ?? this.outsideStartTime,
      serverOffset: serverOffset ?? this.serverOffset,
      pendingPolicies: pendingPolicies ?? this.pendingPolicies,
      needsPolicyRead: needsPolicyRead ?? this.needsPolicyRead,
      officeLat: officeLat ?? this.officeLat,
      officeLong: officeLong ?? this.officeLong,
      allowedRadiusMeters: allowedRadiusMeters ?? this.allowedRadiusMeters,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository repository;
  final StorageService storageService;

  Timer? _outsideTrackingTimer;
  bool _isEvaluatingOutside = false;

  AttendanceNotifier({
    required this.repository,
    required this.storageService,
  }) : super(const AttendanceState()) {
    _initAndFetch();
  }

  @override
  void dispose() {
    _stopOutsideTrackingTimer();
    super.dispose();
  }

  void _startOutsideTrackingTimer() {
    _outsideTrackingTimer?.cancel();
    if (state.isWFO && !state.isWFH && state.todayWorkingStatus == 'present') {
      _outsideTrackingTimer = Timer.periodic(const Duration(seconds: 120), (_) {
        evaluateOutsideOfficeTracking();
      });
    }
  }

  void _stopOutsideTrackingTimer() {
    _outsideTrackingTimer?.cancel();
    _outsideTrackingTimer = null;
  }

  Future<void> _initAndFetch() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // 1. Immediately check today-specific cached assignment
    final todayStatus = await storageService.getString('user_work_location_status_$todayStr');
    final todayLocation = await storageService.getString('user_today_work_location_$todayStr');

    if (todayStatus != null && todayStatus.isNotEmpty) {
      final isExplicitWfo = todayStatus.toUpperCase() == 'WFO' &&
          !(todayLocation?.toLowerCase().contains('home') ?? false) &&
          !(todayLocation?.toLowerCase().contains('wfh') ?? false);
      final isWfh = !isExplicitWfo;
      if (mounted) {
        state = state.copyWith(
          workLocationStatus: isWfh ? 'WFH' : 'WFO',
          locationStatus: isWfh ? 'inside' : state.locationStatus,
          attendance: state.attendance.copyWith(
            workLocationStatus: isWfh ? 'WFH' : 'WFO',
            todayWorkLocation: isWfh ? 'Work_From_Home' : 'Work_From_Office',
          ),
        );
      }
    } else {
      // If no specific cache for today, check login work mode
      final cachedWorkMode = await storageService.getString('user_work_mode');
      final isExplicitWfo = cachedWorkMode != null &&
          (cachedWorkMode.toLowerCase().contains('office') || cachedWorkMode.toLowerCase() == 'wfo') &&
          !cachedWorkMode.toLowerCase().contains('home') &&
          !cachedWorkMode.toLowerCase().contains('wfh');
      final isWfh = !isExplicitWfo;
      if (mounted) {
        state = state.copyWith(
          workLocationStatus: isWfh ? 'WFH' : 'WFO',
          locationStatus: isWfh ? 'inside' : state.locationStatus,
          attendance: state.attendance.copyWith(
            workLocationStatus: isWfh ? 'WFH' : 'WFO',
            todayWorkLocation: isWfh ? 'Work_From_Home' : 'Work_From_Office',
          ),
        );
      }
    }

    final savedShiftMode = await storageService.getString('user_punch_in_mode_$todayStr');
    if (savedShiftMode != null && savedShiftMode.isNotEmpty && mounted) {
      state = state.copyWith(punchInWorkMode: savedShiftMode);
    }

    // Load cached office coordinates if available so cold starts don't rely on hardcoded defaults
    final cachedLatStr = await storageService.getString('cached_office_lat');
    final cachedLongStr = await storageService.getString('cached_office_long');
    final cachedRadiusStr = await storageService.getString('cached_office_radius');
    final cachedLat = cachedLatStr != null ? double.tryParse(cachedLatStr) : null;
    final cachedLong = cachedLongStr != null ? double.tryParse(cachedLongStr) : null;
    final cachedRadius = cachedRadiusStr != null ? double.tryParse(cachedRadiusStr) : null;
    if (cachedLat != null && cachedLong != null && cachedLat != 0.0 && cachedLong != 0.0 && mounted) {
      state = state.copyWith(
        officeLat: cachedLat,
        officeLong: cachedLong,
        allowedRadiusMeters: cachedRadius ?? state.allowedRadiusMeters,
      );
    }

    // 2. Dual-fetch latest from API
    await fetchTodayAttendance();
  }

  Future<String> _getEmpId() async {
    return (await storageService.getSecure(ApiConstants.storageEmpIdKey)) ??
        (await storageService.getString(ApiConstants.storageEmpIdKey)) ??
        '';
  }

  Future<String> _getSecureKey() async {
    return (await storageService.getSecure(ApiConstants.storageSecureKey)) ??
        (await storageService.getString(ApiConstants.storageSecureKey)) ??
        '';
  }

  /// Initial dashboard load: Dual-fetches employee details AND daily activity in parallel
  Future<void> fetchTodayAttendance() async {
    try {
      // 0. Automatically sync any pending offline outbox queue actions to server
      await repository.syncOfflineOutbox().catchError((_) => 0);

      final empId = await _getEmpId();
      final secure = await _getSecureKey();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Parallel Dual-Fetch for immediate synchronization with error resilience
      final results = await Future.wait([
        repository.fetchEmployeeDetails(
          empId: empId,
          todayDate: todayStr,
          secure: secure,
        ).catchError((_) => const AttendanceEntity()),
        repository.getDailyActivity(
          empId: empId,
          date: todayStr,
          secure: secure,
        ).catchError((_) => const AttendanceEntity()),
      ]);

      final detailsEntity = results[0];
      final activityEntity = results[1];

      // Merge punch times, shift times, and daily activity metrics
      final mergedPunchIn = detailsEntity.punchInTime ?? activityEntity.punchInTime;
      final mergedPunchOut = detailsEntity.punchOutTime ?? activityEntity.punchOutTime;
      final mergedLunchIn = activityEntity.lunchInTime ?? detailsEntity.lunchInTime;
      final mergedLunchOut = activityEntity.lunchOutTime ?? detailsEntity.lunchOutTime;
      final mergedBreakIn = activityEntity.breakInTime ?? detailsEntity.breakInTime;
      final mergedBreakOut = activityEntity.breakOutTime ?? detailsEntity.breakOutTime;

      final mergedLunchStatus = activityEntity.lunchStatus != 'none'
          ? activityEntity.lunchStatus
          : detailsEntity.lunchStatus;
      final mergedBreakStatus = activityEntity.breakStatus != 'none'
          ? activityEntity.breakStatus
          : detailsEntity.breakStatus;

      final isPunchedInShift = (mergedPunchIn != null && mergedPunchOut == null);
      final mergedWorkingStatus = isPunchedInShift
          ? 'present'
          : (mergedPunchOut != null ? 'punch_out' : detailsEntity.todayWorkingStatus);

      // HR / Management assignment in detailsEntity is authoritative for the employee's current work location.
      // If HR changes status from WFH to WFO, detailsEntity reflects this change and must override
      // any past punch-in location status in activityEntity.
      final isDetailsWfo = (detailsEntity.workLocationStatus.toUpperCase() == 'WFO' ||
              detailsEntity.todayWorkLocation.toLowerCase() == 'work_from_office' ||
              detailsEntity.todayWorkLocation.toLowerCase().contains('office')) &&
          !detailsEntity.todayWorkLocation.toLowerCase().contains('home') &&
          !detailsEntity.todayWorkLocation.toLowerCase().contains('wfh') &&
          !detailsEntity.todayWorkLocation.toLowerCase().contains('remote') &&
          detailsEntity.workLocationStatus != 'WFH';

      final isExplicitWfo = isDetailsWfo;

      final mergedWorkLocationStatus = isExplicitWfo ? 'WFO' : 'WFH';
      final mergedTodayWorkLocation = isExplicitWfo
          ? (detailsEntity.todayWorkLocation.isNotEmpty
              ? detailsEntity.todayWorkLocation
              : 'Work_From_Office')
          : (detailsEntity.todayWorkLocation.isNotEmpty
              ? detailsEntity.todayWorkLocation
              : 'Work_From_Home');
      final isWfhAssigned = mergedWorkLocationStatus == 'WFH';

      await storageService.saveString(
          'user_work_location_status_$todayStr', mergedWorkLocationStatus);
      await storageService.saveString(
          'user_today_work_location_$todayStr', mergedTodayWorkLocation);
      await storageService.saveString(
          'user_work_location_status', mergedWorkLocationStatus);
      await storageService.saveString(
          'user_today_work_location', mergedTodayWorkLocation);
      await storageService.saveString('user_work_mode', mergedTodayWorkLocation);

      final mergedEntity = detailsEntity.copyWith(
        punchInTime: mergedPunchIn,
        punchOutTime: mergedPunchOut,
        lunchInTime: mergedLunchIn,
        lunchOutTime: mergedLunchOut,
        breakInTime: mergedBreakIn,
        breakOutTime: mergedBreakOut,
        lunchStatus: mergedLunchStatus,
        breakStatus: mergedBreakStatus,
        todayWorkingStatus: mergedWorkingStatus,
        workLocationStatus: mergedWorkLocationStatus,
        todayWorkLocation: mergedTodayWorkLocation,
        openingTime: detailsEntity.openingTime ?? activityEntity.openingTime,
        closingTime: detailsEntity.closingTime ?? activityEntity.closingTime,
        isLate: detailsEntity.isLate || activityEntity.isLate,
        lateBy: detailsEntity.lateBy ?? activityEntity.lateBy,
        holidayName: activityEntity.holidayName ?? detailsEntity.holidayName,
        leaveType: activityEntity.leaveType ?? detailsEntity.leaveType,
        backendStatus: (activityEntity.backendStatus != null &&
                activityEntity.backendStatus!.isNotEmpty &&
                activityEntity.backendStatus != 'Active' &&
                activityEntity.backendStatus != 'Inactive')
            ? activityEntity.backendStatus
            : (detailsEntity.backendStatus != 'Active' &&
                    detailsEntity.backendStatus != 'Inactive'
                ? detailsEntity.backendStatus
                : activityEntity.backendStatus),
        totalBreakDuration: activityEntity.totalBreakDuration > Duration.zero
            ? activityEntity.totalBreakDuration
            : detailsEntity.totalBreakDuration,
        totalLunchDuration: activityEntity.totalLunchDuration > Duration.zero
            ? activityEntity.totalLunchDuration
            : detailsEntity.totalLunchDuration,
        netWorkingDuration: activityEntity.netWorkingDuration > Duration.zero
            ? activityEntity.netWorkingDuration
            : detailsEntity.netWorkingDuration,
      );

      Duration calculatedOffset = state.serverOffset;
      if (detailsEntity.serverTime != null) {
        calculatedOffset = detailsEntity.serverTime!.difference(DateTime.now());
      } else if (activityEntity.serverTime != null) {
        calculatedOffset = activityEntity.serverTime!.difference(DateTime.now());
      }

      // Resolve punch-in work mode for the active shift
      String resolvedShiftMode = state.punchInWorkMode;
      final savedShiftMode = await storageService.getString('user_punch_in_mode_$todayStr');
      if (savedShiftMode != null && savedShiftMode.isNotEmpty) {
        resolvedShiftMode = savedShiftMode;
      } else if (isPunchedInShift) {
        // Infer from activityEntity or previous state if employee is already punched in
        if (activityEntity.workLocationStatus.isNotEmpty) {
          resolvedShiftMode = activityEntity.workLocationStatus;
        } else if (activityEntity.punchInLat == 0.0 && activityEntity.punchInLong == 0.0) {
          resolvedShiftMode = 'WFH';
        } else if (mergedWorkLocationStatus.isNotEmpty) {
          resolvedShiftMode = mergedWorkLocationStatus;
        }
        if (resolvedShiftMode.isNotEmpty) {
          await storageService.saveString('user_punch_in_mode_$todayStr', resolvedShiftMode);
        }
      }

      final isShiftWfh = resolvedShiftMode.toUpperCase() == 'WFH' ||
          (isPunchedInShift && resolvedShiftMode.isEmpty && isWfhAssigned);

      // Dynamically resolve office coordinates from API responses (detailsEntity has priority, then activityEntity)
      final dynamicOfficeLat = (detailsEntity.officeLat != 0.0)
          ? detailsEntity.officeLat
          : (activityEntity.officeLat != 0.0 ? activityEntity.officeLat : null);
      final dynamicOfficeLong = (detailsEntity.officeLong != 0.0)
          ? detailsEntity.officeLong
          : (activityEntity.officeLong != 0.0 ? activityEntity.officeLong : null);
      final dynamicRadius = (detailsEntity.allowedRadiusMeters > 0)
          ? detailsEntity.allowedRadiusMeters
          : (activityEntity.allowedRadiusMeters > 0 ? activityEntity.allowedRadiusMeters : null);

      if (dynamicOfficeLat != null && dynamicOfficeLong != null) {
        await storageService.saveString('cached_office_lat', dynamicOfficeLat.toString());
        await storageService.saveString('cached_office_long', dynamicOfficeLong.toString());
      }
      if (dynamicRadius != null) {
        await storageService.saveString('cached_office_radius', dynamicRadius.toString());
      }

      if (mounted) {
        state = state.copyWith(
          attendance: mergedEntity,
          todayWorkingStatus: mergedWorkingStatus,
          lunchStatus: mergedLunchStatus,
          breakStatus: mergedBreakStatus,
          workLocationStatus: mergedWorkLocationStatus,
          punchInWorkMode: resolvedShiftMode,
          locationStatus: (isWfhAssigned || isShiftWfh) ? 'inside' : state.locationStatus,
          serverOffset: calculatedOffset,
          officeLat: dynamicOfficeLat ?? state.officeLat,
          officeLong: dynamicOfficeLong ?? state.officeLong,
          allowedRadiusMeters: dynamicRadius ?? state.allowedRadiusMeters,
        );

        if (isWfhAssigned || isShiftWfh) {
          state = state.copyWith(
            totalOutsideDuration: Duration.zero,
            isCurrentlyOutside: false,
            outsideStartTime: null,
            locationStatus: 'inside',
          );
        }

        // Schedule local shift reminders (30m, 15m, 5m start, 30m, 10m end)
        unawaited(
          NotificationService.instance
              .scheduleShiftRemindersFromAttendance(state.attendance)
              .catchError((_) {}),
        );
      }

      if (!isWfhAssigned && !isShiftWfh) {
        await loadSavedOutsideDuration();
        // Drain any queued offline punches/breaks in the background
        unawaited(repository.syncOfflineOutbox().catchError((_) => 0));
        // Auto-detect location on dashboard load in the background
        unawaited(refreshLocation().catchError((_) {}));
        if (state.todayWorkingStatus == 'present') {
          _startOutsideTrackingTimer();
        }
      } else {
        _stopOutsideTrackingTimer();
        // For WFH: sync offline queue without location refresh
        unawaited(repository.syncOfflineOutbox().catchError((_) => 0));
      }
    } catch (_) {
      // Retain existing state gracefully
    }
  }

  /// Manually or reactively flush the pending offline outbox queue to the server
  Future<int> syncPendingOfflineData() async {
    final synced = await repository.syncOfflineOutbox();
    if (synced > 0) {
      await fetchTodayAttendance();
    }
    return synced;
  }

  /// Refreshes daily activity metrics from `/users/attendance/daily-activity`
  Future<void> refreshDailyActivity() async {
    try {
      final empId = await _getEmpId();
      final secure = await _getSecureKey();
      final trustedDate = state.trustedCurrentTime;
      final todayStr = DateFormat('yyyy-MM-dd').format(trustedDate);

      final activity = await repository.getDailyActivity(
        empId: empId,
        date: todayStr,
        secure: secure,
      );

      if (mounted) {
        final mergedLunchIn = activity.lunchInTime ?? state.attendance.lunchInTime;
        final mergedLunchOut = activity.lunchOutTime ?? state.attendance.lunchOutTime;
        final mergedBreakIn = activity.breakInTime ?? state.attendance.breakInTime;
        final mergedBreakOut = activity.breakOutTime ?? state.attendance.breakOutTime;
        final mergedLunchStatus = activity.lunchStatus != 'none'
            ? activity.lunchStatus
            : state.lunchStatus;
        final mergedBreakStatus = activity.breakStatus != 'none'
            ? activity.breakStatus
            : state.breakStatus;
        final mergedPunchIn = state.attendance.punchInTime ?? activity.punchInTime;
        final mergedPunchOut = state.attendance.punchOutTime ?? activity.punchOutTime;
        final isPunchedInShift = (mergedPunchIn != null && mergedPunchOut == null);
        final mergedWorkingStatus = isPunchedInShift
            ? 'present'
            : (mergedPunchOut != null ? 'punch_out' : state.todayWorkingStatus);

        final merged = state.attendance.copyWith(
          punchInTime: mergedPunchIn,
          punchOutTime: mergedPunchOut,
          lunchInTime: mergedLunchIn,
          lunchOutTime: mergedLunchOut,
          breakInTime: mergedBreakIn,
          breakOutTime: mergedBreakOut,
          lunchStatus: mergedLunchStatus,
          breakStatus: mergedBreakStatus,
          todayWorkingStatus: mergedWorkingStatus,
          openingTime: state.attendance.openingTime ?? activity.openingTime,
          closingTime: state.attendance.closingTime ?? activity.closingTime,
          isLate: state.attendance.isLate || activity.isLate,
          lateBy: state.attendance.lateBy ?? activity.lateBy,
          holidayName: state.attendance.holidayName ?? activity.holidayName,
          leaveType: state.attendance.leaveType ?? activity.leaveType,
          backendStatus: activity.backendStatus ?? state.attendance.backendStatus,
          totalBreakDuration: activity.totalBreakDuration > Duration.zero
              ? activity.totalBreakDuration
              : state.attendance.totalBreakDuration,
          totalLunchDuration: activity.totalLunchDuration > Duration.zero
              ? activity.totalLunchDuration
              : state.attendance.totalLunchDuration,
          netWorkingDuration: activity.netWorkingDuration > Duration.zero
              ? activity.netWorkingDuration
              : state.attendance.netWorkingDuration,
        );
        state = state.copyWith(
          attendance: merged,
          todayWorkingStatus: mergedWorkingStatus,
          lunchStatus: mergedLunchStatus,
          breakStatus: mergedBreakStatus,
        );
      }
    } catch (_) {}
  }

  /// Alias for backward compatibility
  Future<void> checkOutsideOfficePerimeter() => evaluateOutsideOfficeTracking();

  /// 🔒 GOLDEN MUTEX INVARIANT: Unauthorized Outside Office Tracking Engine
  /// Muted & Inactive 100% when employee is on official Break or Tiffin, or when Punched Out!
  Future<void> evaluateOutsideOfficeTracking() async {
    if (_isEvaluatingOutside) return;
    _isEvaluatingOutside = true;
    try {
      // 🔴 0. Strict WFH Guard: WFH employees (or shifts started as WFH) never track outside office!
      if (state.isWFH || !state.isWFO || state.isShiftStartedAsWfh) {
        if (state.isCurrentlyOutside || state.totalOutsideDuration > Duration.zero) {
          state = state.copyWith(
            isCurrentlyOutside: false,
            outsideStartTime: null,
            totalOutsideDuration: Duration.zero,
          );
        }
        return;
      }

      // 🔴 1. If employee has punched out OR has not punched in yet, strictly ABORT:
      if (state.todayWorkingStatus != 'present') {
        if (state.isCurrentlyOutside) {
          state = state.copyWith(isCurrentlyOutside: false, outsideStartTime: null);
        }
        return; // ⛔ NEVER TRACK OUTSIDE TIME WHEN PUNCHED OUT
      }

      // 🔴 2. CRITICAL MUTEX GUARD: If employee activated official Break or Lunch, FREEZE outside tracking!
      final isOnOfficialBreak = state.breakStatus == 'ongoing';
      final isOnOfficialLunch = state.lunchStatus == 'ongoing';

      if (isOnOfficialBreak || isOnOfficialLunch) {
        // If an unauthorized outside session was active before pressing break/tiffin, commit and stop it:
        if (state.isCurrentlyOutside && state.outsideStartTime != null) {
          final session = state.trustedCurrentTime.difference(state.outsideStartTime!);
          final updated = state.totalOutsideDuration + session;
          state = state.copyWith(
            isCurrentlyOutside: false,
            outsideStartTime: null,
            totalOutsideDuration: updated,
          );
          await _persistOutsideDuration(updated);
        }
        return; // ⛔ EXIT IMMEDIATELY. ZERO SECONDS ADDED WHILE ON BREAK OR TIFFIN.
      }

      // 3. Check Physical Distance from Office Premises (50 meters boundary)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              timeLimit: const Duration(seconds: 8),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              timeLimit: const Duration(seconds: 8),
            );

      final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      if (pos.isMocked) return;

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        state.officeLat,
        state.officeLong,
      );

      const double perimeterThreshold = 50.0; // 50 meters boundary
      final isOutsideOffice = distance > perimeterThreshold;
      final now = state.trustedCurrentTime;

      if (isOutsideOffice) {
        // Employee is outside without turning on Break or Tiffin!
        if (!state.isCurrentlyOutside) {
          state = state.copyWith(
            isCurrentlyOutside: true,
            outsideStartTime: now,
          );
        }
      } else {
        // Employee returned back inside the 50m office boundary
        if (state.isCurrentlyOutside && state.outsideStartTime != null) {
          final sessionDuration = now.difference(state.outsideStartTime!);
          final updatedTotal = state.totalOutsideDuration + sessionDuration;
          state = state.copyWith(
            isCurrentlyOutside: false,
            outsideStartTime: null,
            totalOutsideDuration: updatedTotal,
          );
          await _persistOutsideDuration(updatedTotal);
        }
      }
    } catch (_) {
    } finally {
      _isEvaluatingOutside = false;
    }
  }

  Future<void> _persistOutsideDuration(Duration d) async {
    final key = 'unauth_outside_${DateFormat('yyyy-MM-dd').format(state.trustedCurrentTime)}';
    await storageService.saveSecure(key, d.inSeconds.toString());
    await storageService.saveString(key, d.inSeconds.toString());
  }

  Future<void> loadSavedOutsideDuration() async {
    if (state.isWFH || !state.isWFO) {
      state = state.copyWith(totalOutsideDuration: Duration.zero);
      return;
    }
    final key = 'unauth_outside_${DateFormat('yyyy-MM-dd').format(state.trustedCurrentTime)}';
    final val = await storageService.getSecure(key) ??
        await storageService.getString(key);
    if (val != null) {
      final sec = int.tryParse(val) ?? 0;
      state = state.copyWith(totalOutsideDuration: Duration(seconds: sec));
    }
  }

  /// Strict 50-Meter Geofence Proximity Verification for START and END Actions
  Future<bool> verifyOfficeProximity({required String actionName}) async {
    // WFH employees bypass location restrictions.
    // Also, if the shift was started as WFH, in-shift actions (punch out, break, tiffin) bypass geofence.
    if (state.isWFH || !state.isWFO) return true;
    if (state.isShiftStartedAsWfh && !actionName.toLowerCase().contains('punch in')) {
      return true;
    }

    state = state.copyWith(locationStatus: 'checking');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        locationStatus: 'error',
        errorMessage: 'GPS Location services are disabled. Please enable GPS to $actionName.',
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          locationStatus: 'error',
          errorMessage: 'Location permissions are denied. Cannot verify geofence to $actionName.',
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        locationStatus: 'error',
        errorMessage: 'Location permissions are permanently denied. Please enable in Settings.',
      );
      return false;
    }

    state = state.copyWith(locationStatus: 'calculating');

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            timeLimit: const Duration(seconds: 8),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            timeLimit: const Duration(seconds: 8),
          );

    final Position pos = await Geolocator.getCurrentPosition(locationSettings: settings);

    // 1. Anti-Mock / Fake GPS Detection
    if (pos.isMocked) {
      state = state.copyWith(
        locationStatus: 'error',
        errorMessage: 'Security Alert: Fake GPS / Mock Location detected.',
      );
      return false;
    }

    // 2. Minimum GPS Accuracy Verification
    if (pos.accuracy > 50.0) {
      state = state.copyWith(
        locationStatus: 'error',
        errorMessage: 'Low GPS accuracy (${pos.accuracy.toStringAsFixed(1)}m). Please step into open air and retry.',
      );
      return false;
    }

    // 3. Strict 50-Meter Geofence Distance Calculation
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      state.officeLat,
      state.officeLong,
    );

    const double maxAllowedDistance = 50.0; // Strict 50-meter perimeter

    if (distance > maxAllowedDistance) {
      state = state.copyWith(locationStatus: 'outside');
      final distInt = distance.round();
      state = state.copyWith(
        errorMessage: 'Geofence Alert: You are ${distInt}m away. You must be within 50m of the office to $actionName.',
      );
      return false;
    }

    state = state.copyWith(locationStatus: 'inside');
    return true;
  }

  /// Public action to re-check GPS location and determine if inside or outside office geofence
  Future<void> refreshLocation() async {
    if (state.isWFH || !state.isWFO) {
      state = state.copyWith(
        locationStatus: 'inside',
        actionSuccessMessage: state.isWFH ? 'Work Mode: Home Office' : null,
      );
      return;
    }

    state = state.copyWith(locationStatus: 'checking');

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          locationStatus: 'error',
          errorMessage: 'GPS Location services are disabled. Please enable GPS.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          locationStatus: 'denied',
          errorMessage: 'Location permission not granted.',
        );
        return;
      }

      state = state.copyWith(locationStatus: 'calculating');

      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              timeLimit: const Duration(seconds: 8),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              timeLimit: const Duration(seconds: 8),
            );

      final Position pos = await Geolocator.getCurrentPosition(locationSettings: settings);

      if (pos.isMocked) {
        state = state.copyWith(
          locationStatus: 'error',
          errorMessage: 'Security Alert: Fake GPS / Mock Location detected.',
        );
        return;
      }

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        state.officeLat,
        state.officeLong,
      );

      final isInside = distance <= state.allowedRadiusMeters;
      state = state.copyWith(
        locationStatus: isInside ? 'inside' : 'outside',
        actionSuccessMessage: isInside
            ? 'Inside Office (${distance.round()}m from center)'
            : 'Outside Office (${distance.round()}m from office)',
      );
    } catch (e) {
      state = state.copyWith(
        locationStatus: 'error',
        errorMessage: 'Unable to detect location. Please retry.',
      );
    }
  }

  /// 1. PUNCH IN (with 2-Hour Early Window & 5-Minute Grace Period logic)
  Future<bool> punchIn() async {
    if (state.todayWorkingStatus != 'not_present') {
      state = state.copyWith(
        errorMessage: 'You have already punched in for today\'s shift.',
      );
      return false;
    }

    final trustedNow = state.trustedCurrentTime;

    // Check if 2-hour early punch window is open
    if (!state.isPunchInWindowOpen(trustedNow)) {
      final earliest = state.earliestPunchInTime(trustedNow);
      final shift = state.shiftStartTime(trustedNow);
      final earliestFormatted = earliest != null ? DateFormat('h:mm a').format(earliest) : '2 hours before shift';
      final shiftFormatted = shift != null ? DateFormat('h:mm a').format(shift) : '';
      state = state.copyWith(
        errorMessage: 'Punch In opens 2 hours before shift start time (at $earliestFormatted${shiftFormatted.isNotEmpty ? ' for $shiftFormatted shift' : ''}).',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      isPunchingIn: true,
      errorMessage: null,
      actionSuccessMessage: null,
    );

    try {
      final allowed = await verifyOfficeProximity(actionName: 'punch in');
      if (!allowed) {
        state = state.copyWith(
          isLoading: false,
          isPunchingIn: false,
        );
        return false;
      }

      final empId = await _getEmpId();
      final secure = await _getSecureKey();
      final todayStr = DateFormat('yyyy-MM-dd').format(trustedNow);
      final timeStr = DateFormat('HH:mm:ss').format(trustedNow);

      double punchLat = state.officeLat;
      double punchLong = state.officeLong;

      if (state.isWFH) {
        punchLat = 0.0;
        punchLong = 0.0;
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 3),
            ),
          );
          punchLat = pos.latitude;
          punchLong = pos.longitude;
        } catch (_) {}
      }

      final updated = await repository.punchInWithParams(
        todayDate: todayStr,
        punchInTime: timeStr,
        empId: empId,
        secure: secure,
        punchInLat: punchLat,
        punchInLong: punchLong,
        workLocationStatus: state.workLocationStatus,
      );

      // Determine if punch-in occurred after scheduled shift start time (e.g. 09:33 > 09:30 => Late)
      final isLate = state.isPunchInLate(trustedNow);
      final calculatedIsLate = isLate || updated.isLate;

      final newAttendance = updated.copyWith(
        punchInTime: trustedNow,
        todayWorkingStatus: 'present',
        isLate: calculatedIsLate,
      );

      final shiftMode = state.isWFH ? 'WFH' : 'WFO';
      await storageService.saveString('user_punch_in_mode_$todayStr', shiftMode);

      state = state.copyWith(
        attendance: newAttendance,
        todayWorkingStatus: 'present',
        punchInWorkMode: shiftMode,
        isLoading: false,
        isPunchingIn: false,
        actionSuccessMessage: calculatedIsLate
            ? 'Successfully punched in (Late Login recorded).'
            : 'Successfully punched in for today\'s shift (On Time).',
      );

      NotificationService.instance.showNotification(
        title: 'Punch In Successful!',
        body: 'Your attendance for today has been recorded successfully.',
      );

      await refreshDailyActivity();
      if (!state.isWFH) {
        _startOutsideTrackingTimer();
      }
      return true;
    } on ConflictException {
      state = state.copyWith(
        todayWorkingStatus: 'present',
        isLoading: false,
        isPunchingIn: false,
        actionSuccessMessage: 'Shift active on server. Synced successfully.',
      );
      await fetchTodayAttendance();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPunchingIn: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Marks policy as read locally after user agreement
  void markPoliciesAsRead() {
    state = state.copyWith(
      needsPolicyRead: false,
      pendingPolicies: [],
    );
  }

  /// 2. PUNCH OUT (with 409 Conflict Self-Healing & Permanent Outside Tracking Termination)
  Future<bool> punchOut() async {
    if (state.todayWorkingStatus != 'present') {
      state = state.copyWith(
        errorMessage: 'Cannot Punch Out when you are not currently on shift.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      isPunchingOut: true,
      errorMessage: null,
      actionSuccessMessage: null,
    );

    try {
      final empId = await _getEmpId();
      final secure = await _getSecureKey();

      // Gatekeeper 1: Policy Check
      final policyResult = await repository.checkPolicies(
        employeeId: empId,
        secure: secure,
      );

      if (!policyResult.isAllRead && state.needsPolicyRead) {
        state = state.copyWith(
          isLoading: false,
          isPunchingOut: false,
          needsPolicyRead: true,
          pendingPolicies: policyResult.unreadPolicies,
          errorMessage: 'Please read and accept pending company policies before punching out.',
        );
        return false;
      }

      // Gatekeeper 2: Strict 50-Meter Geofence
      final allowed = await verifyOfficeProximity(actionName: 'punch out');
      if (!allowed) {
        state = state.copyWith(
          isLoading: false,
          isPunchingOut: false,
        );
        return false;
      }

      final trustedNow = state.trustedCurrentTime;
      final todayStr = DateFormat('yyyy-MM-dd').format(trustedNow);
      final timeStr = DateFormat('HH:mm:ss').format(trustedNow);

      double punchOutLat = state.officeLat;
      double punchOutLong = state.officeLong;

      if (state.isWFH || state.isShiftStartedAsWfh) {
        punchOutLat = 0.0;
        punchOutLong = 0.0;
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 3),
            ),
          );
          punchOutLat = pos.latitude;
          punchOutLong = pos.longitude;
        } catch (_) {}
      }

      final updated = await repository.punchOutWithParams(
        todayDate: todayStr,
        punchOutTime: timeStr,
        empId: empId,
        secure: secure,
        punchOutLat: punchOutLat,
        punchOutLong: punchOutLong,
      );

      final newAttendance = updated.copyWith(
        punchOutTime: trustedNow,
        todayWorkingStatus: 'punch_out',
      );

      // Commit any active outside session before punch out
      if (state.isCurrentlyOutside && state.outsideStartTime != null) {
        final session = trustedNow.difference(state.outsideStartTime!);
        final finalTotal = state.totalOutsideDuration + session;
        await _persistOutsideDuration(finalTotal);
        state = state.copyWith(totalOutsideDuration: finalTotal);
      }

      // 🔴 PERMANENTLY TERMINATE OUTSIDE TRACKING FOR TODAY:
      _stopOutsideTrackingTimer();
      state = state.copyWith(
        attendance: newAttendance,
        todayWorkingStatus: 'punch_out',
        isCurrentlyOutside: false,
        outsideStartTime: null,
        isLoading: false,
        isPunchingOut: false,
        actionSuccessMessage: 'Shift ended. Great work today!',
      );

      NotificationService.instance.showNotification(
        title: 'Punch Out Complete!',
        body: 'Your shift has ended. Have a great rest of the day!',
      );

      await refreshDailyActivity();
      return true;
    } on ConflictException {
      _stopOutsideTrackingTimer();
      state = state.copyWith(
        todayWorkingStatus: 'punch_out',
        isCurrentlyOutside: false,
        outsideStartTime: null,
        isLoading: false,
        isPunchingOut: false,
        actionSuccessMessage: 'Shift completed on server.',
      );
      await fetchTodayAttendance();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPunchingOut: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// 3. BREAK MANAGEMENT (Start & Stop with Strict 50m Geofence Gate & Cumulative Duration)
  Future<bool> toggleBreak() async {
    if (state.todayWorkingStatus != 'present') {
      state = state.copyWith(
        errorMessage: 'Please Punch In before starting a break.',
      );
      return false;
    }

    if (state.lunchStatus == 'ongoing') {
      state = state.copyWith(
        errorMessage: 'Cannot start a Break while Tiffin Time is active.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      isBreakLoading: true,
      errorMessage: null,
      actionSuccessMessage: null,
    );

    try {
      final actionName = state.isOnBreak ? 'end your break' : 'start your break';
      final allowed = await verifyOfficeProximity(actionName: actionName);
      if (!allowed) {
        state = state.copyWith(
          isLoading: false,
          isBreakLoading: false,
        );
        return false;
      }

      final empId = await _getEmpId();
      final secure = await _getSecureKey();
      final trustedNow = state.trustedCurrentTime;
      final dateStr = DateFormat('yyyy-MM-dd').format(trustedNow);
      final timeStr = DateFormat('HH:mm:ss').format(trustedNow);

      if (state.isOnBreak) {
        // Break Out
        await repository.breakOutWithParams(
          breakDate: dateStr,
          breakOutTime: timeStr,
          empId: empId,
          secure: secure,
        );

        // Add active break session duration to cumulative total
        final sessionDuration = state.attendance.breakInTime != null
            ? trustedNow.difference(state.attendance.breakInTime!)
            : Duration.zero;

        final newBreakTotal = state.attendance.totalBreakDuration + sessionDuration;

        final newAttendance = state.attendance.copyWith(
          breakOutTime: trustedNow,
          breakStatus: 'complete',
          totalBreakDuration: newBreakTotal,
        );

        state = state.copyWith(
          attendance: newAttendance,
          breakStatus: 'complete',
          isLoading: false,
          isBreakLoading: false,
          actionSuccessMessage: 'Short break ended. Back to work!',
        );
        _startOutsideTrackingTimer();
        unawaited(evaluateOutsideOfficeTracking().catchError((_) {}));
      } else {
        // Break In
        _stopOutsideTrackingTimer();
        await repository.breakInWithParams(
          breakDate: dateStr,
          breakInTime: timeStr,
          empId: empId,
          secure: secure,
        );

        final newAttendance = state.attendance.copyWith(
          breakInTime: trustedNow,
          breakStatus: 'ongoing',
        );

        state = state.copyWith(
          attendance: newAttendance,
          breakStatus: 'ongoing',
          isLoading: false,
          isBreakLoading: false,
          actionSuccessMessage: 'Short break started.',
        );
      }

      await refreshDailyActivity();
      return true;
    } on ConflictException {
      state = state.copyWith(
        isLoading: false,
        isBreakLoading: false,
      );
      await fetchTodayAttendance();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isBreakLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// 4. LUNCH / TIFFIN MANAGEMENT (Single Daily Session with Strict 50m Geofence Gate)
  Future<bool> toggleTiffin() async {
    if (state.todayWorkingStatus != 'present') {
      state = state.copyWith(
        errorMessage: 'Please Punch In before starting Tiffin Time.',
      );
      return false;
    }

    if (state.breakStatus == 'ongoing') {
      state = state.copyWith(
        errorMessage: 'Cannot start Tiffin Time while a General Break is active.',
      );
      return false;
    }

    if (state.lunchStatus == 'complete') {
      state = state.copyWith(
        errorMessage: 'Today\'s Tiffin is already completed for this shift.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      isLunchLoading: true,
      errorMessage: null,
      actionSuccessMessage: null,
    );

    try {
      final actionName = state.isOnTiffin ? 'end tiffin' : 'start tiffin';
      final allowed = await verifyOfficeProximity(actionName: actionName);
      if (!allowed) {
        state = state.copyWith(
          isLoading: false,
          isLunchLoading: false,
        );
        return false;
      }

      final empId = await _getEmpId();
      final secure = await _getSecureKey();
      final trustedNow = state.trustedCurrentTime;
      final dateStr = DateFormat('yyyy-MM-dd').format(trustedNow);
      final timeStr = DateFormat('HH:mm:ss').format(trustedNow);

      if (state.isOnTiffin) {
        // Lunch Out -> permanently sets lunchStatus = 'complete'
        await repository.lunchOutWithParams(
          todayDate: dateStr,
          lunchOutTime: timeStr,
          empId: empId,
          secure: secure,
        );

        final sessionDuration = state.attendance.lunchInTime != null
            ? trustedNow.difference(state.attendance.lunchInTime!)
            : Duration.zero;

        final newLunchTotal = state.attendance.totalLunchDuration + sessionDuration;

        final newAttendance = state.attendance.copyWith(
          lunchOutTime: trustedNow,
          lunchStatus: 'complete',
          totalLunchDuration: newLunchTotal,
        );

        state = state.copyWith(
          attendance: newAttendance,
          lunchStatus: 'complete',
          isLoading: false,
          isLunchLoading: false,
          actionSuccessMessage: 'Tiffin break ended. Refreshed and ready!',
        );
        _startOutsideTrackingTimer();
        unawaited(evaluateOutsideOfficeTracking().catchError((_) {}));
      } else {
        // Lunch In
        _stopOutsideTrackingTimer();
        await repository.lunchInWithParams(
          todayDate: dateStr,
          lunchInTime: timeStr,
          empId: empId,
          secure: secure,
        );

        final newAttendance = state.attendance.copyWith(
          lunchInTime: trustedNow,
          lunchStatus: 'ongoing',
        );

        state = state.copyWith(
          attendance: newAttendance,
          lunchStatus: 'ongoing',
          isLoading: false,
          isLunchLoading: false,
          actionSuccessMessage: 'Tiffin break started. Enjoy your meal!',
        );
      }

      await refreshDailyActivity();
      return true;
    } on ConflictException {
      state = state.copyWith(
        isLoading: false,
        isLunchLoading: false,
      );
      await fetchTodayAttendance();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLunchLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final attendanceNotifierProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final repository = ref.watch(attendanceRepositoryProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AttendanceNotifier(
    repository: repository,
    storageService: storageService,
  );
});
