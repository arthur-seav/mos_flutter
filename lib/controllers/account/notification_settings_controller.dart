import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';

/// The "Notifications" switch on the profile page (SA §4.2.5.2). Off =
/// no "order ready" / "order rejected" notices (FR-16, FR-38). On by
/// default; remembered on this phone.
final notificationsEnabledProvider =
    AsyncNotifierProvider<NotificationSettingsController, bool>(
      NotificationSettingsController.new,
    );

class NotificationSettingsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.read(settingsRepositoryProvider).notificationsEnabled();

  Future<void> set(bool value) async {
    await future; // let the saved value load first, so it cannot win
    state = AsyncData(value);
    await ref.read(settingsRepositoryProvider).setNotificationsEnabled(value);
  }
}
