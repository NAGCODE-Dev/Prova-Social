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

abstract final class EmeraldColors {
  static const background = Color(0xFF050907);
  static const backgroundSecondary = Color(0xFF080F0C);
  static const surface = Color(0xFF101A15);
  static const surfaceElevated = Color(0xFF14231B);
  static const surfaceHighlight = Color(0xFF193329);
  static const primary = Color(0xFF20D99A);
  static const primaryLight = Color(0xFF50F0B5);
  static const primaryDark = Color(0xFF087C52);
  static const primaryGlow = Color(0xFF00E6A0);
  static const textPrimary = Color(0xFFF5F7F6);
  static const textSecondary = Color(0xFFAAB7B0);
  static const textMuted = Color(0xFF718078);
  static const border = Color(0xFF23382E);
  static const borderHighlight = Color(0xFF176B4A);
  static const error = Color(0xFFFF6464);
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
      primary: EmeraldColors.primary,
      onPrimary: EmeraldColors.background,
      secondary: EmeraldColors.primaryLight,
      onSecondary: EmeraldColors.background,
      surface: EmeraldColors.surface,
      onSurface: EmeraldColors.textPrimary,
      onSurfaceVariant: EmeraldColors.textSecondary,
      error: EmeraldColors.error,
      onError: EmeraldColors.background,
      outline: EmeraldColors.border,
      surfaceContainerHighest: EmeraldColors.surfaceElevated,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 44,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: EmeraldColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 38,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: EmeraldColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: EmeraldColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: EmeraldColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: EmeraldColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.45,
          color: EmeraldColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: EmeraldColors.textSecondary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: EmeraldColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: EmeraldColors.border),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: EmeraldColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: EmeraldColors.primary,
            width: 1.5,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        hintStyle: const TextStyle(color: EmeraldColors.textMuted),
        labelStyle: const TextStyle(color: EmeraldColors.textSecondary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EmeraldColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: EmeraldColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: EmeraldColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: EmeraldColors.surfaceHighlight,
        height: 96,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 58),
          backgroundColor: EmeraldColors.primary,
          foregroundColor: EmeraldColors.background,
          elevation: 3,
          shadowColor: EmeraldColors.primaryGlow.withValues(alpha: .18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 58),
          foregroundColor: EmeraldColors.primaryLight,
          side: const BorderSide(
            color: EmeraldColors.borderHighlight,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerColor: EmeraldColors.border,
    );
  }
}
