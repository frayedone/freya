import 'package:package_info_plus/package_info_plus.dart';

/// Версия приложения из `pubspec.yaml` (без ручных дублей в интерфейсе).
class AppInfo {
  AppInfo._();

  static String? _label;

  /// «1.0.0+11» — значение один раз читается из платформы и кэшируется.
  static Future<String> versionLabel() async {
    final cached = _label;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      _label = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _label = '—';
    }
    return _label!;
  }
}
