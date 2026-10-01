import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_preset.dart';
import '../models/week_schedule.dart';
import 'schedule_service.dart';

/// Хранилище пресетов расписания.
///
/// Пресет — это сохранённый снимок [WeekSchedule] с именем. Активный пресет
/// пишется в [ScheduleService], поэтому все экраны видят его как обычное
/// расписание.
class PresetService {
  PresetService._();

  static const String _listKey = 'schedulePresets';
  static const String _activeKey = 'activePresetId';

  /// Меняется при любом изменении списка пресетов — экраны перечитывают его.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static Future<List<SchedulePreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => SchedulePreset.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<void> _persist(List<SchedulePreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _listKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
    revision.value++;
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Сохраняет текущее расписание как новый пресет и делает его активным.
  static Future<SchedulePreset> saveCurrentAs(String name) async {
    final schedule = await ScheduleService().load();
    return addFrom(name: name, schedule: schedule);
  }

  static Future<SchedulePreset> addFrom({
    required String name,
    required WeekSchedule schedule,
  }) async {
    final preset = SchedulePreset(id: _newId(), name: name, schedule: schedule);
    final presets = List<SchedulePreset>.from(await loadAll())..add(preset);
    await _persist(presets);
    return preset;
  }

  static Future<void> rename(String id, String name) async {
    final presets = List<SchedulePreset>.from(await loadAll());
    final index = presets.indexWhere((p) => p.id == id);
    if (index == -1) return;
    presets[index] = presets[index].copyWith(name: name);
    await _persist(presets);
  }

  /// Заменяет расписание пресета текущим и делает его активным.
  static Future<void> overwriteWithCurrent(String id) async {
    final schedule = await ScheduleService().load();
    final presets = List<SchedulePreset>.from(await loadAll());
    final index = presets.indexWhere((p) => p.id == id);
    if (index == -1) return;
    presets[index] = presets[index].copyWith(schedule: schedule);
    await _persist(presets);
    await _setActive(id);
  }

  static Future<void> delete(String id) async {
    final presets = List<SchedulePreset>.from(await loadAll())
      ..removeWhere((p) => p.id == id);
    await _persist(presets);
    final active = await activeId();
    if (active == id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeKey);
    }
  }

  /// Делает пресет активным и записывает его расписание как текущее.
  static Future<void> apply(SchedulePreset preset) async {
    await ScheduleService().save(preset.schedule);
    await _setActive(preset.id);
  }

  static Future<void> _setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    revision.value++;
  }

  /// Создаёт стартовый пресет из текущего расписания, если список пуст.
  ///
  /// Возвращает пресет, который теперь активен, либо null, если список уже
  /// был непустым.
  static Future<SchedulePreset?> seedIfEmpty({String? name}) async {
    if ((await loadAll()).isNotEmpty) return null;
    final preset = await saveCurrentAs(name ?? (await ScheduleService().load()).group);
    await _setActive(preset.id);
    return preset;
  }
}
