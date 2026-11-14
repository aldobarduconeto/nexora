import 'package:nexora/src/utils/serial_task_queue.dart';

import 'package:flutter/foundation.dart';
import 'package:nexora/src/models/seting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;
  static final SettingsService instance = SettingsService();
  static const _storageKey = 'nexora.settings.v3';
  final SharedPreferencesAsync? _providedPreferences;
  Setting _settings = Setting.defaults;
  final _tasks = SerialTaskQueue();
  Setting get settings => _settings;
  SharedPreferencesAsync get _prefs =>
      _providedPreferences ?? SharedPreferencesAsync();

  Future<void> load() => _tasks.run(() async {
    final raw = await _prefs.getString(_storageKey);
    _settings = raw == null || raw.isEmpty
        ? Setting.defaults
        : Setting.fromJson(raw);
    notifyListeners();
  });

  Future<void> updateSetting(Setting Function(Setting) updater) =>
      _tasks.run(() async {
        final updated = updater(_settings);
        await _prefs.setString(_storageKey, updated.toJson());
        _settings = updated;
        notifyListeners();
      });

  Future<void> reset() => updateSetting((_) => Setting.defaults);
}
