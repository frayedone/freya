import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
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
      var uri = Uri.parse(url);
      var authenticated = githubToken.isNotEmpty;
      var received = 0;
      int? total;
      File? file;
      IOSink? sink;

      for (var hop = 0; hop < 6; hop++) {
        final request = http.Request('GET', uri)..followRedirects = false;
        request.headers['Accept'] =
            'application/vnd.github+json, application/octet-stream';
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

        total = response.contentLength ?? 0;
        file = File(
          '${Directory.systemTemp.path}/freya_update_${DateTime.now().millisecondsSinceEpoch}.apk',
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

  /// Запускает системный установщик APK (только Android).
  Future<void> installApk(String path) async {
    try {
      await _installChannel.invokeMethod<void>('installApk', {
        'path': path,
      });
    } catch (e) {
      throw UpdateException('Не удалось открыть установщик (${e.toString()})');
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