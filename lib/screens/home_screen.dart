import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../services/notification_router.dart';
import '../services/update_service.dart';
import '../theme.dart';
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
  UpdateInfo? _update;
  StreamSubscription<String>? _installSub;

  static const _screens = [
    ScheduleScreen(),
    WeatherScreen(),
    TransportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationRouter.action.addListener(_onNotificationAction);
    _installSub = UpdateService.installErrors.listen(_onInstallError);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_checkForUpdatesSilently());
    }
  }

  /// Проверка обновлений при запуске: если вышла новая версия, держим
  /// навязчивую кнопку обновления сверху. Ошибки игнорируем.
  Future<void> _checkForUpdatesSilently() async {
    try {
      final update = await UpdateService().checkForUpdate();
      if (update == null || !mounted) return;
      setState(() => _update = update);
    } catch (_) {}
  }

  void _onInstallError(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason)));
  }

  @override
  void dispose() {
    NotificationRouter.action.removeListener(_onNotificationAction);
    _installSub?.cancel();
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
    final update = _update;
    return Scaffold(
      body: Column(
        children: [
          if (update != null) _buildUpdateBanner(update),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
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

  /// Навязчивая кнопка обновления: висит сверху, пока не установишь версию.
  Widget _buildUpdateBanner(UpdateInfo update) {
    return Material(
      color: context.colors.accentSoft,
      child: InkWell(
        onTap: () => UpdateDialog.show(context, update),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  color: context.colors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Доступно обновление Freya ${update.versionName}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: context.colors.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => UpdateDialog.show(context, update),
                  child: const Text('Обновить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}