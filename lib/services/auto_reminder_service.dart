import 'dart:async';

import 'notifications/notifications.dart';
import 'schedule_service.dart';
import 'settings_service.dart';

/// Результат синхронизации автонапоминания о ближайшей паре.
class AutoReminderResult {
  const AutoReminderResult({
    required this.activeIds,
    this.scheduledSubject,
    this.permissionDenied = false,
  });

  /// id всех напоминаний, которые сейчас запланированы.
  final Set<int> activeIds;

  /// Название пары, о которой поставили напоминание в этом проходе.
  final String? scheduledSubject;

  /// Разрешение на уведомления не выдано — стоит показать подсказку.
  final bool permissionDenied;
}

/// Ставит напоминание о ближайшей паре автоматически.
///
/// Пользователь ничего не нажимает: при открытии расписания (и периодически,
/// пока приложение открыто) ищется первая сегодняшняя пара, ещё не начавшаяся,
/// и по ней ставится уведомление за 10 минут до начала. В настройках это
/// поведение выключается, а выключенный вручную колокольчик само включение
/// не подхватывает.
class AutoReminderService {
  AutoReminderService._();

  static const int _minutesBefore = 10;

  static Future<AutoReminderResult> sync() async {
    final active = await NotificationService.instance.activePreLessonIds();
    if (!NotificationService.instance.isSupported) {
      return AutoReminderResult(activeIds: active);
    }

    final storedId = await SettingsService.loadAutoReminderId();
    final enabled = await SettingsService.loadAutoNextReminder();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!enabled) {
      return _clearStored(active, storedId);
    }

    final skipped = await SettingsService.loadSkippedWeekdays();
    if (skipped.contains(now.weekday)) {
      return _clearStored(active, storedId);
    }

    final lessons = (await const ScheduleService().load()).lessonsFor(today);
    if (lessons.isEmpty) {
      return _clearStored(active, storedId);
    }

    final suppressed = await SettingsService.loadSuppressedReminders();

    // Берём пары, которые ещё не начались: если до ближайшей осталось
    // меньше 10 минут, напомнить уже нельзя — пробуем следующую.
    for (var index = 0; index < lessons.length; index++) {
      if (!lessons[index].startOn(today).isAfter(now)) continue;
      final id = NotificationService.preLessonIdFor(today, index);
      if (active.contains(id)) {
        await _forgetStored(storedId, sameAs: id);
        return AutoReminderResult(activeIds: active);
      }
      if (suppressed.contains(id)) continue;

      if (!await NotificationService.instance.ensurePermission()) {
        return AutoReminderResult(activeIds: active, permissionDenied: true);
      }

      final result = await NotificationService.instance.schedulePreLesson(
        lesson: lessons[index],
        onDate: today,
        lessonIndex: index,
        minutesBefore: _minutesBefore,
      );
      if (result == NotificationResult.scheduled) {
        if (storedId != id) {
          await NotificationService.instance.cancelPreLessonById(storedId);
        }
        await SettingsService.saveAutoReminderId(id);
        active.add(id);
        return AutoReminderResult(
          activeIds: active,
          scheduledSubject: lessons[index].subject,
        );
      }
      if (result == NotificationResult.notSupported) {
        return AutoReminderResult(activeIds: active);
      }
      // tooLate — пара начинается меньше чем через 10 минут, идём дальше.
    }

    return _clearStored(active, storedId);
  }

  /// Убирает пометку об автонапоминании, если оно больше неактуально
  /// (настройка выключена, пар нет или день отменён).
  static AutoReminderResult _clearStored(Set<int> active, int storedId) {
    if (storedId != 0) {
      unawaited(_forget(storedId));
    }
    return AutoReminderResult(activeIds: active);
  }

  static Future<void> _forgetStored(int storedId, {required int sameAs}) async {
    if (storedId == 0 || storedId == sameAs) return;
    // Прошлое автонапоминание этой же даты: пара уже началась, уведомление
    // либо сработало, либо больше не нужно.
    await NotificationService.instance.cancelPreLessonById(storedId);
    await SettingsService.saveAutoReminderId(0);
  }

  static Future<void> _forget(int storedId) async {
    await NotificationService.instance.cancelPreLessonById(storedId);
    await SettingsService.saveAutoReminderId(0);
  }
}
