import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freya/models/week_schedule.dart';
import 'package:freya/screens/schedule_screen.dart';
import 'package:freya/services/schedule_service.dart';
import 'package:freya/utils/wmo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('WeekSchedule.fromJson сортирует пары и группирует по дням', () {
    final schedule = WeekSchedule.fromJson(jsonDecode('''
      {
        "group": "КС-23",
        "days": [
          {"weekday": 2, "lessons": [
            {"subject": "Позже", "start": "10:10", "end": "11:40"},
            {"subject": "Раньше", "start": "08:30", "end": "10:00"}
          ]}
        ]
      }
    ''') as Map<String, dynamic>);

    expect(schedule.group, 'КС-23');
    expect(schedule.lessonsFor(DateTime(2026, 1, 6)).length, 2);
    expect(schedule.lessonsFor(DateTime(2026, 1, 7)), isEmpty);
    expect(schedule.lessonsFor(DateTime(2026, 1, 6)).first.subject, 'Раньше');
  });

  test('ScheduleService.assetPath указывает на существующий ассет', () {
    expect(ScheduleService.assetPath, 'assets/schedule.json');
  });

  test('wmoInfo расшифровывает коды погоды', () {
    expect(wmoInfo(0).$1, 'Ясно');
    expect(wmoInfo(3).$1, 'Пасмурно');
    expect(wmoInfo(61).$2, Icons.umbrella_outlined);
    expect(wmoInfo(999).$1, 'Неизвестно');
  });

  testWidgets('Экран расписания показывает пары', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final schedule = WeekSchedule.fromJson(jsonDecode('''
      {
        "group": "Тест",
        "days": [
          {"weekday": 1, "lessons": [
            {"subject": "Алгебра", "type": "Лекция", "room": "А-1", "teacher": "Иванов", "start": "08:30", "end": "10:00"}
          ]}
        ]
      }
    ''') as Map<String, dynamic>);

    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(schedule: schedule)),
    );
    await tester.pumpAndSettle();

    // Пары для проверки лежат в понедельник — выбираем его.
    if (DateTime.now().weekday != 1) {
      await tester.tap(find.text('Пн'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Алгебра'), findsOneWidget);
    expect(find.textContaining('А-1'), findsOneWidget);

    // Размонтируем дерево, чтобы отменить фоновый таймер экрана.
    await tester.pumpWidget(const SizedBox());
  });
}