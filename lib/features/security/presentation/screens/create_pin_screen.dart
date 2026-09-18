import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:local_auth/local_auth.dart';

/// Screen where first-time logged-in users enter and confirm a 4-digit PIN.
/// Once successfully created, the hash is saved via [securityNotifierProvider]
/// and the user is redirected to Biometric Setup.
class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _firstPin = '';
  String _currentPin = '';
  bool _isConfirming = false;
  bool _isPinConfirmed = false;
  bool _hasError = false;
  final int _maxPinLength = 4;
  
  bool _isHardwareSupported = false;
  bool _biometricEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final bios = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _isHardwareSupported = (canCheck && isSupported) || bios.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  void _onNumberPressed(String digit) {
    if (_currentPin.length < _maxPinLength) {
      setState(() {
        _hasError = false;
        _currentPin += digit;
      });

      if (_currentPin.length == _maxPinLength) {
        if (!_isConfirming) {
          // Move to Confirmation Step
          _proceedToConfirmStep();
        } else {
          // Verify confirmation PIN
          _verifyAndCompletePin();
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  Future<void> _proceedToConfirmStep() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() {
      _firstPin = _currentPin;
      _currentPin = '';
      _isConfirming = true;
    });

    AppToast.showInfo(
      context,
      title: 'Confirm PIN',
      message: 'Please re-enter your 4-digit PIN to confirm.',
    );
  }

  Future<void> _verifyAndCompletePin() async {
    if (_currentPin == _firstPin) {
      // Transition to Step 2 (Biometrics) unconditionally upon PIN match
      setState(() {
        _isPinConfirmed = true;
      });
    } else {
      // PIN mismatch
      setState(() {
        _hasError = true;
      });

      AppToast.showError(
        context,
        title: 'PIN Mismatch',
        message: 'The confirmed PIN does not match. Please re-enter your PIN.',
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _firstPin = '';
        _currentPin = '';
        _isConfirming = false;
        _isPinConfirmed = false;
        _hasError = false;
      });
    }
  }

  Future<void> _saveAndCompleteSetup() async {
    setState(() => _isSaving = true);
    
    // 1. Prompt native Face ID / Touch ID authorization on device
    bool biometricEnrolled = false;
    if (_isHardwareSupported && _biometricEnabled) {
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verify Face ID or Fingerprint to enable Biometric Unlock',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        biometricEnrolled = authenticated;
      } catch (_) {
        biometricEnrolled = false;
      }
    }

    // 2. Save hashed PIN
    await ref.read(securityNotifierProvider.notifier).createAndSavePin(_firstPin);
    
    // 3. Save Biometric Preference (true if user verified with Face ID)
    final storage = ref.read(storageServiceProvider);
    await storage.saveBool('biometric_enabled', biometricEnrolled);
    
    // 4. Mark setup complete
    await ref.read(appStartupProvider.notifier).setPinSetupCompleted();

    if (mounted) {
      if (context.canPop()) {
        AppToast.showSuccess(
          context,
          title: 'PIN Updated',
          message: 'Your 4-digit security PIN has been updated.',
        );
        context.pop();
      } else {
        AppToast.showSuccess(
          context,
          title: 'Security Setup Complete',
          message: 'Your workspace is securely locked.',
        );
        context.go(AppRoutes.securitySuccess);
      }
    }
  }

  void _handleBack() {
    if (_isConfirming && !_isPinConfirmed) {
      setState(() {
        _firstPin = '';
        _currentPin = '';
        _isConfirming = false;
        _hasError = false;
      });
    } else if (_isPinConfirmed) {
      setState(() {
        _currentPin = '';
        _isPinConfirmed = false;
      });
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.sm,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 20,
                    maxWidth: 450,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Section: Header & Instructions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              _isPinConfirmed
                                  ? 'Step 2 of 2 • Biometrics'
                                  : (context.canPop()
                                      ? (_isConfirming ? 'Step 2 of 2 • Confirmation' : 'Security Settings • PIN Update')
                                      : 'Step 1 of 2 • Security Setup'),
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isPinConfirmed
                                ? 'Biometric Unlock'
                                : _isConfirming
                                    ? 'Confirm Your Security PIN'
                                    : (context.canPop() ? 'Update Security PIN' : 'Create a 4-Digit PIN'),
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _isPinConfirmed
                                  ? 'Would you like to enable biometric authentication for faster access?'
                                  : _isConfirming
                                      ? 'Re-enter your 4 digits to confirm.'
                                      : (context.canPop()
                                          ? 'Enter a new 4-digit PIN to update your workspace unlock code.'
                                          : 'Set up a PIN to unlock your MethotX workspace swiftly without typing your password each time.'),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 36),

                          if (!_isPinConfirmed)
                            PinDotsIndicator(
                              pinLength: _currentPin.length,
                              maxPinLength: _maxPinLength,
                              hasError: _hasError,
                            ),
                        ],
                      ),

                      // Middle Section: Visual Biometric Illustration
                      if (_isPinConfirmed)
                        _buildBiometricIllustration(),

                      // Bottom Section: Numeric Keypad
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          if (_isPinConfirmed)
                            _buildFinalSetupStep()
                          else
                            NumericKeypad(
                              onNumberPressed: _onNumberPressed,
                              onBackspacePressed: _onBackspacePressed,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Encrypted with SHA-256 on device keystore',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.outline.withValues(alpha: 0.6),
                            ),
                          ),
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

  Widget _buildFinalSetupStep() {
    return Column(
      children: [
        if (_isHardwareSupported) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: CheckboxListTile(
              value: _biometricEnabled,
              onChanged: (val) {
                setState(() => _biometricEnabled = val ?? false);
              },
              title: Text(
                'Enable Biometric Authentication',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Use fingerprint or face unlock',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              activeColor: AppColors.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 32),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAndCompleteSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Complete Setup',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricIllustration() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryContainer.withValues(alpha: 0.3),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 58,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
