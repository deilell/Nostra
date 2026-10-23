import 'package:flutter/material.dart';

/// Design tokens for Nostra.
class AppColors {
  static const Color primary = Color(0xFF2D9CDB);
  static const Color primaryDark = Color(0xFF1E7AB5);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF2994A);
  static const Color error = Color(0xFFEB5757);

  // Dark scheme
  static const Color darkBg = Color(0xFF0F1218);
  static const Color darkSurface = Color(0xFF1A1E27);
  static const Color darkSurface2 = Color(0xFF232833);
  static const Color darkBorder = Color(0xFF2C3340);
  static const Color darkText = Color(0xFFE8ECF1);
  static const Color darkTextDim = Color(0xFF8A93A6);
  static const Color darkBubbleSelf = Color(0xFF2D9CDB);
  static const Color darkBubbleOther = Color(0xFF2A3040);

  // Light scheme
  static const Color lightBg = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEEF1F6);
  static const Color lightBorder = Color(0xFFE2E6EE);
  static const Color lightText = Color(0xFF1A1D24);
  static const Color lightTextDim = Color(0xFF6B7280);
  static const Color lightBubbleSelf = Color(0xFF2D9CDB);
  static const Color lightBubbleOther = Color(0xFFE8ECF2);
}

class AppRadii {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

class AppText {
  static const double display = 28;
  static const double title = 20;
  static const double body = 15;
  static const double caption = 13;
  static const double timestamp = 11;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final textDim = isDark ? AppColors.darkTextDim : AppColors.lightTextDim;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: b,
      ).copyWith(surface: surface),
      cardColor: surface,
      dividerColor: border,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: AppText.display, fontWeight: FontWeight.w700, color: text),
        titleLarge: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w600, color: text),
        bodyMedium: TextStyle(fontSize: AppText.body, color: text, height: 1.4),
        bodySmall: TextStyle(fontSize: AppText.caption, color: textDim),
        labelSmall: TextStyle(fontSize: AppText.timestamp, color: textDim),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w700, color: text),
        iconTheme: IconThemeData(color: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: TextStyle(color: textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.l),
          side: BorderSide(color: border, width: 0.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textDim,
        titleTextStyle: TextStyle(fontSize: AppText.body, color: text, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(fontSize: AppText.caption, color: textDim),
      ),
    );
  }
}
