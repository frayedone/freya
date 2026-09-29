import 'dart:async';

import 'package:flutter/material.dart';

import '../models/transport.dart';
import '../services/transport_service.dart';
import '../theme.dart';

/// Время прибытия транспорта у остановок рядом с колледжем.
///
/// Считается по типовому интервалу движения маршрута: живых данных о
/// транспорте Алматы нет, поэтому это оценка, а не точный прогноз.
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  Future<TransitData>? _future;
  int _stopIndex = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _future = const TransportService().load();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Транспорт'), centerTitle: false),
      body: FutureBuilder<TransitData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: CircularProgressIndicator(color: kAccent),
            );
          }
          if (data.stops.isEmpty) {
            return const Center(
              child: Text(
                'Нет данных',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
            );
          }
          final stop = data.stops[_stopIndex.clamp(0, data.stops.length - 1)];
          final now = DateTime.now();
          final arrivals = _arrivals(stop, data, now);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                data.college,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kText,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.stops.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _StopChip(
                    stop: data.stops[index],
                    selected: index == _stopIndex,
                    onTap: () => setState(() => _stopIndex = index),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...arrivals.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ArrivalTile(
                    route: item.route,
                    minutes: item.minutes,
                    clock: item.clock,
                    running: item.minutes != null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
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

  static String _two(int value) => value.toString().padLeft(2, '0');
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kAccentSoft : kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kAccent : kBorder),
        ),
        child: Text(
          '${stop.name} · ${stop.distMeters} м',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? kAccent : kMuted,
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
    final icon = switch (route.kind) {
      TransitKind.bus => Icons.directions_bus,
      TransitKind.trolley => Icons.electric_bolt,
      TransitKind.metro => Icons.subway,
    };
    final eta = !running
        ? '—'
        : soon
            ? 'через $minutes мин'
            : '≈ $minutes мин';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: soon ? kAccent.withValues(alpha: 0.5) : kBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: soon ? kAccentSoft : kCardRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: kAccent),
                const SizedBox(height: 2),
                Text(
                  route.number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: soon ? kAccent : kText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  running
                      ? '${route.kind.label} · рейс в $clock · каждые ~${route.interval} мин'
                      : '${route.kind.label} · движение завершено',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
