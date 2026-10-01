import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/notifications/notifications.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.load();
  await NotificationService.instance.init();
  await NotificationService.instance.refreshDailyAgendas();
  runApp(const FreyaApp());
}

class FreyaApp extends StatelessWidget {
  const FreyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<({ThemeChoice theme, AccentChoice accent})>(
      valueListenable: SettingsService.appearance,
      builder: (context, value, _) {
        final theme = value.theme;
        final accent = value.accent.color;
        return MaterialApp(
          title: 'Freya',
          debugShowCheckedModeBanner: false,
          theme: FreyaTheme.build(brightness: Brightness.light, accent: accent),
          darkTheme: FreyaTheme.build(brightness: Brightness.dark, accent: accent),
          themeMode: theme.mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}