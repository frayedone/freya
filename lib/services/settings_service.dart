import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_avatar.dart';
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
  static const String _onboardingKey = 'onboardingDone';
  static const String _avatarKey = 'appAvatar';

  /// Автонапоминание о ближайшей паре.
  static const String _autoNextKey = 'autoNextReminder';

  /// id последнего напоминания, поставленного автоматически.
  static const String _autoIdKey = 'autoNextReminderId';

  /// id пар, по которым пользователь вручную выключил напоминание.
  static const String _suppressedKey = 'autoReminderSuppressed';

  /// Ограничение списка suppress-ов, чтобы он не рос бесконечно.
  static const int _suppressedLimit = 60;

  /// Изменяется при смене темы/акцента — подписан MaterialApp.
  static final ValueNotifier<({ThemeChoice theme, AccentChoice accent})> appearance =
      ValueNotifier((theme: ThemeChoice.dark, accent: AccentChoice.amber));

  /// Показывать ли онбординг при старте (false — показывать).
  static final ValueNotifier<bool> onboardingDone = ValueNotifier(true);

  /// Выбранная аватарка/иконка приложения.
  static final ValueNotifier<AppAvatar> avatar = ValueNotifier(AppAvatar.freya);

  static bool _loaded = false;

  /// Загружает тему и акцент; повторные вызовы не читают хранилище заново.
  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    appearance.value = (
      theme: ThemeChoice.fromName(prefs.getString(_themeKey)),
      accent: AccentChoice.fromName(prefs.getString(_accentKey)),
    );
    onboardingDone.value = prefs.getBool(_onboardingKey) ?? false;
    avatar.value = AppAvatar.fromKey(prefs.getString(_avatarKey));
    _loaded = true;
  }

  /// Отмечает онбординг пройденным (или сбрасывает его для повторного показа).
  static Future<void> setOnboardingDone(bool done) async {
    onboardingDone.value = done;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, done);
  }

  static Future<void> saveAvatar(AppAvatar choice) async {
    avatar.value = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, choice.key);
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

  /// Включено ли автоматическое напоминание о ближайшей паре (по умолчанию — да).
  static Future<bool> loadAutoNextReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoNextKey) ?? true;
  }

  static Future<void> saveAutoNextReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNextKey, enabled);
  }

  /// id напоминания, которое сейчас поставлено автоматически (или 0).
  static Future<int> loadAutoReminderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoIdKey) ?? 0;
  }

  static Future<void> saveAutoReminderId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == 0) {
      await prefs.remove(_autoIdKey);
    } else {
      await prefs.setInt(_autoIdKey, id);
    }
  }

  /// Пары, по которым автонапоминание больше не включается (выключено вручную).
  static Future<Set<int>> loadSuppressedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_suppressedKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> addSuppressedReminder(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        (prefs.getStringList(_suppressedKey) ?? const <String>[])
            .where((raw) => raw != '$id')
            .toList();
    current.add('$id');
    while (current.length > _suppressedLimit) {
      current.removeAt(0);
    }
    await prefs.setStringList(_suppressedKey, current);
  }

  static Future<void> removeSuppressedReminder(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        (prefs.getStringList(_suppressedKey) ?? const <String>[])
            .where((raw) => raw != '$id')
            .toList();
    await prefs.setStringList(_suppressedKey, current);
  }

  /// Полностью сбрасывает список пар, по которым автонапоминание выключено.
  static Future<void> clearSuppressedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_suppressedKey);
  }
}