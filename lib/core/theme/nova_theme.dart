import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'nova_colors.dart';
import 'nova_spacing.dart';
import 'nova_typography.dart';

/// Tema Canônico do NovaReader
class NovaTheme {
  NovaTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NovaColors.background,
      primaryColor: NovaColors.accent,
      colorScheme: const ColorScheme.dark(
        surface: NovaColors.surface,
        onSurface: NovaColors.textPrimary,
        primary: NovaColors.accent,
        onPrimary: NovaColors.background,
        secondary: NovaColors.accentDark,
        onSecondary: NovaColors.textPrimary,
        error: NovaColors.error,
        onError: NovaColors.background,
        outline: NovaColors.border,
      ),
      dividerTheme: const DividerThemeData(
        color: NovaColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NovaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: NovaColors.textPrimary),
        titleTextStyle: NovaTypography.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: NovaColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: NovaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: NovaShapes.roundedMd,
          side: const BorderSide(color: NovaColors.border, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: NovaColors.surface,
        selectedItemColor: NovaColors.textPrimary,
        unselectedItemColor: NovaColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8.0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: NovaColors.surface,
        selectedIconTheme: IconThemeData(color: NovaColors.textPrimary),
        unselectedIconTheme: IconThemeData(color: NovaColors.textMuted),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: NovaColors.textPrimary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: NovaColors.textMuted,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Tema com acento secundário do perfil (G-07). O [accent] substitui o
  /// primário/secundário do `ColorScheme`; o restante permanece monocromático.
  static ThemeData darkThemeWithAccent(Color accent) {
    final base = darkTheme;
    return base.copyWith(
      primaryColor: accent,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
      ),
    );
  }
}
