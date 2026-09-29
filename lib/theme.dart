import 'package:flutter/material.dart';

/// Дизайн-токены Freya: тёмная, спокойная палитра с одним тёплым акцентом.
const Color kBg = Color(0xFF0A0C0F);
const Color kCard = Color(0xFF14171D);
const Color kCardRaised = Color(0xFF1A1E26);
const Color kBorder = Color(0xFF232833);
const Color kText = Color(0xFFF0F1F4);
const Color kMuted = Color(0xFF97A0AC);
const Color kAccent = Color(0xFFF2B554);
const Color kAccentSoft = Color(0xFF32270F);
const Color kDanger = Color(0xFFFF6B5E);
const Color kDangerSoft = Color(0xFF3A1D19);

class FreyaTheme {
  FreyaTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kAccent,
      onPrimary: const Color(0xFF1A1206),
      surface: kBg,
      onSurface: kText,
      onSurfaceVariant: kMuted,
      outline: kBorder,
      error: kDanger,
      surfaceContainerHighest: kCard,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: kBg,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: kText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: kAccent.withValues(alpha: 0.16),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? kAccent : kMuted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: kBorder, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kCardRaised,
        contentTextStyle: const TextStyle(color: kText, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kBorder),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: kCardRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: const Color(0xFF1A1206),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: kMuted,
        ),
      ),
    );
  }
}