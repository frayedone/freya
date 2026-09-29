import 'package:flutter/material.dart';

/// Расшифровка кодов погоды WMO (Open-Meteo) в текст и иконку.
(String label, IconData icon) wmoInfo(int code) {
  if (code == 0) return ('Ясно', Icons.wb_sunny_outlined);
  if (code == 1) return ('Преимущественно ясно', Icons.wb_sunny_outlined);
  if (code == 2) return ('Переменная облачность', Icons.wb_cloudy_outlined);
  if (code == 3) return ('Пасмурно', Icons.cloud_outlined);
  if (code == 45 || code == 48) return ('Туман', Icons.foggy);
  if (code >= 51 && code <= 57) return ('Морось', Icons.grain);
  if (code >= 61 && code <= 67) return ('Дождь', Icons.umbrella_outlined);
  if (code >= 71 && code <= 77) return ('Снег', Icons.ac_unit);
  if (code >= 80 && code <= 82) return ('Ливень', Icons.umbrella_outlined);
  if (code >= 85 && code <= 86) return ('Снегопад', Icons.ac_unit);
  if (code >= 95 && code <= 99) return ('Гроза', Icons.thunderstorm_outlined);
  return ('Неизвестно', Icons.help_outline);
}