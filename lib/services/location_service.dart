import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Текущее положение пользователя (GPS). Возвращает null, если
/// недоступно: нет разрешения, выключен GPS, не Android/iOS.
class LocationService {
  const LocationService._();

  static Future<Position?> currentPosition() async {
    if (kIsWeb) return null;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Точка назначения — колледж (пр. Достык, 108, Алматы).
  static const double collegeLat = 43.240951;
  static const double collegeLon = 76.957425;
  static const String collegeAddress = 'пр. Достык, 108, Алматы';

  /// Ссылка на маршрут в Яндекс.Картах. Если позиция неизвестна —
  /// просто показывает колледж на карте.
  static String mapsRouteUrl(double? lat, double? lon) {
    if (lat == null || lon == null) {
      return 'https://yandex.ru/maps/?pt=76.957425,43.240951&z=17';
    }
    return 'https://yandex.ru/maps/?rtext='
        '${lon.toStringAsFixed(6)},${lat.toStringAsFixed(6)}'
        '~76.957425,43.240951&rtt=mt';
  }
}