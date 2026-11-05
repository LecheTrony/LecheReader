import 'package:flutter/material.dart';

/// Paleta cálida de inspiración editorial: papel, tinta y terracota.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.outline,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.sage,
    required this.gold,
    required this.danger,
    required this.shadow,
    required this.coverFallback,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color outline;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color sage;
  final Color gold;
  final Color danger;
  final Color shadow;
  final List<Color> coverFallback;

  static const light = AppPalette(
    background: Color(0xFFF4EDE1),
    surface: Color(0xFFFFFBF3),
    surfaceAlt: Color(0xFFEDE2D1),
    ink: Color(0xFF251D17),
    inkSoft: Color(0xFF6F6155),
    outline: Color(0xFFDACAB4),
    primary: Color(0xFFB4552D),
    primarySoft: Color(0xFFF2DBCC),
    onPrimary: Color(0xFFFFF8F1),
    sage: Color(0xFF6C7A5B),
    gold: Color(0xFFC99A3F),
    danger: Color(0xFFA33B2B),
    shadow: Color(0xFF2A160C),
    coverFallback: [
      Color(0xFF9C5A3C),
      Color(0xFF6C7A5B),
      Color(0xFF4E6070),
      Color(0xFF8A6A3B),
    ],
  );

  static const dark = AppPalette(
    background: Color(0xFF141110),
    surface: Color(0xFF1E1916),
    surfaceAlt: Color(0xFF2A221D),
    ink: Color(0xFFF2E8DA),
    inkSoft: Color(0xFFB0A091),
    outline: Color(0xFF3C322A),
    primary: Color(0xFFE0926C),
    primarySoft: Color(0xFF3A261D),
    onPrimary: Color(0xFF2A130A),
    sage: Color(0xFF9AA986),
    gold: Color(0xFFDDB86A),
    danger: Color(0xFFE5897A),
    shadow: Color(0xFF000000),
    coverFallback: [
      Color(0xFF8E4E33),
      Color(0xFF556249),
      Color(0xFF3E4F5E),
      Color(0xFF755A31),
    ],
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkSoft,
    Color? outline,
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? sage,
    Color? gold,
    Color? danger,
    Color? shadow,
    List<Color>? coverFallback,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      sage: sage ?? this.sage,
      gold: gold ?? this.gold,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      coverFallback: coverFallback ?? this.coverFallback,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      coverFallback: coverFallback,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

/// Colores de lectura, independientes del tema de la interfaz.
enum ReaderTheme {
  paper('Papel', Color(0xFFFBF4E7), Color(0xFF2B221B), Color(0xFF8A7663)),
  sepia('Sépia', Color(0xFFF1E0C2), Color(0xFF3A2C1E), Color(0xFF8B7458)),
  night('Noche', Color(0xFF131110), Color(0xFFD9CDBD), Color(0xFF8F8172)),
  slate('Pizarra', Color(0xFF1B2228), Color(0xFFCFD8DC), Color(0xFF7C8A92));

  const ReaderTheme(this.label, this.background, this.text, this.muted);

  final String label;
  final Color background;
  final Color text;
  final Color muted;
}
