import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/models/pickup_schedule.dart';
import 'package:mos_app/data/models/store_info.dart';

void main() {
  const settings = StoreSettings(
    storeName: 'MOS Coffee',
    address: '',
    phone: '',
  ); // slots every 15 min, 30 min lead time, ASAP in 10 min
  final store = StoreInfo(
    settings: settings,
    hours: [
      for (var d = 0; d < 7; d++)
        d == 0 ? const DayHours.closed(0) : DayHours.between(d, 7, 21),
    ],
  );
  // Thursday 29 October 2026.
  DateTime at(int h, int m) => DateTime(2026, 10, 29, h, m);
  PickupSchedule when(DateTime now) => PickupSchedule(store: store, now: now);
  String hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  test('BR-07: the first slot is at least 30 minutes away', () {
    final s = when(at(10, 12));
    final available = s.slots
        .where((x) => x.isAvailable)
        .map((x) => hm(x.time));
    expect(available.first, '10:45');
    // 10:15 and 10:30 are listed but too soon (Figma: faded).
    expect(s.slots.where((x) => !x.isAvailable).map((x) => hm(x.time)), [
      '10:15',
      '10:30',
    ]);
    expect(s.allows(at(10, 41)), isFalse);
    expect(s.allows(at(10, 42)), isTrue);
  });

  test('TC-19: closes at 9:00 PM, so nothing after 8:00 PM', () {
    final s = when(at(10, 12));
    expect(hm(s.slots.last.time), '20:00');
    expect(s.allows(at(20, 0)), isTrue);
    expect(s.allows(at(20, 15)), isFalse);
    expect(s.allows(at(20, 1)), isFalse);
  });

  test('slots follow the 15-minute interval from opening time', () {
    final times = when(at(10, 12)).slots.map((x) => x.time.minute).toSet();
    expect(times, {0, 15, 30, 45});
  });

  test('before opening: no ASAP, but later slots can be booked', () {
    final s = when(at(6, 0));
    expect(s.isOpenNow, isFalse);
    expect(s.canPickUpAsap, isFalse);
    expect(s.canSchedule, isTrue);
    expect(hm(s.slots.firstWhere((x) => x.isAvailable).time), '7:00');
  });

  test('ASAP stops when the drink could not be ready before closing', () {
    expect(when(at(20, 49)).canPickUpAsap, isTrue);
    expect(when(at(20, 50)).canPickUpAsap, isFalse);
  });

  test('late in the day there is nothing left to schedule', () {
    final s = when(at(19, 45));
    expect(s.canSchedule, isFalse);
    expect(s.canPickUpAsap, isTrue);
  });

  test('a closed day has no ASAP and no slots', () {
    final sunday = when(DateTime(2026, 11, 1, 12));
    expect(sunday.isOpenNow, isFalse);
    expect(sunday.slots, isEmpty);
    expect(sunday.canPickUpAsap, isFalse);
  });
}
