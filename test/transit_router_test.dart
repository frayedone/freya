import 'package:flutter_test/flutter_test.dart';
import 'package:freya/models/transit_network.dart';
import 'package:freya/models/transport.dart';
import 'package:freya/services/transit_router.dart';

TransitNetwork _network() => TransitNetwork(
      serviceStart: 0,
      serviceEnd: 1440,
      note: '',
      stops: [
        const NetStop(id: 'a', name: 'A', lat: 43.2400, lng: 76.9500),
        const NetStop(id: 'b', name: 'B', lat: 43.2400, lng: 76.9600),
        const NetStop(id: 'c', name: 'C', lat: 43.2400, lng: 76.9700),
        const NetStop(id: 'd', name: 'D', lat: 43.2400, lng: 76.9800),
      ],
      lines: const [
        TransitLine(
          number: '1',
          kind: TransitKind.bus,
          interval: 10,
          stopIds: ['a', 'b', 'c'],
        ),
        TransitLine(
          number: '2',
          kind: TransitKind.bus,
          interval: 10,
          stopIds: ['c', 'd'],
        ),
      ],
    );

void main() {
  const router = TransitRouter();

  test('находит прямую поездку без пересадок', () {
    final results = router.route(
      network: _network(),
      originId: 'a',
      destinationId: 'c',
      now: DateTime(2026, 1, 1, 12),
    );
    expect(results, isNotEmpty);
    final direct = results.first;
    expect(direct.transfers, 0);
    expect(direct.legs.single.line.number, '1');
    expect(direct.totalMinutes, greaterThan(0));
  });

  test('находит маршрут с одной пересадкой', () {
    final results = router.route(
      network: _network(),
      originId: 'a',
      destinationId: 'd',
      now: DateTime(2026, 1, 1, 12),
    );
    expect(results, isNotEmpty);
    final best = results.first;
    expect(best.transfers, 1);
    expect(best.legs.map((l) => l.line.number).toList(), ['1', '2']);
    expect(best.legs.last.from.id, 'c');
  });

  test('возвращает пусто для одинаковых точек', () {
    final results = router.route(
      network: _network(),
      originId: 'a',
      destinationId: 'a',
    );
    expect(results, isEmpty);
  });
}
