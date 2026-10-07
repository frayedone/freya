import '../../models/lesson.dart';
import '../../models/week_schedule.dart';
import 'notification_result.dart';

/// Заглушка для платформ без поддержки локальных уведомлений (web).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static int preLessonIdFor(DateTime day, int lessonIndex) =>
      1000 + day.year * 100000 + (day.month * 100 + day.day) * 10 + lessonIndex;

  Future<void> init() async {}

  bool get isSupported => false;

  Future<bool> ensurePermission() async => false;

  Future<bool> enableDailyAgenda(WeekSchedule schedule, Set<int> skippedWeekdays) async => false;

  Future<void> disableDailyAgenda() async {}

  Future<void> refreshDailyAgendas() async {}

  Future<bool> canScheduleExact() async => false;

  Future<bool> requestExactAlarms() async => false;

  Future<void> openBatterySettings() async {}

  Future<bool> sendTestNotification() async => false;

  Future<NotificationResult> schedulePreLesson({
    required Lesson lesson,
    required DateTime onDate,
    required int lessonIndex,
    int minutesBefore = 10,
  }) async =>
      NotificationResult.notSupported;

  Future<void> cancelPreLesson(DateTime day, int lessonIndex) async {}

  Future<void> cancelPreLessonById(int id) async {}

  Future<Set<int>> activePreLessonIds() async => {};

  Future<void> cancelAll() async {}
}