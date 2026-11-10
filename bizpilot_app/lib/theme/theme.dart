import 'package:flutter/material.dart';

class AppColors {
  // Slate & Navy primary surfaces
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  // Brand Accents
  static const Color indigoPrimary = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFF6366F1);
  static const Color indigoSubtle = Color(0xFFEEF2FF);

  // Functional Accents
  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color emeraldSubtle = Color(0xFFECFDF5);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color amberSubtle = Color(0xFFFFFBEB);
  static const Color roseDanger = Color(0xFFF43F5E);
  static const Color roseSubtle = Color(0xFFFFF1F2);
  static const Color cyanInfo = Color(0xFF06B6D4);
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color cyanSubtle = Color(0xFFECFEFF);
}

class AppTheme {
  static const TextStyle tabularStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.indigoPrimary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.indigoSubtle,
        onPrimaryContainer: AppColors.indigoPrimary,
        secondary: AppColors.slate700,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.slate900,
        surfaceContainerHighest: AppColors.slate100,
        error: AppColors.roseDanger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.slate50,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.slate900,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.slate200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.indigoPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.roseDanger, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.slate600, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigoPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.slate800,
          side: const BorderSide(color: AppColors.slate300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.indigoSubtle,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.indigoPrimary, size: 24);
          }
          return const IconThemeData(color: AppColors.slate500, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.indigoPrimary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.indigoLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.slate800,
        onPrimaryContainer: AppColors.indigoLight,
        secondary: AppColors.slate300,
        onSecondary: AppColors.slate950,
        surface: AppColors.slate900,
        onSurface: AppColors.slate100,
        surfaceContainerHighest: AppColors.slate800,
        error: AppColors.roseDanger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.slate950,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate900,
        foregroundColor: AppColors.slate100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.slate100,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.slate900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.slate800, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.slate800,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
