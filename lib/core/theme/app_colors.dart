import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Primaries (#0A86C6 Signature Brand Blue Spectrum)
  static const Color brandBlue = Color(0xFF0A86C6);
  static const Color brandBlueDark = Color(0xFF076B9E);
  static const Color brandBlueLight = Color(0xFF249CE2);
  static const Color brandBlueSoft = Color(0xFF5CB8EE);
  static const Color brandBluePale = Color(0xFFBAE3FA);
  static const Color brandBlueUltralight = Color(0xFFE6F5FD);

  static const Color primary = Color(0xFF0A86C6);
  static const Color primaryContainer = Color(0xFF076B9E);
  static const Color primaryFixed = Color(0xFFBAE3FA);
  static const Color primaryFixedDim = Color(0xFF7AC9F4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFF2F9FD);
  static const Color softTeal = Color(0xFF249CE2); // replaced with brandBlueLight

  // Secondary & Accents
  static const Color secondary = Color(0xFF0875AC);
  static const Color secondaryContainer = Color(0xFFBAE3FA);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF054C71);
  static const Color secondaryFixed = Color(0xFFBAE3FA);
  static const Color secondaryFixedDim = Color(0xFF7AC9F4);

  // Tertiary
  static const Color tertiary = Color(0xFF515D5F);
  static const Color tertiaryContainer = Color(0xFF697678);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFF2FDFF);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Color(0xFFF9F9FC);
  static const Color surfaceDim = Color(0xFFDADADC);
  static const Color surfaceBright = Color(0xFFF9F9FC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F6);
  static const Color surfaceContainer = Color(0xFFEEEEE0);
  static const Color surfaceContainerHigh = Color(0xFFE8E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E5);

  // Typography & Neutrals
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF3E484C);
  static const Color onBackground = Color(0xFF1A1C1E);
  static const Color outline = Color(0xFF6F797C);
  static const Color outlineVariant = Color(0xFFBEC8CC);

  // Dark Mode Surfaces & Backgrounds (Slate Spectrum)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceDim = Color(0xFF0B1120);
  static const Color darkSurfaceBright = Color(0xFF334155);
  static const Color darkSurfaceContainerLowest = Color(0xFF161F30);
  static const Color darkSurfaceContainerLow = Color(0xFF1E293B);
  static const Color darkSurfaceContainer = Color(0xFF243042);
  static const Color darkSurfaceContainerHigh = Color(0xFF334155);
  static const Color darkSurfaceContainerHighest = Color(0xFF475569);

  // Dark Mode Typography & Neutrals
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOnBackground = Color(0xFFF8FAFC);
  static const Color darkOutline = Color(0xFF64748B);
  static const Color darkOutlineVariant = Color(0xFF334155);

  // Semantics: Success
  static const Color success = Color(0xFF137333);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF166534);

  // Semantics: Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFFFFFFFF);

  // Semantics: Warning & Holidays
  static const Color warning = Color(0xFFE37400);
  static const Color warningContainer = Color(0xFFFEF7E0);
  static const Color onWarningContainer = Color(0xFF8A3B00);

  static const Color holidayBlue = Color(0xFF0A86C6);
  static const Color holidayContainer = Color(0xFFE6F5FD);

  static const Color offGray = Color(0xFF5F6368);
  static const Color offContainer = Color(0xFFF1F3F4);

  // Gradient Tokens
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static const LinearGradient swipeTrackGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandBlueLight, primary],
  );
}
