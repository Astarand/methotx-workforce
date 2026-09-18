import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final DateFormat fullDate = DateFormat('dd MMMM yyyy');
  static final DateFormat shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat monthYear = DateFormat('MMMM yyyy');
  static final DateFormat dayDate = DateFormat('EEEE, dd MMMM yyyy');
  static final DateFormat time12Hour = DateFormat('hh:mm a');
  static final DateFormat time24Hour = DateFormat('HH:mm');

  static String formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatSimpleDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Converts any 24-hour, ISO, or time string (e.g. "13:39:54", "20:54:14", "09:30")
  /// into clean, standard 12-hour format with AM/PM (e.g. "01:39 PM", "08:54 PM", "09:30 AM").
  static String formatTime12Hour(String? rawTime) {
    if (rawTime == null || rawTime.trim().isEmpty || rawTime.trim() == 'null') {
      return 'Not recorded';
    }
    final clean = rawTime.trim();

    // Preserve standard system status labels / placeholders
    if (clean == 'Not recorded' ||
        clean == 'Not arrived yet' ||
        clean == 'Office Holiday' ||
        clean == 'Weekend Off' ||
        clean == 'Active Shift' ||
        clean == 'Punched Out' ||
        clean == 'Not checked in' ||
        clean == 'Not checked out' ||
        clean == '--:-- --') {
      return clean;
    }

    // If already 12-hour format with AM/PM
    if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
      try {
        final parsed = DateFormat('h:mm:ss a').parse(clean.toUpperCase());
        return time12Hour.format(parsed);
      } catch (_) {
        try {
          final parsed = DateFormat('h:mm a').parse(clean.toUpperCase());
          return time12Hour.format(parsed);
        } catch (_) {
          return clean;
        }
      }
    }

    // Try parsing ISO or DateTime string
    try {
      final dt = DateTime.tryParse(clean);
      if (dt != null) {
        return time12Hour.format(dt);
      }
    } catch (_) {}

    // Try parsing 24-hour time "HH:mm:ss" or "HH:mm"
    try {
      final parsed = DateFormat('HH:mm:ss').parse(clean);
      return time12Hour.format(parsed);
    } catch (_) {
      try {
        final parsed = DateFormat('HH:mm').parse(clean);
        return time12Hour.format(parsed);
      } catch (_) {
        try {
          final parsed = DateFormat('H:m:s').parse(clean);
          return time12Hour.format(parsed);
        } catch (_) {
          try {
            final parsed = DateFormat('H:m').parse(clean);
            return time12Hour.format(parsed);
          } catch (_) {}
        }
      }
    }

    return clean;
  }

  /// Converts raw late duration strings (e.g. "04:09", "04:09:00", "4h 9m")
  /// into user-friendly readable format: "4 hours 9 minutes", "9 minutes", "1 hour", etc.
  static String formatLateDuration(String? rawLateBy) {
    if (rawLateBy == null || rawLateBy.trim().isEmpty || rawLateBy.trim() == 'null') {
      return '';
    }
    var clean = rawLateBy.trim();
    if (clean.toLowerCase().startsWith('late by')) {
      clean = clean.substring(7).trim();
    }

    // Already user-friendly
    if (clean.contains('hour') || clean.contains('minute')) {
      return clean;
    }

    // Format like "4h 9m" or "4h" or "9m"
    if (clean.contains('h') || clean.contains('m')) {
      final hMatch = RegExp(r'(\d+)\s*h').firstMatch(clean);
      final mMatch = RegExp(r'(\d+)\s*m').firstMatch(clean);
      final h = hMatch != null ? int.tryParse(hMatch.group(1)!) ?? 0 : 0;
      final m = mMatch != null ? int.tryParse(mMatch.group(1)!) ?? 0 : 0;
      if (h > 0 && m > 0) {
        final hUnit = h == 1 ? 'hour' : 'hours';
        final mUnit = m == 1 ? 'minute' : 'minutes';
        return '$h $hUnit $m $mUnit';
      } else if (h > 0) {
        final hUnit = h == 1 ? 'hour' : 'hours';
        return '$h $hUnit';
      } else if (m > 0) {
        final mUnit = m == 1 ? 'minute' : 'minutes';
        return '$m $mUnit';
      }
    }

    // Parse "04:09" or "04:09:00" or "4:9"
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;

      if (hours > 0 && minutes > 0) {
        final hUnit = hours == 1 ? 'hour' : 'hours';
        final mUnit = minutes == 1 ? 'minute' : 'minutes';
        return '$hours $hUnit $minutes $mUnit';
      } else if (hours > 0) {
        final hUnit = hours == 1 ? 'hour' : 'hours';
        return '$hours $hUnit';
      } else if (minutes > 0) {
        final mUnit = minutes == 1 ? 'minute' : 'minutes';
        return '$minutes $mUnit';
      }
    }

    // Single number (interpreted as minutes)
    final singleNum = int.tryParse(clean);
    if (singleNum != null && singleNum > 0) {
      return '$singleNum ${singleNum == 1 ? 'minute' : 'minutes'}';
    }

    return clean;
  }
}
