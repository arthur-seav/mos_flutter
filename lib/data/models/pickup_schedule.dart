import 'package:flutter/foundation.dart' show immutable;

import 'store_info.dart';

/// Today's pickup choices for a store at a given moment (FR-11, BR-07).
///
/// BR-07: a scheduled slot must be at least `min_prep_min` after now,
/// within opening hours, and no later than 60 minutes before closing.
/// The backend checks the same rule when the order is placed.
///
/// Deviation from SA 2.0 (Arthur, 2026-10-29): the demo store uses a
/// 5-minute lead time instead of 30 (README: Deviations).
@immutable
class PickupSchedule {
  const PickupSchedule({required this.store, required this.now});

  final StoreInfo store;
  final DateTime now;

  /// BR-07: the last slot is this long before closing.
  static const lastSlotBeforeClose = Duration(minutes: 60);

  DayHours get _today => store.hoursOn(now);

  DateTime _at(int minuteOfDay) => DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(minutes: minuteOfDay));

  DateTime? get opensAt => _today.isOpenDay ? _at(_today.openMinute!) : null;
  DateTime? get closesAt => _today.isOpenDay ? _at(_today.closeMinute!) : null;

  bool get isOpenNow {
    final open = opensAt, close = closesAt;
    return open != null &&
        close != null &&
        !now.isBefore(open) &&
        now.isBefore(close);
  }

  /// "As soon as possible": the store is open and the drink can be ready
  /// before it closes.
  bool get canPickUpAsap =>
      isOpenNow &&
      now
          .add(Duration(minutes: store.settings.asapPrepMin))
          .isBefore(closesAt!);

  DateTime get earliestSlot =>
      now.add(Duration(minutes: store.settings.minPrepMin));

  DateTime? get latestSlot => closesAt?.subtract(lastSlotBeforeClose);

  /// BR-07 for one time.
  bool allows(DateTime time) {
    final open = opensAt, latest = latestSlot;
    if (open == null || latest == null) return false;
    return !time.isBefore(earliestSlot) &&
        !time.isBefore(open) &&
        !time.isAfter(latest);
  }

  /// At most this many times are offered.
  static const slotCount = 6;

  /// The next [slotCount] pickup times: the first at least `min_prep_min`
  /// from now, rounded up to a 5-minute mark (10:41 + 5 -> 10:50), then
  /// every `slot_interval_min` (11:00, 11:10, ...). None before opening
  /// or after [latestSlot], so late in the day there may be fewer.
  List<DateTime> get slots {
    final open = opensAt, latest = latestSlot;
    if (open == null || latest == null) return const [];
    var t = _roundUpTo5(earliestSlot);
    if (t.isBefore(open)) t = open;
    final step = Duration(minutes: store.settings.slotIntervalMin);
    final result = <DateTime>[];
    while (result.length < slotCount && !t.isAfter(latest)) {
      result.add(t);
      t = t.add(step);
    }
    return result;
  }

  static DateTime _roundUpTo5(DateTime t) {
    var m = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    if (m.isBefore(t)) m = m.add(const Duration(minutes: 1)); // 10:46:30
    return m.add(Duration(minutes: (5 - m.minute % 5) % 5));
  }

  bool get canSchedule => slots.isNotEmpty;
}
