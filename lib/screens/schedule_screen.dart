import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/lesson.dart';
import '../models/weather_data.dart';
import '../models/week_schedule.dart';
import '../services/auto_reminder_service.dart';
import '../services/notifications/notifications.dart';
import '../services/schedule_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../utils/wmo.dart';
import 'schedule_edit_screen.dart';
import 'settings_screen.dart';

enum _LessonStatus { past, soon, current, upcoming }

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.schedule});

  /// Готовое расписание (для тестов). Если передано — загрузка из ассета
  /// не выполняется.
  final WeekSchedule? schedule;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _service = ScheduleService();
  final ScrollController _scrollController = ScrollController();

  late Future<WeekSchedule> _future;
  late int _selectedWeekday;

  Timer? _clock;
  int _lastMinute = 0;
  bool _syncingAuto = false;
  bool _autoHintShown = false;
  Set<int> _skippedWeekdays = {};
  Set<int> _activeReminders = {};
  Future<WeatherData?>? _weatherFuture;

  static const double _cardStep = 142;

  @override
  void initState() {
    super.initState();
    _future = widget.schedule != null
        ? Future.value(widget.schedule!)
        : _service.load();
    _selectedWeekday = DateTime.now().weekday;
    _lastMinute = DateTime.now().minute;
    // Тик раз в 30 секунд, но перерисовка — только когда сменилась минута:
    // весь экран перестраивать каждый тик незачем.
    _clock = Timer.periodic(Duration(seconds: 30), (_) {
      if (!mounted) return;
      final minute = DateTime.now().minute;
      if (minute != _lastMinute) {
        _lastMinute = minute;
        setState(() {});
      }
      unawaited(_syncAutoReminder());
    });
    _weatherFuture = _loadWeather();
    unawaited(_loadSettings());
    unawaited(_syncAutoReminder());
    unawaited(_future.then(_scrollToRelevant));
    ScheduleService.revision.addListener(_onScheduleChanged);
  }

  /// Перечитывает расписание после правок в редакторе.
  void _onScheduleChanged() {
    if (widget.schedule != null || !mounted) return;
    setState(() => _future = _service.load());
    unawaited(_syncAutoReminder());
  }

  @override
  void dispose() {
    ScheduleService.revision.removeListener(_onScheduleChanged);
    _clock?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<WeatherData?> _loadWeather() async {
    try {
      return await WeatherService().fetch();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSettings() async {
    final skipped = await SettingsService.loadSkippedWeekdays();
    if (!mounted) return;
    setState(() => _skippedWeekdays = skipped);
  }

  /// Перечитывает напоминания и ставит автонапоминание о ближайшей паре.
  Future<void> _syncAutoReminder() async {
    if (_syncingAuto) return;
    _syncingAuto = true;
    try {
      final result = await AutoReminderService.sync();
      if (!mounted) return;
      setState(() => _activeReminders = result.activeIds);
      if (_autoHintShown) return;
      if (result.permissionDenied) {
        _autoHintShown = true;
        _showMessage(
          'Разреши уведомления — Freya сама напомнит о следующей паре',
        );
      } else if (result.scheduledSubject != null) {
        _autoHintShown = true;
        _showMessage(
          'Напоминание о «${result.scheduledSubject}» включено автоматически',
        );
      }
    } finally {
      _syncingAuto = false;
    }
  }

  DateTime get _selectedDay {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: _selectedWeekday - now.weekday));
  }

  bool get _selectedSkipped => _skippedWeekdays.contains(_selectedWeekday);

  void _scrollToRelevant(WeekSchedule schedule) {
    final lessons = schedule.lessonsFor(_selectedDay);
    if (lessons.isEmpty || !_scrollController.hasClients) return;
    final now = DateTime.now();
    final day = _selectedDay;
    var index = lessons.indexWhere((l) => l.endOn(day).isAfter(now));
    if (index == -1) index = lessons.length - 1;
    final target = (index - 1).clamp(0, lessons.length - 1);
    _scrollController.animateTo(
      (target * _cardStep).toDouble(),
      duration: Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSkip() async {
    HapticFeedback.selectionClick();
    final updated = Set<int>.of(_skippedWeekdays);
    if (updated.contains(_selectedWeekday)) {
      updated.remove(_selectedWeekday);
    } else {
      updated.add(_selectedWeekday);
    }
    setState(() => _skippedWeekdays = updated);
    await SettingsService.saveSkippedWeekdays(updated);
    if (!await SettingsService.loadAgendaEnabled()) return;
    final schedule = await _future;
    if (!mounted) return;
    await NotificationService.instance.disableDailyAgenda();
    await NotificationService.instance.enableDailyAgenda(schedule, updated);
  }

  Future<void> _toggleReminder(Lesson lesson, int index) async {
    if (_selectedSkipped) return;
    HapticFeedback.selectionClick();
    final id = NotificationService.preLessonIdFor(_selectedDay, index);
    if (_activeReminders.contains(id)) {
      await NotificationService.instance.cancelPreLesson(_selectedDay, index);
      // Колокольчик выключен вручную — автонапоминание его не включает снова.
      await SettingsService.addSuppressedReminder(id);
      if (!mounted) return;
      setState(() => _activeReminders.remove(id));
      _showMessage('Напоминание о «${lesson.subject}» убрано');
    } else {
      final result = await NotificationService.instance.schedulePreLesson(
        lesson: lesson,
        onDate: _selectedDay,
        lessonIndex: index,
      );
      if (!mounted) return;
      switch (result) {
        case NotificationResult.scheduled:
          await SettingsService.removeSuppressedReminder(id);
          setState(() => _activeReminders.add(id));
          _showMessage('Напомним о «${lesson.subject}» за 10 минут до пары');
        case NotificationResult.tooLate:
          _showMessage('До «${lesson.subject}» меньше 10 минут — не успеем');
        case NotificationResult.notSupported:
          _showMessage('Здесь локальные уведомления недоступны');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => SettingsScreen()),
    );
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => ScheduleEditScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание'),
        actions: [
          IconButton(
            tooltip: 'Изменить расписание',
            onPressed: _openEditor,
            icon: Icon(Icons.edit_calendar_outlined,
                size: 20, color: context.colors.muted),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: _openSettings,
            icon: Icon(Icons.tune),
          ),
        ],
      ),
      body: FutureBuilder<WeekSchedule>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Не удалось загрузить расписание:\n${snapshot.error}',
              ),
            );
          }
          final schedule = snapshot.data!;
          final lessons = schedule.lessonsFor(_selectedDay);
          final cancelled = _selectedSkipped;
          final isToday = _selectedWeekday == DateTime.now().weekday;
          final next = isToday && !cancelled
              ? lessons
                    .where((l) => l.endOn(_selectedDay).isAfter(DateTime.now()))
                    .toList()
              : const <Lesson>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                group: schedule.group,
                day: _selectedDay,
                isToday: isToday,
              ),
              _DayStrip(
                schedule: schedule,
                skippedWeekdays: _skippedWeekdays,
                selectedWeekday: _selectedWeekday,
                onSelected: (weekday) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedWeekday = weekday);
                },
              ),
              if (cancelled)
                _CancelledBanner(onRestore: _toggleSkip)
              else if (lessons.isNotEmpty)
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _ContextLine(
                    key: ValueKey('$_selectedWeekday-$isToday'),
                    next: next,
                    lessonCount: lessons.length,
                    isToday: isToday,
                  ),
                ),
              if (!cancelled) _CancelBar(onPressed: _toggleSkip),
              if (isToday && !cancelled && _weatherFuture != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 2, 18, 0),
                  child: _WeatherHint(
                    future: _weatherFuture!,
                    nextLessonStart: next.isNotEmpty ? next.first.start : null,
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: lessons.isEmpty && !cancelled
                      ? KeyedSubtree(
                          key: ValueKey('empty'),
                          child: _EmptyDay(),
                        )
                      : KeyedSubtree(
                          key: ValueKey('$_selectedWeekday-$cancelled'),
                          child: _Timeline(
                            lessons: lessons,
                            day: _selectedDay,
                            cancelled: cancelled,
                            activeReminderIds: _activeReminders,
                            scrollController: _scrollController,
                            onToggleReminder: _toggleReminder,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

_LessonStatus _statusOf(Lesson lesson, DateTime day, DateTime now) {
  final start = lesson.startOn(day);
  final end = lesson.endOn(day);
  if (now.isBefore(start)) {
    return start.difference(now).inMinutes <= 10
        ? _LessonStatus.soon
        : _LessonStatus.upcoming;
  }
  return now.isBefore(end) ? _LessonStatus.current : _LessonStatus.past;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.day,
    required this.isToday,
  });

  final String group;
  final DateTime day;
  final bool isToday;

  static final List<String> _weekdayShort = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];
  static final List<String> _weekdayFull = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  static final List<String> _monthGen = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_weekdayShort[day.weekday - 1]} · ${day.day} ${_monthGen[day.month - 1]}'
            .toUpperCase();
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: context.colors.muted,
                ),
              ),
              Spacer(),
              if (isToday)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'СЕГОДНЯ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: context.colors.accent,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            _weekdayFull[day.weekday - 1],
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.1,
              color: context.colors.text,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Группа $group',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.schedule,
    required this.skippedWeekdays,
    required this.selectedWeekday,
    required this.onSelected,
  });

  final WeekSchedule schedule;
  final Set<int> skippedWeekdays;
  final int selectedWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            Expanded(
              child: _WeekCell(
                weekday: weekday,
                date: DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(Duration(days: weekday - now.weekday)),
                isToday: weekday == now.weekday,
                hasLessons: schedule.days.containsKey(weekday),
                skipped: skippedWeekdays.contains(weekday),
                selected: weekday == selectedWeekday,
                onTap: () => onSelected(weekday),
              ),
            ),
            if (weekday < 7) Container(width: 1, height: 24, color: context.colors.border),
          ],
        ],
      ),
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.hasLessons,
    required this.skipped,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final DateTime date;
  final bool isToday;
  final bool hasLessons;
  final bool skipped;
  final bool selected;
  final VoidCallback onTap;

  static final List<String> _names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final accent = skipped ? context.colors.danger : context.colors.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _names[weekday - 1],
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: selected ? accent : context.colors.muted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: selected || isToday ? accent : context.colors.text,
            ),
          ),
          SizedBox(height: 5),
          AnimatedContainer(
            duration: Duration(milliseconds: 180),
            height: 2.5,
            width: selected ? 24 : (hasLessons ? 5 : 0),
            decoration: BoxDecoration(
              color: selected
                  ? accent
                  : (hasLessons && !skipped ? context.colors.border : Colors.transparent),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  const _ContextLine({
    super.key,
    required this.next,
    required this.lessonCount,
    required this.isToday,
  });

  final List<Lesson> next;
  final int lessonCount;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final String text;
    final bool showDot;
    if (isToday) {
      if (next.isNotEmpty) {
        text =
            'Следующая — ${next.first.start} · ${next.first.subject} · через ${_countdownTo(next.first.startOn(DateTime.now()))}';
        showDot = true;
      } else if (lessonCount > 0) {
        text = 'Пары на сегодня закончились';
        showDot = false;
      } else {
        text = 'Сегодня пар нет';
        showDot = false;
      }
    } else {
      text = lessonCount > 0 ? 'Пар: $lessonCount' : 'Пар нет';
      showDot = false;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Row(
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Живой отсчёт до начала пары (Ч М МИН).
  static String _countdownTo(DateTime start) {
    final remain = start.difference(DateTime.now());
    if (remain.isNegative || remain.inMinutes < 1) return 'скоро';
    final minutes = remain.inMinutes;
    if (minutes < 60) return '$minutes мин';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours ч' : '$hours ч $rest мин';
  }
}

class _WeatherHint extends StatelessWidget {
  const _WeatherHint({required this.future, this.nextLessonStart});

  final Future<WeatherData?> future;
  final String? nextLessonStart;

  static bool _isRainy(int code) =>
      (code >= 51 && code <= 67) || (code >= 71 && code <= 86) || (code >= 95 && code <= 99);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(height: 2);
        }
        final data = snapshot.data;
        if (data == null) return SizedBox(height: 2);
        final (label, icon) = wmoInfo(data.current.weatherCode);
        final rainy = _isRainy(data.current.weatherCode);
        final hint = rainy ? ' · возьми зонт' : '';
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: rainy ? context.colors.accent.withValues(alpha: 0.55) : context.colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: rainy ? context.colors.accent : context.colors.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'На улице ${data.current.temperature.round()}°, $label'
                  '${nextLessonStart == null ? '' : ' · к первой паре $nextLessonStart'}$hint',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(18, 10, 18, 2),
      padding: EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: context.colors.dangerSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.colors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy, size: 17, color: context.colors.danger),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'День отменён — пары сегодня не состоятся',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.colors.danger,
              ),
            ),
          ),
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.danger,
              padding: EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text('Вернуть'),
          ),
        ],
      ),
    );
  }
}

