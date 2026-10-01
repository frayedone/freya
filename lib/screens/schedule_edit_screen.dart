import 'dart:async';

import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/week_schedule.dart';
import '../services/notifications/notifications.dart';
import '../services/schedule_service.dart';
import '../theme.dart';

/// Редактор собственного расписания: группа, пары и время.
///
/// Каждая пара хранит своё начало и конец, поэтому «звонки» задаются
/// прямо здесь — отдельного списка расписания звонков не нужно.
class ScheduleEditScreen extends StatefulWidget {
  const ScheduleEditScreen({super.key});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final ScheduleService _service = const ScheduleService();

  WeekSchedule? _schedule;
  int _weekday = DateTime.now().weekday;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final schedule = await _service.load();
    if (!mounted) return;
    setState(() => _schedule = schedule);
  }

  Future<void> _commit(WeekSchedule next) async {
    setState(() => _saving = true);
    await _service.save(next);
    // В утреннем уведомлении содержится список пар — обновляем его.
    unawaited(NotificationService.instance.refreshDailyAgendas());
    if (!mounted) return;
    setState(() {
      _schedule = next;
      _saving = false;
    });
  }

  Future<void> _renameGroup() async {
    final schedule = _schedule;
    if (schedule == null) return;
    final controller = TextEditingController(text: schedule.group);
    final group = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Моя группа'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: 'Например, ИС-22'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (group == null || group.isEmpty || !mounted) return;
    await _commit(schedule.copyWith(group: group));
  }

  Future<void> _editLesson({Lesson? existing, int? index}) async {
    final schedule = _schedule;
    if (schedule == null) return;
    final result = await showModalBottomSheet<Lesson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (context) => _LessonSheet(lesson: existing),
    );
    if (result == null || !mounted) return;

    final lessons = List<Lesson>.from(schedule.days[_weekday] ?? const []);
    if (existing != null && index != null && index < lessons.length) {
      lessons[index] = result;
    } else {
      lessons.add(result);
    }
    await _commit(schedule.withDay(_weekday, lessons));
  }

  Future<void> _deleteLesson(int index) async {
    final schedule = _schedule;
    if (schedule == null) return;
    final lessons = List<Lesson>.from(schedule.days[_weekday] ?? const []);
    if (index < 0 || index >= lessons.length) return;
    final removed = lessons.removeAt(index);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить пару?'),
        content: Text('${removed.subject}\n${removed.start}–${removed.end}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _commit(schedule.withDay(_weekday, lessons));
  }

  Future<void> _clearDay() async {
    final schedule = _schedule;
    if (schedule == null) return;
    final lessons = schedule.days[_weekday] ?? const <Lesson>[];
    if (lessons.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Убрать все пары?'),
        content: Text(
          'День: ${WeekSchedule.weekdayShort[_weekday - 1]}. '
          'Будет удалено пар: ${lessons.length}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            child: Text('Убрать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _commit(schedule.withDay(_weekday, const []));
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Вернуть исходное расписание?'),
        content: Text('Все твои правки будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            child: Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final schedule = await _service.reset();
    if (!mounted) return;
    setState(() => _schedule = schedule);
    unawaited(NotificationService.instance.refreshDailyAgendas());
    _showMessage('Расписание возвращено к исходному');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    final lessons = schedule?.days[_weekday] ?? const <Lesson>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(schedule?.group ?? 'Расписание'),
        actions: [
          if (schedule != null && lessons.isNotEmpty)
            IconButton(
              tooltip: 'Убрать пары дня',
              onPressed: _clearDay,
              icon: Icon(Icons.delete_sweep_outlined, size: 20, color: context.colors.muted),
            ),
          if (schedule != null)
            IconButton(
              tooltip: 'Переименовать группу',
              onPressed: _renameGroup,
              icon: Icon(Icons.edit_outlined, size: 20, color: context.colors.muted),
            ),
          if (schedule != null)
            IconButton(
              tooltip: 'Сбросить к исходному',
              onPressed: _resetAll,
              icon: Icon(Icons.restart_alt, size: 20, color: context.colors.muted),
            ),
        ],
      ),
      floatingActionButton: schedule == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editLesson(),
              backgroundColor: context.colors.accent,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add, size: 20),
              label: Text('Добавить пару'),
            ),
      body: schedule == null
          ? Center(
              child: CircularProgressIndicator(color: context.colors.accent),
            )
          : Column(
              children: [
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: 7,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final weekday = index + 1;
                      final selected = weekday == _weekday;
                      return GestureDetector(
                        onTap: () => setState(() => _weekday = weekday),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? context.colors.accentSoft : context.colors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? context.colors.accent : context.colors.border,
                            ),
                          ),
                          child: Text(
                            WeekSchedule.weekdayShort[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? context.colors.accent : context.colors.muted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_saving)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: context.colors.accent,
                  ),
                Expanded(
                  child: lessons.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 34,
                                color: context.colors.border,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'В этот день пар нет',
                                style: TextStyle(color: context.colors.muted, fontSize: 13),
                              ),
                              SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => _editLesson(),
                                icon: Icon(Icons.add, size: 18),
                                label: Text('Добавить пару'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                          itemCount: lessons.length,
                          itemBuilder: (context, index) {
                            final lesson = lessons[index];
                            return Dismissible(
                              key: ValueKey('${_weekday}_${lesson.start}_${lesson.subject}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: context.colors.danger,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteLesson(index),
                              child: InkWell(
                                onTap: () => _editLesson(existing: lesson, index: index),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: context.colors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: context.colors.accentSoft,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: context.colors.accent,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lesson.subject,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: context.colors.text,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              [
                                                '${lesson.start}–${lesson.end}',
                                                if (lesson.type.isNotEmpty) lesson.type,
                                                if (lesson.room.isNotEmpty) lesson.room,
                                              ].join(' · '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.colors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: context.colors.border,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Форма редактирования одной пары.
class _LessonSheet extends StatefulWidget {
  const _LessonSheet({this.lesson});

  final Lesson? lesson;

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  late final TextEditingController _subject =
      TextEditingController(text: widget.lesson?.subject ?? '');
  late final TextEditingController _type =
      TextEditingController(text: widget.lesson?.type ?? '');
  late final TextEditingController _room =
      TextEditingController(text: widget.lesson?.room ?? '');
  late final TextEditingController _teacher =
      TextEditingController(text: widget.lesson?.teacher ?? '');

  late TimeOfDay _start = _parse(widget.lesson?.start) ?? const TimeOfDay(hour: 9, minute: 0);
  late TimeOfDay _end = _parse(widget.lesson?.end) ?? const TimeOfDay(hour: 10, minute: 30);

  @override
  void initState() {
    super.initState();
    // Чтобы кнопка «Сохранить» включалась по мере ввода предмета.
    _subject.addListener(_onSubjectChanged);
  }

  void _onSubjectChanged() => setState(() {});

  static TimeOfDay? _parse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _format(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _subject.dispose();
    _type.dispose();
    _room.dispose();
    _teacher.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lesson == null ? 'Новая пара' : 'Изменить пару',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.text,
              ),
            ),
            SizedBox(height: 16),
            _Field(controller: _subject, label: 'Предмет', autofocus: widget.lesson == null),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Field(controller: _type, label: 'Тип (лекция, практика)')),
                SizedBox(width: 10),
                Expanded(child: _Field(controller: _room, label: 'Аудитория')),
              ],
            ),
            SizedBox(height: 10),
            _Field(controller: _teacher, label: 'Преподаватель'),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Начало',
                    value: _format(_start),
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _TimeButton(
                    label: 'Конец',
                    value: _format(_end),
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.colors.border),
                      foregroundColor: context.colors.muted,
                    ),
                    child: Text('Отмена'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _subject.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                              Lesson(
                                subject: _subject.text.trim(),
                                type: _type.text.trim(),
                                room: _room.text.trim(),
                                teacher: _teacher.text.trim(),
                                start: _format(_start),
                                end: _format(_end),
                              ),
                            ),
                    child: Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.autofocus = false});

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: TextStyle(color: context.colors.text, fontSize: 15),
      cursorColor: context.colors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.muted, fontSize: 13.5),
        filled: true,
        fillColor: context.colors.cardRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.cardRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 16, color: context.colors.muted),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}