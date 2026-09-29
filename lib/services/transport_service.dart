import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/transport_route.dart';
import '../models/transport_stop.dart';

/// Оффлайн-справочник городского транспорта (встроенный в приложение).
///
/// Живые позиции транспорта в Алматы сейчас недоступны (нет публичного API
/// без авторизации), поэтому приложение показывает справочную информацию:
/// маршруты, границы движения и реальные координаты остановок.
class TransportService {
  const TransportService();

  static const String assetPath = 'assets/transport_routes.json';
  static const String stopsAssetPath = 'assets/transport_stops.json';

  Future<List<TransportRoute>> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => TransportRoute.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Геоточки: остановки, метро и колледж.
  Future<List<TransportStop>> loadStops() async {
    try {
      final raw = await rootBundle.loadString(stopsAssetPath);
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => TransportStop.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}