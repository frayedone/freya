import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;

import '../app_avatar.dart';

/// Меняет иконку приложения на рабочем столе (activity-alias на Android).
class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('kz.freya.freya/appicon');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Возвращает true, если иконка была переключена.
  static Future<bool> apply(AppAvatar avatar) async {
    if (!_supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setAppIcon', {
        'key': avatar.key,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
