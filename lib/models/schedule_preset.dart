import 'week_schedule.dart';

/// Именованный набор расписания (пресет).
///
/// Пресеты хранятся локально и позволяют быстро переключаться между
/// группами или вариантами недели, не теряя правки.
class SchedulePreset {
  const SchedulePreset({
    required this.id,
    required this.name,
    required this.schedule,
  });

  final String id;
  final String name;
  final WeekSchedule schedule;

  String get group => schedule.group;

  int get lessonCount =>
      schedule.days.values.fold(0, (sum, lessons) => sum + lessons.length);

  SchedulePreset copyWith({String? name, WeekSchedule? schedule}) => SchedulePreset(
        id: id,
        name: name ?? this.name,
        schedule: schedule ?? this.schedule,
      );

  factory SchedulePreset.fromJson(Map<String, dynamic> json) => SchedulePreset(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Пресет',
        schedule: WeekSchedule.fromJson(
          json['schedule'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'schedule': schedule.toJson(),
      };
}
