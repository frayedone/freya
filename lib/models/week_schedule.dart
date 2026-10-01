import 'lesson.dart';

/// Недельное расписание: день недели (1 = пн … 7 = вс) -> список пар.
class WeekSchedule {
  WeekSchedule({required this.group, required this.days});

  final String group;
  final Map<int, List<Lesson>> days;

  WeekSchedule copyWith({String? group, Map<int, List<Lesson>>? days}) =>
      WeekSchedule(group: group ?? this.group, days: days ?? this.days);

  /// Замена списка пар конкретного дня (с сортировкой по времени начала).
  WeekSchedule withDay(int weekday, List<Lesson> lessons) {
    final next = Map<int, List<Lesson>>.from(days);
    final sorted = List<Lesson>.from(lessons)
      ..sort((a, b) => a.start.compareTo(b.start));
    next[weekday] = sorted;
    return copyWith(days: next);
  }

  static const List<String> weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  String weekdayName(int weekday) => weekdayShort[weekday - 1];

  List<Lesson> lessonsFor(DateTime day) => days[day.weekday] ?? const [];

  factory WeekSchedule.fromJson(Map<String, dynamic> json) {
    final days = <int, List<Lesson>>{};
    for (final item in json['days'] as List? ?? const []) {
      final map = item as Map<String, dynamic>;
      final weekday = map['weekday'] as int;
      final lessons = (map['lessons'] as List? ?? const [])
          .map((lesson) => Lesson.fromJson(lesson as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      days[weekday] = lessons;
    }
    return WeekSchedule(
      group: json['group'] as String? ?? 'Группа',
      days: days,
    );
  }

  Map<String, dynamic> toJson() => {
        'group': group,
        'days': days.entries
            .map((e) => {
                  'weekday': e.key,
                  'lessons': e.value.map((lesson) => lesson.toJson()).toList(),
                })
            .toList(),
      };
}