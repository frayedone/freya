import 'dart:math' as math;

import 'transport.dart';

/// Остановка демо-сети: координаты и название.
class NetStop {
  const NetStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  factory NetStop.fromJson(Map<String, dynamic> json) => NetStop(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// Расстояние до другой остановки, метров (формула гаверсинуса).
  double distanceTo(NetStop other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

/// Линия транспорта: упорядоченная последовательность остановок.
class TransitLine {
  const TransitLine({
    required this.number,
    required this.kind,
    required this.interval,
    required this.stopIds,
  });

  final String number;
  final TransitKind kind;
  final int interval;
  final List<String> stopIds;

  factory TransitLine.fromJson(Map<String, dynamic> json) => TransitLine(
        number: json['number'] as String,
        kind: TransitKind.fromString(json['type'] as String? ?? 'bus'),
        interval: (json['interval'] as num).toInt(),
        stopIds: (json['stops'] as List? ?? const [])
            .map((value) => value as String)
            .toList(),
      );

  bool contains(String stopId) => stopIds.contains(stopId);

  int? indexOf(String stopId) {
    final index = stopIds.indexOf(stopId);
    return index == -1 ? null : index;
  }

  /// Есть ли путь от [from] до [to] в правильном направлении.
  bool hasPath(String from, String to) {
    final a = indexOf(from);
    final b = indexOf(to);
    return a != null && b != null && a < b;
  }

  /// Общие остановки с другой линией (кандидаты на пересадку).
  List<String> sharedStops(TransitLine other) {
    final otherIds = other.stopIds.toSet();
    return stopIds.where(otherIds.contains).toList();
  }

  /// Остановки на отрезке пути, включая начальную и конечную.
  List<String> segment(String from, String to) {
    final a = indexOf(from);
    final b = indexOf(to);
    if (a == null || b == null || a > b) return const [];
    return stopIds.sublist(a, b + 1);
  }
}

/// Демо-сеть транспорта для построения маршрута «откуда → куда».
class TransitNetwork {
  const TransitNetwork({
    required this.stops,
    required this.lines,
    required this.serviceStart,
    required this.serviceEnd,
    required this.note,
  });

  final List<NetStop> stops;
  final List<TransitLine> lines;
  final int serviceStart;
  final int serviceEnd;
  final String note;

  NetStop? stopById(String id) {
    for (final stop in stops) {
      if (stop.id == id) return stop;
    }
    return null;
  }

  Map<String, NetStop> byId() => {for (final s in stops) s.id: s};
}
