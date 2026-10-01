import 'dart:async';

import 'package:flutter/material.dart';

import '../models/transit_network.dart';
import '../models/transport.dart';
import '../services/transit_router.dart';
import '../services/transport_service.dart';
import '../theme.dart';

/// Транспорт: прибытие у остановок рядом с колледжем и построение маршрута.
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Транспорт'), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Остановка')),
                ButtonSegment(value: 1, label: Text('Маршрут')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (values) => setState(() => _mode = values.first),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: [
                _StopArrivals(),
                _RoutePlanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Прибытие транспорта у остановок рядом с колледжем.
///
/// Считается по типовому интервалу движения маршрута: живых данных о
/// транспорте Алматы нет, поэтому это оценка, а не точный прогноз.
class _StopArrivals extends StatefulWidget {
  @override
  State<_StopArrivals> createState() => _StopArrivalsState();
}

class _StopArrivalsState extends State<_StopArrivals> {
  Future<TransitData>? _future;
  int _stopIndex = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _future = TransportService().load();
    _ticker = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransitData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.accent),
          );
        }
        if (data.stops.isEmpty) {
          return Center(
            child: Text(
              'Нет данных',
              style: TextStyle(color: context.colors.muted, fontSize: 13),
            ),
          );
        }
        final stop = data.stops[_stopIndex.clamp(0, data.stops.length - 1)];
        final now = DateTime.now();
        final arrivals = _arrivals(stop, data, now);

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              data.college,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.colors.text,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.stops.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, index) => _StopChip(
                  stop: data.stops[index],
                  selected: index == _stopIndex,
                  onTap: () => setState(() => _stopIndex = index),
                ),
              ),
            ),
            SizedBox(height: 16),
            ...arrivals.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _ArrivalTile(
                  route: item.route,
                  minutes: item.minutes,
                  clock: item.clock,
                  running: item.minutes != null,
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              data.note,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Оценка ожидания: равномерный интервал начиная с начала движения.
  List<_Arrival> _arrivals(TransitStop stop, TransitData data, DateTime now) {
    final minuteOfDay = now.hour * 60 + now.minute;
    final beforeStart = minuteOfDay < data.serviceStart;
    final afterEnd = minuteOfDay > data.serviceEnd;

    final result = <_Arrival>[];
    for (final route in stop.routes) {
      int? minutes;
      var clock = '';
      if (!beforeStart && !afterEnd) {
        final elapsed = minuteOfDay - data.serviceStart;
        minutes = route.interval - (elapsed % route.interval);
        final arrival = now.add(Duration(minutes: minutes));
        clock = '${_two(arrival.hour)}:${_two(arrival.minute)}';
      }
      result.add(_Arrival(route, minutes, clock));
    }
    result.sort((a, b) {
      if (a.minutes == null) return 1;
      if (b.minutes == null) return -1;
      return a.minutes!.compareTo(b.minutes!);
    });
    return result;
  }
}

/// Построение маршрута «откуда → куда» с пересадками.
class _RoutePlanner extends StatefulWidget {
  @override
  State<_RoutePlanner> createState() => _RoutePlannerState();
}

