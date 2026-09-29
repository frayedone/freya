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

  Future<bool> enableDailyAgenda(WeekSchedule schedule, Set<int> skippedWeekdays) async => false;

  Future<void> disableDailyAgenda() async {}

  Future<void> refreshDailyAgendas() async {}

  Future<NotificationResult> schedulePreLesson({
    required Lesson lesson,
    required DateTime onDate,
    required int lessonIndex,
    int minutesBefore = 10,
  }) async =>
      NotificationResult.notSupported;

  Future<void> cancelPreLesson(DateTime day, int lessonIndex) async {}

  Future<Set<int>> activePreLessonIds() async => {};

  Future<void> cancelAll() async {}
}