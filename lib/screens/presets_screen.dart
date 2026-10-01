import 'dart:async';

import 'package:flutter/material.dart';

import '../models/schedule_preset.dart';
import '../services/preset_service.dart';
import '../services/schedule_service.dart';
import '../theme.dart';

/// Список пресетов расписания: сохранение, переключение и удаление.
class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  List<SchedulePreset> _presets = const [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PresetService.revision.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void dispose() {
    PresetService.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final presets = await PresetService.loadAll();
    final active = await PresetService.activeId();
    if (!mounted) return;
    setState(() {
      _presets = presets;
      _activeId = active;
      _loading = false;
    });
  }

  Future<void> _saveCurrent() async {
    final schedule = await ScheduleService().load();
    if (!mounted) return;
    final controller = TextEditingController(text: schedule.group);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сохранить как пресет'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Название пресета'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await PresetService.saveCurrentAs(name);
    _showMessage('Пресет «$name» сохранён');
  }

  Future<void> _apply(SchedulePreset preset) async {
    await PresetService.apply(preset);
    if (!mounted) return;
    _showMessage('Включён пресет «${preset.name}»');
  }

  Future<void> _rename(SchedulePreset preset) async {
    final controller = TextEditingController(text: preset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Название пресета'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await PresetService.rename(preset.id, name);
  }

  Future<void> _overwrite(SchedulePreset preset) async {
    final confirmed = await _confirm(
      title: 'Обновить «${preset.name}»?',
      body: 'В пресет будет записано текущее расписание. Прежние пары пресета '
          'будут потеряны.',
      action: 'Обновить',
    );
    if (!confirmed || !mounted) return;
    await PresetService.overwriteWithCurrent(preset.id);
    _showMessage('Пресет «${preset.name}» обновлён');
  }

  Future<void> _delete(SchedulePreset preset) async {
    final confirmed = await _confirm(
      title: 'Удалить «${preset.name}»?',
      body: 'Пресет будет удалён. Текущее расписание не изменится.',
      action: 'Удалить',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await PresetService.delete(preset.id);
    _showMessage('Пресет удалён');
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body, style: TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: danger
                ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Пресеты расписания'),
        actions: [
          IconButton(
            tooltip: 'Сохранить текущее как пресет',
            onPressed: _saveCurrent,
            icon: Icon(Icons.add, color: context.colors.accent),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.accent))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Пресет — сохранённый набор пар. Переключайся между группами '
                  'или вариантами недели одним касанием.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.colors.muted,
                  ),
                ),
                SizedBox(height: 14),
                if (_presets.isEmpty)
                  _Empty()
                else
                  ..._presets.map(
                    (preset) => _PresetTile(
                      preset: preset,
                      active: preset.id == _activeId,
                      onApply: () => _apply(preset),
                      onRename: () => _rename(preset),
                      onOverwrite: () => _overwrite(preset),
                      onDelete: () => _delete(preset),
                    ),
                  ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saveCurrent,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.accent,
                    side: BorderSide(color: context.colors.accent),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(Icons.bookmark_add_outlined, size: 19),
                  label: Text('Сохранить текущее расписание как пресет'),
                ),
              ],
            ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.active,
    required this.onApply,
    required this.onRename,
    required this.onOverwrite,
    required this.onDelete,
  });

  final SchedulePreset preset;
  final bool active;
  final VoidCallback onApply;
  final VoidCallback onRename;
  final VoidCallback onOverwrite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? context.colors.accent : context.colors.border,
        ),
      ),
      child: InkWell(
        onTap: active ? null : onApply,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? context.colors.accentSoft : context.colors.cardRaised,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  active ? Icons.check_circle : Icons.bookmark_outline,
                  size: 21,
                  color: active ? context.colors.accent : context.colors.muted,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.text,
                            ),
                          ),
                        ),
                        if (active) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'АКТИВЕН',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: context.colors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Группа ${preset.group} · пар: ${preset.lessonCount}',
                      style: TextStyle(fontSize: 11.5, color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: context.colors.cardRaised,
                icon: Icon(Icons.more_vert, size: 20, color: context.colors.muted),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      onRename();
                    case 'overwrite':
                      onOverwrite();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                  PopupMenuItem(
                    value: 'overwrite',
                    child: Text('Записать текущее'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Удалить',
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.bookmarks_outlined, size: 42, color: context.colors.border),
          SizedBox(height: 10),
          Text(
            'Пресетов пока нет',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: context.colors.muted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Сохрани текущее расписание, чтобы вернуться к нему позже.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}