/// Ненавязчивая кнопка отмены дня: маленькая, справа, без рамки.
class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 10, 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: context.colors.muted,
            padding: EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          icon: Icon(Icons.event_busy_outlined, size: 14),
          label: Text('Отменить день'),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.lessons,
    required this.day,
    required this.cancelled,
    required this.activeReminderIds,
    required this.scrollController,
    required this.onToggleReminder,
  });

  final List<Lesson> lessons;
  final DateTime day;
  final bool cancelled;
  final Set<int> activeReminderIds;
  final ScrollController scrollController;
  final void Function(Lesson lesson, int index) onToggleReminder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final isLast = index == lessons.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimeBlock(lesson: lesson),
              SizedBox(width: 12),
              _Rail(
                lesson: lesson,
                day: day,
                isFirst: index == 0,
                isLast: isLast,
                cancelled: cancelled,
              ),
              SizedBox(width: 12),
              Expanded(
                child: _LessonCard(
                  lesson: lesson,
                  day: day,
                  cancelled: cancelled,
                  reminderActive: activeReminderIds.contains(
                    NotificationService.preLessonIdFor(day, index),
                  ),
                  onToggleReminder: () => onToggleReminder(lesson, index),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: Padding(
        padding: EdgeInsets.only(top: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.start,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
                color: context.colors.text,
              ),
            ),
            SizedBox(height: 2),
            Text(
              lesson.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                color: context.colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.lesson,
    required this.day,
    required this.isFirst,
    required this.isLast,
    required this.cancelled,
  });

  final Lesson lesson;
  final DateTime day;
  final bool isFirst;
  final bool isLast;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = _statusOf(lesson, day, now);
    final start = lesson.startOn(day);
    final end = lesson.endOn(day);

    // Насколько «пройден» временной слот этой пары.
    final fillFraction = cancelled
        ? 0.0
        : switch (status) {
            _LessonStatus.past => 1.0,
            _LessonStatus.current =>
              (now.difference(start).inMilliseconds /
                      end.difference(start).inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            _LessonStatus.soon || _LessonStatus.upcoming => 0.0,
          };

    final started =
        !cancelled &&
        (status == _LessonStatus.past || status == _LessonStatus.current);
    final dotColor = cancelled
        ? context.colors.danger
        : switch (status) {
            _LessonStatus.past ||
            _LessonStatus.current ||
            _LessonStatus.soon => context.colors.accent,
            _LessonStatus.upcoming => context.colors.muted,
          };
    final segmentColor = started ? context.colors.accent : context.colors.border;
    final dotSize = !cancelled && status == _LessonStatus.current ? 9.0 : 7.0;

    return SizedBox(
      width: 9,
      child: Column(
        children: [
          // Короткий отрезок до точки: у первой пары отсутствует, чтобы линия
          // начиналась ровно от её точки.
          if (!isFirst)
            Align(
              alignment: Alignment.topCenter,
              child: Container(width: 1.75, height: 15, color: segmentColor),
            ),
          Container(
            width: dotSize,
            height: dotSize,
            margin: EdgeInsets.only(top: 3, bottom: 3),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          if (!isLast)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: _accentFlex(fillFraction),
                    child: Container(width: 1.75, color: context.colors.accent),
                  ),
                  Expanded(
                    flex: 1000 - _accentFlex(fillFraction),
                    child: Container(width: 1.75, color: context.colors.border),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _accentFlex(double fraction) {
    return (fraction.clamp(0.0, 1.0) * 1000).round();
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.day,
    required this.cancelled,
    required this.reminderActive,
    required this.onToggleReminder,
  });

  final Lesson lesson;
  final DateTime day;
  final bool cancelled;
  final bool reminderActive;
  final VoidCallback onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(lesson, day, DateTime.now());
    final dimmed = cancelled || status == _LessonStatus.past;
    final live =
        !cancelled &&
        (status == _LessonStatus.current || status == _LessonStatus.soon);

    final meta = [
      if (lesson.type.isNotEmpty) lesson.type,
      if (lesson.teacher.isNotEmpty) lesson.teacher,
      if (lesson.room.isNotEmpty) lesson.room,
    ].join(' · ');

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: live ? context.colors.cardRaised : context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: live ? context.colors.accent.withValues(alpha: 0.75) : context.colors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cancelled) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      margin: EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: context.colors.dangerSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ОТМЕНЁН',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: context.colors.danger,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    lesson.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: context.colors.text,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                  if (live) ...[
                    SizedBox(height: 7),
                    Text(
                      status == _LessonStatus.current
                          ? 'ИДЁТ СЕЙЧАС'
                          : 'ЧЕРЕЗ ${_minutesTo(lesson, day, status)} МИН',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: context.colors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!cancelled)
              SizedBox(
                width: 34,
                height: 30,
                child: IconButton(
                  tooltip: reminderActive
                      ? 'Убрать напоминание'
                      : 'Напомнить о паре за 10 минут',
                  onPressed: onToggleReminder,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  iconSize: 19,
                  icon: AnimatedSwitcher(
                    duration: Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        RotationTransition(turns: animation, child: child),
                    child: Icon(
                      reminderActive
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      key: ValueKey(reminderActive),
                      color: reminderActive ? context.colors.accent : context.colors.muted,
                      size: 19,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _minutesTo(Lesson lesson, DateTime day, _LessonStatus status) {
    final now = DateTime.now();
    if (status == _LessonStatus.current) {
      return lesson.endOn(day).difference(now).inMinutes.clamp(0, 999);
    }
    return lesson.startOn(day).difference(now).inMinutes.clamp(0, 999);
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.coffee_outlined, size: 46, color: context.colors.border),
          SizedBox(height: 12),
          Text(
            'В этот день пар нет',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
