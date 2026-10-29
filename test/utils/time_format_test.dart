import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/utils/time_format.dart';

void main() {
  test('12-hour time with a plain space before AM/PM', () {
    expect(formatClock(DateTime(2026, 10, 29, 21)), '9:00 PM');
    expect(formatClock(DateTime(2026, 10, 29, 10, 45)), '10:45 AM');
    expect(formatClock(DateTime(2026, 10, 29, 0, 5)), '12:05 AM');
  });

  test('date with the weekday', () {
    expect(formatDate(DateTime(2026, 10, 29, 10, 12)), 'Thu, 29 Oct 2026');
    expect(formatDate(DateTime(2026, 11, 1)), 'Sun, 1 Nov 2026');
  });
}
