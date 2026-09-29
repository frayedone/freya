import 'package:flutter/foundation.dart';

/// Маршрутизация тапов по уведомлениям. Приложение слушает [action]
/// и переключается на нужную вкладку.
class NotificationRouter {
  NotificationRouter._();

  static const String openScheduleAction = 'open_schedule';
  static const String openSchedulePayload = 'schedule';

  static final ValueNotifier<String?> action = ValueNotifier<String?>(null);

  /// Вызывается плагином при нажатии на уведомление или его кнопку.
  static void handleResponse(dynamic response) {
    try {
      final actionId = (response).actionId as String?;
      final payload = response.payload as String?;
      if (actionId == openScheduleAction || payload == openSchedulePayload) {
        action.value = openSchedulePayload;
      }
    } catch (_) {}
  }
}