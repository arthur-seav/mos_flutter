import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../utils/clock.dart';
import '../../utils/time_format.dart';

/// What the "Help & support" panel shows (Figma: overlay-support).
@immutable
class SupportInfo {
  const SupportInfo({required this.phone, required this.hours});

  /// "012 345 678"
  final String phone;

  /// Today's opening hours, "7:00 AM – 9:00 PM", or "Closed today".
  final String hours;
}

final supportInfoProvider = FutureProvider.autoDispose<SupportInfo>((
  ref,
) async {
  final store = await ref.read(storeRepositoryProvider).fetchStoreInfo();
  final now = ref.read(clockProvider)();
  final today = store.hoursOn(now);
  final day = DateTime(now.year, now.month, now.day);
  final hours = today.isOpenDay
      ? '${formatClock(day.add(Duration(minutes: today.openMinute!)))} – '
            '${formatClock(day.add(Duration(minutes: today.closeMinute!)))}'
      : 'Closed today';
  return SupportInfo(phone: store.settings.phone, hours: hours);
});
