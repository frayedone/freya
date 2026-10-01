import 'package:flutter/material.dart';

/// Акцентные цвета, которые можно выбрать в настройках.
enum AccentChoice {
  amber('Янтарь', Color(0xFFF2B554)),
  ocean('Океан', Color(0xFF4FA3E3)),
  jade('Нефрит', Color(0xFF4FC08D)),
  violet('Виолет', Color(0xFFA98BF0)),
  rose('Роза', Color(0xFFF27D9A)),
  steel('Сталь', Color(0xFF8FA3B8));

  const AccentChoice(this.label, this.color);

  final String label;
  final Color color;

  static AccentChoice fromName(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => AccentChoice.amber);
}

/// Режим темы: как в системе, всегда светлая или всегда тёмная.
enum ThemeChoice {
  system('Как в системе'),
  light('Светлая'),
  dark('Тёмная');

  const ThemeChoice(this.label);

  final String label;

  static ThemeChoice fromName(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => ThemeChoice.dark);

  ThemeMode get mode => switch (this) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      };
}

/// Палитра Freya. Живёт в [ThemeData.extensions], поэтому виджеты читают
/// цвета через `context.colors` и автоматически перерисовываются при смене
/// темы или акцента.
@immutable
class FreyaColors extends ThemeExtension<FreyaColors> {
  const FreyaColors({
    required this.bg,
    required this.card,
    required this.cardRaised,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color bg;
  final Color card;
  final Color cardRaised;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;

  factory FreyaColors.dark(Color accent) => FreyaColors(
        bg: const Color(0xFF0A0C0F),
        card: const Color(0xFF14171D),
        cardRaised: const Color(0xFF1A1E26),
        border: const Color(0xFF232833),
        text: const Color(0xFFF0F1F4),
        muted: const Color(0xFF97A0AC),
        accent: accent,
        accentSoft: Color.lerp(const Color(0xFF0A0C0F), accent, 0.16)!,
        danger: const Color(0xFFFF6B5E),
        dangerSoft: const Color(0xFF3A1D19),
      );

  factory FreyaColors.light(Color accent) => FreyaColors(
        bg: const Color(0xFFF4F5F7),
        card: const Color(0xFFFFFFFF),
        cardRaised: const Color(0xFFEFF1F4),
        border: const Color(0xFFDDE1E7),
        text: const Color(0xFF14171D),
        muted: const Color(0xFF69737F),
        accent: accent,
        accentSoft: Color.lerp(const Color(0xFFFFFFFF), accent, 0.16)!,
        danger: const Color(0xFFD94436),
        dangerSoft: const Color(0xFFFBE7E5),
      );

  @override
  FreyaColors copyWith({
    Color? bg,
    Color? card,
    Color? cardRaised,
    Color? border,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accentSoft,
    Color? danger,
    Color? dangerSoft,
  }) =>
      FreyaColors(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        cardRaised: cardRaised ?? this.cardRaised,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
      );

  @override
  FreyaColors lerp(covariant FreyaColors? other, double t) {
    if (other == null) return this;
    return FreyaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardRaised: Color.lerp(cardRaised, other.cardRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

/// Доступ к палитре из виджета.
extension FreyaColorsContext on BuildContext {
  FreyaColors get colors =>
      Theme.of(this).extension<FreyaColors>() ??
      FreyaColors.dark(AccentChoice.amber.color);
}

class FreyaTheme {
  FreyaTheme._();

  static ThemeData build({required Brightness brightness, required Color accent}) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? FreyaColors.dark(accent) : FreyaColors.light(accent);
    final onAccent = isDark ? const Color(0xFF1A1206) : Colors.white;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: colors.accent,
      onPrimary: onAccent,
      surface: colors.bg,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      outline: colors.border,
      error: colors.danger,
      surfaceContainerHighest: colors.card,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bg,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: colors.text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: colors.accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? colors.accent : colors.muted);
        }),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.cardRaised,
        contentTextStyle: TextStyle(color: colors.text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: onAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }
}

/// Маленький заголовок-капс для секций (используется в настройках и шапках).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: context.colors.muted,
        ),
      ),
    );
  }
}