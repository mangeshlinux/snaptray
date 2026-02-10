import 'package:flutter/material.dart';

class SnapAppTheme {
  // Calmer, more sophisticated seed colors
  static const Color windowsSeed = Color(
    0xFF6366F1,
  ); // Indigo (Calm/Professional)
  static const Color androidSeed = Color(0xFF10B981); // Emerald (Fresh/Calm)

  // Base Seed (Default)
  static const Color seedColor = Color(0xFF475569); // Slate (Neutral)

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
        surface: const Color(0xFFF8FAFC), // Slate-50
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF0F172A), // Slate-900
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
