import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Хранилище пользовательских настроек.
///
/// Настройки темы лежат в том же [ValueNotifier], поэтому MaterialApp
/// перерисовывается сразу при смене темы или акцента.
class SettingsService {
  SettingsService._();

  static const String _skippedKey = 'skippedWeekdays';
  static const String _agendaKey = 'dailyAgendaEnabled';
  static const String _themeKey = 'themeChoice';
  static const String _accentKey = 'accentChoice';

  /// Изменяется при смене темы/акцента — подписан MaterialApp.
  static final ValueNotifier<({ThemeChoice theme, AccentChoice accent})> appearance =
      ValueNotifier((theme: ThemeChoice.dark, accent: AccentChoice.amber));

  static bool _loaded = false;

  /// Загружает тему и акцент; повторные вызовы не читают хранилище заново.
  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    appearance.value = (
      theme: ThemeChoice.fromName(prefs.getString(_themeKey)),
      accent: AccentChoice.fromName(prefs.getString(_accentKey)),
    );
    _loaded = true;
  }

  static Future<void> saveTheme(ThemeChoice choice) async {
    appearance.value = (theme: choice, accent: appearance.value.accent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, choice.name);
  }

  static Future<void> saveAccent(AccentChoice choice) async {
    appearance.value = (theme: appearance.value.theme, accent: choice);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, choice.name);
  }

  /// Дни недели (1 = пн … 7 = вс), которые пользователь отменил.
  static Future<Set<int>> loadSkippedWeekdays() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_skippedKey) ?? const []).map(int.parse).toSet();
  }

  static Future<void> saveSkippedWeekdays(Set<int> weekdays) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = weekdays.toList()..sort();
    await prefs.setStringList(_skippedKey, sorted.map((w) => '$w').toList());
  }

  /// Включены ли утренние уведомления с расписанием.
  static Future<bool> loadAgendaEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_agendaKey) ?? false;
  }

  static Future<void> saveAgendaEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_agendaKey, enabled);
  }
}