import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../utils/wmo.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _service = WeatherService();

  late Future<WeatherData> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetch();
  }

  void _reload() => setState(() => _future = _service.fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Погода'),
        actions: [
          IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<WeatherData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString(), onRetry: _reload);
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _HeroCard(current: data.current),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('На неделю', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      'Алматы',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < data.daily.length; i++) ...[
                  _ForecastTile(day: data.daily[i]),
                  if (i < data.daily.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.current});

  final CurrentWeather current;

  static List<Color> _backdrop(int code) {
    if (code == 0) return const [Color(0xFF0D47A1), Color(0xFF1976D2)];
    if (code == 1 || code == 2) return const [Color(0xFF283593), Color(0xFF3949AB)];
    if (code == 3) return const [Color(0xFF37474F), Color(0xFF546E7A)];
    if (code == 45 || code == 48) return const [Color(0xFF455A64), Color(0xFF607D8B)];
    if (code >= 51 && code <= 67) return const [Color(0xFF01579B), Color(0xFF0277BD)];
    if (code >= 71 && code <= 86) return const [Color(0xFF37474F), Color(0xFF78909C)];
    if (code >= 95) return const [Color(0xFF4A148C), Color(0xFF6A1B9A)];
    return const [Color(0xFF263238), Color(0xFF37474F)];
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon) = wmoInfo(current.weatherCode);
    final gradient = _backdrop(current.weatherCode);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.white),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${current.temperature.toStringAsFixed(0)}°',
                    style: const TextStyle(
                      fontSize: 66,
                      height: 1.0,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.device_thermostat,
                label: 'Ощущается ${current.feelsLike.toStringAsFixed(0)}°',
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.water_drop_outlined,
                label: '${current.humidity.toStringAsFixed(0)}%',
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.air,
                label: '${current.windSpeed.toStringAsFixed(0)} м/с',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Алматы',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ForecastTile extends StatelessWidget {
  const _ForecastTile({required this.day});

  final ForecastDay day;

  static const List<String> _weekday = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const List<String> _monthGen = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon) = wmoInfo(day.weatherCode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekday[day.date.weekday - 1],
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${day.date.day} ${_monthGen[day.date.month - 1]}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (day.precipitationProbability > 0)
                  Row(
                    children: [
                      Icon(Icons.water_drop_outlined, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${day.precipitationProbability}% осадков',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${day.min.toStringAsFixed(0)}°',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            '${day.max.toStringAsFixed(0)}°',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}