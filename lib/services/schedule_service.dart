import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/week_schedule.dart';

/// Расписание колледжа.
///
/// По умолчанию берётся из `assets/schedule.json`. Если пользователь что-то
/// изменил, используется его версия, сохранённая локально.
class ScheduleService {
  const ScheduleService();

  static const String assetPath = 'assets/schedule.json';
  static const String _userKey = 'userSchedule';

  /// Меняется при каждом сохранении — экраны подписываются и перечитывают
  /// расписание, чтобы правки были видны сразу.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  Future<WeekSchedule> load() async => await loadCustom() ?? _loadDefault();

  /// Пользовательская версия расписания или null, если правок не было.
  Future<WeekSchedule?> loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return WeekSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<WeekSchedule> _loadDefault() async {
    final raw = await rootBundle.loadString(assetPath);
    return WeekSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Сохраняет расписание пользователя и оповещает подписчиков.
  Future<void> save(WeekSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(schedule.toJson()));
    revision.value++;
  }

  /// Возвращает исходное расписание из ассета.
  Future<WeekSchedule> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    revision.value++;
    return _loadDefault();
  }
}