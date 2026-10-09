import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHover = Color(0xFFF1F4F1);
  static const ink = Color(0xFF171A18);
  static const muted = Color(0xFF68706B);
  static const line = Color(0xFFE3E7E4);
  static const brand = Color(0xFF16A36A);
  static const brandHover = Color(0xFF12875A);
  static const brandSoft = Color(0xFFE7F6EF);
  static const mint = Color(0xFF74E3B5);
  static const warning = Color(0xFFE5A524);
  static const success = Color(0xFF16A36A);
  static const danger = Color(0xFFDC4C4C);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

abstract final class AppMotion {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 400);

  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : duration;
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      // White labels on the brighter brand green miss comfortable contrast.
      // Keep that green as an accent and use the deeper brand shade for actions.
      primary: AppColors.brandHover,
      onPrimary: Colors.white,
      secondary: AppColors.brand,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.line,
      surfaceContainerHighest: AppColors.surfaceHover,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandSoft,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerColor: AppColors.line,
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF63D6A3),
      onPrimary: Color(0xFF062A1B),
      secondary: Color(0xFF74E3B5),
      onSecondary: Color(0xFF062A1B),
      surface: Color(0xFF181C19),
      onSurface: Color(0xFFF3F5F3),
      error: Color(0xFFFF8B8B),
      onError: Color(0xFF310B0B),
      outline: Color(0xFF2A302C),
      surfaceContainerHighest: Color(0xFF242A26),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF101311),
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF181C19),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF2A302C)),
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101311),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFFF3F5F3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF63D6A3), width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A302C),
        contentTextStyle: const TextStyle(color: Color(0xFFF3F5F3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF181C19),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Color(0xFF244B37),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFF2A302C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      dividerColor: scheme.outline,
    );
  }
}