class _RoutePlannerState extends State<_RoutePlanner> {
  TransitNetwork? _network;
  String? _origin;
  String? _destination;
  List<Itinerary>? _results;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final network = await TransportService().loadNetwork();
    if (!mounted) return;
    setState(() {
      _network = network;
      if (network.stops.isNotEmpty) {
        _origin = _pick(network, 'college', 0);
        _destination = _pick(network, 'kok_tobe_base', network.stops.length - 1);
      }
    });
  }

  static String _pick(TransitNetwork network, String id, int fallback) {
    final index = network.stops.indexWhere((s) => s.id == id);
    return network.stops[index == -1 ? fallback : index].id;
  }

  void _swap() {
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
      _results = null;
    });
  }

  void _build() {
    final network = _network;
    final origin = _origin;
    final destination = _destination;
    if (network == null || origin == null || destination == null) return;
    final results = const TransitRouter().route(
      network: network,
      originId: origin,
      destinationId: destination,
    );
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final network = _network;
    if (network == null) {
      return Center(child: CircularProgressIndicator(color: context.colors.accent));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(14, 14, 6, 14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _Endpoint(
                icon: Icons.trip_origin,
                color: context.colors.accent,
                label: 'Откуда',
                value: _origin,
                stops: network.stops,
                onChanged: (value) => setState(() {
                  _origin = value;
                  _results = null;
                }),
              ),
              Padding(
                padding: EdgeInsets.only(left: 11),
                child: Row(
                  children: [
                    Container(width: 2, height: 18, color: context.colors.border),
                    Spacer(),
                    IconButton(
                      tooltip: 'Поменять местами',
                      onPressed: _swap,
                      icon: Icon(
                        Icons.swap_vert,
                        color: context.colors.muted,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
              _Endpoint(
                icon: Icons.place,
                color: context.colors.danger,
                label: 'Куда',
                value: _destination,
                stops: network.stops,
                onChanged: (value) => setState(() {
                  _destination = value;
                  _results = null;
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _build,
            icon: Icon(Icons.directions, size: 20),
            label: Text('Построить маршрут'),
          ),
        ),
        SizedBox(height: 18),
        if (_results != null)
          ..._buildResults(context, network, _results!)
        else
          _Hint(),
        SizedBox(height: 14),
        Text(
          network.note,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults(
    BuildContext context,
    TransitNetwork network,
    List<Itinerary> results,
  ) {
    if (results.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.wrong_location_outlined, color: context.colors.muted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Маршрут не найден. В демо-сети не так много линий — попробуй '
                  'другие остановки.',
                  style: TextStyle(color: context.colors.muted, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      Text(
        'Вариантов: ${results.length}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.colors.muted,
        ),
      ),
      SizedBox(height: 10),
      for (final itinerary in results)
        _ItineraryCard(itinerary: itinerary, network: network),
    ];
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.stops,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final List<NetStop> stops;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6, right: 12),
          child: Icon(icon, size: 18, color: color),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: context.colors.cardRaised,
            icon: Icon(Icons.expand_more, color: context.colors.muted, size: 20),
            style: TextStyle(fontSize: 14, color: context.colors.text),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: context.colors.muted, fontSize: 12.5),
              isDense: true,
            ),
            items: [
              for (final stop in stops)
                DropdownMenuItem(
                  value: stop.id,
                  child: Text(stop.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(Icons.alt_route, size: 42, color: context.colors.border),
          SizedBox(height: 10),
          Text(
            'Выбери «откуда» и «куда»',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.muted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Покажем маршрут с пересадками и когда придёт транспорт.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  const _ItineraryCard({required this.itinerary, required this.network});

  final Itinerary itinerary;
  final TransitNetwork network;

  @override
  Widget build(BuildContext context) {
    final first = itinerary.legs.first;
    final arrival = DateTime.now().add(Duration(minutes: first.waitMinutes));
    final arrivalClock = '${_two(arrival.hour)}:${_two(arrival.minute)}';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '≈ ${itinerary.totalMinutes} мин',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.colors.text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${_transfersLabel(itinerary.transfers)} · '
                    '${itinerary.stopsCount} ${_stopsWord(itinerary.stopsCount)}',
                    style: TextStyle(fontSize: 11.5, color: context.colors.muted),
                  ),
                ],
              ),
              Spacer(),
              if (itinerary.transfers == 0)
                _Badge(
                  text: 'Без пересадок',
                  color: context.colors.accent,
                  background: context.colors.accentSoft,
                )
              else
                _Badge(
                  text: '${itinerary.transfers} ${_transferWord(itinerary.transfers)}',
                  color: context.colors.muted,
                  background: context.colors.cardRaised,
                ),
            ],
          ),
          SizedBox(height: 12),
          for (var i = 0; i < itinerary.legs.length; i++)
            _LegRow(
              leg: itinerary.legs[i],
              isFirst: i == 0,
              isLast: i == itinerary.legs.length - 1,
            ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_kindIcon(first.line.kind), size: 16, color: context.colors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_kindName(first.line.kind)} ${first.line.number} придёт '
                    'через ${first.waitMinutes} мин (в $arrivalClock)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg, required this.isFirst, required this.isLast});

  final ItineraryLeg leg;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_kindIcon(leg.line.kind), size: 14, color: context.colors.accent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.75,
                      color: context.colors.border,
                      margin: EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_kindName(leg.line.kind)} ${leg.line.number} · '
                    '${leg.rideMinutes} мин',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.text,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '${leg.from.name} → ${leg.to.name}',
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                  if (!isFirst) ...[
                    SizedBox(height: 2),
                    Text(
                      'Пересадка, ожидание ~${leg.waitMinutes} мин',
                      style: TextStyle(fontSize: 11, color: context.colors.muted),
                    ),
                  ] else ...[
                    SizedBox(height: 2),
                    Text(
                      'Остановок: ${leg.stopsCount} · ожидание ~${leg.waitMinutes} мин',
                      style: TextStyle(fontSize: 11, color: context.colors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Arrival {
  const _Arrival(this.route, this.minutes, this.clock);

  final TransitRoute route;
  final int? minutes;
  final String clock;
}

class _StopChip extends StatelessWidget {
  const _StopChip({
    required this.stop,
    required this.selected,
    required this.onTap,
  });

  final TransitStop stop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.colors.accentSoft : context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? context.colors.accent : context.colors.border),
        ),
        child: Text(
          '${stop.name} · ${stop.distMeters} м',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? context.colors.accent : context.colors.muted,
          ),
        ),
      ),
    );
  }
}

class _ArrivalTile extends StatelessWidget {
  const _ArrivalTile({
    required this.route,
    required this.minutes,
    required this.clock,
    required this.running,
  });

  final TransitRoute route;
  final int? minutes;
  final String clock;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final soon = running && minutes != null && minutes! <= 5;
    final eta = !running
        ? '—'
        : soon
            ? 'через $minutes мин'
            : '≈ $minutes мин';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: soon ? context.colors.accent.withValues(alpha: 0.5) : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: soon ? context.colors.accentSoft : context.colors.cardRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_kindIcon(route.kind), size: 13, color: context.colors.accent),
                SizedBox(height: 2),
                Text(
                  route.number,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.colors.accent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: soon ? context.colors.accent : context.colors.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  running
                      ? '${route.kind.label} · рейс в $clock · каждые ~${route.interval} мин'
                      : '${route.kind.label} · движение завершено',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(TransitKind kind) => switch (kind) {
      TransitKind.bus => Icons.directions_bus,
      TransitKind.trolley => Icons.electric_bolt,
      TransitKind.metro => Icons.subway,
    };

String _kindName(TransitKind kind) => switch (kind) {
      TransitKind.bus => 'Автобус',
      TransitKind.trolley => 'Троллейбус',
      TransitKind.metro => 'Метро',
    };

String _two(int value) => value.toString().padLeft(2, '0');

String _transfersLabel(int count) {
  if (count == 0) return 'Без пересадок';
  return '$count ${_transferWord(count)}';
}

String _transferWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'пересадка';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
    return 'пересадки';
  }
  return 'пересадок';
}

String _stopsWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'остановка';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
    return 'остановки';
  }
  return 'остановок';
}
