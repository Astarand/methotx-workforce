import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import 'app_startup_notifier.dart';
import 'main_shell_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/permissions/presentation/screens/permissions_screen.dart';
import '../features/authentication/presentation/screens/login_page.dart';
import '../features/security/presentation/screens/create_pin_screen.dart';
import '../features/security/presentation/screens/security_success_screen.dart';
import '../features/security/presentation/screens/pin_unlock_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/attendance/presentation/screens/attendance_history_screen.dart';
import '../features/tasks/presentation/screens/task_management_screen.dart';
import '../features/payslip/presentation/screens/generate_payslip_screen.dart';
import '../features/leave/presentation/screens/leave_management_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/notifications/presentation/screens/notification_list_screen.dart';
import '../features/payslip/presentation/screens/payslip_pdf_viewer_screen.dart';
import '../features/hr_letter/presentation/screens/hr_letter_list_screen.dart';
import '../features/hr_letter/presentation/screens/hr_letter_view_screen.dart';
import '../features/hr_letter/domain/entities/hr_letter_entity.dart';
import '../features/performance/presentation/screens/performance_review_list_screen.dart';
import '../features/performance/presentation/screens/performance_review_details_screen.dart';
import '../features/performance/domain/entities/performance_review_entity.dart';
import '../features/claims/presentation/screens/claims_list_screen.dart';
import '../features/claims/presentation/screens/claim_details_screen.dart';
import '../features/claims/presentation/screens/apply_claim_screen.dart';
import '../features/claims/domain/entities/claim_entity.dart';
import '../features/supply/presentation/screens/supply_list_screen.dart';
import '../features/supply/presentation/screens/supply_details_screen.dart';
import '../features/supply/presentation/screens/apply_supply_screen.dart';
import '../features/supply/domain/entities/supply_entity.dart';

/// Bridges Riverpod's AppStartupState directly to GoRouter's refreshListenable
class AppRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  AppRouterNotifier(this._ref) {
    // Re-evaluate routes immediately when AppStartupState changes
    _ref.listen<AppStartupState>(
      appStartupProvider,
      (_, _) => notifyListeners(),
    );
  }

  /// GoRouter redirect callback
  String? redirect(BuildContext context, GoRouterState state) {
    final startupState = _ref.read(appStartupProvider);
    final location = state.matchedLocation;

    // If app is locked and user is navigating to an authenticated destination (e.g. from push notification),
    // record target location so they are smoothly restored after unlocking with PIN or Biometrics.
    if (startupState.isAppLocked &&
        location != AppRoutes.pinUnlock &&
        location != AppRoutes.unlock &&
        location != AppRoutes.splash &&
        location != AppRoutes.login &&
        location != AppRoutes.onboarding &&
        location != AppRoutes.permissions &&
        location != AppRoutes.createPin &&
        location != AppRoutes.changePin &&
        location != AppRoutes.securitySuccess) {
      _ref.read(appStartupProvider.notifier).setPendingRedirectUri(location);
    }

    return evaluateRedirect(
      location: location,
      state: startupState,
    );
  }

  /// Strictly enforces this exact sequence:
  /// 1. Splash Screen (during cold boot initialization)
  /// 2. Permissions Screen (if !hasGrantedPermissions)
  /// 3. Login Page (if !isLoggedIn)
  /// 4. Create PIN -> Confirm PIN -> Biometric Setup (if isLoggedIn && !hasPinSetup)
  /// 5. Unlock Screen (if app is locked)
  /// 6. Dashboard (if all above are true and app is not locked)
  String? evaluateRedirect({
    required String location,
    required AppStartupState state,
  }) {
    return staticEvaluateRedirect(location: location, state: state);
  }

  static String? staticEvaluateRedirect({
    required String location,
    required AppStartupState state,
  }) {
    // 1. Splash Screen (during cold boot initialization)
    if (state.isInitializing) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    // 2. 3 Introduction Screens (if !hasCompletedOnboarding)
    if (!state.hasCompletedOnboarding) {
      return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }

    // 3. Permissions Screen (if !hasGrantedPermissions)
    if (!state.hasGrantedPermissions) {
      return location == AppRoutes.permissions ? null : AppRoutes.permissions;
    }

    // 4. If !isLoggedIn ➡️ return /login
    if (!state.isLoggedIn) {
      return location == AppRoutes.login ? null : AppRoutes.login;
    }

    // 5. If !hasPinSetup ➡️ return /create-pin
    if (!state.hasPinSetup) {
      final isSecuritySuccess = location == AppRoutes.securitySuccess;
      return isSecuritySuccess ? null : AppRoutes.createPin;
    }

    // 5. If hasPinSetup && isLoggedIn && isAppLocked ➡️ return /pin-unlock
    if (state.isAppLocked) {
      final isUnlockLocation =
          location == AppRoutes.pinUnlock || location == AppRoutes.unlock;
      return isUnlockLocation ? null : AppRoutes.pinUnlock;
    }

    // Allow user to finish security setup flow or security success screen if they are currently on it
    if (location == AppRoutes.securitySuccess || location == AppRoutes.createPin) {
      return null;
    }

    // 6. Fallback / Success ➡️ return /dashboard
    final isIntroOrAuthRoute = location == AppRoutes.splash ||
        location == AppRoutes.onboarding ||
        location == AppRoutes.permissions ||
        location == AppRoutes.login ||
        location == AppRoutes.createPin ||
        location == AppRoutes.pinUnlock ||
        location == AppRoutes.unlock;

    if (isIntroOrAuthRoute) {
      final pending = state.pendingRedirectUri;
      if (pending != null &&
          pending.isNotEmpty &&
          pending != AppRoutes.dashboard &&
          pending != AppRoutes.pinUnlock &&
          pending != AppRoutes.unlock) {
        return pending;
      }
      return AppRoutes.dashboard;
    }

    // Allow navigation to intended destination (e.g. /tasks, /payslip, /attendance-history)
    return null;
  }
}

