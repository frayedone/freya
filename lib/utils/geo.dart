import 'dart:math';

/// Расстояние между двумя точками на сфере (формула гаверсинуса), км.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _rad(double deg) => deg * pi / 180;

/// Человекочитаемое расстояние: «340 м» или «1,2 км».
String prettyDistanceKm(double km) {
  if (km < 1) return '${(km * 1000).round()} м';
  return '${km.toStringAsFixed(1)} км'.replaceAll('.', ',');
}