import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Tipografía editorial: Fraunces para titulares, Inter para interfaz.
class AppType {
  static const display = 'Fraunces';
  static const ui = 'Inter';
  static const reading = 'Literata';

  static TextTheme textTheme(Color ink, Color soft) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: display,
        fontSize: 46,
        height: 1.04,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontFamily: display,
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontFamily: display,
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: display,
        fontSize: 26,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: display,
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: display,
        fontSize: 20,
        height: 1.24,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: display,
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: ui,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontFamily: ui,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: ui,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontFamily: ui,
        fontSize: 12.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: soft,
      ),
      labelLarge: TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontFamily: ui,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: soft,
      ),
      labelSmall: TextStyle(
        fontFamily: ui,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: soft,
      ),
    );
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.light ? AppPalette.light : AppPalette.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: palette.primarySoft,
    onPrimaryContainer: palette.ink,
    secondary: palette.sage,
    onSecondary: palette.surface,
    secondaryContainer: palette.surfaceAlt,
    onSecondaryContainer: palette.ink,
    tertiary: palette.gold,
    onTertiary: palette.ink,
    error: palette.danger,
    onError: palette.onPrimary,
    surface: palette.surface,
    onSurface: palette.ink,
    surfaceContainerHighest: palette.surfaceAlt,
    onSurfaceVariant: palette.inkSoft,
    outline: palette.outline,
    outlineVariant: palette.outline.withValues(alpha: 0.55),
    shadow: palette.shadow,
    scrim: palette.shadow,
    inverseSurface: palette.ink,
    onInverseSurface: palette.surface,
    inversePrimary: palette.gold,
  );

  const radius = BorderRadius.all(Radius.circular(16));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AppType.ui,
    scaffoldBackgroundColor: palette.background,
    textTheme: AppType.textTheme(palette.ink, palette.inkSoft),
    extensions: [palette],
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: palette.ink, size: 22),
      titleTextStyle: AppType.textTheme(palette.ink, palette.inkSoft).titleLarge,
      foregroundColor: palette.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.outline,
        disabledForegroundColor: palette.inkSoft,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: AppType.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.outline),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: AppType.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        textStyle: const TextStyle(
          fontFamily: AppType.ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.ink,
        highlightColor: palette.primary.withValues(alpha: 0.1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      selectedColor: palette.primary,
      disabledColor: palette.surfaceAlt,
      side: BorderSide(color: palette.outline.withValues(alpha: 0.8)),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      labelStyle: TextStyle(
        fontFamily: AppType.ui,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: palette.inkSoft,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: AppType.ui,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.onPrimary,
      ),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.inkSoft, fontFamily: AppType.ui),
      labelStyle: TextStyle(color: palette.inkSoft, fontFamily: AppType.ui),
      prefixIconColor: palette.inkSoft,
      suffixIconColor: palette.inkSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.outline.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.danger),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surface,
      modalBarrierColor: palette.shadow.withValues(alpha: 0.45),
      showDragHandle: true,
      dragHandleColor: palette.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: AppType.textTheme(palette.ink, palette.inkSoft).headlineSmall,
      contentTextStyle: AppType.textTheme(palette.ink, palette.inkSoft).bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(
        fontFamily: AppType.ui,
        color: palette.surface,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: palette.gold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.primary,
      inactiveTrackColor: palette.outline,
      thumbColor: palette.primary,
      overlayColor: palette.primary.withValues(alpha: 0.14),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.onPrimary;
        return palette.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.primary;
        return palette.outline;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(
      color: palette.outline.withValues(alpha: 0.65),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.outline.withValues(alpha: 0.7),
      linearMinHeight: 3,
      refreshBackgroundColor: palette.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.primarySoft,
      elevation: 0,
      height: 70,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: AppType.ui,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? palette.primary : palette.inkSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 23,
          color: selected ? palette.primary : palette.inkSoft,
        );
      }),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        color: palette.surface,
        fontFamily: AppType.ui,
        fontSize: 12,
      ),
    ),
  );
}
