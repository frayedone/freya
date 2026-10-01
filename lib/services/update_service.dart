import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'update_token.dart';

/// Обновление приложения через GitHub Releases.
///
/// Поддерживает как публичный, так и приватный репозиторий.
///
/// Соглашение о релизах (важно при создании релиза на GitHub):
///  - тег релиза — это versionCode из pubspec («3», «v3» или «1.0.0+3»);
///  - к релизу прикрепляется APK (файл `app-release.apk`);
///  - текст релиза показывается как заметки к обновлению.
///
/// Безопасность приватного репозитория:
///  - токен живёт только в приложении и используется для GitHub API;
///  - при скачивании APK токен не передаётся на сторонние хосты —
///    берётся подписанная ссылка GitHub и запрос идёт уже без токена.
class UpdateInfo {
  const UpdateInfo({
    required this.remoteCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    this.assetId,
  });

  final int remoteCode;
  final String versionName;
  final String notes;
  final String apkUrl;

  /// id ассета APK (для приватных репозиториев, где прямая ссылка
  /// недоступна анонимно).
  final int? assetId;
}

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  const UpdateService();

  /// Место публикации релизов.
  static const String repoOwner = 'frayedone';
  static const String repoName = 'freya';

  /// Токен GitHub для приватного репозитория.
  ///
  /// Хранится в отдельном файле `lib/services/update_token.dart`,
  /// который исключён из git (секрет не коммитится).
  /// Пустая строка = репозиторий публичный, токен не нужен.
  static const String githubToken = kUpdateGithubToken;

  static const MethodChannel _installChannel =
      MethodChannel('kz.freya.freya/updates');

  static final StreamController<String> _installErrorController =
      StreamController<String>.broadcast();
  static bool _handlerSet = false;

  /// Страница релизов — резервный способ скачать APK вручную.
  String get releasePageUrl =>
      'https://github.com/$repoOwner/$repoName/releases/latest';

  /// Сообщения об ошибках установки от системы (PackageInstaller).
  static Stream<String> get installErrors => _installErrorController.stream;

  /// Подписывается на отчёты нативного установщика. Вызвать один раз
  /// при старте приложения.
  static void init() {
    if (_handlerSet) return;
    _handlerSet = true;
    _installChannel.setMethodCallHandler((call) async {
      if (call.method == 'installResult') {
        final args = call.arguments;
        final reason = args is Map
            ? (args['reason'] as String? ?? 'Не удалось установить приложение')
            : 'Не удалось установить приложение';
        _installErrorController.add(reason);
      }
      return null;
    });
  }

  /// Возвращает информацию об обновлении, если на GitHub вышел релиз
  /// новее установленной версии. Иначе — null (в т.ч. при ошибке сети
  /// или отсутствии релизов).
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(info.buildNumber) ?? 0;

      final uri = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Freya',
              if (githubToken.isNotEmpty)
                'Authorization': 'Bearer $githubToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteTag = json['tag_name'] as String? ?? '';
      final remoteCode = _parseCode(remoteTag);
      final asset = _findApkAsset(json['assets']);
      if (remoteCode <= localCode || asset == null) return null;

      final directUrl = asset['browser_download_url'] as String?;
      final assetId = asset['id'] as int?;
      final needsSignedUrl = githubToken.isNotEmpty && assetId != null;
      final apkUrl = needsSignedUrl
          ? 'https://api.github.com/repos/$repoOwner/$repoName/'
              'releases/assets/$assetId'
          : directUrl;
      if (apkUrl == null) return null;

      return UpdateInfo(
        remoteCode: remoteCode,
        versionName: json['name'] as String? ?? remoteTag,
        notes: (json['body'] as String? ?? '').trim(),
        apkUrl: apkUrl,
        assetId: needsSignedUrl ? assetId : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Скачивает APK во временную папку приложения.
  ///
  /// Для приватных репозиториев токен используется только для GitHub API,
  /// а сам файл скачивается по подписанной ссылке без токена.
  Future<File> downloadApk(String url, {void Function(double)? onProgress}) async {
    final client = http.Client();
    try {
      final dir = await _updateDir();
      var uri = Uri.parse(url);
      var authenticated = githubToken.isNotEmpty;
      var received = 0;
      int? total;
      File? file;
      IOSink? sink;

      for (var hop = 0; hop < 6; hop++) {
        final request = http.Request('GET', uri)..followRedirects = false;
        // ВАЖНО: только octet-stream. Если добавить application/vnd.github+json,
        // GitHub отдаёт JSON-метаданные (200 application/json) вместо файла,
        // и установщик получает «битый» APK.
        request.headers['Accept'] = 'application/octet-stream';
        if (authenticated) {
          request.headers['Authorization'] = 'Bearer $githubToken';
        }
        final response = await client.send(request).timeout(
              const Duration(minutes: 5),
            );

        final location = response.headers['location'];
        if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
          await response.stream.drain<void>();
          // Дальше идём без токена — ссылка GitHub уже подписана.
          authenticated = false;
          uri = Uri.parse(location);
          continue;
        }

        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw UpdateException(
              'Не удалось скачать обновление (код ${response.statusCode})');
        }

        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('json')) {
          await response.stream.drain<void>();
          throw UpdateException('GitHub вернул не файл обновления — попробуй ещё раз');
        }

        total = response.contentLength ?? 0;
        file = File(
          '${dir.path}/freya_update_${DateTime.now().millisecondsSinceEpoch}.apk',
        );
        sink = file.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          }
        } finally {
          await sink.close();
        }
        if (total > 0 && received < total) {
          throw UpdateException('Скачивание прервано');
        }
        if (received == 0) {
          throw UpdateException('Скачался пустой файл');
        }
        if (!await _looksLikeApk(file)) {
          try {
            await file.delete();
          } catch (_) {}
          throw UpdateException('Скачанный файл повреждён — попробуй ещё раз');
        }
        return file;
      }
      throw UpdateException('Слишком много перенаправлений при скачивании');
    } catch (e) {
      if (e is UpdateException) rethrow;
      throw UpdateException('Нет соединения — проверь интернет');
    } finally {
      client.close();
    }
  }

  /// Папка для файлов обновления.
  ///
  /// Путь берём у Android: `Directory.systemTemp` на разных устройствах
  /// указывает то на `cache`, то на `code_cache`, из-за чего установщик
  /// не мог найти файл через FileProvider.
  Future<Directory> _updateDir() async {
    try {
      final path = await _installChannel.invokeMethod<String>('updateDir');
      if (path != null && path.isNotEmpty) {
        return Directory(path);
      }
    } on MissingPluginException {
      // не Android
    } on PlatformException {
      // канал недоступен — используем системную временную папку
    }
    return Directory.systemTemp;
  }

  /// Запускает системный установщик APK (только Android).
  Future<void> installApk(String path) async {
    try {
      await _installChannel.invokeMethod<void>('installApk', {
        'path': path,
      });
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? 'Не удалось запустить установку');
    } catch (e) {
      throw UpdateException('Не удалось открыть установщик (${e.toString()})');
    }
  }

  /// Разрешена ли установка приложений из Freya (Android 8+).
  Future<bool> canInstall() async {
    try {
      return await _installChannel.invokeMethod<bool>('canInstall') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  /// Открывает экран «Установка неизвестных приложений» для Freya.
  Future<void> openInstallSettings() async {
    try {
      await _installChannel.invokeMethod<void>('openInstallSettings');
    } catch (_) {}
  }

  /// Открывает ссылку во внешнем браузере (для ручной установки).
  Future<void> openUrl(String url) async {
    await _installChannel.invokeMethod<void>('openUrl', {'url': url});
  }

  /// Проверяет, что файл начинается с ZIP-заголовка (`PK\x03\x04`).
  Future<bool> _looksLikeApk(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(4);
      return header.length >= 4 &&
          header[0] == 0x50 &&
          header[1] == 0x4B &&
          header[2] == 0x03 &&
          header[3] == 0x04;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  Map<String, dynamic>? _findApkAsset(dynamic assets) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) return asset;
      }
    }
    return null;
  }

  /// Извлекает versionCode из тега релиза: «3» -> 3, «v3» -> 3,
  /// «1.0.0+3» -> 3 (берётся число после '+'), «1.0.1» -> 1.
  int _parseCode(String tag) {
    var value = tag;
    final plus = value.indexOf('+');
    if (plus >= 0) value = value.substring(plus + 1);
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}