import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  AppToast._();

  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _showToast(
      context,
      type: ToastType.success,
      message: message,
      title: title ?? 'Success',
      icon: Icons.check_circle_rounded,
      accentColor: const Color(0xFF10B981),
      bgColor: const Color(0xFF064E3B),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _showToast(
      context,
      type: ToastType.error,
      message: message,
      title: title ?? 'Error',
      icon: Icons.error_rounded,
      accentColor: const Color(0xFFEF4444),
      bgColor: const Color(0xFF450A0A),
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _showToast(
      context,
      type: ToastType.warning,
      message: message,
      title: title ?? 'Notice',
      icon: Icons.warning_amber_rounded,
      accentColor: const Color(0xFFF59E0B),
      bgColor: const Color(0xFF451A03),
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _showToast(
      context,
      type: ToastType.info,
      message: message,
      title: title ?? 'Info',
      icon: Icons.info_rounded,
      accentColor: AppColors.brandBlue,
      bgColor: const Color(0xFF082F49),
    );
  }

  static void _showToast(
    BuildContext context, {
    required ToastType type,
    required String message,
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  try {
                    messenger.hideCurrentSnackBar();
                  } catch (_) {}
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
