import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/notifications/notifications.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await NotificationService.instance.refreshDailyAgendas();
  runApp(const FreyaApp());
}

class FreyaApp extends StatelessWidget {
  const FreyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freya',
      debugShowCheckedModeBanner: false,
      darkTheme: FreyaTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}