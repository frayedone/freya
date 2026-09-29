import 'package:shared_preferences/shared_preferences.dart';

/// Хранение пользовательских настроек (отменённые дни, уведомления).
class SettingsService {
  SettingsService._();

  static const String _skippedKey = 'skippedWeekdays';
  static const String _agendaKey = 'dailyAgendaEnabled';

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