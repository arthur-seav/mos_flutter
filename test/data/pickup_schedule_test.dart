import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/models/pickup_schedule.dart';
import 'package:mos_app/data/models/store_info.dart';

void main() {
  // The demo store's settings: slots every 10 min, 5 min lead time.
  StoreInfo storeWith({int interval = 10, int lead = 5}) => StoreInfo(
    settings: StoreSettings(
      storeName: 'MOS Coffee',
      address: '',
      phone: '',
      slotIntervalMin: interval,
      minPrepMin: lead,
    ),
    hours: [
      for (var d = 0; d < 7; d++)
        d == 0 ? const DayHours.closed(0) : DayHours.between(d, 7, 21),
    ],
  );
  final store = storeWith();
  // Thursday 29 October 2026.
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 10, 29, h, m, s);
  PickupSchedule when(DateTime now, [StoreInfo? s]) =>
      PickupSchedule(store: s ?? store, now: now);
  List<String> times(PickupSchedule s) => [
    for (final t in s.slots) '${t.hour}:${t.minute.toString().padLeft(2, '0')}',
  ];

  test("Arthur's example: at 10:41, six times from 10:50, 10 min apart", () {
    expect(times(when(at(10, 41))), [
      '10:50',
      '11:00',
      '11:10',
      '11:20',
      '11:30',
      '11:40',
    ]);
  });

  test('the first time is 5 min ahead, rounded up to a 5-minute mark', () {
    expect(times(when(at(10, 12))).first, '10:20'); // 10:17 -> 10:20
    expect(times(when(at(10, 15))).first, '10:20'); // already on a mark
    expect(times(when(at(10, 15, 1))).first, '10:25'); // 10:20:01 -> 10:25
  });

  test('BR-07: the backend allows any time from 5 min ahead', () {
    final s = when(at(10, 12));
    expect(s.allows(at(10, 16)), isFalse);
    expect(s.allows(at(10, 17)), isTrue);
  });

  test('TC-19: closes at 9:00 PM, so nothing after 8:00 PM', () {
    expect(times(when(at(19, 20))), ['19:25', '19:35', '19:45', '19:55']);
    expect(times(when(at(19, 50))), ['19:55']);
    final s = when(at(10, 12));
    expect(s.allows(at(20, 0)), isTrue);
    expect(s.allows(at(20, 1)), isFalse);
  });

  test('late in the day there is nothing left to schedule', () {
    final s = when(at(19, 56)); // 20:01 -> 20:05, past 20:00
    expect(s.slots, isEmpty);
    expect(s.canSchedule, isFalse);
    expect(s.canPickUpAsap, isTrue);
  });

  test('before opening: no ASAP; times start at opening', () {
    final s = when(at(6, 0));
    expect(s.isOpenNow, isFalse);
    expect(s.canPickUpAsap, isFalse);
    expect(times(s), ['7:00', '7:10', '7:20', '7:30', '7:40', '7:50']);
    expect(times(when(at(6, 58))).first, '7:05'); // 7:03 -> 7:05
  });

  test('lead time and interval come from store_settings', () {
    // The SA defaults: 30 min lead, 15 min apart.
    final s = when(at(10, 41), storeWith(interval: 15, lead: 30));
    expect(times(s), ['11:15', '11:30', '11:45', '12:00', '12:15', '12:30']);
  });

  test('ASAP stops when the drink could not be ready before closing', () {
    expect(when(at(20, 49)).canPickUpAsap, isTrue);
    expect(when(at(20, 50)).canPickUpAsap, isFalse);
  });

  test('a closed day has no ASAP and no slots', () {
    final sunday = when(DateTime(2026, 11, 1, 12));
    expect(sunday.isOpenNow, isFalse);
    expect(sunday.slots, isEmpty);
    expect(sunday.canPickUpAsap, isFalse);
  });
}
