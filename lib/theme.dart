import 'package:flutter/material.dart';

/// Шрифт для заголовков (Outlast Trials vibe). Должен совпадать с family в pubspec.
const String kDisplayFont = 'BASE02';

/// Акцентные цвета, которые можно выбрать в настройках.
enum AccentChoice {
  amber('Янтарь', Color(0xFFE2A23B)),
  crimson('Багрянец', Color(0xFFD94A4A)),
  toxic('Токсин', Color(0xFF43C46A)),
  ocean('Океан', Color(0xFF4FA3E3)),
  violet('Виолет', Color(0xFFA98BF0)),
  steel('Сталь', Color(0xFF8FA3B8));

  const AccentChoice(this.label, this.color);

  final String label;
  final Color color;

  static AccentChoice fromName(String? name) => values.firstWhere(
    (e) => e.name == name,
    orElse: () => AccentChoice.crimson,
  );
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
    required this.glow,
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
  final Color glow;

  factory FreyaColors.dark(Color accent) => FreyaColors(
    bg: const Color(0xFF050607),
    card: const Color(0xFF101316),
    cardRaised: const Color(0xFF171B20),
    border: const Color(0xFF23282F),
    text: const Color(0xFFF2F3F5),
    muted: const Color(0xFF8A939E),
    accent: accent,
    accentSoft: accent.withValues(alpha: 0.14),
    danger: const Color(0xFFFF5C4D),
    dangerSoft: const Color(0xFF3A1714),
    glow: accent.withValues(alpha: 0.22),
  );

  factory FreyaColors.light(Color accent) => FreyaColors(
    bg: const Color(0xFFF1F3F6),
    card: const Color(0xFFFFFFFF),
    cardRaised: const Color(0xFFE8EBEF),
    border: const Color(0xFFD5DAE1),
    text: const Color(0xFF111418),
    muted: const Color(0xFF5E6976),
    accent: accent,
    accentSoft: accent.withValues(alpha: 0.14),
    danger: const Color(0xFFD94436),
    dangerSoft: const Color(0xFFFBE7E5),
    glow: accent.withValues(alpha: 0.18),
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
    Color? glow,
  }) => FreyaColors(
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
    glow: glow ?? this.glow,
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
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

/// Доступ к палитре из виджета.
extension FreyaColorsContext on BuildContext {
  FreyaColors get colors =>
      Theme.of(this).extension<FreyaColors>() ??
      FreyaColors.dark(AccentChoice.crimson.color);
}

class FreyaTheme {
  FreyaTheme._();

  static ThemeData build({
    required Brightness brightness,
    required Color accent,
  }) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark
        ? FreyaColors.dark(accent)
        : FreyaColors.light(accent);
    final onAccent = isDark ? const Color(0xFF08090B) : Colors.white;

    final scheme =
        ColorScheme.fromSeed(
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

    final textTheme = base.textTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 22,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.2,
          color: colors.text,
        ),
        iconTheme: IconThemeData(color: colors.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: colors.accent.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: selected ? colors.accent : colors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? colors.accent : colors.muted,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
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
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 20,
          letterSpacing: 0.8,
          color: colors.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: onAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.cardRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.accent),
        ),
        labelStyle: TextStyle(color: colors.muted),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

/// Заголовок-секция (стиль Outlast Trials: крупный штамп BASE02).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: context.colors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: kDisplayFont,
              fontSize: 14,
              letterSpacing: 1.8,
              color: context.colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
