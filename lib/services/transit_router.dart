import '../models/transit_network.dart';

/// Один участок поездки — проезд на линии (с ожиданием на остановке).
class ItineraryLeg {
  const ItineraryLeg({
    required this.line,
    required this.from,
    required this.to,
    required this.stops,
    required this.rideMinutes,
    required this.waitMinutes,
  });

  final TransitLine line;
  final NetStop from;
  final NetStop to;

  /// Полная последовательность остановок участка, включая начальную и конечную.
  final List<NetStop> stops;

  final int rideMinutes;

  /// Ожидание транспорта на остановке перед посадкой.
  final int waitMinutes;

  int get stopsCount => stops.length - 1;
}

/// Готовый вариант маршрута «откуда → куда».
class Itinerary {
  const Itinerary({required this.legs, required this.signature});

  final List<ItineraryLeg> legs;

  /// Подпись из номеров линий и точек пересадки — для отсева дублей.
  final String signature;

  int get transfers => legs.length - 1;

  int get totalMinutes =>
      legs.fold(0, (sum, leg) => sum + leg.rideMinutes + leg.waitMinutes);

  int get stopsCount =>
      legs.fold(0, (sum, leg) => sum + leg.stopsCount);
}

/// Подбор маршрута по демо-сети: прямые поездки и варианты с 1–2 пересадками.
///
/// Живых данных о транспорте Алматы нет, поэтому время считается по
/// расстояниям между остановками, средней скорости и интервалу движения.
class TransitRouter {
  const TransitRouter();

  static const double _rideMetersPerMinute = 350; // ~21 км/ч с остановками
  static const int _transferBufferMinutes = 2;

  List<Itinerary> route({
    required TransitNetwork network,
    required String originId,
    required String destinationId,
    DateTime? now,
  }) {
    if (originId == destinationId) return const [];
    final clock = now ?? DateTime.now();
    final lines = network.lines;
    final found = <String, Itinerary>{};

    void consider(List<TransitLine> chain, List<String> transferStops) {
      final itinerary = _build(
        network: network,
        originId: originId,
        destinationId: destinationId,
        chain: chain,
        transferStops: transferStops,
        now: clock,
      );
      if (itinerary != null) found[itinerary.signature] = itinerary;
    }

    for (final line in lines) {
      if (line.hasPath(originId, destinationId)) {
        consider([line], const []);
      }
    }

    for (final first in lines) {
      if (!first.contains(originId)) continue;
      for (final second in lines) {
        if (identical(second, first) || !second.contains(destinationId)) continue;
        for (final stop in first.sharedStops(second)) {
          if (first.hasPath(originId, stop) &&
              second.hasPath(stop, destinationId)) {
            consider([first, second], [stop]);
          }
        }
      }
    }

    for (final first in lines) {
      if (!first.contains(originId)) continue;
      for (final second in lines) {
        if (identical(second, first)) continue;
        for (final firstTransfer in first.sharedStops(second)) {
          if (!first.hasPath(originId, firstTransfer)) continue;
          for (final third in lines) {
            if (identical(third, first) ||
                identical(third, second) ||
                !third.contains(destinationId)) {
              continue;
            }
            for (final secondTransfer in second.sharedStops(third)) {
              if (second.hasPath(firstTransfer, secondTransfer) &&
                  third.hasPath(secondTransfer, destinationId)) {
                consider([first, second, third], [firstTransfer, secondTransfer]);
              }
            }
          }
        }
      }
    }

    final results = found.values.toList()
      ..sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
    return results.take(4).toList();
  }

  Itinerary? _build({
    required TransitNetwork network,
    required String originId,
    required String destinationId,
    required List<TransitLine> chain,
    required List<String> transferStops,
    required DateTime now,
  }) {
    final byId = network.byId();
    final points = [originId, ...transferStops, destinationId];
    final legs = <ItineraryLeg>[];

    for (var i = 0; i < chain.length; i++) {
      final line = chain[i];
      final fromId = points[i];
      final toId = points[i + 1];
      final from = byId[fromId];
      final to = byId[toId];
      if (from == null || to == null || !line.hasPath(fromId, toId)) return null;

      final stopIds = line.segment(fromId, toId);
      final stops = stopIds.map((id) => byId[id]).whereType<NetStop>().toList();
      if (stops.length < 2) return null;

      var meters = 0.0;
      for (var j = 0; j < stops.length - 1; j++) {
        meters += stops[j].distanceTo(stops[j + 1]);
      }
      final ride = (meters / _rideMetersPerMinute).ceil().clamp(1, 999);

      final wait = i == 0
          ? _waitFor(line.interval, network, now)
          : (line.interval / 2).ceil() + _transferBufferMinutes;

      legs.add(
        ItineraryLeg(
          line: line,
          from: from,
          to: to,
          stops: stops,
          rideMinutes: ride,
          waitMinutes: wait,
        ),
      );
    }

    return Itinerary(
      legs: legs,
      signature: '${chain.map((l) => l.number).join('>')}'
          '|${transferStops.join('>')}',
    );
  }

  /// Сколько минут до ближайшего транспорта линии (оценка по интервалу).
  int _waitFor(int interval, TransitNetwork network, DateTime now) {
    final minuteOfDay = now.hour * 60 + now.minute;
    if (minuteOfDay < network.serviceStart || minuteOfDay > network.serviceEnd) {
      return interval;
    }
    final elapsed = minuteOfDay - network.serviceStart;
    final wait = interval - (elapsed % interval);
    return wait <= 0 ? interval : wait;
  }
}
