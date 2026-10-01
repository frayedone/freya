import 'package:flutter/material.dart';

import '../services/preset_service.dart';
import '../services/schedule_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// Приветственный экран-онбординг.
///
/// Показывается один раз (флаг [SettingsService.onboardingDone]) и может быть
/// запущен повторно из настроек — тогда [replay] = true и экран не меняет
/// корень приложения, а закрывается по завершении.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _presetSaved = false;
  bool _saving = false;

  static const int _lastPage = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SettingsService.setOnboardingDone(true);
    if (!mounted) return;
    if (widget.replay) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createPreset() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final schedule = await ScheduleService().load();
      final preset = await PresetService.seedIfEmpty(name: schedule.group);
      if (!mounted) return;
      setState(() => _presetSaved = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              preset == null
                  ? 'Пресет «${schedule.group}» уже сохранён'
                  : 'Расписание «${schedule.group}» сохранено как пресет',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_page >= _lastPage) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    widget.replay ? 'Закрыть' : 'Пропустить',
                    style: TextStyle(color: context.colors.muted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  _WelcomePage(),
                  _FeaturePage(
                    icon: Icons.calendar_month_rounded,
                    title: 'Расписание под рукой',
                    subtitle:
                        'Пары на день, отмена занятий и напоминания за 10 минут '
                        'до начала.',
                    points: const [
                      'Свои пары и группа — редактируются в любой момент',
                      'Утреннее уведомление со списком пар в 9:00',
                      'Колокольчик на карточке — напоминание о конкретной паре',
                    ],
                  ),
                  _FeaturePage(
                    icon: Icons.explore_rounded,
                    title: 'Погода и транспорт',
                    subtitle:
                        'Погода в Алматы и подсказка «взять зонт» прямо на '
                        'экране расписания.',
                    points: const [
                      'Прогноз на день для Алматы',
                      'Прибытие транспорта у остановок рядом с колледжем',
                      'Маршрут «откуда → куда» с пересадками',
                    ],
                  ),
                  _PresetPage(
                    saved: _presetSaved,
                    saving: _saving,
                    onCreate: _createPreset,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i <= _lastPage; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 6,
                          width: i == _page ? 20 : 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? context.colors.accent
                                : context.colors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_page >= _lastPage ? 'Начать' : 'Дальше'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final avatar = SettingsService.avatar.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.colors.accent, width: 1.5),
            ),
            child: Icon(avatar.icon, size: 50, color: context.colors.accent),
          ),
          const SizedBox(height: 26),
          Text(
            'Добро пожаловать в Freya',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Расписание колледжа, погода и транспорт — всё в одном месте. '
            'Покажем основы за полминуты.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 32, color: context.colors.accent),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, height: 1.45, color: context.colors.muted),
          ),
          const SizedBox(height: 20),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle,
                      size: 17,
                      color: context.colors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: context.colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PresetPage extends StatelessWidget {
  const _PresetPage({
    required this.saved,
    required this.saving,
    required this.onCreate,
  });

  final bool saved;
  final bool saving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.bookmark_add_rounded,
              size: 32,
              color: context.colors.accent,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Сохрани первый пресет',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Пресет — это сохранённый набор пар. Мы запишем твоё текущее '
            'расписание в пресет, и позже ты сможешь переключаться между '
            'группами одним касанием.',
            style: TextStyle(fontSize: 14, height: 1.45, color: context.colors.muted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: (saving || saved) ? null : onCreate,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.accent,
                side: BorderSide(
                  color: saved ? context.colors.border : context.colors.accent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.accent,
                      ),
                    )
                  : Icon(
                      saved ? Icons.check_circle : Icons.bookmark_add_outlined,
                      size: 19,
                    ),
              label: Text(saved ? 'Пресет сохранён' : 'Создать первый пресет'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Можно пропустить — пресеты доступны в настройках в любой момент.',
            style: TextStyle(fontSize: 11.5, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}
