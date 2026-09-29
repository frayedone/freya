import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/week_schedule.dart';

/// Загружает расписание из локального JSON-файла `assets/schedule.json`.
class ScheduleService {
  const ScheduleService();

  static const String assetPath = 'assets/schedule.json';

  Future<WeekSchedule> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return WeekSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}