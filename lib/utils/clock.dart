import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" for the whole app. Opening hours, pickup slots (BR-07) and
/// payment timers read the time from here, so tests can fix it:
/// `clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 10, 12))`.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
