class Lesson {
  const Lesson({
    required this.subject,
    required this.type,
    required this.room,
    required this.teacher,
    required this.start,
    required this.end,
  });

  final String subject;
  final String type;
  final String room;
  final String teacher;

  /// Время начала пары в формате "HH:mm".
  final String start;

  /// Время окончания пары в формате "HH:mm".
  final String end;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        subject: json['subject'] as String,
        type: json['type'] as String? ?? '',
        room: json['room'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        start: json['start'] as String,
        end: json['end'] as String,
      );

  /// Пара проходит в 09:00..10:30, а `day` — конкретный день недели.
  bool isActiveAt(DateTime time, DateTime day) {
    final s = startOn(day);
    final e = endOn(day);
    return !time.isBefore(s) && time.isBefore(e);
  }

  DateTime startOn(DateTime day) => _timeOn(day, start);
  DateTime endOn(DateTime day) => _timeOn(day, end);

  static DateTime _timeOn(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'type': type,
        'room': room,
        'teacher': teacher,
        'start': start,
        'end': end,
      };
}