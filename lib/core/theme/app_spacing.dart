import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double marginMobile = 20.0;
  static const double gutterMobile = 16.0;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: marginMobile,
    vertical: md,
  );

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(
    marginMobile,
    md,
    marginMobile,
    100.0, // generous bottom padding to prevent bottom navigation overlap
  );
}

class AppRadius {
  AppRadius._();

  static const double sm = 4.0;
  static const double regular = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius regularRadius = BorderRadius.all(Radius.circular(regular));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullRadius = BorderRadius.all(Radius.circular(full));
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color.fromRGBO(22, 126, 149, 0.05),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color.fromRGBO(22, 126, 149, 0.08),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color.fromRGBO(22, 126, 149, 0.12),
      offset: Offset(0, 10),
      blurRadius: 30,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      offset: Offset(0, -4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
}
