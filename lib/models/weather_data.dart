/// Погода в текущий момент.
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
  });

  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final int weatherCode;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
        temperature: (json['temperature_2m'] as num).toDouble(),
        feelsLike: (json['apparent_temperature'] as num).toDouble(),
        humidity: (json['relative_humidity_2m'] as num).toDouble(),
        windSpeed: (json['wind_speed_10m'] as num).toDouble(),
        weatherCode: json['weather_code'] as int,
      );
}

/// Прогноз на один день.
class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.weatherCode,
    required this.min,
    required this.max,
    required this.precipitationProbability,
  });

  final DateTime date;
  final int weatherCode;
  final double min;
  final double max;
  final int precipitationProbability;

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
        date: DateTime.parse(json['time'] as String),
        weatherCode: json['weather_code'] as int,
        min: (json['temperature_2m_min'] as num).toDouble(),
        max: (json['temperature_2m_max'] as num).toDouble(),
        precipitationProbability: json['precipitation_probability_max'] as int? ?? 0,
      );
}

class WeatherData {
  const WeatherData({required this.current, required this.daily});

  final CurrentWeather current;
  final List<ForecastDay> daily;

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final times = daily['time'] as List;
    final codes = daily['weather_code'] as List;
    final mins = daily['temperature_2m_min'] as List;
    final maxs = daily['temperature_2m_max'] as List;
    final probs = daily['precipitation_probability_max'] as List? ?? [];

    final forecast = <ForecastDay>[];
    for (var i = 0; i < times.length; i++) {
      forecast.add(ForecastDay.fromJson({
        'time': times[i],
        'weather_code': codes[i],
        'temperature_2m_min': mins[i],
        'temperature_2m_max': maxs[i],
        'precipitation_probability_max': i < probs.length ? probs[i] : 0,
      }));
    }

    return WeatherData(
      current: CurrentWeather.fromJson(current),
      daily: forecast,
    );
  }
}