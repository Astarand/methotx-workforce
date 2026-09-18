import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An isolated StreamProvider that emits the current time every second.
/// This prevents the entire dashboard from rebuilding every second.
/// Localized UI components (like the digital clock or active working hours)
/// should watch this provider directly.
final clockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
