import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../app_avatar.dart';
import '../services/app_icon_service.dart';
import '../services/notifications/notifications.dart';
import '../services/schedule_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/update_dialog.dart';
import 'onboarding_screen.dart';
import 'presets_screen.dart';
import 'schedule_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final String _version = '1.0.0';

  bool _agendaEnabled = false;
  String? _group;
  ThemeChoice _theme = ThemeChoice.dark;
  AccentChoice _accent = AccentChoice.amber;
  AppAvatar _avatar = AppAvatar.freya;
  bool _exactAlarms = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final agenda = await SettingsService.loadAgendaEnabled();
    String? group;
    try {
      final schedule = await ScheduleService().load();
      group = schedule.group;
    } catch (_) {}
    final appearance = SettingsService.appearance.value;
    final exact = await NotificationService.instance.canScheduleExact();
    if (!mounted) return;
    setState(() {
      _agendaEnabled = agenda;
      _group = group;
      _theme = appearance.theme;
      _accent = appearance.accent;
      _avatar = SettingsService.avatar.value;
      _exactAlarms = exact;
    });
  }

  Future<void> _setTheme(ThemeChoice choice) async {
    HapticFeedback.selectionClick();
    setState(() => _theme = choice);
    await SettingsService.saveTheme(choice);
  }

  Future<void> _setAccent(AccentChoice choice) async {
    HapticFeedback.selectionClick();
    setState(() => _accent = choice);
    await SettingsService.saveAccent(choice);
  }

  Future<void> _setAvatar(AppAvatar choice) async {
    HapticFeedback.selectionClick();
    setState(() => _avatar = choice);
    await SettingsService.saveAvatar(choice);
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('Иконка «${choice.label}» сохранена');
      return;
    }
    final ok = await AppIconService.apply(choice);
    if (!mounted) return;
    _showMessage(
      ok
          ? 'Иконка «${choice.label}» установлена — обнови рабочий стол, если не сменилась'
          : 'Не удалось сменить иконку на этом устройстве',
    );
  }

  void _openPresets() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const PresetsScreen()),
    );
  }

  void _replayOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const OnboardingScreen(replay: true),
      ),
    );
  }

  Future<void> _askExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('Доступно только на Android');
      return;
    }
    final granted = await NotificationService.instance.requestExactAlarms();
    final ok = await NotificationService.instance.canScheduleExact();
    if (!mounted) return;
    setState(() => _exactAlarms = ok);
    _showMessage(granted || ok
        ? 'Точные будильники включены — уведомления будут приходить вовремя'
        : 'Разрешение не выдано — система может задерживать уведомления');
  }

  Future<void> _testNotification() async {
    final ok = await NotificationService.instance.sendTestNotification();
    if (!mounted) return;
    _showMessage(ok
        ? 'Проверочное уведомление придёт через 15 секунд'
        : 'Не удалось поставить уведомление — проверь разрешения');
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const ScheduleEditScreen()),
    );
  }

  Future<void> _toggleAgenda(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      final schedule = await ScheduleService().load();
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

  Future<void> _reset() async {    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сбросить настройки?'),
        content: Text(
          'Будут удалены отменённые дни и все напоминания. Само расписание не изменится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Сбросить', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SettingsService.saveSkippedWeekdays(<int>{});
    await NotificationService.instance.disableDailyAgenda();
    await SettingsService.saveAgendaEnabled(false);
    await NotificationService.instance.cancelAll();
    if (!mounted) return;
    setState(() => _agendaEnabled = false);
    _showMessage('Настройки сброшены');
  }

  void _showAbout() {    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Freya'),
        content: Text(
          'Персональное расписание колледжа и погода. Все данные хранятся '
          'локально на устройстве.\n\nВерсия $_version',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Как работают уведомления'),
        content: Text(
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
            child: Text('Понятно'),
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
      final update = await UpdateService().checkForUpdate();
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
      appBar: AppBar(title: Text('Настройки')),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        children: [
          SectionLabel('Уведомления'),
          SwitchListTile(
            activeThumbColor: context.colors.accent,
            activeTrackColor: context.colors.accentSoft,
            title: Text('Утреннее расписание в 9:00', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Список пар на день каждое утро', style: TextStyle(color: context.colors.muted, fontSize: 12.5)),
            value: _agendaEnabled,
            onChanged: _toggleAgenda,
          ),
          ListTile(
            leading: Icon(Icons.alarm_add_outlined, color: context.colors.muted),
            title: Text('Напоминания о парах', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Включаются колокольчиком на карточке занятия — за 10 минут до пары',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
          ),
          Divider(),
          SectionLabel('Оформление'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<ThemeChoice>(
              segments: [
                for (final choice in ThemeChoice.values)
                  ButtonSegment(
                    value: choice,
                    label: Text(
                      choice.label,
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
              selected: {_theme},
              showSelectedIcon: false,
              onSelectionChanged: (values) => _setTheme(values.first),
            ),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final choice in AccentChoice.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => _setAccent(choice),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: choice.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent == choice
                                ? context.colors.text
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _accent == choice
                            ? Icon(Icons.check, size: 17, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Цвет акцента: ${_accent.label}',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          SectionLabel('Иконка приложения'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final choice in AppAvatar.values)
                  _AvatarOption(
                    avatar: choice,
                    selected: _avatar == choice,
                    onTap: () => _setAvatar(choice),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${_avatar.label}: ${_avatar.description}',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
          ),
          Divider(),
          SectionLabel('Доставка уведомлений'),
          ListTile(
            leading: Icon(
              _exactAlarms ? Icons.verified_outlined : Icons.warning_amber_outlined,
              color: _exactAlarms ? context.colors.accent : context.colors.danger,
            ),
            title: Text('Точное время', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _exactAlarms
                  ? 'Уведомления приходят вовремя, даже когда приложение закрыто'
                  : 'Без этого система задерживает уведомления на десятки минут',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
            trailing: _exactAlarms
                ? null
                : Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _exactAlarms ? null : _askExactAlarms,
          ),
          ListTile(
            leading: Icon(Icons.notifications_active_outlined, color: context.colors.muted),
            title: Text('Проверить уведомление', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Придёт через 15 секунд', style: TextStyle(color: context.colors.muted, fontSize: 12.5)),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _testNotification,
          ),
          ListTile(
            leading: Icon(Icons.battery_saver_outlined, color: context.colors.muted),
            title: Text('Экономия батареи', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Отключите оптимизацию для Freya, иначе Xiaomi и Samsung сносят отложенные уведомления',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: () => NotificationService.instance.openBatterySettings(),
          ),
          Divider(),
          SectionLabel('Приложение'),
          ListTile(
            leading: Icon(Icons.info_outline, color: context.colors.muted),
            title: Text('О приложении', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Freya · версия $_version', style: TextStyle(color: context.colors.muted, fontSize: 12.5)),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _showAbout,
          ),
          ListTile(
            leading: Icon(Icons.school_outlined, color: context.colors.muted),
            title: Text('Моё расписание и группа', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _group ?? 'Загрузка…',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _openEditor,
          ),
          ListTile(
            leading: Icon(Icons.bookmarks_outlined, color: context.colors.muted),
            title: Text('Пресеты расписания', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Сохраняй наборы пар и переключайся между ними',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _openPresets,
          ),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined, color: context.colors.muted),
            title: Text('Пройти обучение заново', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Повторить знакомство с приложением',
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _replayOnboarding,
          ),
          ListTile(
            leading: Icon(Icons.thermostat_outlined, color: context.colors.muted),
            title: Text('Погода', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Алматы · Open-Meteo', style: TextStyle(color: context.colors.muted, fontSize: 12.5)),
            onTap: () => _showMessage('Погода обновляется при открытии вкладки'),
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: context.colors.muted),
            title: Text('Как включить уведомления', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _showNotificationsHelp,
          ),
          ListTile(
            leading: Icon(Icons.system_update_alt_outlined, color: context.colors.muted),
            title: Text('Проверить обновления', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Новая версия: скачать и установить', style: TextStyle(color: context.colors.muted, fontSize: 12.5)),
            trailing: _checkForUpdatesBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.accent),
                  )
                : Icon(Icons.chevron_right, color: context.colors.border),
            onTap: _checkForUpdates,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colors.danger),
            title: Text('Сбросить настройки', style: TextStyle(fontWeight: FontWeight.w500, color: context.colors.danger)),
            onTap: _reset,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Freya $_version',
              style: TextStyle(fontSize: 11.5, color: context.colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AppAvatar avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: selected ? context.colors.accentSoft : context.colors.card,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? context.colors.accent : context.colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              avatar.icon,
              size: 25,
              color: selected ? context.colors.accent : context.colors.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            avatar.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: selected ? context.colors.accent : context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}