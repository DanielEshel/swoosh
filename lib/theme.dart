// lib/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1D3557);
  static const Color textColor = Colors.black;
  static const Color secondaryColor = Colors.amber;
  static const Color backgroundColor = Colors.white;

  // light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      onPrimaryContainer: Colors.white,
      primaryContainer: primaryColor,
      secondaryContainer: Colors.white,
      secondary: secondaryColor,
      surface: backgroundColor,
    ),
    textTheme: TextTheme(
      
      // text logo theme
      headlineLarge: GoogleFonts.monda(
        fontSize: 48, fontWeight: FontWeight.bold, color: primaryColor),
      // text logo theme
      headlineMedium: GoogleFonts.monda(
        fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),

      // Titles
      displayLarge: GoogleFonts.monda(
        fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
      displayMedium: GoogleFonts.monda(
        fontSize: 28, fontWeight: FontWeight.w600, color: primaryColor),
      titleLarge: GoogleFonts.monda(
        fontSize: 22, fontWeight: FontWeight.w600, color: primaryColor),

      // Subtitles
      titleMedium: GoogleFonts.monda(
        fontSize: 18, fontWeight: FontWeight.w500, color: secondaryColor),
      titleSmall: GoogleFonts.monda(
        fontSize: 16, fontWeight: FontWeight.w400, color: secondaryColor),

      // Body
      bodyLarge: GoogleFonts.karla(
        fontSize: 18, fontWeight: FontWeight.normal, color: Colors.black87),
      bodyMedium: GoogleFonts.karla(
        fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black87),
      bodySmall: GoogleFonts.karla(
        fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black54),

      // Labels
      labelLarge: GoogleFonts.karla(
        fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
      labelMedium: GoogleFonts.karla(
        fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor),
      labelSmall: GoogleFonts.karla(
        fontSize: 10, fontWeight: FontWeight.w400, color: Colors.grey),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
    ),
  );
}
