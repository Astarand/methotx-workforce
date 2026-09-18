import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../routes/app_routes.dart';
import '../../../../routes/app_startup_notifier.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../controllers/security_notifier.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/pin_dots_indicator.dart';

/// The gatekeeper unlock screen for returning users.
///
/// Features:
/// - Auto-triggers native OS biometric prompt when hardware is supported and enabled.
/// - Full fallback to on-screen numeric keypad for 4-digit PIN entry.
/// - Clears lockout and background keys on successful authentication.
/// - Restores system UI overlays and routes to [AppRoutes.dashboard].
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String _pin = '';
  final int _maxPinLength = 4;
  bool _hasError = false;
  String? _errorMessage;
  bool _isAuthenticating = false;
  bool _isHardwareReady = false;
  bool _isBiometricEnabled = false;
  bool _hasUserCancelledBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoTriggerBiometrics();
    });
  }

  /// 1. Hardware & Preference Check + Auto-Trigger
  Future<void> _checkAndAutoTriggerBiometrics() async {
    if (_hasUserCancelledBiometrics) return;
    try {
      final security = ref.read(securityServiceProvider);
      final storage = ref.read(storageServiceProvider);

      final isHardwareReady = await security.isBiometricsAvailable();
      final isBiometricEnabled = await storage.getBool('biometric_enabled') ?? false;

      if (mounted) {
        setState(() {
          _isHardwareReady = isHardwareReady;
          _isBiometricEnabled = isBiometricEnabled;
        });
      }

      // Auto-trigger if both hardware readiness and preference are true
      if (isHardwareReady && isBiometricEnabled && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_hasUserCancelledBiometrics) {
          await _triggerNativeBiometrics();
        }
      }
    } catch (_) {
      // Gracefully fall back to keypad if check errors
    }
  }

  /// 2. Native OS Prompt
  Future<void> _triggerNativeBiometrics() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final security = ref.read(securityServiceProvider);
      final authenticated = await security.authenticateWithBiometrics(
        reason: 'Authenticate to unlock MethotX',
      );

      if (!mounted) return;

      if (authenticated) {
        // 3. Success Handler
        await _handleUnlockSuccess();
      } else {
        // 4. Failure Handler
        _handleBiometricFailure();
      }
    } on PlatformException catch (_) {
      if (mounted) _handleBiometricFailure();
    } catch (_) {
      if (mounted) _handleBiometricFailure();
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  /// Success Handler: cleans SharedPreferences, clears lock state, restores UI, routes to dashboard
  Future<void> _handleUnlockSuccess() async {
    final storage = ref.read(storageServiceProvider);
    final appStartupNotifier = ref.read(appStartupProvider.notifier);
    final securityNotifier = ref.read(securityNotifierProvider.notifier);
    final pendingUri = ref.read(appStartupProvider).pendingRedirectUri;

    await storage.remove('pin_attempt_count');
    await storage.remove('app_was_backgrounded');
    await storage.remove('app_paused_time');

    // Restore system UI overlays
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Call providers to clear lock state
    await securityNotifier.clearPinRequired();
    await appStartupNotifier.unlockApp();
    appStartupNotifier.clearPendingRedirectUri();

    if (mounted) {
      HapticFeedback.lightImpact();
      if (pendingUri != null &&
          pendingUri.isNotEmpty &&
          pendingUri != AppRoutes.dashboard &&
          pendingUri != AppRoutes.pinUnlock &&
          pendingUri != AppRoutes.unlock) {
        context.go(pendingUri);
      } else {
        context.go(AppRoutes.dashboard);
      }
    }
  }

  /// Failure Handler: shows error banner and falls back to numeric keypad
  void _handleBiometricFailure() {
    _hasUserCancelledBiometrics = true;
    setState(() {
      _hasError = true;
      _errorMessage = 'Authentication failed. Use PIN instead.';
      _pin = '';
    });
    HapticFeedback.vibrate();
    AppToast.showError(
      context,
      title: 'Biometrics Failed',
      message: 'Authentication failed. Use PIN instead.',
    );
  }

  void _onNumberPressed(String digit) {
    final securityState = ref.read(securityNotifierProvider);
    if (securityState.isLockedOut) {
      AppToast.showError(
        context,
        title: 'Account Locked',
        message: 'Too many failed PIN attempts. Please contact HR or IT support.',
      );
      return;
    }

    if (_pin.length < _maxPinLength) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _pin += digit;
      });

      if (_pin.length == _maxPinLength) {
        _handleVerifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  /// Verifies entered PIN through SecurityNotifier (SHA-256 verification)
  Future<void> _handleVerifyPin() async {
    final securityNotifier = ref.read(securityNotifierProvider.notifier);
    final isValid = await securityNotifier.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      await _handleUnlockSuccess();
    } else {
      HapticFeedback.vibrate();
      final currentAttempts =
          ref.read(securityNotifierProvider).failedAttempts;
      setState(() {
        _hasError = true;
        _errorMessage =
            'Invalid security PIN. Attempt $currentAttempts of ${SecurityNotifier.maxPinAttempts}.';
        _pin = '';
      });

      if (!mounted) return;

      AppToast.showError(
        context,
        title: 'Incorrect PIN',
        message:
            'Invalid security PIN. Attempt $currentAttempts of ${SecurityNotifier.maxPinAttempts}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(securityNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                    maxWidth: 450,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Section: Workspace Lock Icon & Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Unlock Workspace',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your 4-digit PIN to continue',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // PIN Indicator Dots
                          PinDotsIndicator(
                            pinLength: _pin.length,
                            maxPinLength: _maxPinLength,
                            hasError: _hasError,
                          ),

                          // Visible Error / Failure Message Banner
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onErrorContainer,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Middle Section: Lockout Warning Banner (if applicable)
                      if (securityState.isLockedOut)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account locked due to consecutive failed attempts.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.onErrorContainer,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Bottom Section: Numeric Keypad with Biometric Fallback Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          NumericKeypad(
                            onNumberPressed: _onNumberPressed,
                            onBackspacePressed: _onBackspacePressed,
                            extraAction: (_isHardwareReady && _isBiometricEnabled)
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 32,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'Unlock with Biometrics',
                                    onPressed: securityState.isLockedOut ||
                                            _isAuthenticating
                                        ? null
                                        : _triggerNativeBiometrics,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 20),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
