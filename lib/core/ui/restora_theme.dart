import 'package:flutter/material.dart';

abstract final class RestoraColors {
  static const canvas = Color(0xfff6f8f5);
  static const ink = Color(0xff193d35);
  static const muted = Color(0xff5c7068);
  static const teal = Color(0xff246b5b);
  static const paleTeal = Color(0xffe7f1eb);
  static const border = Color(0xffdce5de);
  static const amber = Color(0xff795b1c);
  static const paleAmber = Color(0xfffff1d6);
  static const danger = Color(0xffa73535);
  static const paleDanger = Color(0xffffeded);
}

abstract final class RestoraTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: RestoraColors.teal,
          brightness: Brightness.light,
        ).copyWith(
          primary: RestoraColors.teal,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: RestoraColors.ink,
          onSurfaceVariant: RestoraColors.muted,
          outlineVariant: RestoraColors.border,
          error: RestoraColors.danger,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: RestoraColors.canvas,
      textTheme: base.textTheme
          .apply(bodyColor: RestoraColors.ink, displayColor: RestoraColors.ink)
          .copyWith(
            headlineLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: RestoraColors.ink,
            ),
            headlineMedium: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: RestoraColors.ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: RestoraColors.ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: RestoraColors.ink,
            ),
            bodyLarge: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: RestoraColors.ink,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: RestoraColors.ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RestoraColors.canvas,
        foregroundColor: RestoraColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: RestoraColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: RestoraColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RestoraColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RestoraColors.teal, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: RestoraColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      dividerColor: RestoraColors.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RestoraColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
