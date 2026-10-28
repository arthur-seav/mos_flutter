import 'package:intl/intl.dart';

/// "10:45 AM"
///
/// intl puts a narrow no-break space (U+202F) before AM/PM, as newer
/// Unicode data does. It is swapped for a plain space so the text can be
/// searched and compared like any other ("9:00 PM").
String formatClock(DateTime time) =>
    DateFormat.jm('en_US').format(time).replaceAll('\u202f', ' ');
