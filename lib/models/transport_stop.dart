/// Тип точки на карте транспорта.
enum TransportStopKind { stop, metro, college }

/// Геоточка: остановки, станции метро и колледж с реальными координатами.
class TransportStop {
  const TransportStop({
    required this.name,
    required this.lat,
    required this.lon,
    required this.routes,
    required this.kind,
    this.nearCollege = false,
  });

  final String name;
  final double lat;
  final double lon;

  /// Номера маршрутов, проходящих через точку (справочно).
  final List<String> routes;

  final TransportStopKind kind;

  /// Остановка находится рядом с колледжем.
  final bool nearCollege;

  factory TransportStop.fromJson(Map<String, dynamic> json) => TransportStop(
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        routes: (json['routes'] as List? ?? const [])
            .map((route) => route as String)
            .toList(),
        kind: switch (json['kind'] as String? ?? 'stop') {
          'metro' => TransportStopKind.metro,
          'college' => TransportStopKind.college,
          _ => TransportStopKind.stop,
        },
        nearCollege: json['nearCollege'] as bool? ?? false,
      );
}