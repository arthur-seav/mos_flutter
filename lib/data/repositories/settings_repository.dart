import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings kept on this phone, not on the backend (the profile page's
/// notification switch).
abstract interface class SettingsRepository {
  Future<bool> notificationsEnabled();
  Future<void> setNotificationsEnabled(bool value);
}

/// Saved with `shared_preferences` (Android SharedPreferences, iOS
/// NSUserDefaults, browser localStorage).
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const _notificationsKey = 'notifications_enabled';

  @override
  Future<bool> notificationsEnabled() async =>
      await _prefs.getBool(_notificationsKey) ?? true;

  @override
  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_notificationsKey, value);
}

/// For tests: forgets everything when the app closes.
class InMemorySettingsRepository implements SettingsRepository {
  bool _notifications = true;

  @override
  Future<bool> notificationsEnabled() async => _notifications;

  @override
  Future<void> setNotificationsEnabled(bool value) async =>
      _notifications = value;
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(),
);
