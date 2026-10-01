import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme.dart';

/// Диалоги обновления приложения: подтверждение → скачивание → установка.
class UpdateDialog {
  UpdateDialog._();

  /// Показать карточку: «Доступна новая версия» с кнопкой «Обновить».
  static Future<void> show(BuildContext context, UpdateInfo update) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Доступна новая версия'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Freya ${update.versionName}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.colors.accent,
              ),
            ),
            if (update.notes.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(
                update.notes,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.text,
                ),
              ),
            ],
            SizedBox(height: 10),
            Text(
              'Обновление скачается и установится поверх текущей версии.',
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Позже'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.accent, foregroundColor: context.colors.bg),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Обновить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _UpdateFlow(update: update),
      );
    }
  }
}

enum _FlowState { downloading, ready, error }

class _UpdateFlow extends StatefulWidget {
  const _UpdateFlow({required this.update});

  final UpdateInfo update;

  @override
  State<_UpdateFlow> createState() => _UpdateFlowState();
}

class _UpdateFlowState extends State<_UpdateFlow> {
  _FlowState _state = _FlowState.downloading;
  double _progress = 0;
  File? _file;
  String? _error;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    unawaited(_download());
  }

  Future<void> _download() async {
    setState(() {
      _state = _FlowState.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final file = await UpdateService().downloadApk(
        widget.update.apkUrl,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _state = _FlowState.ready;
        _file = file;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _FlowState.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _install() async {
    final file = _file;
    if (file == null) return;
    Navigator.of(context).pop();
    if (_isAndroid) {
      try {
        await UpdateService().installApk(file.path);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != _FlowState.downloading,
      child: AlertDialog(
        title: Text('Обновление'),
        content: switch (_state) {
          _FlowState.downloading => _buildDownloading(),
          _FlowState.ready => _buildReady(),
          _FlowState.error => _buildError(),
        },
        actions: switch (_state) {
          _FlowState.downloading => const [],
          _FlowState.ready => [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Позже'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.bg,
                ),
                onPressed: _isAndroid ? _install : null,
                child: Text('Установить'),
              ),
            ],
          _FlowState.error => [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Позже'),
              ),
              TextButton(
                onPressed: _download,
                child: Text('Повторить'),
              ),
            ],
        },
      ),
    );
  }

  Widget _buildDownloading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Скачивание новой версии…',
          style: TextStyle(fontSize: 13, color: context.colors.text),
        ),
        SizedBox(height: 14),
        LinearProgressIndicator(
          value: _progress > 0 ? _progress : null,
          color: context.colors.accent,
          backgroundColor: context.colors.accentSoft,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
        SizedBox(height: 8),
        Text(
          _progress > 0 ? '${(_progress * 100).round()}%' : 'Подключение…',
          style: TextStyle(fontSize: 11.5, color: context.colors.muted),
        ),
      ],
    );
  }

  Widget _buildReady() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Готово. Нажми «Установить», чтобы запустить системный установщик.',
          style: TextStyle(fontSize: 13, height: 1.45, color: context.colors.text),
        ),
        SizedBox(height: 6),
        Text(
          'Может понадобиться разрешить установку из неизвестных источников.',
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _isAndroid ? Icons.cloud_off_outlined : Icons.error_outline,
          color: context.colors.danger,
          size: 22,
        ),
        SizedBox(height: 8),
        Text(
          _error ?? 'Неизвестная ошибка',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.text),
        ),
      ],
    );
  }
}