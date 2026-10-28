/// "Good morning" / "Good afternoon" / "Good evening" for the Home header,
/// from the phone's local time.
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}
