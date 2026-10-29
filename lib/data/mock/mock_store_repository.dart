import '../models/store_info.dart';
import '../repositories/store_repository.dart';

/// The demo store: open every day 7:00 AM to 9:00 PM (Figma: "Open until
/// 9:00 PM"), slots every 10 minutes, 5 minutes' lead time (BR-07 says
/// 30; Arthur chose 5 for the demo, README: Deviations).
///
/// [pauseOnlineOrdering] stands in for staff pausing orders (FR-41, TC-20).
class MockStoreRepository implements StoreRepository {
  MockStoreRepository({
    this.latency = const Duration(milliseconds: 300),
    List<DayHours>? hours,
  }) : _hours =
           hours ?? [for (var d = 0; d < 7; d++) DayHours.between(d, 7, 21)];

  final Duration latency;
  final List<DayHours> _hours;

  StoreSettings _settings = const StoreSettings(
    storeName: 'MOS Coffee',
    address: 'Street 240, Phnom Penh',
    phone: '012 345 678',
    slotIntervalMin: 10,
    minPrepMin: 5,
  );

  /// What staff do on the dashboard. Demo and tests only.
  void pauseOnlineOrdering() =>
      _settings = _settings.copyWith(onlineOrderingOpen: false);

  void resumeOnlineOrdering() =>
      _settings = _settings.copyWith(onlineOrderingOpen: true);

  @override
  Future<StoreInfo> fetchStoreInfo() async {
    await Future<void>.delayed(latency);
    return StoreInfo(settings: _settings, hours: List.unmodifiable(_hours));
  }
}
