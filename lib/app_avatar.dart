import 'package:flutter/material.dart';

/// Варианты аватарки приложения.
///
/// [key] — идентификатор, по которому профиль меняет иконку на рабочем столе
/// (activity-alias в AndroidManifest и метод канала `setAppIcon`).
enum AppAvatar {
  freya('Freya', Icons.auto_awesome_rounded, 'freya'),
  moon('Луна', Icons.nightlight_round, 'moon'),
  star('Звезда', Icons.star_rounded, 'star'),
  leaf('Лист', Icons.eco_rounded, 'leaf'),
  comet('Комета', Icons.rocket_launch_rounded, 'comet');

  const AppAvatar(this.label, this.icon, this.key);

  final String label;
  final IconData icon;
  final String key;

  String get description => switch (this) {
        AppAvatar.freya => 'Искра — классическая иконка Freya',
        AppAvatar.moon => 'Спокойная ночная иконка',
        AppAvatar.star => 'Яркая звезда для иконки',
        AppAvatar.leaf => 'Зелёный лист для иконки',
        AppAvatar.comet => 'Комета для иконки',
      };

  static AppAvatar fromKey(String? key) =>
      values.firstWhere((e) => e.key == key, orElse: () => AppAvatar.freya);
}
