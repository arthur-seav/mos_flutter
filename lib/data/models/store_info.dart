import 'package:flutter/foundation.dart' show immutable;

/// Store-wide settings (data dictionary: `store_settings`; FR-36, FR-40).
@immutable
class StoreSettings {
  const StoreSettings({
    required this.storeName,
    required this.address,
    required this.phone,
    this.slotIntervalMin = 15,
    this.minPrepMin = 30,
    this.pickupTimeoutMin = 30,
    this.asapPrepMin = 10,
    this.onlineOrderingOpen = true,
  });

  final String storeName;
  final String address;
  final String phone;

  /// Minutes between pickup slots.
  final int slotIntervalMin;

  /// BR-07: shortest lead time for a scheduled pickup.
  final int minPrepMin;

  /// Minutes in "Ready" before staff complete the order (BR-12).
  final int pickupTimeoutMin;

  /// "Ready in about 10 min" for ASAP orders. Not in the data dictionary
  /// yet (README: Open questions).
  final int asapPrepMin;

  /// False = staff paused online ordering (FR-41, TC-20).
  final bool onlineOrderingOpen;

  StoreSettings copyWith({bool? onlineOrderingOpen}) => StoreSettings(
    storeName: storeName,
    address: address,
    phone: phone,
    slotIntervalMin: slotIntervalMin,
    minPrepMin: minPrepMin,
    pickupTimeoutMin: pickupTimeoutMin,
    asapPrepMin: asapPrepMin,
    onlineOrderingOpen: onlineOrderingOpen ?? this.onlineOrderingOpen,
  );
}

/// Opening hours for one day of the week (data dictionary:
/// `opening_hours`; FR-37). Times are minutes after midnight.
@immutable
class DayHours {
  const DayHours({
    required this.dayOfWeek,
    this.openMinute,
    this.closeMinute,
    this.isClosed = false,
  });

  /// "09:00-21:00"
  const DayHours.between(this.dayOfWeek, int openHour, int closeHour)
    : openMinute = openHour * 60,
      closeMinute = closeHour * 60,
      isClosed = false;

  const DayHours.closed(this.dayOfWeek)
    : openMinute = null,
      closeMinute = null,
      isClosed = true;

  /// 0 = Sunday to 6 = Saturday, as in the data dictionary.
  final int dayOfWeek;
  final int? openMinute;
  final int? closeMinute;
  final bool isClosed;

  bool get isOpenDay => !isClosed && openMinute != null && closeMinute != null;
}

/// Settings and the week's opening hours.
@immutable
class StoreInfo {
  const StoreInfo({required this.settings, required this.hours});

  final StoreSettings settings;
  final List<DayHours> hours;

  /// Hours for the day [date] falls on.
  DayHours hoursOn(DateTime date) {
    final day = date.weekday % 7; // DateTime: Monday 1 ... Sunday 7
    return hours.firstWhere(
      (h) => h.dayOfWeek == day,
      orElse: () => DayHours.closed(day),
    );
  }
}
