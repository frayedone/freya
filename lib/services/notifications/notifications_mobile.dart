import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
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

  static const MethodChannel _channel = MethodChannel('kz.freya.freya/updates');

  /// Разрешение на точные будильники; пересчитывается при планировании.
  static bool _exactAllowed = false;

  static const int _agendaIdBase = 300;
  static const int _preLessonIdBase = 1000;

  /// id одноразовых уведомлений расписания: _agendaIdBase + смещение дня.
  static const int _agendaDays = 7;
  static const int _testId = 9999;

  /// id из прошлой версии (повторяющиеся будильники) — гасим при перепланировании.
  static const int _legacyAgendaIdBase = 400;

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

  /// Плагин уведомлений инициализирован и может работать на этой платформе.
  bool get isSupported => _ready;

  /// Запросить разрешение на показ уведомлений (Android 13+/iOS).
  ///
  /// Возвращает false, если уведомления на этой платформе недоступны
  /// или пользователь отказал.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    return _requestPermission();
  }

  /// Включить утренние уведомления: расписание на день.
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

  /// Есть ли разрешение на точные будильники (Android 12+).
  ///
  /// Без него `exactAllowWhileIdle` недоступен, а повторяющиеся будильники
  /// Android батчит в общее окно — уведомления приходят с большой задержкой.
  Future<bool> canScheduleExact() async {
    if (!_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открыть системный экран выдачи разрешения на точные будильники.
  Future<bool> requestExactAlarms() async {
    if (!_ready) return false;
    try {
      return await _channel.invokeMethod<bool>('requestExactAlarms') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Открыть настройки оптимизации батареи: без исключения агрессивные
  /// OEM-прошивки (Xiaomi, Samsung, Huawei) сносят отложенные уведомления.
  Future<void> openBatterySettings() async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } catch (_) {}
  }

  /// Проверка: поставить уведомление через 15 секунд, чтобы убедиться, что
  /// канал и разрешения работают, не дожидаясь утра.
  Future<bool> sendTestNotification() async {
    if (!_ready) return false;
    try {
      if (!await _requestPermission()) return false;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda',
          'Расписание на день',
          channelDescription: 'Утреннее расписание занятий на сегодня',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.zonedSchedule(
        id: _testId,
        title: 'Проверка уведомлений',
        body: 'Если вы это видите — уведомления работают.',
        scheduledDate: tz.TZDateTime.now(tz.local)
            .add(const Duration(seconds: 15)),
        notificationDetails: details,
        androidScheduleMode: _scheduleMode(),
        payload: NotificationRouter.openSchedulePayload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Выключить утренние уведомления и убрать все отложенные будильники.
  Future<void> disableDailyAgenda() => _cancelAgendas();

  /// Режим планирования: точный, если разрешение выдано, иначе неточный.
  ///
  /// `matchDateTimeComponents` намеренно не используется: повторяющийся
  /// будильник Android ставит через `AlarmManager.setRepeating()`, который
  /// батчится в maintenance-окно и приходит с задержкой до часа. Поэтому
  /// вместо повтора ставим отдельные одноразовые будильники.
  AndroidScheduleMode _scheduleMode() =>
      _exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Отменить все будильники расписания (по id из [_agendaIdBase]).
  Future<void> _cancelAgendas() async {
    if (!_ready) return;
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _agendaIdBase + weekday);
    }
    // id повторных уведомлений из прошлых версий
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _legacyAgendaIdBase + weekday);
    }
    await _plugin.cancel(id: _testId);
  }

  Future<void> _scheduleAgendas(WeekSchedule schedule, Set<int> skippedWeekdays) async {
    if (!_ready) return;
    _exactAllowed = await canScheduleExact();
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

    // Погода осмысленна только в ближайших днях.
    final weatherLine = await _todayWeatherLine();
    final now = DateTime.now();
    for (var dayOffset = 0; dayOffset < _agendaDays; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      final weekday = date.weekday;
      if (skippedWeekdays.contains(weekday)) continue;
      final lessons = schedule.days[weekday] ?? const <Lesson>[];
      final body = [
        if (dayOffset <= 1 && weatherLine.isNotEmpty) weatherLine,
        if (lessons.isEmpty) 'Сегодня пар нет'
        else ...lessons.map((lesson) => '${lesson.start} · ${lesson.subject}'),
      ].where((line) => line.isNotEmpty).join('\n');

      final fireAt = DateTime(date.year, date.month, date.day, 9, 0);
      if (!fireAt.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: _agendaIdBase + dayOffset,
          title: 'Расписание на сегодня',
          body: body,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: _scheduleMode(),
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
          androidScheduleMode: _scheduleMode(),
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

  /// Отменить напоминание по его id ([preLessonIdFor]).
  Future<void> cancelPreLessonById(int id) async {
    if (!_ready || id == 0) return;
    await _plugin.cancel(id: id);
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