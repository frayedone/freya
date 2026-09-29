/// Вид городского транспорта.
enum TransitKind {
  bus,
  trolley,
  metro;

  static TransitKind fromString(String value) => switch (value) {
        'trolley' => TransitKind.trolley,
        'metro' => TransitKind.metro,
        _ => TransitKind.bus,
      };

  String get label => switch (this) {
        TransitKind.bus => 'автобус',
        TransitKind.trolley => 'троллейбус',
        TransitKind.metro => 'метро',
      };
}

/// Маршрут: номер, вид и типичный интервал движения (в минутах).
class TransitRoute {
  const TransitRoute({
    required this.number,
    required this.kind,
    required this.interval,
  });

  final String number;
  final TransitKind kind;

  /// Типичный интервал движения, минут (ориентировочно).
  final int interval;

  factory TransitRoute.fromJson(Map<String, dynamic> json) => TransitRoute(
        number: json['number'] as String,
        kind: TransitKind.fromString(json['type'] as String? ?? 'bus'),
        interval: (json['interval'] as num).toInt(),
      );
}

/// Остановка рядом с колледжем: название, расстояние пешком и маршруты.
class TransitStop {
  const TransitStop({
    required this.name,
    required this.distMeters,
    required this.routes,
  });

  final String name;

  /// Расстояние от колледжа пешком, метров.
  final int distMeters;

  /// Маршруты, проходящие через остановку (уже разрезолвены).
  final List<TransitRoute> routes;

  factory TransitStop.fromJson(
    Map<String, dynamic> json,
    Map<String, TransitRoute> byNumber,
  ) =>
      TransitStop(
        name: json['name'] as String,
        distMeters: (json['dist'] as num).toInt(),
        routes: (json['routes'] as List? ?? const [])
            .map((number) => byNumber[number as String])
            .whereType<TransitRoute>()
            .toList(),
      );
}

/// Данные транспорта: заголовок, период движения и остановки.
class TransitData {
  const TransitData({
    required this.college,
    required this.note,
    required this.serviceStart,
    required this.serviceEnd,
    required this.stops,
  });

  final String college;
  final String note;

  /// Начало/конец движения в минутах от полуночи.
  final int serviceStart;
  final int serviceEnd;

  final List<TransitStop> stops;
}
