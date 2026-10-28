import 'package:flutter/foundation.dart' show immutable;

import 'store_info.dart';

/// One time on the "Schedule pickup" panel.
@immutable
class PickupSlot {
  const PickupSlot(this.time, {required this.isAvailable});

  final DateTime time;

  /// False = too soon (less than `min_prep_min` from now). Shown faded.
  final bool isAvailable;
}

/// Today's pickup choices for a store at a given moment (FR-11, BR-07).
///
/// BR-07: a scheduled slot must be at least `min_prep_min` after now,
/// within opening hours, and no later than 60 minutes before closing.
/// The backend checks the same rule when the order is placed.
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

  /// The rest of today's slots, every `slot_interval_min` from opening
  /// time: from the first one after now up to [latestSlot]. Those that are
  /// too soon are included but not available (Figma: faded 10:30 AM).
  List<PickupSlot> get slots {
    final open = opensAt, latest = latestSlot;
    if (open == null || latest == null) return const [];
    final step = Duration(minutes: store.settings.slotIntervalMin);
    final result = <PickupSlot>[];
    for (var t = open; !t.isAfter(latest); t = t.add(step)) {
      if (t.isBefore(now)) continue;
      result.add(PickupSlot(t, isAvailable: allows(t)));
    }
    return result;
  }

  bool get canSchedule => slots.any((s) => s.isAvailable);
}
