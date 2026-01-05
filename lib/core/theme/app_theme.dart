import 'package:flutter/material.dart';
import '../config/constants.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Qanelas', // ✅ GLOBAL FONT

      textTheme: _textTheme(Brightness.light),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radius),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Qanelas', // ✅ GLOBAL FONT

      textTheme: _textTheme(Brightness.dark),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radius),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;

    return base.copyWith(
      // Headings
      headlineLarge: const TextStyle(fontWeight: FontWeight.w800),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w600),

      // Body
      bodyLarge: const TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400),
      bodySmall: const TextStyle(fontWeight: FontWeight.w300),

      // Labels / Buttons
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(fontWeight: FontWeight.w500),
      labelSmall: const TextStyle(fontWeight: FontWeight.w400),
    );
  }
}