final routerNotifierProvider = ChangeNotifierProvider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // 1. Onboarding Screen
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 2. Permissions Screen
      GoRoute(
        path: AppRoutes.permissions,
        builder: (context, state) => const PermissionsScreen(),
      ),

      // 3. Authentication Flow
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      // 4. PIN & Biometrics Security Setup Flow
      GoRoute(
        path: AppRoutes.createPin,
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePin,
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: AppRoutes.securitySuccess,
        builder: (context, state) => const SecuritySuccessScreen(),
      ),

      // 5. PIN & Biometric Unlock Screens
      GoRoute(
        path: AppRoutes.pinUnlock,
        builder: (context, state) => const PinUnlockScreen(),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        builder: (context, state) => const PinUnlockScreen(),
      ),

      // Standalone Notification List Screen
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationListScreen(),
      ),

      // Standalone Fullscreen Payslip PDF Viewer
      GoRoute(
        path: AppRoutes.payslipPdfViewer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final filePath = extra?['filePath'] as String? ?? '';
          final title = extra?['title'] as String?;
          return PayslipPdfViewerScreen(
            filePath: filePath,
            title: title,
          );
        },
      ),

      // Standalone Fullscreen HR Letter Details View Screen
      GoRoute(
        path: AppRoutes.hrLetterView,
        builder: (context, state) {
          final letter = state.extra as HrLetterEntity;
          return HrLetterViewScreen(letter: letter);
        },
      ),

      // Standalone Fullscreen Performance Review Details Screen
      GoRoute(
        path: AppRoutes.performanceDetails,
        builder: (context, state) {
          final review = state.extra as PerformanceReviewEntity;
          return PerformanceReviewDetailsScreen(review: review);
        },
      ),

      // Standalone Fullscreen Claim Details Screen
      GoRoute(
        path: AppRoutes.claimDetails,
        builder: (context, state) {
          final claim = state.extra as ClaimEntity;
          return ClaimDetailsScreen(claim: claim);
        },
      ),

      // Standalone Fullscreen Apply Claim Screen
      GoRoute(
        path: AppRoutes.applyClaim,
        builder: (context, state) => const ApplyClaimScreen(),
      ),

      // Standalone Fullscreen Requisition Details Screen
      GoRoute(
        path: AppRoutes.requisitionDetails,
        builder: (context, state) {
          final requisition = state.extra as SupplyEntity;
          return SupplyDetailsScreen(requisition: requisition);
        },
      ),

      // Standalone Fullscreen Apply Requisition Screen
      GoRoute(
        path: AppRoutes.applyRequisition,
        builder: (context, state) => const ApplySupplyScreen(),
      ),

      // Main App Shell (Dashboard & Navigation Tabs)
      ShellRoute(
        builder: (context, state, child) {
          return MainShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.attendanceHistory,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AttendanceHistoryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TaskManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.payslip,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GeneratePayslipScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.leave,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaveManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrLetter,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HrLetterListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.performance,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PerformanceReviewListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.claims,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClaimsListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.requisitions,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SupplyListScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
