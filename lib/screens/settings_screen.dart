import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/notifications/notifications.dart';
import '../services/schedule_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _version = '1.0.0';

  bool _agendaEnabled = false;
  String? _group;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final agenda = await SettingsService.loadAgendaEnabled();
    String? group;
    try {
      final schedule = await const ScheduleService().load();
      group = schedule.group;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _agendaEnabled = agenda;
      _group = group;
    });
  }

  Future<void> _toggleAgenda(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      final schedule = await const ScheduleService().load();
      final skipped = await SettingsService.loadSkippedWeekdays();
      final ok = await NotificationService.instance
          .enableDailyAgenda(schedule, skipped);
      if (!mounted) return;
      if (!ok) {
        _showMessage('Не удалось включить уведомления — разреши их для Freya');
        return;
      }
      await SettingsService.saveAgendaEnabled(true);
      if (!mounted) return;
      setState(() => _agendaEnabled = true);
      _showMessage('Каждое утро в 9:00 — расписание на день');
    } else {
      await NotificationService.instance.disableDailyAgenda();
      await SettingsService.saveAgendaEnabled(false);
      if (!mounted) return;
      setState(() => _agendaEnabled = false);
      _showMessage('Утренние напоминания выключены');
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text(
          'Будут удалены отменённые дни и все напоминания. Само расписание не изменится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SettingsService.saveSkippedWeekdays(<int>{});
    await SettingsService.saveAgendaEnabled(false);
    await NotificationService.instance.cancelAll();
    if (!mounted) return;
    setState(() => _agendaEnabled = false);
    _showMessage('Настройки сброшены');
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Freya'),
        content: Text(
          'Персональное расписание колледжа и погода. Все данные хранятся '
          'локально на устройстве.\n\nВерсия $_version',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Как работают уведомления'),
        content: const Text(
          'Утреннее расписание приходит каждый день в 9:00, пропуская выходные '
          'и отменённые дни.\n\n'
          'Напоминание о конкретной паре включается колокольчиком на её карточке '
          'и придёт за 10 минут до начала.\n\n'
          'На Android при первом включении разрешите уведомления в системном окне.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _checkForUpdatesBusy = false;

  Future<void> _checkForUpdates() async {
    if (_checkForUpdatesBusy) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('Проверка обновлений доступна на Android');
      return;
    }
    setState(() => _checkForUpdatesBusy = true);
    try {
      final update = await const UpdateService().checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        _showMessage('Установлена актуальная версия');
      } else {
        await UpdateDialog.show(context, update);
      }
    } finally {
      if (mounted) setState(() => _checkForUpdatesBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionLabel('Уведомления'),
          SwitchListTile(
            activeThumbColor: kAccent,
            activeTrackColor: kAccentSoft,
            title: const Text('Утреннее расписание в 9:00', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Список пар на день каждое утро', style: TextStyle(color: kMuted, fontSize: 12.5)),
            value: _agendaEnabled,
            onChanged: _toggleAgenda,
          ),
          const ListTile(
            leading: Icon(Icons.alarm_add_outlined, color: kMuted),
            title: Text('Напоминания о парах', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Включаются колокольчиком на карточке занятия — за 10 минут до пары',
              style: TextStyle(color: kMuted, fontSize: 12.5),
            ),
          ),
          const Divider(),
          const SectionLabel('Приложение'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: kMuted),
            title: const Text('О приложении', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Freya · версия $_version', style: const TextStyle(color: kMuted, fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right, color: kBorder),
            onTap: _showAbout,
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: kMuted),
            title: const Text('Моя группа', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _group ?? 'Загрузка…',
              style: const TextStyle(color: kMuted, fontSize: 12.5),
            ),
            onTap: () => _showMessage('Группа ${_group ?? ''}закреплена в расписании'),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat_outlined, color: kMuted),
            title: const Text('Погода', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Алматы · Open-Meteo', style: TextStyle(color: kMuted, fontSize: 12.5)),
            onTap: () => _showMessage('Погода обновляется при открытии вкладки'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: kMuted),
            title: const Text('Как включить уведомления', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right, color: kBorder),
            onTap: _showNotificationsHelp,
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt_outlined, color: kMuted),
            title: const Text('Проверить обновления', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Новая версия: скачать и установить', style: TextStyle(color: kMuted, fontSize: 12.5)),
            trailing: _checkForUpdatesBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
                  )
                : const Icon(Icons.chevron_right, color: kBorder),
            onTap: _checkForUpdates,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: kDanger),
            title: const Text('Сбросить настройки', style: TextStyle(fontWeight: FontWeight.w500, color: kDanger)),
            onTap: _reset,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Freya $_version',
              style: const TextStyle(fontSize: 11.5, color: kMuted),
            ),
          ),
        ],
      ),
    );
  }
}