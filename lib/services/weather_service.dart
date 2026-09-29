import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_data.dart';

class WeatherException implements Exception {
  WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Прогноз погоды из бесплатного [Open-Meteo](https://open-meteo.com).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Координаты центра Алматы.
  static const double latitude = 43.2387;
  static const double longitude = 76.8893;

  Future<WeatherData> fetch({int days = 7}) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'Asia/Almaty',
        'forecast_days': '$days',
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WeatherException('Нет соединения с сервером погоды');
    }

    if (response.statusCode != 200) {
      throw WeatherException('Сервер погоды ошибся (${response.statusCode})');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return WeatherData.fromJson(json);
  }
}