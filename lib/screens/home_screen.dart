import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../services/notification_router.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'schedule_screen.dart';
import 'transport_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [
    ScheduleScreen(),
    WeatherScreen(),
    TransportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationRouter.action.addListener(_onNotificationAction);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_checkForUpdatesSilently());
    }
  }

  /// Проверка обновлений при запуске: предложение показывается только
  /// если вышла реально новая версия, ошибки игнорируются.
  Future<void> _checkForUpdatesSilently() async {
    try {
      final update = await UpdateService().checkForUpdate();
      if (update == null || !mounted) return;
      await UpdateDialog.show(context, update);
    } catch (_) {}
  }

  @override
  void dispose() {
    NotificationRouter.action.removeListener(_onNotificationAction);
    super.dispose();
  }

  void _onNotificationAction() {
    if (NotificationRouter.action.value == null) return;
    NotificationRouter.action.value = null;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.popUntil((route) => route.isFirst);
    if (!mounted) return;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Расписание',
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Погода',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Транспорт',
          ),
        ],
      ),
    );
  }
}