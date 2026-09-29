/// Тип городского транспорта.
enum TransportType {
  bus,
  trolley,
  tram,
  metro;

  static TransportType fromString(String value) => switch (value) {
        'bus' => TransportType.bus,
        'trolley' => TransportType.trolley,
        'tram' => TransportType.tram,
        'metro' => TransportType.metro,
        _ => TransportType.bus,
      };
}

/// Маршрут городского транспорта: номер, описание, остановки по ходу движения.
class TransportRoute {
  const TransportRoute({
    required this.number,
    required this.name,
    required this.type,
    required this.stops,
  });

  final String number;
  final String name;
  final TransportType type;

  /// Остановки в порядке следования.
  final List<String> stops;

  factory TransportRoute.fromJson(Map<String, dynamic> json) => TransportRoute(
        number: json['number'] as String,
        name: json['name'] as String? ?? '',
        type: TransportType.fromString(json['transport'] as String? ?? 'bus'),
        stops: (json['stops'] as List? ?? const [])
            .map((stop) => stop as String)
            .toList(),
      );
}