import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transport_route.dart';
import '../models/transport_stop.dart';
import '../services/location_service.dart';
import '../services/transport_service.dart';
import '../theme.dart';
import '../utils/geo.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  Future<(List<TransportRoute>, List<TransportStop>)>? _future;
  String _query = '';
  TransportType? _filter;

  Position? _position;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (_canUseGps) {
      _locate();
    }
  }

  bool get _canUseGps =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<(List<TransportRoute>, List<TransportStop>)> _load() async {
    final routes = await const TransportService().load();
    final stops = await const TransportService().loadStops();
    return (routes, stops);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final position = await LocationService.currentPosition();
    if (!mounted) return;
    setState(() {
      _position = position;
      _locating = false;
    });
  }

  Future<void> _openMaps() async {
    final url = LocationService.mapsRouteUrl(
      _position?.latitude,
      _position?.longitude,
    );
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('Не удалось открыть карты');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Транспорт'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _future = _load();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              style: const TextStyle(color: kText, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск: номер или остановка',
                hintStyle: const TextStyle(color: kMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: kMuted),
                filled: true,
                fillColor: kCard,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kAccent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Все',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Автобус',
                  selected: _filter == TransportType.bus,
                  onTap: () => setState(() => _filter = TransportType.bus),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Троллейбус',
                  selected: _filter == TransportType.trolley,
                  onTap: () => setState(() => _filter = TransportType.trolley),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Метро',
                  selected: _filter == TransportType.metro,
                  onTap: () => setState(() => _filter = TransportType.metro),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<(List<TransportRoute>, List<TransportStop>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: kAccent),
                  );
                }
                final routes = snapshot.data?.$1 ?? const <TransportRoute>[];
                final stops = snapshot.data?.$2 ?? const <TransportStop>[];
                final filtered = _applyFilters(routes);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _CollegeCard(
                      position: _position,
                      locating: _locating,
                      canUseGps: _canUseGps,
                      onLocate: _locate,
                      onMaps: _openMaps,
                    ),
                    if (_position != null) ...[
                      const SizedBox(height: 14),
                      _SectionHeader('Ближайшие остановки ко мне'),
                      const SizedBox(height: 6),
                      ..._nearestTo(_position!, stops, limit: 3),
                    ],
                    const SizedBox(height: 14),
                    const _SectionHeader('Остановки у колледжа'),
                    const SizedBox(height: 6),
                    ..._nearestTo(
                      Position(
                        latitude: LocationService.collegeLat,
                        longitude: LocationService.collegeLon,
                        timestamp: DateTime.now(),
                        accuracy: 0,
                        altitude: 0,
                        altitudeAccuracy: 0,
                        heading: 0,
                        headingAccuracy: 0,
                        speed: 0,
                        speedAccuracy: 0,
                      ),
                      stops.where((stop) => stop.kind != TransportStopKind.college).toList(),
                      limit: 3,
                    ),
                    if (filtered.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _SectionHeader(
                        'Справочник маршрутов',
                        trailing: 'можно искать по названию',
                      ),
                      const SizedBox(height: 8),
                      ...filtered.map(
                        (route) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RouteCard(
                            route: route,
                            onTap: () => _showRoute(route),
                          ),
                        ),
                      ),
                    ] else if (_query.isNotEmpty || _filter != null) ...[
                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(color: kMuted, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const SafeArea(
                      top: false,
                      child: Text(
                        'Справочная информация: маршруты и остановки. '
                        'Живые позиции автобусов в Алматы пока недоступны.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 10.5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TransportRoute> _applyFilters(List<TransportRoute> all) {
    final query = _query.toLowerCase();
    return all.where((route) {
      if (_filter != null && route.type != _filter) return false;
      if (query.isEmpty) return true;
      if (route.number.toLowerCase().contains(query)) return true;
      if (route.name.toLowerCase().contains(query)) return true;
      return route.stops.any(
        (stop) => stop.toLowerCase().contains(query),
      );
    }).toList();
  }

  List<Widget> _nearestTo(
    Position from,
    List<TransportStop> stops, {
    required int limit,
  }) {
    final sorted = [...stops]..sort(
        (a, b) => haversineKm(from.latitude, from.longitude, a.lat, a.lon)
            .compareTo(
                haversineKm(from.latitude, from.longitude, b.lat, b.lon)),
      );
    return sorted.take(limit).map((stop) {
      final distance = haversineKm(
        from.latitude,
        from.longitude,
        stop.lat,
        stop.lon,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _StopTile(stop: stop, distance: distance),
      );
    }).toList();
  }

  void _showRoute(TransportRoute route) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final stops = route.stops;
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      decoration: BoxDecoration(
                        color: kBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _TypeBadge(
                          type: route.type,
                          number: route.number,
                          large: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            route.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: stops.length,
                      itemBuilder: (context, index) {
                        final isFirst = index == 0;
                        final isLast = index == stops.length - 1;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 18,
                                child: Column(
                                  children: [
                                    SizedBox(height: isFirst ? 0 : 6),
                                    if (!isFirst)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: kBorder,
                                        ),
                                      ),
                                    Container(
                                      width: isFirst || isLast ? 10 : 8,
                                      height: isFirst || isLast ? 10 : 8,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isLast || isFirst
                                            ? kAccent
                                            : kMuted,
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: kBorder,
                                        ),
                                      ),
                                    SizedBox(height: isLast ? 0 : 6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: Text(
                                    stops[index],
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isFirst || isLast
                                          ? kText
                                          : kMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: kMuted,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 11, color: kBorder),
          ),
      ],
    );
  }
}

class _CollegeCard extends StatelessWidget {
  const _CollegeCard({
    required this.position,
    required this.locating,
    required this.canUseGps,
    required this.onLocate,
    required this.onMaps,
  });

  final Position? position;
  final bool locating;
  final bool canUseGps;
  final VoidCallback onLocate;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    final distance = position == null
        ? null
        : haversineKm(
            position!.latitude,
            position!.longitude,
            LocationService.collegeLat,
            LocationService.collegeLon,
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 18, color: kAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Центрально-Азиатский технико-экономический колледж',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kText,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            LocationService.collegeAddress,
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMaps,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: const BorderSide(color: kAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 17),
                  label: const Text(
                    'Маршрут',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: locating ? null : (canUseGps ? onLocate : null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kMuted,
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: locating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kMuted,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 17),
                  label: Text(
                    distance == null
                        ? (canUseGps ? 'GPS' : 'Нет GPS')
                        : 'GPS · ${prettyDistanceKm(distance)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.distance});

  final TransportStop stop;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final icon = switch (stop.kind) {
      TransportStopKind.metro => Icons.subway_outlined,
      TransportStopKind.college => Icons.school_outlined,
      TransportStopKind.stop => Icons.directions_bus_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stop.nearCollege ? kAccent.withValues(alpha: 0.4) : kBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: stop.nearCollege ? kAccentSoft : kCardRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: kAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kText,
                        ),
                      ),
                    ),
                    if (stop.nearCollege) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: kAccentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'колледж',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: kAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  prettyDistanceKm(distance),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: kMuted,
                  ),
                ),
                if (stop.routes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: stop.routes
                        .map((route) => _RouteChip(route: route))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final isTrolley = route.startsWith('т');
    final isMetro = route == 'метро';
    final label = isMetro ? 'М' : route;
    final isAccent = isMetro || isTrolley;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isAccent ? kAccentSoft : kCardRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAccent ? kAccent : kBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isAccent ? kAccent : kMuted,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kAccentSoft : kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kAccent : kBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onTap});

  final TransportRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            _TypeBadge(type: route.type, number: route.number),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${route.stops.length} ${_stopWord(route.stops.length)}',
                    style: const TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: kMuted),
          ],
        ),
      ),
    );
  }

  static String _stopWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'остановка';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 12 || count % 100 > 14)) {
      return 'остановки';
    }
    return 'остановок';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    required this.number,
    this.large = false,
  });

  final TransportType type;
  final String number;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      TransportType.bus => Icons.directions_bus,
      TransportType.trolley => Icons.electric_bolt,
      TransportType.tram => Icons.tram,
      TransportType.metro => Icons.subway,
    };
    return Container(
      width: large ? 52 : 44,
      height: large ? 52 : 44,
      decoration: BoxDecoration(
        color: type == TransportType.metro ? kAccent : kAccentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: large ? 18 : 14, color: kAccent),
          const SizedBox(height: 2),
          Text(
            number,
            style: TextStyle(
              fontSize: large ? 15 : 12,
              fontWeight: FontWeight.w800,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }
}