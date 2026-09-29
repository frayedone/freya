import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/lesson.dart';
import '../../models/week_schedule.dart';
import '../schedule_service.dart';
import '../settings_service.dart';
import '../weather_service.dart';
import '../../utils/wmo.dart';
import '../notification_router.dart';
import 'notification_result.dart';

/// Локальные уведомления (Android/iOS/десктоп).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _agendaIdBase = 300;
  static const int _preLessonIdBase = 1000;

  /// Стабильный id напоминания о паре: уникален для пары «дата + номер урока».
  static int preLessonIdFor(DateTime day, int lessonIndex) =>
      _preLessonIdBase + day.year * 100000 + (day.month * 100 + day.day) * 10 + lessonIndex;

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: NotificationRouter.handleResponse,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Включить утренние уведомления: каждый день в 09:00 — расписание на день.
  /// Для отменённых дней (в [skippedWeekdays]) уведомление не создаётся.
  Future<bool> enableDailyAgenda(WeekSchedule schedule, Set<int> skippedWeekdays) async {
    if (!_ready) return false;
    final granted = await _requestPermission();
    if (!granted) return false;
    await _scheduleAgendas(schedule, skippedWeekdays);
    return true;
  }

  /// Обновить утренние уведомления: перечитать настройки и перепланировать
  /// с актуальной погодой. Вызывается при запуске приложения.
  Future<void> refreshDailyAgendas() async {
    if (!_ready) return;
    try {
      if (!await SettingsService.loadAgendaEnabled()) return;
      final skipped = await SettingsService.loadSkippedWeekdays();
      final schedule = await const ScheduleService().load();
      await _scheduleAgendas(schedule, skipped);
    } catch (_) {}
  }

  Future<void> disableDailyAgenda() => _cancelAgendas();

  Future<void> _cancelAgendas() async {
    if (!_ready) return;
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _agendaIdBase + weekday);
    }
  }

  Future<void> _scheduleAgendas(WeekSchedule schedule, Set<int> skippedWeekdays) async {
    if (!_ready) return;
    await _cancelAgendas();
    const androidDetails = AndroidNotificationDetails(
      'agenda',
      'Расписание на день',
      channelDescription: 'Утреннее расписание занятий на сегодня',
      importance: Importance.high,
      priority: Priority.high,
      actions: [AndroidNotificationAction('open_schedule', 'Открыть расписание')],
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final weatherLine = await _todayWeatherLine();
    final now = DateTime.now();
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (skippedWeekdays.contains(weekday)) continue;
      final lessons = schedule.days[weekday] ?? const <Lesson>[];
      final body = [
        weatherLine,
        if (lessons.isEmpty) 'Сегодня пар нет'
        else ...lessons.map((lesson) => '${lesson.start} · ${lesson.subject}'),
      ].where((line) => line.isNotEmpty).join('\n');
      final fireAt = _nextWeekdayAt(weekday, 9, 0, from: now);
      try {
        await _plugin.zonedSchedule(
          id: _agendaIdBase + weekday,
          title: 'Расписание на сегодня',
          body: body,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: NotificationRouter.openSchedulePayload,
        );
      } catch (_) {
        // одна неудачная запись не должна ломать остальные
      }
    }
  }

  Future<String> _todayWeatherLine() async {
    try {
      final data = await WeatherService().fetch(days: 1);
      final (label, _) = wmoInfo(data.current.weatherCode);
      return 'За окном ${data.current.temperature.round()}° · $label';
    } catch (_) {
      return '';
    }
  }

  DateTime _nextWeekdayAt(int weekday, int hour, int minute, {required DateTime from}) {
    final delta = (weekday - from.weekday + 7) % 7;
    var fireAt = DateTime(from.year, from.month, from.day, hour, minute).add(Duration(days: delta));
    if (!fireAt.isAfter(from)) fireAt = fireAt.add(const Duration(days: 7));
    return fireAt;
  }

  /// Напомнить о паре за `minutesBefore` минут до её начала.
  ///
  /// На телефонах — отложенное уведомление. На десктопах, где планирование
  /// не поддерживается, показывает уведомление сразу (демонстрация работы).
  Future<NotificationResult> schedulePreLesson({
    required Lesson lesson,
    required DateTime onDate,
    required int lessonIndex,
    int minutesBefore = 10,
  }) async {
    if (!_ready) return NotificationResult.notSupported;

    final id = preLessonIdFor(onDate, lessonIndex);
    const androidDetails = AndroidNotificationDetails(
      'lessons',
      'Занятия',
      channelDescription: 'Напоминания о занятиях в колледже',
      importance: Importance.high,
      priority: Priority.high,
      actions: [AndroidNotificationAction('open_schedule', 'Открыть расписание')],
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    const title = 'Скоро пара';
    final body =
        '${lesson.subject} · ${lesson.type.isEmpty ? 'занятие' : lesson.type} в ${lesson.start}';

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      final fireAt = lesson.startOn(onDate).subtract(Duration(minutes: minutesBefore));
      if (fireAt.isBefore(DateTime.now())) return NotificationResult.tooLate;
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: NotificationRouter.openSchedulePayload,
        );
        return NotificationResult.scheduled;
      } catch (_) {
        return NotificationResult.notSupported;
      }
    }

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: NotificationRouter.openSchedulePayload,
      );
      return NotificationResult.scheduled;
    } catch (_) {
      return NotificationResult.notSupported;
    }
  }

  /// Отменить напоминание о конкретной паре.
  Future<void> cancelPreLesson(DateTime day, int lessonIndex) async {
    if (!_ready) return;
    await _plugin.cancel(id: preLessonIdFor(day, lessonIndex));
  }

  /// id напоминаний, которые сейчас запланированы (для отрисовки тогглов).
  Future<Set<int>> activePreLessonIds() async {
    if (!_ready) return {};
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending
          .where((request) => request.id >= _preLessonIdBase)
          .map((request) => request.id)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Отменить все уведомления приложения.
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}