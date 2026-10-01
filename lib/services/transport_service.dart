import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/transit_network.dart';
import '../models/transport.dart';

/// Оффлайн-оценка времени прибытия транспорта у колледжа.
///
/// Живых данных о движении транспорта в Алматы нет (публичных API без
/// авторизации не существует), поэтому приложение считает «через сколько»
/// по типовому интервалу движения маршрута.
class TransportService {
  const TransportService();

  static const String assetPath = 'assets/transport.json';

  Future<TransitData> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final byNumber = <String, TransitRoute>{
        for (final item in json['routes'] as List? ?? const [])
          (item as Map<String, dynamic>)['number'] as String:
              TransitRoute.fromJson(item),
      };
      return TransitData(
        college: json['college'] as String? ?? '',
        note: json['note'] as String? ?? '',
        serviceStart: (json['serviceStart'] as num?)?.toInt() ?? 360,
        serviceEnd: (json['serviceEnd'] as num?)?.toInt() ?? 1380,
        stops: (json['stops'] as List? ?? const [])
            .map((item) =>
                TransitStop.fromJson(item as Map<String, dynamic>, byNumber))
            .toList(),
      );
    } catch (_) {
      return const TransitData(
        college: '',
        note: '',
        serviceStart: 360,
        serviceEnd: 1380,
        stops: [],
      );
    }
  }

  /// Загружает демо-сеть остановок и линий для построения маршрута.
  Future<TransitNetwork> loadNetwork() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final network = json['network'] as Map<String, dynamic>? ?? const {};
      return TransitNetwork(
        stops: (network['stops'] as List? ?? const [])
            .map((item) => NetStop.fromJson(item as Map<String, dynamic>))
            .toList(),
        lines: (network['lines'] as List? ?? const [])
            .map((item) => TransitLine.fromJson(item as Map<String, dynamic>))
            .toList(),
        serviceStart: (json['serviceStart'] as num?)?.toInt() ?? 360,
        serviceEnd: (json['serviceEnd'] as num?)?.toInt() ?? 1380,
        note: network['note'] as String? ??
            json['networkNote'] as String? ??
            json['note'] as String? ??
            '',
      );
    } catch (_) {
      return const TransitNetwork(
        stops: [],
        lines: [],
        serviceStart: 360,
        serviceEnd: 1380,
        note: '',
      );
    }
  }
}
